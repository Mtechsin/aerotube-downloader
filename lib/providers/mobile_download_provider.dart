import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;

import '../core/constants/app_constants.dart';
import '../core/utils/downloaded_file_finder.dart';
import '../core/utils/error_helper.dart';
import '../models/download_item.dart';
import '../models/download_mode.dart';
import '../providers/platform_settings_provider.dart';
import '../services/core/android_storage_service.dart';
import '../services/cookie/cookie_service.dart';
import '../services/notification/download_foreground_service.dart';
import '../services/core/logging_service.dart';
import '../services/ytdlp/native_ytdlp_android.dart';
import '../services/ytdlp/ytdlp_service_android.dart';

/// Mobile-optimized download provider with foreground service integration.
class MobileDownloadProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  static const String _historyBoxName = AppConstants.mobileDownloadsHistoryBox;
  static const String _activeBoxName = AppConstants.mobileActiveDownloadsBox;
  final dynamic ytdlpService; // YtdlpServiceAndroid on mobile
  final DownloadForegroundService _foregroundService =
      DownloadForegroundService();
  final AndroidStorageService _storageService = AndroidStorageService();
  final LoggingService _logger = LoggingService();
  final PlatformSettingsProvider? _settingsProvider;

  final List<DownloadItem> _downloads = [];
  final Map<String, StreamController<double>> _progressControllers = {};
  final Map<String, String> _processToDownloadId = {};
  StreamSubscription<Map<String, dynamic>>? _nativeEventsSubscription;
  Box<DownloadItem>? _historyBox;
  Box<DownloadItem>? _activeBox;

  final Set<String> _currentlyProcessingIds = {};

  bool _isDisposed = false;
  bool _isInitialized = false;
  int _maxConcurrentDownloads = 3;
  // B20 fix: collision-free ID counter
  static int _idCounter = 0;
  // P7 fix: re-entrancy guard for concurrent initialize() calls
  Completer<void>? _initCompleter;

  // PF2 fix: cached unmodifiable/filtered views for select identity stability
  List<DownloadItem>? _cachedDownloads;
  List<DownloadItem>? _cachedActiveDownloads;
  List<DownloadItem>? _cachedCompletedDownloads;
  List<DownloadItem>? _cachedFailedDownloads;
  bool _downloadsDirty = true;
  bool _activeDirty = true;
  bool _completedDirty = true;
  bool _failedDirty = true;

  // Progress events from yt-dlp arrive at native callback rate (~1-5/s per
  // download). Coalescing the UI notification to ~10 Hz cuts rebuild work
  // sharply; the cards' tweened progress bars smooth between ticks, so the
  // result is visually identical. Status changes bypass the throttle.
  static const Duration _progressNotifyThrottle = Duration(milliseconds: 100);
  Timer? _pendingProgressNotify;
  DateTime _lastProgressNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _throttledProgressNotify() {
    if (_isDisposed) return;
    final sinceLast = DateTime.now().difference(_lastProgressNotifyAt);
    if (sinceLast >= _progressNotifyThrottle) {
      _lastProgressNotifyAt = DateTime.now();
      notifyListeners();
      return;
    }
    _pendingProgressNotify ??= Timer(_progressNotifyThrottle - sinceLast, () {
      _pendingProgressNotify = null;
      _lastProgressNotifyAt = DateTime.now();
      notifyListeners();
    });
  }

  void _flushPendingProgressNotify() {
    _pendingProgressNotify?.cancel();
    _pendingProgressNotify = null;
    _lastProgressNotifyAt = DateTime.now();
    notifyListeners();
  }

  void _markDownloadsDirty() {
    _downloadsDirty = true;
    _activeDirty = true;
    _completedDirty = true;
    _failedDirty = true;
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  MobileDownloadProvider({
    required this.ytdlpService,
    CookieService? cookieService, // kept for signature compatibility
    PlatformSettingsProvider? settingsProvider,
  }) : _settingsProvider = settingsProvider {
    final settings = _settingsProvider;
    if (settings != null) {
      _maxConcurrentDownloads = settings.maxConcurrentDownloads;
      settings.addListener(_onSettingsChanged);
    }
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveActiveDownloads());
    }
  }

  void _onSettingsChanged() {
    final settings = _settingsProvider;
    if (settings != null &&
        _maxConcurrentDownloads != settings.maxConcurrentDownloads) {
      _maxConcurrentDownloads = settings.maxConcurrentDownloads;
      _processQueue();
    }
  }

  List<DownloadItem> get downloads {
    if (_downloadsDirty || _cachedDownloads == null) {
      _cachedDownloads = List.unmodifiable(_downloads);
      _downloadsDirty = false;
    }
    return _cachedDownloads!;
  }

  List<DownloadItem> get activeDownloads {
    if (_activeDirty || _cachedActiveDownloads == null) {
      _cachedActiveDownloads = List.unmodifiable(
        _downloads
            .where(
              (d) =>
                  d.status == DownloadStatus.downloadingVideo ||
                  d.status == DownloadStatus.downloadingAudio ||
                  d.status == DownloadStatus.merging ||
                  d.status == DownloadStatus.pending ||
                  d.status == DownloadStatus.queued ||
                  d.status == DownloadStatus.paused,
            )
            .toList(),
      );
      _activeDirty = false;
    }
    return _cachedActiveDownloads!;
  }

  List<DownloadItem> get completedDownloads {
    if (_completedDirty || _cachedCompletedDownloads == null) {
      _cachedCompletedDownloads = List.unmodifiable(
        _downloads.where((d) => d.status == DownloadStatus.completed).toList(),
      );
      _completedDirty = false;
    }
    return _cachedCompletedDownloads!;
  }

  List<DownloadItem> get failedDownloads {
    if (_failedDirty || _cachedFailedDownloads == null) {
      _cachedFailedDownloads = List.unmodifiable(
        _downloads.where((d) => d.status == DownloadStatus.failed).toList(),
      );
      _failedDirty = false;
    }
    return _cachedFailedDownloads!;
  }

  bool get isInitialized => _isInitialized;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  int get activeDownloadsCount => activeDownloads.length;
  int get runningDownloadsCount => _downloads
      .where(
        (d) =>
            d.status == DownloadStatus.downloadingVideo ||
            d.status == DownloadStatus.downloadingAudio ||
            d.status == DownloadStatus.merging,
      )
      .length;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    try {
      await _initHistoryStorage();
      await _initBackground();
      _isInitialized = true;
      _logger.info(
        'MobileDownloadProvider initialized',
        component: 'MobileDownloadProvider',
      );
      _initCompleter!.complete();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize MobileDownloadProvider',
        component: 'MobileDownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
      if (!_initCompleter!.isCompleted) _initCompleter!.complete();
      _initCompleter = null;
    }
  }

  Future<Box<DownloadItem>?> _openBoxWithRecovery(String boxName) async {
    try {
      return await Hive.openBox<DownloadItem>(boxName);
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Hive box "$boxName" open failed ($e). Attempting corruption recovery...',
        component: 'MobileDownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (_) {}
      try {
        return await Hive.openBox<DownloadItem>(boxName);
      } catch (retryErr, retrySt) {
        LoggingService().warning(
          'Reopening box "$boxName" failed ($retryErr). Falling back to recovery box...',
          component: 'MobileDownloadProvider',
          error: retryErr,
          stackTrace: retrySt,
        );
        try {
          return await Hive.openBox<DownloadItem>('${boxName}_recovered');
        } catch (fallbackErr, fallbackSt) {
          LoggingService().error(
            'Failed to open fallback box for "$boxName": $fallbackErr',
            component: 'MobileDownloadProvider',
            error: fallbackErr,
            stackTrace: fallbackSt,
          );
          return null;
        }
      }
    }
  }

  Future<void> _initHistoryStorage() async {
    // Open history box and active downloads box with corruption recovery
    if (_historyBox == null || !_historyBox!.isOpen) {
      _historyBox = await _openBoxWithRecovery(_historyBoxName);
    }
    if (_activeBox == null || !_activeBox!.isOpen) {
      _activeBox = await _openBoxWithRecovery(_activeBoxName);
    }

    // Trim history box if it exceeds 200 entries – per-key safe read.
    if (_historyBox != null) {
      try {
        if (_historyBox!.length > 200) {
          final List<MapEntry<dynamic, DownloadItem>> entries = [];
          for (final k in _historyBox!.keys) {
            try {
              final v = _historyBox!.get(k);
              if (v != null) entries.add(MapEntry(k, v));
            } catch (e, st) {
              _logger.warning(
                'Skipping corrupted history entry "$k" during trim: $e',
                component: 'MobileDownloadProvider',
                error: e,
                stackTrace: st,
              );
              try {
                await _historyBox!.delete(k);
              } catch (_) {}
            }
          }
          entries.sort(
            (a, b) => (a.value.completedDate ?? DateTime(1970)).compareTo(
              b.value.completedDate ?? DateTime(1970),
            ),
          );
          final excess = entries.length - 200;
          for (int i = 0; i < excess; i++) {
            try {
              await _historyBox!.delete(entries[i].key);
            } catch (e, st) {
              _logger.warning(
                'Failed to delete excess history entry ${entries[i].key}: $e',
                component: 'MobileDownloadProvider',
                error: e,
                stackTrace: st,
              );
            }
          }
        }
      } catch (e, stackTrace) {
        _logger.warning(
          'Failed to trim history box (corrupted): $e',
          component: 'MobileDownloadProvider',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    // Read persisted history per-key to isolate corrupted entries.
    List<DownloadItem> persistedHistory = [];
    if (_historyBox != null) {
      try {
        for (final key in _historyBox!.keys) {
          try {
            final item = _historyBox!.get(key);
            if (item != null) persistedHistory.add(item);
          } catch (e, stackTrace) {
            _logger.warning(
              'Skipping corrupted history entry "$key": $e',
              component: 'MobileDownloadProvider',
              error: e,
              stackTrace: stackTrace,
            );
            try {
              await _historyBox!.delete(key);
            } catch (_) {}
          }
        }
        persistedHistory.sort(
          (a, b) => (b.completedDate ?? DateTime(1970)).compareTo(
            a.completedDate ?? DateTime(1970),
          ),
        );
      } catch (e, stackTrace) {
        // Box-level corruption when reading keys/values.
        LoggingService().warning(
          'Failed to read history box values (corrupted): $e. Clearing and recreating box.',
          component: 'MobileDownloadProvider',
          error: e,
          stackTrace: stackTrace,
        );
        LoggingService().showUserLog(
          'Corrupted download history was reset to recover the app',
          isWarning: true,
        );
        try {
          await _historyBox!.clear();
        } catch (_) {
          try {
            await Hive.deleteBoxFromDisk(_historyBoxName);
            _historyBox = await Hive.openBox<DownloadItem>(_historyBoxName);
          } catch (_) {}
        }
        persistedHistory = [];
      }
    }

    // Pre-existing active items if any were added before init completed
    final preInitActive = _downloads
        .where((d) => !_isTerminalStatus(d.status))
        .toList();

    _downloads
      ..clear()
      ..addAll(preInitActive)
      ..addAll(persistedHistory);

    // Restore orphaned in-flight downloads from active box as paused
    await _restoreOrphanedDownloads();
    _markDownloadsDirty();
    notifyListeners();
  }

  /// Persist all active (non-terminal) downloads to Hive active box so they survive process kills.
  Future<void> _saveActiveDownloads() async {
    final box = _activeBox;
    if (box == null || !box.isOpen) return;

    try {
      final activeItems = _downloads
          .where((d) => !_isTerminalStatus(d.status))
          .toList();
      final currentKeys = box.keys.toSet();
      final activeIds = activeItems.map((item) => item.id).toSet();

      // Delete any items from active box that are no longer active
      final keysToDelete = currentKeys.difference(activeIds);
      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
      }

      // Save/update all current active items
      for (final item in activeItems) {
        await box.put(item.id, item);
      }
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to save active downloads: $e',
        component: 'MobileDownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Remove a single item from the active box upon becoming terminal or removed.
  Future<void> _removeActiveDownload(String downloadId) async {
    final box = _activeBox;
    if (box == null || !box.isOpen) return;
    try {
      await box.delete(downloadId);
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to remove active download $downloadId: $e',
        component: 'MobileDownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// On startup, inspect items in _activeBox.
  /// Any item that was in-flight (downloadingVideo, downloadingAudio, merging, pending, queued)
  /// when the process was killed should be restored with status DownloadStatus.paused
  /// ('Interrupted by app close - tap to resume').
  /// Existing partial download files (.part / .ytdl) are retained on disk.
  Future<void> _restoreOrphanedDownloads() async {
    final box = _activeBox;
    if (box == null || !box.isOpen) return;

    final List<DownloadItem> orphans = [];
    for (final key in box.keys) {
      try {
        final item = box.get(key);
        if (item != null) orphans.add(item);
      } catch (e, stackTrace) {
        _logger.warning(
          'Skipping corrupted active download entry "$key": $e',
          component: 'MobileDownloadProvider',
          error: e,
          stackTrace: stackTrace,
        );
        try {
          await box.delete(key);
        } catch (_) {}
      }
    }

    if (orphans.isEmpty) return;

    _logger.info(
      'Restoring ${orphans.length} active download(s) from previous session',
      component: 'MobileDownloadProvider',
    );

    const interruptedMsg = 'Interrupted by app close - tap to resume';
    final List<DownloadItem> restoredActive = [];

    for (final item in orphans) {
      if (_isTerminalStatus(item.status)) {
        await _persistHistoryItem(item);
        await box.delete(item.id);
        continue;
      }

      if (item.status == DownloadStatus.paused) {
        // Paused items are preserved as paused across restarts
        restoredActive.add(item);
      } else {
        // In-flight items (downloadingVideo, downloadingAudio, merging, pending, queued)
        // are transitioned to paused so user can tap to resume without losing partial downloads
        final restored = item.copyWith(
          status: DownloadStatus.paused,
          speed: 0.0,
          eta: 0,
          statusText: interruptedMsg,
          error: interruptedMsg,
        );
        restoredActive.add(restored);
        await box.put(restored.id, restored);
      }
    }

    final restoredIds = restoredActive.map((d) => d.id).toSet();
    final nonRestoredActive = _downloads
        .where(
          (d) => !_isTerminalStatus(d.status) && !restoredIds.contains(d.id),
        )
        .toList();
    final terminalHistory = _downloads
        .where((d) => _isTerminalStatus(d.status))
        .toList();

    _downloads
      ..clear()
      ..addAll(restoredActive)
      ..addAll(nonRestoredActive)
      ..addAll(terminalHistory);

    _markDownloadsDirty();
    notifyListeners();
  }

  @visibleForTesting
  Box<DownloadItem>? get activeBox => _activeBox;

  @visibleForTesting
  Future<void> restoreOrphanedDownloads() => _restoreOrphanedDownloads();

  @visibleForTesting
  Future<void> saveActiveDownloads() => _saveActiveDownloads();

  Future<void> _persistHistoryItem(DownloadItem item) async {
    final box = _historyBox;
    if (box == null) return;
    await box.put(item.id, item);
    // P6 fix: trim history to max 200 entries to prevent unbounded growth
    if (box.length > 200) {
      final entries = box.keys.map((k) => MapEntry(k, box.get(k)!)).toList()
        ..sort(
          (a, b) => (a.value.completedDate ?? DateTime(1970)).compareTo(
            b.value.completedDate ?? DateTime(1970),
          ),
        );
      final excess = entries.length - 200;
      for (int i = 0; i < excess; i++) {
        await box.delete(entries[i].key);
      }
    }
  }

  Future<void> _removeHistoryItem(String downloadId) async {
    final box = _historyBox;
    if (box == null) return;
    await box.delete(downloadId);
  }

  Future<void> _removeHistoryByStatus(DownloadStatus status) async {
    final box = _historyBox;
    if (box == null) return;
    final keysToDelete = box.values
        .where((item) => item.status == status)
        .map((item) => item.id)
        .toList();
    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }
  }

  Future<void> _initBackground() async {
    await _foregroundService.initialize();

    _nativeEventsSubscription ??= NativeYtdlpAndroid.downloadEvents
        .handleError(
          (error) {
            _logger.warning(
              'Native download events unavailable: $error',
              component: 'MobileDownloadProvider',
            );
          },
          test: (error) =>
              error is MissingPluginException || error is PlatformException,
        )
        .listen(
          _handleNativeDownloadEvent,
          onError: (error) {
            _logger.warning(
              'Native download events stream error: $error',
              component: 'MobileDownloadProvider',
            );
          },
        );
  }

  void setMaxConcurrentDownloads(int max) {
    _maxConcurrentDownloads = max;
    notifyListeners();
  }

  Future<void> addDownload({
    required String url,
    required String title,
    required DownloadMode mode,
    String? formatId,
    String? thumbnailUrl,
    String? outputPath,
    Map<String, dynamic>? options,
    int? estimatedFileSize,
  }) async {
    try {
      // B20 fix: URL dedupe (desktop parity) - avoid duplicate active downloads
      final alreadyExists = _downloads.any(
        (d) => d.url == url && !_isTerminalStatus(d.status),
      );
      if (alreadyExists) {
        _logger.info(
          'Download already in queue: $title',
          component: 'MobileDownloadProvider',
        );
        return;
      }
      // B20 fix: collision-free ID using microseconds + counter
      final downloadId =
          '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

      String saveDir;
      if (outputPath != null) {
        saveDir = outputPath;
      } else if (_settingsProvider?.outputPath != null &&
          _settingsProvider!.outputPath!.isNotEmpty) {
        // Use user-configured output path from settings
        saveDir = _settingsProvider.outputPath!;
      } else {
        saveDir = mode == DownloadMode.audioOnly
            ? await _storageService.getAudioDirectory()
            : await _storageService.getVideoDirectory();
      }

      // Resolve estimatedFileSize: explicit param wins, then options map
      final resolvedEstimatedSize =
          estimatedFileSize ??
          (options?['estimatedFileSize'] as int?) ??
          (options?['totalBytes'] as int?);
      final normalizedSize =
          (resolvedEstimatedSize != null && resolvedEstimatedSize > 0)
          ? resolvedEstimatedSize
          : null;

      final downloadItem = DownloadItem(
        id: downloadId,
        title: title,
        url: url,
        outputPath: saveDir,
        thumbnailUrl: thumbnailUrl,
        status: runningDownloadsCount >= _maxConcurrentDownloads
            ? DownloadStatus.queued
            : DownloadStatus.pending,
        progress: 0.0,
        audioOnly: mode == DownloadMode.audioOnly,
        formatId: formatId,
        audioFormatId: options?['audioFormatId'] as String?,
        videoQuality: _formatVideoQuality(options?['targetHeight']),
        audioQuality: options?['audioQuality'] as String?,
        subtitleLanguages: (options?['subtitleLanguages'] as List?)
            ?.map((e) => e.toString())
            .toList(),
        embedSubtitles: options?['embedSubtitles'] as bool? ?? false,
        sponsorBlock: options?['sponsorBlock'] as bool? ?? false,
        useDownloadArchive: options?['useDownloadArchive'] as bool? ?? false,
        totalBytes: normalizedSize,
      );

      _downloads.add(downloadItem);
      _markDownloadsDirty();
      await _saveActiveDownloads();
      notifyListeners();
      _processQueue();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to add download',
        component: 'MobileDownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// PF10 fix (mobile parity): batched enqueue — one Hive write, one
  /// notifyListeners, one queue pass instead of N addDownload calls
  /// (N Hive writes + N rebuilds) when queuing a playlist.
  /// Returns the number of items actually added (dedup applied).
  Future<int> startDownloadsBatch({
    required List<({String url, String title, String? thumbnailUrl})> items,
    required DownloadMode mode,
    String? formatId,
    String? outputPath,
    Map<String, dynamic>? options,
    int? estimatedFileSize,
  }) async {
    if (items.isEmpty) return 0;
    try {
      // Resolve the save dir once for the whole batch.
      String saveDir;
      if (outputPath != null) {
        saveDir = outputPath;
      } else if (_settingsProvider?.outputPath != null &&
          _settingsProvider!.outputPath!.isNotEmpty) {
        saveDir = _settingsProvider.outputPath!;
      } else {
        saveDir = mode == DownloadMode.audioOnly
            ? await _storageService.getAudioDirectory()
            : await _storageService.getVideoDirectory();
      }

      final resolvedEstimatedSize =
          estimatedFileSize ??
          (options?['estimatedFileSize'] as int?) ??
          (options?['totalBytes'] as int?);
      final normalizedSize =
          (resolvedEstimatedSize != null && resolvedEstimatedSize > 0)
          ? resolvedEstimatedSize
          : null;

      // O(1) dedup within the batch and against non-terminal active downloads.
      final activeUrls = <String>{
        for (final d in _downloads)
          if (!_isTerminalStatus(d.status)) d.url,
      };
      final seenUrls = <String>{};

      final nextStatus = runningDownloadsCount >= _maxConcurrentDownloads
          ? DownloadStatus.queued
          : DownloadStatus.pending;

      var added = 0;
      for (final entry in items) {
        if (entry.url.isEmpty ||
            seenUrls.contains(entry.url) ||
            activeUrls.contains(entry.url)) {
          continue;
        }
        seenUrls.add(entry.url);
        activeUrls.add(entry.url);

        _downloads.add(
          DownloadItem(
            id: '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
            title: entry.title,
            url: entry.url,
            outputPath: saveDir,
            thumbnailUrl: entry.thumbnailUrl,
            status: nextStatus,
            progress: 0.0,
            audioOnly: mode == DownloadMode.audioOnly,
            formatId: formatId,
            audioFormatId: options?['audioFormatId'] as String?,
            videoQuality: _formatVideoQuality(options?['targetHeight']),
            audioQuality: options?['audioQuality'] as String?,
            subtitleLanguages: (options?['subtitleLanguages'] as List?)
                ?.map((e) => e.toString())
                .toList(),
            embedSubtitles: options?['embedSubtitles'] as bool? ?? false,
            sponsorBlock: options?['sponsorBlock'] as bool? ?? false,
            useDownloadArchive:
                options?['useDownloadArchive'] as bool? ?? false,
            totalBytes: normalizedSize,
          ),
        );
        added++;
      }

      if (added == 0) {
        _logger.info(
          'Batch queue: no new items to add (all duplicates/empty)',
          component: 'MobileDownloadProvider',
        );
        return 0;
      }

      _markDownloadsDirty();
      await _saveActiveDownloads();
      notifyListeners();
      _processQueue();

      _logger.info(
        'Batch queued $added/${items.length} downloads',
        component: 'MobileDownloadProvider',
      );
      return added;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to queue batch downloads',
        component: 'MobileDownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  void _processQueue() {
    final availableSlots = _maxConcurrentDownloads - runningDownloadsCount;
    if (availableSlots <= 0) return;

    final queuedItems = _downloads
        .where(
          (d) =>
              (d.status == DownloadStatus.queued ||
                  d.status == DownloadStatus.pending) &&
              !_currentlyProcessingIds.contains(d.id),
        )
        .take(availableSlots)
        .toList();

    for (final item in queuedItems) {
      _startDownload(item);
    }
  }

  Future<void> _startDownload(DownloadItem item) async {
    if (_currentlyProcessingIds.contains(item.id)) return;
    _currentlyProcessingIds.add(item.id);
    try {
      if (ytdlpService is! YtdlpServiceAndroid) {
        throw UnsupportedError(
          'Only YtdlpServiceAndroid is supported on mobile',
        );
      }

      final hasPermission = await _storageService.requestStoragePermission();
      // Always resolve a guaranteed-writable directory. requestStoragePermission
      // no longer fakes a grant, and getSafeDownloadDirectory falls back to
      // app-specific storage when public Downloads is blocked.
      if (!hasPermission) {
        _logger.warning(
          'External storage permission not granted, redirecting to app storage',
          component: 'MobileDownloadProvider',
        );
        final safePath = await _storageService.getSafeDownloadDirectory();
        if (safePath != item.outputPath) {
          final updated = item.copyWith(outputPath: safePath);
          final idx = _downloads.indexWhere((d) => d.id == item.id);
          if (idx != -1) {
            _downloads[idx] = updated;
            await _saveActiveDownloads();
          }
          _logger.showUserLog(
            'Saving to app storage because external storage access was not granted. Files will still appear in Downloads after saving.',
          );
        }
      } else if (_storageService.isAppPrivatePath(item.outputPath)) {
        // Previously saved path is app-private; move writes to a safe path.
        final safePath = await _storageService.getSafeDownloadDirectory();
        if (safePath != item.outputPath) {
          final updated = item.copyWith(outputPath: safePath);
          final idx = _downloads.indexWhere((d) => d.id == item.id);
          if (idx != -1) {
            _downloads[idx] = updated;
            await _saveActiveDownloads();
          }
        }
      }

      // Disk-space pre-flight (B10 fix): check available space before download
      if (item.totalBytes != null && item.totalBytes! > 0) {
        final available = await _getAvailableDiskSpaceMobile(item.outputPath);
        if (available != null) {
          const bufferBytes = 100 * 1024 * 1024;
          final required = item.totalBytes! + bufferBytes;
          if (available < required) {
            _logger.warning(
              'Insufficient disk space for ${item.title}: need ${_formatBytes(required)}, available ${_formatBytes(available)}',
              component: 'MobileDownloadProvider',
            );
            await _failDownload(
              item.id,
              'Insufficient disk space. Need ${_formatBytes(item.totalBytes!)}, available ${_formatBytes(available)}. Free up space and try again.',
            );
            return;
          } else {
            _logger.debug(
              'Disk-space pre-flight passed for ${item.title}: need ${_formatBytes(required)}, available ${_formatBytes(available)}',
              component: 'MobileDownloadProvider',
            );
          }
        } else {
          _logger.debug(
            'Unable to determine available disk space for ${item.outputPath}, proceeding anyway',
            component: 'MobileDownloadProvider',
          );
        }
      } else {
        _logger.debug(
          'Skipping disk-space pre-flight: totalBytes unknown for ${item.title}',
          component: 'MobileDownloadProvider',
        );
      }

      final service = ytdlpService as YtdlpServiceAndroid;

      if (!_currentlyProcessingIds.contains(item.id)) return;
      final checkIndex = _downloads.indexWhere((d) => d.id == item.id);
      if (checkIndex == -1 ||
          _isTerminalStatus(_downloads[checkIndex].status) ||
          _downloads[checkIndex].status == DownloadStatus.paused) {
        return;
      }

      _updateDownloadStatus(
        item.id,
        item.audioOnly
            ? DownloadStatus.downloadingAudio
            : DownloadStatus.downloadingVideo,
      );

      final statusIndex = _downloads.indexWhere((d) => d.id == item.id);
      if (statusIndex != -1 &&
          !_isTerminalStatus(_downloads[statusIndex].status) &&
          _downloads[statusIndex].status != DownloadStatus.paused) {
        _downloads[statusIndex] = _downloads[statusIndex].copyWith(
          statusText: 'Preparing download...',
        );
        _markDownloadsDirty();
        notifyListeners();
      }

      // Build format string for foreground service
      String? format;
      if (item.audioOnly) {
        format = item.audioFormatId ?? 'bestaudio';
      } else if (item.formatId != null && item.audioFormatId != null) {
        format = '${item.formatId}+${item.audioFormatId}';
      } else if (item.formatId != null) {
        format = item.formatId;
      }

      try {
        await _foregroundService.startDownload(
          downloadId: item.id,
          url: item.url,
          outputPath: item.outputPath,
          title: item.title,
          format: format,
          cookiesPath: service.isUsingCookies ? service.cookiePath : null,
          userAgent: service.userAgent,
        );
      } catch (e) {
        _logger.warning(
          'Foreground service notification failed (non-fatal): $e',
          component: 'MobileDownloadProvider',
        );
      }

      _progressControllers[item.id] = StreamController<double>.broadcast();

      _logger.info(
        'Calling yt-dlp: format=${item.formatId} -> dir=${item.outputPath}',
        component: 'MobileDownloadProvider',
      );

      final processId = await service.downloadVideo(
        url: item.url,
        outputPath: item.outputPath,
        processId: item.id,
        formatId: item.formatId,
        audioFormatId: item.audioFormatId,
        audioOnly: item.audioOnly,
        targetHeight: _parseTargetHeight(item.videoQuality),
        audioQuality: item.audioQuality,
        sponsorBlock: item.sponsorBlock,
        archivePath: item.useDownloadArchive
            ? p.join(item.outputPath, 'download_archive.txt')
            : null,
        embedSubtitles: item.embedSubtitles,
        subtitleLanguages: item.subtitleLanguages,
      );

      if (processId != null) {
        if (_isDisposed) return;
        _processToDownloadId[processId] = item.id;

        final latest = _downloads.firstWhere(
          (d) => d.id == item.id,
          orElse: () => item,
        );
        if (!_isTerminalStatus(latest.status) &&
            latest.status != DownloadStatus.paused) {
          await _completeDownload(item.id);
        }
      } else {
        throw Exception('yt-dlp returned failure - check device logs');
      }
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      final currentIndex = _downloads.indexWhere((d) => d.id == item.id);
      if (currentIndex != -1 &&
          (_isTerminalStatus(_downloads[currentIndex].status) ||
              _downloads[currentIndex].status == DownloadStatus.paused)) {
        _progressControllers[item.id]?.close();
        _progressControllers.remove(item.id);
        _processToDownloadId.removeWhere((k, v) => v == item.id);
        _currentlyProcessingIds.remove(item.id);
        return;
      }
      _logger.error(
        'Download failed: ${item.title}',
        component: 'MobileDownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
      await _failDownload(item.id, e.toString());
    } finally {
      _currentlyProcessingIds.remove(item.id);
    }
  }

  void _handleNativeDownloadEvent(Map<String, dynamic> event) {
    final type = (event['event'] ?? '').toString();
    final processId = (event['process_id'] ?? '').toString();
    if (processId.isEmpty) return;

    final downloadId = _processToDownloadId[processId] ?? processId;
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index == -1) return;

    final item = _downloads[index];

    if (type == 'progress') {
      if (_isTerminalStatus(item.status)) return;

      final rawProgress = (event['progress'] as num?)?.toDouble() ?? -1.0;
      final eta = (event['eta'] as num?)?.toInt() ?? item.eta;
      final line = (event['line'] ?? '').toString();
      // Normally pin progress with max() to hide per-stream jitter when
      // video+audio report separately. Exception: after a resume where the
      // .part was wiped we reset progress to 0 and the native reporter
      // legitimately counts up from 0 again — accept backward movement then,
      // otherwise the UI would be stuck at the stale pre-pause percentage.
      final isRestarting = (item.statusText ?? '').contains('Restarting');
      final nativeProgress = rawProgress >= 0
          ? (rawProgress / 100.0).clamp(0.0, 1.0)
          : item.progress;
      final parsedProgress = isRestarting
          ? nativeProgress
          : (rawProgress >= 0
                ? max(item.progress, nativeProgress)
                : item.progress);

      final parsedSpeed = _extractSpeedBytesPerSecond(line) ?? item.speed;
      final status = _statusFromNativeLine(line, item);
      final readableStatus = _humanReadableStatus(line, item);
      final statusChanged = status != item.status;

      _downloads[index] = item.copyWith(
        progress: parsedProgress,
        speed: parsedSpeed,
        eta: eta < 0 ? item.eta : eta,
        status: status,
        statusText: readableStatus,
      );
      _markDownloadsDirty();
      if (statusChanged) {
        unawaited(_saveActiveDownloads());
      }

      final controller = _progressControllers[downloadId];
      if (controller != null && !controller.isClosed) {
        controller.add(_downloads[index].progress);
      }
      unawaited(
        _foregroundService
            .updateProgress(
              downloadId: downloadId,
              progress: _downloads[index].progress,
              speed: parsedSpeed,
              statusText: readableStatus,
            )
            .catchError((Object e, StackTrace st) {
              _logger.warning(
                'Failed to update progress for $downloadId: $e',
                component: 'MobileDownloadProvider',
                error: e,
                stackTrace: st,
              );
            }),
      );
      if (statusChanged) {
        // Transitions (started, merging, completed) are meaningful — the UI
        // should react to them on the same frame, not on the next tick.
        _flushPendingProgressNotify();
      } else {
        _throttledProgressNotify();
      }
      return;
    }

    if (type == 'completed') {
      unawaited(
        _completeDownload(downloadId).catchError((Object e, StackTrace st) {
          _logger.error(
            'Failed to complete download $downloadId: $e',
            component: 'MobileDownloadProvider',
            error: e,
            stackTrace: st,
          );
        }),
      );
      return;
    }

    if (type == 'error') {
      final error = (event['error'] ?? 'Native download failed').toString();
      unawaited(
        _failDownload(downloadId, error).catchError((Object e, StackTrace st) {
          _logger.error(
            'Failed to handle download error for $downloadId: $e',
            component: 'MobileDownloadProvider',
            error: e,
            stackTrace: st,
          );
        }),
      );
      return;
    }

    if (type == 'cancelled') {
      unawaited(
        cancelDownload(downloadId).catchError((Object e, StackTrace st) {
          _logger.error(
            'Failed to cancel download $downloadId: $e',
            component: 'MobileDownloadProvider',
            error: e,
            stackTrace: st,
          );
        }),
      );
    }
  }

  void _updateDownloadStatus(String downloadId, DownloadStatus status) {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index != -1) {
      _downloads[index] = _downloads[index].copyWith(
        status: status,
        progress: _downloads[index].progress,
      );
      _markDownloadsDirty();
      unawaited(_saveActiveDownloads());
      notifyListeners();
    }
  }

  Future<void> _completeDownload(String downloadId) async {
    if (_isDisposed) return;
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index != -1 && _isTerminalStatus(_downloads[index].status)) {
      _currentlyProcessingIds.remove(downloadId);
      return;
    }
    _currentlyProcessingIds.remove(downloadId);
    _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
    _processToDownloadId.remove(downloadId);
    _processToDownloadId.removeWhere((k, v) => v == downloadId);

    if (index != -1) {
      final item = _downloads[index];
      final file = await _findDownloadedFile(item);
      if (file == null) {
        await _failDownload(
          downloadId,
          'Download finished but no output file was found in ${item.outputPath}',
        );
        return;
      }
      final thumbnailFile = await _findThumbnailFile(
        item.copyWith(savePath: file.path),
      );

      // If the file landed in app-private storage, publish a copy into the
      // public Downloads/AeroTube folder via MediaStore (works without
      // All-files-access on Android 10+).
      try {
        final inPrivate = _storageService.isAppPrivatePath(file.path);
        final publicWritable = await _storageService.canWritePublicDownloads();
        if (inPrivate || !publicWritable) {
          final published = await _storageService.publishToPublicDownloads(
            sourcePath: file.path,
            displayName: p.basename(file.path),
          );
          if (published) {
            _logger.showUserLog('Saved to Downloads/AeroTube');
          }
        }
      } catch (e) {
        _logger.warning(
          'Failed to publish download to public Downloads: $e',
          component: 'MobileDownloadProvider',
        );
      }

      // Trigger media scanner so Android MediaStore immediately indexes the media file
      try {
        await _storageService.scanMediaFile(file.path);
      } catch (e) {
        _logger.warning(
          'Failed to scan completed media file into MediaStore: $e',
          component: 'MobileDownloadProvider',
        );
      }

      _downloads[index] = item.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        speed: 0.0,
        eta: 0,
        savePath: file.path,
        thumbnailPath: thumbnailFile?.path,
        totalBytes: await file.length(),
        completedDate: DateTime.now(),
      );
      _markDownloadsDirty();
      await _removeActiveDownload(downloadId);
      await _persistHistoryItem(_downloads[index]);
      notifyListeners();
    } else {
      await _removeActiveDownload(downloadId);
    }

    await _foregroundService.completeDownload(downloadId);
    _processQueue();

    _logger.info(
      'Download completed: $downloadId',
      component: 'MobileDownloadProvider',
    );
  }

  Future<void> _failDownload(String downloadId, String error) async {
    if (_isDisposed) return;
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index != -1 && _isTerminalStatus(_downloads[index].status)) {
      _currentlyProcessingIds.remove(downloadId);
      return;
    }
    _currentlyProcessingIds.remove(downloadId);
    _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
    _processToDownloadId.remove(downloadId);
    _processToDownloadId.removeWhere((k, v) => v == downloadId);

    final formattedError = _formatDownloadError(error);
    String downloadTitle = downloadId;
    if (index != -1) {
      downloadTitle = _downloads[index].title;
      _downloads[index] = _downloads[index].copyWith(
        status: DownloadStatus.failed,
        error: formattedError,
        completedDate: DateTime.now(),
      );
      _markDownloadsDirty();
      await _removeActiveDownload(downloadId);
      await _persistHistoryItem(_downloads[index]);
      notifyListeners();
    } else {
      await _removeActiveDownload(downloadId);
    }

    await _foregroundService.cancelDownload(downloadId);
    _processQueue();

    _logger.error(
      'Download failed: $downloadId - $formattedError',
      component: 'MobileDownloadProvider',
      error: error,
    );
    _logger.showUserLog(
      'Download failed: $downloadTitle — $formattedError',
      isError: true,
    );
  }

  Future<void> cancelDownload(String downloadId) async {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index != -1) {
      _downloads[index] = _downloads[index].copyWith(
        status: DownloadStatus.cancelled,
        completedDate: DateTime.now(),
      );
      _markDownloadsDirty();
      await _removeActiveDownload(downloadId);
      await _persistHistoryItem(_downloads[index]);
      notifyListeners();
    } else {
      await _removeActiveDownload(downloadId);
    }

    final processId =
        _processToDownloadId.entries
            .where((e) => e.value == downloadId)
            .map((e) => e.key)
            .firstOrNull ??
        downloadId;
    await NativeYtdlpAndroid.cancelDownload(processId);

    await _foregroundService.cancelDownload(downloadId);

    _currentlyProcessingIds.remove(downloadId);
    _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
    _processToDownloadId.remove(processId);
    _processToDownloadId.removeWhere((k, v) => v == downloadId);
    _processQueue();

    _logger.info(
      'Download cancelled: $downloadId',
      component: 'MobileDownloadProvider',
    );
  }

  Future<void> pauseDownload(String downloadId) async {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index == -1) return;

    final processId =
        _processToDownloadId.entries
            .where((e) => e.value == downloadId)
            .map((e) => e.key)
            .firstOrNull ??
        downloadId;
    // Pause is implemented as cancel + later re-enqueue. Resume only avoids
    // re-downloading bytes when yt-dlp finds its partial (.part/.ytdl) files
    // still on disk (see resumeDownload). The status text says so explicitly.
    await NativeYtdlpAndroid.cancelDownload(processId);
    await _foregroundService.cancelDownload(downloadId);

    _downloads[index] = _downloads[index].copyWith(
      status: DownloadStatus.paused,
      speed: 0.0,
      statusText: 'Paused — resumes from partial file if still present',
    );
    _markDownloadsDirty();
    await _saveActiveDownloads();
    notifyListeners();

    _currentlyProcessingIds.remove(downloadId);
    _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
    _processToDownloadId.remove(processId);
    _processToDownloadId.removeWhere((k, v) => v == downloadId);
    _processQueue();

    _logger.info(
      'Download paused: $downloadId',
      component: 'MobileDownloadProvider',
    );
  }

  Future<void> resumeDownload(String downloadId) async {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index == -1) return;

    final item = _downloads[index];
    // If an OEM cleaner / user wiped the .part files while paused, yt-dlp
    // cannot resume — it restarts from zero. Detect that now so the UI does
    // not keep showing the stale pre-pause percentage (see progress handler
    // below, which otherwise pins progress with max()).
    final hasPartial = await _hasPartialFiles(item.outputPath);
    final partialWiped = !hasPartial && item.progress > 0.01;
    if (partialWiped) {
      _logger.warning(
        'Partial files missing for ${item.title}; resume will restart from 0%',
        component: 'MobileDownloadProvider',
      );
      _logger.showUserLog(
        'Partial file was cleaned — "${item.title}" restarts from 0%',
        isWarning: true,
      );
    }

    _downloads[index] = _downloads[index].copyWith(
      status: DownloadStatus.pending,
      progress: partialWiped ? 0.0 : item.progress,
      statusText: partialWiped
          ? 'Restarting from beginning (partial file was cleaned)...'
          : 'Resuming...',
      error: null,
    );
    _markDownloadsDirty();
    await _saveActiveDownloads();
    notifyListeners();

    _processQueue();
  }

  /// True when the output dir still holds yt-dlp resume state
  /// (.part, .ytdl, .temp, frag files). Best-effort: the exact filename is
  /// unknown until completion, so any such file counts as "resumable".
  Future<bool> _hasPartialFiles(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return false;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path).toLowerCase();
        if (name.endsWith('.part') ||
            name.endsWith('.ytdl') ||
            name.endsWith('.temp') ||
            name.contains('.part-') ||
            name.contains('frag')) {
          return true;
        }
      }
      return false;
    } catch (_) {
      // On error assume partials exist so we keep old progress (safe side).
      return true;
    }
  }

  Future<void> removeDownload(String downloadId) async {
    final processId =
        _processToDownloadId.entries
            .where((e) => e.value == downloadId)
            .map((e) => e.key)
            .firstOrNull ??
        downloadId;
    await NativeYtdlpAndroid.cancelDownload(processId);

    _downloads.removeWhere((d) => d.id == downloadId);
    _markDownloadsDirty();
    _currentlyProcessingIds.remove(downloadId);
    _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
    _processToDownloadId.remove(processId);
    _processToDownloadId.removeWhere((k, v) => v == downloadId);
    await _removeActiveDownload(downloadId);
    await _removeHistoryItem(downloadId);
    notifyListeners();
  }

  Future<void> retryDownload(String downloadId) async {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index == -1) return;

    final oldItem = _downloads[index];

    _downloads[index] = oldItem.copyWith(
      status: DownloadStatus.pending,
      progress: 0.0,
      error: null,
    );
    _markDownloadsDirty();
    await _saveActiveDownloads();
    notifyListeners();

    _processQueue();
  }

  Stream<double>? getProgressStream(String downloadId) {
    return _progressControllers[downloadId]?.stream;
  }

  void clearCompleted() {
    _downloads.removeWhere((d) => d.status == DownloadStatus.completed);
    _markDownloadsDirty();
    unawaited(
      _removeHistoryByStatus(DownloadStatus.completed).catchError((
        Object e,
        StackTrace st,
      ) {
        _logger.warning(
          'Failed to clear completed history: $e',
          component: 'MobileDownloadProvider',
          error: e,
          stackTrace: st,
        );
      }),
    );
    notifyListeners();
  }

  void clearFailed() {
    _downloads.removeWhere((d) => d.status == DownloadStatus.failed);
    _markDownloadsDirty();
    unawaited(
      _removeHistoryByStatus(DownloadStatus.failed).catchError((
        Object e,
        StackTrace st,
      ) {
        _logger.warning(
          'Failed to clear failed history: $e',
          component: 'MobileDownloadProvider',
          error: e,
          stackTrace: st,
        );
      }),
    );
    notifyListeners();
  }

  void clearCancelled() {
    _downloads.removeWhere((d) => d.status == DownloadStatus.cancelled);
    _markDownloadsDirty();
    unawaited(
      _removeHistoryByStatus(DownloadStatus.cancelled).catchError((
        Object e,
        StackTrace st,
      ) {
        _logger.warning(
          'Failed to clear cancelled history: $e',
          component: 'MobileDownloadProvider',
          error: e,
          stackTrace: st,
        );
      }),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _settingsProvider?.removeListener(_onSettingsChanged);
    unawaited(
      (_nativeEventsSubscription?.cancel() ?? Future<void>.value()).catchError((
        Object e,
        StackTrace st,
      ) {
        _logger.warning(
          'Failed to cancel native events subscription: $e',
          component: 'MobileDownloadProvider',
          error: e,
          stackTrace: st,
        );
      }),
    );
    _nativeEventsSubscription = null;
    _pendingProgressNotify?.cancel();
    _pendingProgressNotify = null;

    for (final controller in _progressControllers.values) {
      try {
        controller.close();
      } catch (_) {}
    }
    _progressControllers.clear();
    _currentlyProcessingIds.clear();

    unawaited(
      _foregroundService.cancelAll().catchError((Object e, StackTrace st) {
        _logger.warning(
          'Failed to cancel foreground service on dispose: $e',
          component: 'MobileDownloadProvider',
        );
      }),
    );

    super.dispose();
  }

  String _formatDownloadError(String error) {
    return ErrorHelper.formatDownloadError(error);
  }

  bool _isTerminalStatus(DownloadStatus status) {
    return status == DownloadStatus.completed ||
        status == DownloadStatus.failed ||
        status == DownloadStatus.cancelled;
  }

  double? _extractSpeedBytesPerSecond(String line) {
    final trimmed = line.trim();
    final numericSpeed = double.tryParse(trimmed);
    if (numericSpeed != null && numericSpeed > 0) return numericSpeed;

    final speedMatch = RegExp(
      r'at\s+([0-9]*\.?[0-9]+)\s*([KMG]?i?)B/s',
      caseSensitive: false,
    ).firstMatch(line);
    if (speedMatch == null) return null;

    final value = double.tryParse(speedMatch.group(1) ?? '');
    final unit = (speedMatch.group(2) ?? '').toLowerCase();
    if (value == null) return null;

    switch (unit) {
      case 'k':
      case 'ki':
        return value * 1024;
      case 'm':
      case 'mi':
        return value * 1024 * 1024;
      case 'g':
      case 'gi':
        return value * 1024 * 1024 * 1024;
      default:
        return value;
    }
  }

  DownloadStatus _statusFromNativeLine(String line, DownloadItem item) {
    final lower = line.toLowerCase();
    if (lower.contains('merging formats') || lower.contains('[merger]')) {
      return DownloadStatus.merging;
    }
    if (lower.contains('destination:')) {
      if (item.audioOnly ||
          lower.contains('.m4a') ||
          lower.contains('.mp3') ||
          lower.contains('.opus')) {
        return DownloadStatus.downloadingAudio;
      }
      return DownloadStatus.downloadingVideo;
    }
    if (lower.contains('[download]')) {
      return item.audioOnly
          ? DownloadStatus.downloadingAudio
          : DownloadStatus.downloadingVideo;
    }
    return item.status;
  }

  String _humanReadableStatus(String line, DownloadItem item) {
    final lower = line.toLowerCase();
    final trimmed = line.trim();
    if (double.tryParse(trimmed) != null) return 'Downloading...';
    if (line.isEmpty) return '';

    if (lower.contains('merging formats') || lower.contains('[merger]')) {
      return 'Merging formats...';
    }
    if (lower.contains('extracting url') ||
        lower.contains('downloading webpage')) {
      return 'Preparing download...';
    }
    if (lower.contains('downloading') && lower.contains('player')) {
      return 'Preparing download...';
    }
    if (lower.contains('downloading m3u8') ||
        lower.contains('downloading json')) {
      return 'Fetching stream info...';
    }
    if (lower.contains('downloading') && lower.contains('thumbnail')) {
      return 'Saving thumbnail...';
    }
    if (lower.contains('writing') && lower.contains('thumbnail')) {
      return 'Saving thumbnail...';
    }
    if (lower.contains('[info]') && lower.contains('format')) {
      return 'Resolving formats...';
    }

    // Parse actual download progress line: [download]  45.2% of 150.00MiB at  5.00MiB/s ETA 00:30
    final percentMatch = RegExp(r'(\d+\.?\d*)%').firstMatch(line);
    final sizeMatch = RegExp(r'of\s+([0-9.]+\s*[KMG]i?B)').firstMatch(line);
    final speedMatch = RegExp(r'at\s+([0-9.]+\s*[KMG]?i?B/s)').firstMatch(line);
    final etaMatch = RegExp(r'ETA\s+(\S+)').firstMatch(line);

    if (percentMatch != null) {
      final percent = percentMatch.group(1);
      final parts = <String>['$percent%'];
      if (sizeMatch != null) parts.add('of ${sizeMatch.group(1)}');
      if (speedMatch != null) parts.add('at ${speedMatch.group(1)}');
      if (etaMatch != null) parts.add('ETA ${etaMatch.group(1)}');
      return parts.join(' ');
    }

    if (lower.contains('destination:')) {
      final fileName = line.split(':').last.trim().split('/').last;
      return 'Downloading $fileName';
    }

    return line;
  }

  Future<File?> _findDownloadedFile(DownloadItem item) async {
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        if (_isDisposed) return null;
        final file = await findDownloadedFile(item);
        if (file != null) return file;
        if (_isDisposed) return null;
        await Future.delayed(const Duration(milliseconds: 450));
      }
      return null;
    } catch (e) {
      _logger.warning(
        'Failed to resolve downloaded output file: $e',
        component: 'MobileDownloadProvider',
      );
      return null;
    }
  }

  Future<File?> _findThumbnailFile(DownloadItem item) async {
    try {
      final mediaFile = item.savePath != null ? File(item.savePath!) : null;
      final mediaDir = mediaFile?.parent ?? Directory(item.outputPath);
      if (!await mediaDir.exists()) return null;

      final titleWords = item.title
          .toLowerCase()
          .split(' ')
          .where((w) => w.trim().isNotEmpty)
          .take(4)
          .toList();

      final candidates = await mediaDir
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .where((file) {
            final lower = file.path.toLowerCase();
            return lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg') ||
                lower.endsWith('.png') ||
                lower.endsWith('.webp');
          })
          .toList();

      if (candidates.isEmpty) return null;

      final titleMatches = candidates.where((file) {
        final name = file.uri.pathSegments.last.toLowerCase();
        return titleWords.isEmpty || titleWords.every(name.contains);
      }).toList();

      final pool = titleMatches.isNotEmpty ? titleMatches : candidates;
      // PF4 fix: avoid lastModifiedSync O(n log n) sync I/O; cache async modified times once
      final modTimes = <File, DateTime>{};
      await Future.wait(
        pool.map((f) async {
          try {
            modTimes[f] = await f.lastModified();
          } catch (_) {
            try {
              modTimes[f] = (await f.stat()).modified;
            } catch (_) {
              modTimes[f] = DateTime.fromMillisecondsSinceEpoch(0);
            }
          }
        }),
      );
      pool.sort(
        (a, b) => modTimes[b]!.millisecondsSinceEpoch.compareTo(
          modTimes[a]!.millisecondsSinceEpoch,
        ),
      );
      return pool.first;
    } catch (e) {
      _logger.warning(
        'Failed to resolve thumbnail file: $e',
        component: 'MobileDownloadProvider',
      );
      return null;
    }
  }

  int? _parseTargetHeight(String? videoQuality) {
    if (videoQuality == null || videoQuality.isEmpty) return null;
    return int.tryParse(videoQuality.replaceAll('p', ''));
  }

  String? _formatVideoQuality(dynamic targetHeight) {
    if (targetHeight == null) return null;
    return '${targetHeight.toString()}p';
  }

  Future<int?> _getAvailableDiskSpaceMobile(String dirPath) async {
    try {
      const channel = MethodChannel(
        'com.aerotube.youtube_downloader/permissions',
      );
      try {
        final free = await channel
            .invokeMethod<int>('getFreeSpace', {'path': dirPath})
            .timeout(const Duration(seconds: 3));
        if (free != null && free > 0) return free;
      } catch (_) {}
      try {
        await FileStat.stat(dirPath).timeout(const Duration(seconds: 2));
        // FileStat doesn't give free space; try df fallback
      } catch (_) {}
      try {
        final dfResult = await Process.run('df', [
          dirPath,
        ]).timeout(const Duration(seconds: 3));
        if (dfResult.exitCode == 0) {
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
    } catch (_) {
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
}
