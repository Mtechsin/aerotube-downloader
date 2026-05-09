import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/ytdlp_service.dart';
import '../services/notification_service.dart';
import '../services/logging_service.dart';
import '../models/video_info.dart';
import '../models/download_item.dart';
import '../models/download_mode.dart';

class DownloadProvider extends ChangeNotifier {
  final dynamic _ytdlpService;
  final NotificationService? _notificationService;
  final dynamic
  _settingsProvider; // Can be SettingsProvider or PlatformSettingsProvider

  // Active downloads (in memory only while active)
  final List<DownloadItem> _activeDownloads = [];

  // History downloads (persisted)
  List<DownloadItem> _historyDownloads = [];

  final Map<String, Process> _activeProcesses = {};

  late Box<DownloadItem> _downloadsBox;
  late Box<DownloadItem> _activeDownloadsBox;
  bool _isInit = false;

  DownloadProvider(
    this._ytdlpService,
    this._notificationService,
    this._settingsProvider,
  ) {
    _initHive();
  }

  Future<void> _initHive() async {
    _downloadsBox = await Hive.openBox<DownloadItem>('downloads_history');
    _activeDownloadsBox = await Hive.openBox<DownloadItem>('active_downloads');
    await _restoreOrphanedDownloads();
    _loadHistory();
    _isInit = true;
    notifyListeners();
  }

  void _loadHistory() {
    _historyDownloads = _downloadsBox.values.toList()
      ..sort(
        (a, b) => (b.completedDate ?? DateTime.now()).compareTo(
          a.completedDate ?? DateTime.now(),
        ),
      );
    notifyListeners();
  }

  List<DownloadItem> get activeDownloads => List.unmodifiable(_activeDownloads);
  List<DownloadItem> get historyDownloads =>
      List.unmodifiable(_historyDownloads);

  // Backwards compatibility getter if needed, or migration getter
  List<DownloadItem> get downloads => [
    ..._activeDownloads,
    ..._historyDownloads,
  ];

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

  int get pausedCount => _activeDownloads
      .where((i) => i.status == DownloadStatus.paused)
      .length;

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

    final item = DownloadItem(
      id: video.id,
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
    );

    _activeDownloads.add(item);
    _saveActiveDownloads();
    notifyListeners();

    _processQueue();
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
      final templatePath = '${item.outputPath}\\%(title)s.%(ext)s';

      // Build archive path if enabled
      String? archivePath;
      if (item.useDownloadArchive) {
        final dir = Directory(item.outputPath);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
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
        notifyListeners();
      }

      // Handle Output
      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
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
                  notifyListeners();
                }
              }
            }
          }

          final progress = YtdlpService.parseProgress(line);
          if (progress != null) {
            final idx = _activeDownloads.indexWhere((d) => d.id == item.id);
            if (idx != -1) {
              _activeDownloads[idx] = _activeDownloads[idx].copyWith(
                progress: progress.progress,
                speed: progress.speed,
                eta: progress.eta,
                status: progress.status ?? _activeDownloads[idx].status,
              );
              notifyListeners();
            }
          }
        }
      });

      final stderrBuffer = StringBuffer();
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        stderrBuffer.write(data);
        if (data.trim().isNotEmpty) {
          LoggingService().debug(
            'yt-dlp stderr: ${data.trim()}',
            component: 'DownloadProvider',
          );
        }
      });

      final exitCode = await process.exitCode;
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
          if (finalItem.status != DownloadStatus.cancelled) {
            final errorMsg = stderrBuffer.toString().trim();
            finalItem = finalItem.copyWith(
              status: DownloadStatus.failed,
              error: errorMsg.isNotEmpty
                  ? errorMsg
                  : 'Process exited with code $exitCode',
            );
            _activeDownloads.removeAt(idx);
            _saveActiveDownloads();
            _addToHistory(finalItem);
          } else {
            _activeDownloads.removeAt(idx);
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
        final finalItem = _activeDownloads[idx].copyWith(
          status: DownloadStatus.failed,
          error: e.toString(),
          completedDate: DateTime.now(),
        );
        _activeDownloads.removeAt(idx);
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
      _activeDownloads[index] = _activeDownloads[index].copyWith(
        status: DownloadStatus.cancelled,
      );
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
        _activeDownloads[index] = item.copyWith(
          status: DownloadStatus.paused,
        );
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
        _activeDownloads[index] = item.copyWith(
          status: DownloadStatus.queued,
        );
        _saveActiveDownloads();
        notifyListeners();
        _processQueue();
      }
    }
  }

  Future<void> _addToHistory(DownloadItem item) async {
    if (!_isInit) await _initHive();
    await _downloadsBox.put(item.id, item);
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
    // Find the item in history
    final historyIndex = _historyDownloads.indexWhere((d) => d.id == id);
    if (historyIndex == -1) return;

    final item = _historyDownloads[historyIndex];

    // Remove from history
    await _downloadsBox.delete(id);
    _historyDownloads.removeAt(historyIndex);

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
    _saveActiveDownloads();
    notifyListeners();

    _processQueue();
  }

  /// Find the downloaded file in the output directory by scanning for
  /// media files matching the item's title, sorted by last-modified descending.
  Future<File?> _findDownloadedFile(DownloadItem item) async {
    try {
      final dir = Directory(item.outputPath);
      if (!await dir.exists()) return null;

      final candidates = await dir
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .where((file) {
            final lower = file.path.toLowerCase();
            return lower.endsWith('.mp4') ||
                lower.endsWith('.mkv') ||
                lower.endsWith('.webm') ||
                lower.endsWith('.m4a') ||
                lower.endsWith('.mp3') ||
                lower.endsWith('.opus') ||
                lower.endsWith('.aac') ||
                lower.endsWith('.ogg') ||
                lower.endsWith('.wav') ||
                lower.endsWith('.flac');
          })
          .toList();

      if (candidates.isEmpty) return null;

      // Try title match first
      final normalizedTitle = item.title.toLowerCase();
      final titleWords = normalizedTitle
          .split(' ')
          .where((w) => w.trim().isNotEmpty)
          .take(4)
          .toList();

      final titleMatch = candidates.where((f) {
        final name = f.path.split(Platform.pathSeparator).last.toLowerCase();
        return titleWords.every((w) => name.contains(w));
      }).toList();

      final pool = titleMatch.isNotEmpty ? titleMatch : candidates;
      pool.sort(
        (a, b) =>
            b.lastModifiedSync().millisecondsSinceEpoch -
            a.lastModifiedSync().millisecondsSinceEpoch,
      );
      return pool.first;
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
  Future<void> _restoreOrphanedDownloads() async {
    final orphans = _activeDownloadsBox.values.toList();
    if (orphans.isEmpty) return;

    LoggingService().info(
      'Restoring ${orphans.length} orphaned download(s) from previous session',
      component: 'DownloadProvider',
    );

    for (final item in orphans) {
      final failedItem = item.copyWith(
        status: DownloadStatus.failed,
        error: 'App was restarted, download interrupted',
        completedDate: DateTime.now(),
      );
      await _downloadsBox.put(failedItem.id, failedItem);
    }
    await _activeDownloadsBox.clear();
  }
}
