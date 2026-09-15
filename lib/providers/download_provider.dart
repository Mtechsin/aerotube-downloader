import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:path/path.dart' as p;

import '../services/ytdlp/ytdlp_service_windows.dart';
import '../services/notification/notification_service.dart';
import '../services/core/logging_service.dart';
import '../models/video_info.dart';
import '../models/download_item.dart';
import '../models/download_mode.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/downloaded_file_finder.dart';
import '../core/utils/error_helper.dart';

class DownloadProvider extends ChangeNotifier with WidgetsBindingObserver {
  final dynamic _ytdlpService;
  final NotificationService? _notificationService;
  final dynamic
  _settingsProvider; // Can be SettingsProvider or PlatformSettingsProvider

  // Active downloads (in memory only while active)
  final List<DownloadItem> _activeDownloads = [];

  // PF2 fix: cached unmodifiable views for select identity stability
  List<DownloadItem>? _cachedActiveDownloads;
  List<DownloadItem>? _cachedHistoryDownloads;
  List<DownloadItem>? _cachedDownloads;
  bool _activeDirty = true;
  bool _historyDirty = true;
  bool _downloadsDirty = true;

  void _markActiveDirty() {
    _activeDirty = true;
    _downloadsDirty = true;
  }

  void _markHistoryDirty() {
    _historyDirty = true;
    _downloadsDirty = true;
  }

  // Shutdown state
  bool _isShuttingDown = false;
  bool get isShuttingDown => _isShuttingDown;

  // History downloads (persisted)
  List<DownloadItem> _historyDownloads = [];

  final Map<String, Process> _activeProcesses = {};

  late Box<DownloadItem> _downloadsBox;
  late Box<DownloadItem> _activeDownloadsBox;
  bool _isInit = false;

  // B21/B27 fix: collision-free ID counter for unique history keys
  static int _idCounter = 0;
  // P5 fix: idle timer must be cancelled in dispose
  Timer? _activeBoxIdleTimer;

  // PF1 fix: throttle stdout progress notifications to max 10/sec (100 ms)
  // Mirrors ToolUpdateProvider throttling (tool_update_provider:87-90)
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _throttleMs = 100;
  // Compat aliases for existing code/tests expecting _lastProgressNotify naming
  // ignore: unused_element, unnecessary_getters_setters
  DateTime get _lastProgressNotify => _lastNotify;
  // ignore: unused_element, unnecessary_getters_setters
  set _lastProgressNotify(DateTime v) => _lastNotify = v;
  // ignore: unused_field
  static const int _progressThrottleMs = _throttleMs;

  void _throttledNotify() {
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds >= _throttleMs) {
      _lastNotify = now;
      // PF2 cache invalidation: progress mutates _activeDownloads
      _markActiveDirty();
      notifyListeners();
    }
  }

  DownloadProvider(
    this._ytdlpService,
    this._notificationService,
    this._settingsProvider,
  ) {
    _initHive();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Safely open a Hive box, deleting and recreating it if it is corrupted
  /// (e.g. unknown typeId 33). Recovery is logged and surfaced gracefully.
  Future<Box<DownloadItem>> _openBoxWithRecovery(String boxName) async {
    try {
      return await Hive.openBox<DownloadItem>(boxName);
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Hive box "$boxName" open failed ($e). Attempting corruption recovery...',
        component: 'DownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );

      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (delErr) {
        LoggingService().warning(
          'Hive.deleteBoxFromDisk for "$boxName" failed ($delErr)',
          component: 'DownloadProvider',
        );
      }

      try {
        return await Hive.openBox<DownloadItem>(boxName);
      } catch (retryErr, retrySt) {
        LoggingService().warning(
          'Reopening box "$boxName" failed ($retryErr). Falling back to recovery box...',
          component: 'DownloadProvider',
          error: retryErr,
          stackTrace: retrySt,
        );
        try {
          return await Hive.openBox<DownloadItem>('${boxName}_recovered');
        } catch (fallbackErr, fallbackSt) {
          LoggingService().error(
            'Failed to open fallback box for "$boxName": $fallbackErr',
            component: 'DownloadProvider',
            error: fallbackErr,
            stackTrace: fallbackSt,
          );
          rethrow;
        }
      }
    }
  }

  Completer<void>? _initCompleter;

  Future<void> _initHive() async {
    if (_isInit) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    try {
      _downloadsBox =
          await _openBoxWithRecovery(AppConstants.downloadsHistoryBox);
      _activeDownloadsBox =
          await _openBoxWithRecovery(AppConstants.activeDownloadsBox);
      await _restoreOrphanedDownloads();
      _loadHistory();
      if (!_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
    } catch (e, stackTrace) {
      LoggingService().error(
        'Failed to initialize Hive boxes: $e',
        component: 'DownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
      // Ensure boxes are at least openable as empty fallback
      try {
        if (!Hive.isBoxOpen(AppConstants.downloadsHistoryBox)) {
          _downloadsBox =
              await Hive.openBox<DownloadItem>('${AppConstants.downloadsHistoryBox}_fallback');
        }
      } catch (_) {}
      try {
        if (!Hive.isBoxOpen(AppConstants.activeDownloadsBox)) {
          _activeDownloadsBox =
              await Hive.openBox<DownloadItem>('${AppConstants.activeDownloadsBox}_fallback');
        }
      } catch (_) {}
      if (!_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
    } finally {
      _isInit = true;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _initiateGracefulShutdown();
    }
  }

  Future<void> _initiateGracefulShutdown() async {
    if (_isShuttingDown) return;
    _isShuttingDown = true;

    LoggingService().info(
      'Initiating graceful shutdown - pausing active downloads',
      component: 'DownloadProvider',
    );

    final activeItems = _activeDownloads
        .where(
          (item) =>
              item.status == DownloadStatus.downloadingVideo ||
              item.status == DownloadStatus.downloadingAudio ||
              item.status == DownloadStatus.merging,
        )
        .toList();

    for (final item in activeItems) {
      await _pauseDownloadGracefully(item.id);
    }

    await _saveActiveDownloads();

    LoggingService().info(
      'Graceful shutdown completed - ${activeItems.length} downloads paused',
      component: 'DownloadProvider',
    );
  }

  Future<void> _pauseDownloadGracefully(String id) async {
    final process = _activeProcesses[id];
    if (process != null) {
      try {
        process.kill(ProcessSignal.sigterm);
        try {
          await process.exitCode.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          try {
            process.kill(ProcessSignal.sigkill);
          } catch (_) {}
          try {
            await process.exitCode.timeout(const Duration(seconds: 1));
          } catch (_) {}
        }
      } catch (e) {
        LoggingService().warning(
          'Failed to send SIGTERM to download $id: $e',
          component: 'DownloadProvider',
        );
        try {
          process.kill(ProcessSignal.sigkill);
        } catch (_) {}
      } finally {
        _activeProcesses.remove(id);
      }
    }

    final index = _activeDownloads.indexWhere((d) => d.id == id);
    if (index != -1) {
      final item = _activeDownloads[index];
      if (item.status == DownloadStatus.downloadingVideo ||
          item.status == DownloadStatus.downloadingAudio ||
          item.status == DownloadStatus.merging ||
          item.status == DownloadStatus.queued ||
          item.status == DownloadStatus.pending) {
        _activeDownloads[index] = item.copyWith(status: DownloadStatus.paused);
        _markActiveDirty();
      }
    }
  }

  void _loadHistory() {
    try {
      final List<DownloadItem> loaded = [];
      // Read per-key to isolate corrupted entries (e.g. unknown typeId 33).
      for (final key in _downloadsBox.keys) {
        try {
          final item = _downloadsBox.get(key);
          if (item != null) loaded.add(item);
        } catch (e, stackTrace) {
          LoggingService().warning(
            'Skipping corrupted history entry "$key": $e',
            component: 'DownloadProvider',
            error: e,
            stackTrace: stackTrace,
          );
          // Remove the corrupted entry so next startup succeeds.
          // Fire-and-forget: _loadHistory is sync.
          unawaited(_downloadsBox.delete(key).catchError((Object _, StackTrace __) {}));
        }
      }
      loaded.sort(
        (a, b) => (b.completedDate ?? DateTime.now()).compareTo(
          a.completedDate ?? DateTime.now(),
        ),
      );
      _historyDownloads = loaded;
    } catch (e, stackTrace) {
      // Reading keys/values itself threw (box-level corruption).
      LoggingService().warning(
        'Failed to load download history (corrupted box): $e. Resetting history.',
        component: 'DownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
      LoggingService().showUserLog(
        'Corrupted download history was reset to recover the app',
        isWarning: true,
      );
      _historyDownloads = [];
      unawaited(_downloadsBox.clear().catchError((Object _, StackTrace __) => 0));
    }
    _markHistoryDirty();
    notifyListeners();
  }

  List<DownloadItem> get activeDownloads {
    if (_activeDirty || _cachedActiveDownloads == null) {
      _cachedActiveDownloads = List.unmodifiable(_activeDownloads);
      _activeDirty = false;
    }
    return _cachedActiveDownloads!;
  }

  List<DownloadItem> get historyDownloads {
    if (_historyDirty || _cachedHistoryDownloads == null) {
      _cachedHistoryDownloads = List.unmodifiable(_historyDownloads);
      _historyDirty = false;
    }
    return _cachedHistoryDownloads!;
  }

  // Backwards compatibility getter if needed, or migration getter
  List<DownloadItem> get downloads {
    if (_downloadsDirty || _cachedDownloads == null) {
      _cachedDownloads = List.unmodifiable([
        ..._activeDownloads,
        ..._historyDownloads,
      ]);
      _downloadsDirty = false;
    }
    return _cachedDownloads!;
  }

  int get activeCount => _activeDownloads.length;
  int get activeRunningCount => _activeDownloads
      .where(
        (i) =>
            i.status == DownloadStatus.downloadingVideo ||
            i.status == DownloadStatus.downloadingAudio ||
            i.status == DownloadStatus.merging,
      )
      .length;

  int get pendingCount => _activeDownloads
      .where(
        (i) =>
            i.status == DownloadStatus.pending ||
            i.status == DownloadStatus.queued,
      )
      .length;

  int get pausedCount =>
      _activeDownloads.where((i) => i.status == DownloadStatus.paused).length;

  int get completedCount => _historyDownloads
      .length; // Approximate, assuming history is completed/failed

  Future<void> startDownload({
    required VideoInfo video,
    required String outputPath,
    required DownloadMode mode,
    String? formatId,
    String? audioFormatId,
    int? targetHeight,
    String? audioQuality,
    bool embedThumbnail = true,
    bool embedMetadata = true,
    List<String>? subtitleLanguages,
    bool embedSubtitles = false,
    bool sponsorBlock = false,
    bool useDownloadArchive = false,
    int? estimatedFileSize,
  }) async {
    LoggingService().info(
      'Queued download: ${video.title} (${mode.name})',
      component: 'DownloadProvider',
    );

    // Prevent duplicate active downloads of the same URL
    final existing = _activeDownloads.where(
      (d) =>
          d.url == video.url &&
          d.status != DownloadStatus.completed &&
          d.status != DownloadStatus.failed &&
          d.status != DownloadStatus.cancelled,
    );
    if (existing.isNotEmpty) {
      LoggingService().info(
        'Download already in queue: ${video.title}',
        component: 'DownloadProvider',
      );
      return;
    }

    // Normalize estimatedFileSize: treat 0 or negative as unknown (null)
    final normalizedSize = (estimatedFileSize != null && estimatedFileSize > 0)
        ? estimatedFileSize
        : null;

    // B21/B27 fix: use unique ID to avoid history overwrite on re-download
    final uniqueId = '${video.id}_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
    final item = DownloadItem(
      id: uniqueId,
      title: video.title,
      thumbnailUrl: video.thumbnailUrl,
      url: video.url,
      outputPath: outputPath,
      status: DownloadStatus.queued,
      audioOnly: mode == DownloadMode.audioOnly,
      formatId: formatId,
      audioFormatId: audioFormatId,
      videoQuality: targetHeight != null ? '${targetHeight}p' : null,
      audioQuality: audioQuality,
      subtitleLanguages: subtitleLanguages,
      embedSubtitles: embedSubtitles,
      sponsorBlock: sponsorBlock,
      useDownloadArchive: useDownloadArchive,
      totalBytes: normalizedSize,
    );

    _activeDownloads.add(item);
    _markActiveDirty();
    _saveActiveDownloads();
    notifyListeners();

    _processQueue();
  }

  /// PF10 fix: batched enqueue — single Hive write + single notify + single queue processing.
  /// Avoids N rebuilds / N Hive clear+put loops when queuing a playlist.
  Future<void> startDownloadsBatch({
    required List<VideoInfo> videos,
    required String outputPath,
    required DownloadMode mode,
    String? formatId,
    String? audioFormatId,
    int? targetHeight,
    String? audioQuality,
    bool embedThumbnail = true,
    bool embedMetadata = true,
    List<String>? subtitleLanguages,
    bool embedSubtitles = false,
    bool sponsorBlock = false,
    bool useDownloadArchive = false,
    int? estimatedFileSize,
  }) async {
    if (videos.isEmpty) return;

    // PF10: normalize estimatedFileSize once for the batch.
    final normalizedBatchSize =
        (estimatedFileSize != null && estimatedFileSize > 0)
            ? estimatedFileSize
            : null;

    LoggingService().info(
      'Queuing batch of ${videos.length} downloads (${mode.name})',
      component: 'DownloadProvider',
    );

    // Build set of active URLs (non-terminal) for O(1) dedup, matching startDownload filter.
    final activeUrls = <String>{};
    for (final d in _activeDownloads) {
      if (d.status != DownloadStatus.completed &&
          d.status != DownloadStatus.failed &&
          d.status != DownloadStatus.cancelled) {
        activeUrls.add(d.url);
      }
    }
    final seenUrls = <String>{};
    var added = 0;

    for (final video in videos) {
      if (video.url.isEmpty) continue;
      // Dedup within batch and against already-active downloads.
      if (seenUrls.contains(video.url) || activeUrls.contains(video.url)) {
        LoggingService().info(
          'Batch skip duplicate: ${video.title}',
          component: 'DownloadProvider',
        );
        continue;
      }
      seenUrls.add(video.url);
      activeUrls.add(video.url);

      final uniqueId =
          '${video.id}_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
      final item = DownloadItem(
        id: uniqueId,
        title: video.title,
        thumbnailUrl: video.thumbnailUrl,
        url: video.url,
        outputPath: outputPath,
        status: DownloadStatus.queued,
        audioOnly: mode == DownloadMode.audioOnly,
        formatId: formatId,
        audioFormatId: audioFormatId,
        videoQuality: targetHeight != null ? '${targetHeight}p' : null,
        audioQuality: audioQuality,
        subtitleLanguages: subtitleLanguages,
        embedSubtitles: embedSubtitles,
        sponsorBlock: sponsorBlock,
        useDownloadArchive: useDownloadArchive,
        totalBytes: normalizedBatchSize,
      );

      _activeDownloads.add(item);
      added++;
    }

    if (added == 0) {
      LoggingService().info(
        'Batch queue: no new items to add (all duplicates/empty)',
        component: 'DownloadProvider',
      );
      return;
    }

    _markActiveDirty();
    await _saveActiveDownloads();
    notifyListeners();
    _processQueue();

    LoggingService().info(
      'Batch queued $added/${videos.length} downloads',
      component: 'DownloadProvider',
    );
  }

  /// Process the download queue, starting as many downloads as allowed by maxConcurrentDownloads
  void _processQueue() {
    final maxConcurrent = _settingsProvider.maxConcurrentDownloads;
    final currentlyRunning = _activeDownloads
        .where(
          (item) =>
              item.status == DownloadStatus.downloadingVideo ||
              item.status == DownloadStatus.downloadingAudio ||
              item.status == DownloadStatus.merging,
        )
        .length;

    final availableSlots = maxConcurrent - currentlyRunning;
    if (availableSlots <= 0) return;

    // Start queued downloads (skip paused items)
    final queuedItems = _activeDownloads
        .where((item) => item.status == DownloadStatus.queued)
        .take(availableSlots)
        .toList();

    for (final item in queuedItems) {
      _startDownloadInternal(item);
    }
  }

  /// Internal method to actually start a download process
  Future<void> _startDownloadInternal(DownloadItem item) async {
    try {
      // Disk-space pre-flight (B10 fix): check available space before spawning yt-dlp
      if (item.totalBytes != null && item.totalBytes! > 0) {
        final available = await _getAvailableDiskSpace(item.outputPath);
        if (available != null) {
          const bufferBytes = 100 * 1024 * 1024; // 100 MiB safety margin
          final required = item.totalBytes! + bufferBytes;
          if (available < required) {
            LoggingService().warning(
              'Insufficient disk space for ${item.title}: need ${_formatBytes(required)}, available ${_formatBytes(available)}',
              component: 'DownloadProvider',
            );
            final idx = _activeDownloads.indexWhere((d) => d.id == item.id);
            if (idx != -1) {
              final failedItem = _activeDownloads[idx].copyWith(
                status: DownloadStatus.failed,
                error:
                    'Insufficient disk space. Need ${_formatBytes(item.totalBytes!)}, available ${_formatBytes(available)}. Free up space and try again.',
                completedDate: DateTime.now(),
              );
              _activeDownloads.removeAt(idx);
              _markActiveDirty();
              _saveActiveDownloads();
              await _addToHistory(failedItem);
              LoggingService().showUserLog(
                'Download failed: ${item.title} — insufficient disk space',
                isError: true,
              );
              _notificationService?.show(
                title: 'Download Failed',
                body: 'Insufficient disk space for ${item.title}',
                isError: true,
              );
              notifyListeners();
              _processQueue();
              return;
            }
          } else {
            LoggingService().debug(
              'Disk-space pre-flight passed for ${item.title}: need ${_formatBytes(required)}, available ${_formatBytes(available)}',
              component: 'DownloadProvider',
            );
          }
        } else {
          LoggingService().debug(
            'Unable to determine available disk space for ${item.outputPath}, proceeding anyway',
            component: 'DownloadProvider',
          );
        }
      } else {
        LoggingService().debug(
          'Skipping disk-space pre-flight: totalBytes unknown for ${item.title}',
          component: 'DownloadProvider',
        );
      }

      // yt-dlp --windows-filenames (set in _buildCommonArgs) strips
      // | : * ? " < > \ so titles like "A | B" don't fail on NTFS.
      final templatePath = '${item.outputPath}\\%(title)s.%(ext)s';

      // Build archive path if enabled
      // PF4 fix: async dir check/create to avoid blocking main isolate
      String? archivePath;
      if (item.useDownloadArchive) {
        final dir = Directory(item.outputPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        archivePath = '${item.outputPath}\\download_archive.txt';
      }

      final process = await _ytdlpService.downloadVideo(
        url: item.url,
        outputPath: templatePath,
        formatId: item.formatId,
        audioFormatId: item.audioFormatId,
        audioOnly: item.audioOnly,
        targetHeight: item.videoQuality != null
            ? int.tryParse(item.videoQuality!.replaceAll('p', ''))
            : null,
        audioQuality: item.audioQuality,
        embedThumbnail: _settingsProvider.embedThumbnail,
        embedMetadata: _settingsProvider.embedMetadata,
        subtitleLanguages: item.subtitleLanguages,
        embedSubtitles: item.embedSubtitles,
        sponsorBlock: item.sponsorBlock,
        archivePath: archivePath,
      );

      _activeProcesses[item.id] = process;

      final index = _activeDownloads.indexWhere((d) => d.id == item.id);
      if (index != -1) {
        _activeDownloads[index] = item.copyWith(
          status: DownloadStatus.downloadingVideo,
        );
        _markActiveDirty();
        notifyListeners();
      }

      // Handle Output - B5 fix: retain subscriptions to await done
      final stdoutSub = process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        final lines = data.split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;

          // Check for thumbnail path
          if (line.contains('Writing video thumbnail') ||
              line.contains('Writing thumbnail')) {
            final match = RegExp(
              r'Writing.*thumbnail.*to: (.+)',
            ).firstMatch(line);
            if (match != null) {
              final thumbPath = match.group(1)?.trim();
              if (thumbPath != null) {
                final idx = _activeDownloads.indexWhere((d) => d.id == item.id);
                if (idx != -1) {
                  _activeDownloads[idx] = _activeDownloads[idx].copyWith(
                    thumbnailPath: thumbPath,
                  );
                  _markActiveDirty();
                  _throttledNotify();
                }
              }
            }
          }

          final progress = YtdlpService.parseProgress(line);
          if (progress != null) {
            final idx = _activeDownloads.indexWhere((d) => d.id == item.id);
            if (idx != -1) {
              // B8 fix: clear stale speed during merge, ensure monotonic
              final isMerging = progress.status == DownloadStatus.merging;
              _activeDownloads[idx] = _activeDownloads[idx].copyWith(
                progress: progress.progress,
                speed: isMerging ? 0.0 : progress.speed,
                eta: isMerging ? 0 : progress.eta,
                status: progress.status ?? _activeDownloads[idx].status,
              );
              _markActiveDirty();
              _throttledNotify();
            }
          }
        }
      });

      final stderrBuffer = StringBuffer();
      final stderrSub = process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        stderrBuffer.write(data);
        if (data.trim().isNotEmpty) {
          LoggingService().debug(
            'yt-dlp stderr: ${data.trim()}',
            component: 'DownloadProvider',
          );
        }
      });

      // B4 watchdog: do not await indefinitely; kill process on prolonged hang
      int exitCode;
      try {
        exitCode = await process.exitCode.timeout(const Duration(hours: 6), onTimeout: () {
          try { process.kill(ProcessSignal.sigkill); } catch (_) {}
          try { process.kill(); } catch (_) {}
          throw TimeoutException('yt-dlp download timed out after 6h');
        });
      } on TimeoutException catch (e) {
        _activeProcesses.remove(item.id);
        try { await stdoutSub.cancel(); } catch (_) {}
        try { await stderrSub.cancel(); } catch (_) {}
        throw YtdlpException(e.message ?? 'Download timed out');
      }
      // B5 fix: await stream completion to avoid truncated error messages
      try {
        await Future.wait<void>([
          stdoutSub.asFuture<void>(),
          stderrSub.asFuture<void>(),
        ]).timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => [],
        );
      } catch (_) {}
      _activeProcesses.remove(item.id);

      final idx = _activeDownloads.indexWhere((d) => d.id == item.id);
      if (idx != -1) {
        DownloadItem finalItem = _activeDownloads[idx];

        if (exitCode == 0) {
          String? resolvedSavePath;
          try {
            final found = await _findDownloadedFile(item);
            if (found != null) {
              resolvedSavePath = found.path;
            }
          } catch (e) {
            LoggingService().error(
              'Failed to resolve downloaded file path: $e',
              component: 'DownloadProvider',
              error: e,
            );
          }

          finalItem = finalItem.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
            eta: 0,
            savePath: resolvedSavePath,
            completedDate: DateTime.now(),
          );

          _activeDownloads.removeAt(idx);
          _markActiveDirty();
          _saveActiveDownloads();
          _addToHistory(finalItem);

          LoggingService().info(
            'Download completed: ${finalItem.title}',
            component: 'DownloadProvider',
          );

          LoggingService().showUserLog('Download complete: ${finalItem.title}');

          _notificationService?.show(
            title: 'Download Complete',
            body: finalItem.title,
            onTap: () {
              Process.run('explorer', [finalItem.outputPath]);
            },
          );
        } else {
          if (finalItem.status == DownloadStatus.paused) {
            // Special-case paused: leave in active downloads so it stays resumable
            _saveActiveDownloads();
            _markActiveDirty();
          } else if (finalItem.status != DownloadStatus.cancelled) {
            final rawError = stderrBuffer.toString().trim();
            final errorMsg = ErrorHelper.formatDownloadError(
              rawError,
              exitCode,
            );
            finalItem = finalItem.copyWith(
              status: DownloadStatus.failed,
              error: errorMsg,
              completedDate: DateTime.now(),
            );
            _activeDownloads.removeAt(idx);
            _markActiveDirty();
            _saveActiveDownloads();
            _addToHistory(finalItem);

            LoggingService().error(
              'Download failed for ${finalItem.title}: $errorMsg',
              component: 'DownloadProvider',
            );

            LoggingService().showUserLog(
              'Download failed: ${finalItem.title} — $errorMsg',
              isError: true,
            );

            _notificationService?.show(
              title: 'Download Failed',
              body: errorMsg.length > 120
                  ? '${errorMsg.substring(0, 117)}...'
                  : errorMsg,
              isError: true,
            );
          } else {
            _activeDownloads.removeAt(idx);
            _markActiveDirty();
            _saveActiveDownloads();
            finalItem = finalItem.copyWith(completedDate: DateTime.now());
            _addToHistory(finalItem);
          }
        }
        notifyListeners();
      }

      // Process queue after completion
      _processQueue();
    } catch (e, stackTrace) {
      final logger = LoggingService();
      logger.error(
        'Download failed for ${item.title}',
        component: 'DownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );

      final idx = _activeDownloads.indexWhere((d) => d.id == item.id);
      if (idx != -1) {
        if (_activeDownloads[idx].status == DownloadStatus.paused) {
          _saveActiveDownloads();
          _markActiveDirty();
        } else if (_activeDownloads[idx].status == DownloadStatus.cancelled) {
          final finalItem = _activeDownloads[idx].copyWith(completedDate: DateTime.now());
          _activeDownloads.removeAt(idx);
          _markActiveDirty();
          _saveActiveDownloads();
          _addToHistory(finalItem);
        } else {
          final formattedError = ErrorHelper.formatDownloadError(e.toString());
          final finalItem = _activeDownloads[idx].copyWith(
            status: DownloadStatus.failed,
            error: formattedError,
            completedDate: DateTime.now(),
          );
          _activeDownloads.removeAt(idx);
          _markActiveDirty();
          _saveActiveDownloads();
          _addToHistory(finalItem);

          logger.showUserLog(
            'Download failed: ${finalItem.title}',
            isError: true,
          );

          _notificationService?.show(
            title: 'Download Failed',
            body: 'Failed to download ${finalItem.title}',
            isError: true,
          );
        }
      }
      _activeProcesses.remove(item.id);
      notifyListeners();

      // Process queue after failure
      _processQueue();
    }
  }

  void cancelDownload(String id) {
    if (_activeProcesses.containsKey(id)) {
      _activeProcesses[id]?.kill();
      _activeProcesses.remove(id);
    }

    final index = _activeDownloads.indexWhere((d) => d.id == id);
    if (index != -1) {
      final item = _activeDownloads[index];
      // B13 fix: queued/pending items have no process; move to history immediately
      if (item.status == DownloadStatus.queued ||
          item.status == DownloadStatus.pending) {
        final cancelledItem = item.copyWith(
          status: DownloadStatus.cancelled,
          completedDate: DateTime.now(),
        );
        _activeDownloads.removeAt(index);
        _markActiveDirty();
        _saveActiveDownloads();
        _addToHistory(cancelledItem);
        notifyListeners();
        _processQueue();
        return;
      }
      _activeDownloads[index] = _activeDownloads[index].copyWith(
        status: DownloadStatus.cancelled,
        completedDate: DateTime.now(),
      );
      _markActiveDirty();
      _saveActiveDownloads();
      notifyListeners();

      // Process queue after cancellation
      _processQueue();
    }
  }

  void pauseDownload(String id) {
    if (_activeProcesses.containsKey(id)) {
      _activeProcesses[id]?.kill();
      _activeProcesses.remove(id);
    }

    final index = _activeDownloads.indexWhere((d) => d.id == id);
    if (index != -1) {
      final item = _activeDownloads[index];
      if (item.status == DownloadStatus.downloadingVideo ||
          item.status == DownloadStatus.downloadingAudio ||
          item.status == DownloadStatus.merging ||
          item.status == DownloadStatus.queued ||
          item.status == DownloadStatus.pending) {
        _activeDownloads[index] = item.copyWith(status: DownloadStatus.paused);
        _markActiveDirty();
        _saveActiveDownloads();
        notifyListeners();
        _processQueue();
      }
    }
  }

  void resumeDownload(String id) {
    final index = _activeDownloads.indexWhere((d) => d.id == id);
    if (index != -1) {
      final item = _activeDownloads[index];
      if (item.status == DownloadStatus.paused) {
        _activeDownloads[index] = item.copyWith(status: DownloadStatus.queued);
        _markActiveDirty();
        _saveActiveDownloads();
        notifyListeners();
        _processQueue();
      }
    }
  }

  Future<void> _addToHistory(DownloadItem item) async {
    if (!_isInit) await _initHive();
    // B21/B27 fix: avoid overwriting history on re-download; use unique key if collision
    DownloadItem itemToStore = item;
    String key = item.id;
    if (_downloadsBox.containsKey(key)) {
      final newId = '${item.id}_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
      itemToStore = item.copyWith(id: newId);
      key = newId;
    }
    await _downloadsBox.put(key, itemToStore);
    // P6 fix: trim history to max 200 entries to prevent unbounded growth
    if (_downloadsBox.length > 200) {
      final entries = _downloadsBox.keys
          .map((k) => MapEntry(k, _downloadsBox.get(k)!))
          .toList()
        ..sort((a, b) => (a.value.completedDate ?? DateTime(1970))
            .compareTo(b.value.completedDate ?? DateTime(1970)));
      final excess = entries.length - 200;
      for (int i = 0; i < excess; i++) {
        await _downloadsBox.delete(entries[i].key);
      }
    }
    _loadHistory();
  }

  Future<void> deleteFromHistory(String id) async {
    if (!_isInit) return;
    await _downloadsBox.delete(id);
    _loadHistory();
  }

  Future<void> clearHistory() async {
    if (!_isInit) return;
    await _downloadsBox.clear();
    _loadHistory();
  }

  Future<void> clearCompleted() async {
    if (!_isInit) return;

    final keysToDelete = _historyDownloads
        .where((item) => item.status == DownloadStatus.completed)
        .map((item) => item.id)
        .toList();

    await _downloadsBox.deleteAll(keysToDelete);
    _loadHistory();
  }

  Future<void> retryDownload(String id) async {
    if (!_isInit) await _initHive();
    // Find the item in history
    final historyIndex = _historyDownloads.indexWhere((d) => d.id == id);
    if (historyIndex == -1) return;

    final item = _historyDownloads[historyIndex];

    // Remove from history
    await _downloadsBox.delete(id);
    _historyDownloads.removeAt(historyIndex);
    _markHistoryDirty();

    // Re-add to active downloads with reset state
    final retryItem = item.copyWith(
      status: DownloadStatus.queued,
      progress: 0.0,
      speed: 0.0,
      eta: 0,
      error: null,
      completedDate: null,
    );
    _activeDownloads.add(retryItem);
    _markActiveDirty();
    _saveActiveDownloads();
    notifyListeners();

    _processQueue();
  }

  /// Find the downloaded file in the output directory by scanning for
  /// media files matching the item's title, sorted by last-modified descending.
  Future<File?> _findDownloadedFile(DownloadItem item) async {
    try {
      return await findDownloadedFile(item);
    } catch (e) {
      LoggingService().warning(
        'Failed to find downloaded file: $e',
        component: 'DownloadProvider',
      );
      return null;
    }
  }

  /// Persist active downloads to Hive so they can be recovered on restart
  Future<void> _saveActiveDownloads() async {
    if (!_isInit) return;
    await _activeDownloadsBox.clear();
    for (final item in _activeDownloads) {
      await _activeDownloadsBox.put(item.id, item);
    }
  }

  /// On startup, check for orphaned active downloads from a previous session
  /// that were interrupted (e.g. by app crash or restart) and move them to history as failed.
  /// Paused items are preserved as paused so they can be resumed across restarts.
  /// Robust against corrupted entries (unknown typeId 33 etc.) — skips bad entries.
  Future<void> _restoreOrphanedDownloads() async {
    List<DownloadItem> orphans;
    // Read box values per-key to isolate corrupted entries.
    try {
      orphans = [];
      for (final key in _activeDownloadsBox.keys) {
        try {
          final item = _activeDownloadsBox.get(key);
          if (item != null) orphans.add(item);
        } catch (e, stackTrace) {
          LoggingService().warning(
            'Skipping corrupted orphaned entry "$key": $e',
            component: 'DownloadProvider',
            error: e,
            stackTrace: stackTrace,
          );
          try {
            await _activeDownloadsBox.delete(key);
          } catch (_) {}
        }
      }
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Failed to read active downloads box (corrupted): $e. Clearing box.',
        component: 'DownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
      LoggingService().showUserLog(
        'Corrupted active downloads were reset to recover the app',
        isWarning: true,
      );
      try {
        await _activeDownloadsBox.clear();
      } catch (_) {}
      return;
    }

    if (orphans.isEmpty) return;

    LoggingService().info(
      'Restoring ${orphans.length} orphaned download(s) from previous session',
      component: 'DownloadProvider',
    );

    final pausedOrphans = <DownloadItem>[];

    for (final item in orphans) {
      try {
        if (item.status == DownloadStatus.paused) {
          pausedOrphans.add(item);
          _activeDownloads.add(item);
          _markActiveDirty();
        } else {
          final failedItem = item.copyWith(
            status: DownloadStatus.failed,
            error: 'App was restarted, download interrupted',
            completedDate: DateTime.now(),
          );
          try {
            await _downloadsBox.put(failedItem.id, failedItem);
          } catch (e, stackTrace) {
            LoggingService().warning(
              'Failed to persist orphaned download ${item.id}: $e',
              component: 'DownloadProvider',
              error: e,
              stackTrace: stackTrace,
            );
          }
        }
      } catch (e, stackTrace) {
        LoggingService().warning(
          'Skipping corrupted orphaned download entry: $e',
          component: 'DownloadProvider',
          error: e,
          stackTrace: stackTrace,
        );
        continue;
      }
    }

    // Rebuild active box with only paused items (_saveActiveDownloads is
    // guarded by _isInit which is still false during _initHive, so manage box directly).
    try {
      await _activeDownloadsBox.clear();
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Failed to clear active downloads box: $e',
        component: 'DownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
    }
    for (final item in pausedOrphans) {
      try {
        await _activeDownloadsBox.put(item.id, item);
      } catch (e, stackTrace) {
        LoggingService().warning(
          'Failed to restore paused orphan ${item.id}: $e',
          component: 'DownloadProvider',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    if (pausedOrphans.isNotEmpty) {
      LoggingService().info(
        'Preserved ${pausedOrphans.length} paused download(s) for resume',
        component: 'DownloadProvider',
      );
    }
  }

  /// Resume downloads that were paused during graceful shutdown
  Future<void> resumeInterruptedDownloads() async {
    final pausedItems = _activeDownloads
        .where((item) => item.status == DownloadStatus.paused)
        .toList();

    if (pausedItems.isNotEmpty) {
      LoggingService().info(
        'Resuming ${pausedItems.length} interrupted download(s)',
        component: 'DownloadProvider',
      );

      for (final item in pausedItems) {
        final index = _activeDownloads.indexWhere((d) => d.id == item.id);
        if (index != -1) {
          _activeDownloads[index] = item.copyWith(
            status: DownloadStatus.queued,
          );
          _markActiveDirty();
        }
      }
      _saveActiveDownloads();
      notifyListeners();
      _processQueue();
    }
  }

  Future<int?> _getAvailableDiskSpace(String dirPath) async {
    try {
      final normalized = p.normalize(dirPath);
      String drive = p.rootPrefix(normalized);
      if (drive.isEmpty) {
        try {
          final current = Directory.current.path;
          drive = p.rootPrefix(p.normalize(current));
        } catch (_) {}
      }
      if (drive.isEmpty && Platform.isWindows) {
        drive = r'C:\';
      }
      if (Platform.isWindows && drive.isNotEmpty && !drive.endsWith('\\')) {
        if (drive.length == 2 && drive.endsWith(':')) drive = '$drive\\';
      }
      if (Platform.isWindows) {
        // B17a: use Process.start with timeout kill to avoid leaking fsutil/ps on hang
        try {
          final result = await _runProcessWithTimeout('fsutil', ['volume', 'diskfree', drive], const Duration(seconds: 5));
          if (result != null && result.exitCode == 0) {
            final out = result.stdout.toString();
            final match = RegExp(
              r'avail free bytes\s*:\s*(\d+)',
              caseSensitive: false,
            ).firstMatch(out);
            if (match != null) return int.tryParse(match.group(1)!);
            final match2 = RegExp(
              r'Total # of free bytes\s*:\s*(\d+)',
              caseSensitive: false,
            ).firstMatch(out);
            if (match2 != null) return int.tryParse(match2.group(1)!);
          }
        } catch (_) {}
        try {
          final psResult = await _runProcessWithTimeout('powershell', ['-NoProfile', '-Command', "(Get-PSDrive -Name '${drive.isNotEmpty ? drive[0] : 'C'}' -ErrorAction SilentlyContinue).Free"], const Duration(seconds: 5));
          if (psResult != null && psResult.exitCode == 0) {
            final trimmed = psResult.stdout.toString().trim();
            final val = int.tryParse(trimmed);
            if (val != null && val > 0) return val;
          }
        } catch (_) {}
        return null;
      } else {
        try {
          final dfResult = await _runProcessWithTimeout('df', ['-k', dirPath], const Duration(seconds: 5));
          if (dfResult != null && dfResult.exitCode == 0) {
            final lines = dfResult.stdout.toString().split('\n');
            if (lines.length >= 2) {
              final parts = lines[1].trim().split(RegExp(r'\s+'));
              if (parts.length >= 4) {
                final availK = int.tryParse(parts[3]);
                if (availK != null) return availK * 1024;
              }
            }
          }
        } catch (_) {}
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<ProcessResult?> _runProcessWithTimeout(String exe, List<String> args, Duration timeout) async {
    Process? proc;
    try {
      proc = await Process.start(exe, args, runInShell: true);
      final stdoutBuf = StringBuffer();
      final stderrBuf = StringBuffer();
      final outSub = proc.stdout.transform(const SystemEncoding().decoder).listen(stdoutBuf.write);
      final errSub = proc.stderr.transform(const SystemEncoding().decoder).listen(stderrBuf.write);
      int exitCode;
      try {
        exitCode = await proc.exitCode.timeout(timeout, onTimeout: () {
          try { proc!.kill(ProcessSignal.sigkill); } catch (_) {}
          try { proc!.kill(); } catch (_) {}
          throw TimeoutException('Process $exe timed out after ${timeout.inSeconds}s');
        });
      } on TimeoutException {
        try { proc.kill(ProcessSignal.sigkill); } catch (_) {}
        try { proc.kill(); } catch (_) {}
        try { await outSub.cancel(); } catch (_) {}
        try { await errSub.cancel(); } catch (_) {}
        return null;
      }
      try {
        await Future.wait<void>([
          outSub.asFuture<void>(),
          errSub.asFuture<void>(),
        ]).timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => [],
        );
      } catch (_) {}
      return ProcessResult(proc.pid, exitCode, stdoutBuf.toString(), stderrBuf.toString());
    } catch (_) {
      try { proc?.kill(ProcessSignal.sigkill); } catch (_) {}
      return null;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    // PF11/PF2: ensure cached views are invalidated before notifying
    // (covers any mutation site that forgot explicit _markDirty)
    _activeDirty = true;
    _historyDirty = true;
    _downloadsDirty = true;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    // P5 fix: cancel idle timer to prevent post-dispose box access
    _activeBoxIdleTimer?.cancel();
    _activeBoxIdleTimer = null;
    for (final process in _activeProcesses.values) {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
    _activeProcesses.clear();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
