import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/utils/platform_utils.dart';
import '../models/download_item.dart';
import '../models/download_mode.dart';
import '../services/android_storage_service.dart';
import '../services/cookie_service.dart';
import '../services/download_foreground_service.dart';
import '../services/logging_service.dart';
import '../services/native_ytdlp_android.dart';
import '../services/ytdlp_service_android.dart';

/// Mobile-optimized download provider with foreground service integration.
class MobileDownloadProvider extends ChangeNotifier {
  static const String _historyBoxName = 'downloads_history_mobile';
  final dynamic ytdlpService; // YtdlpServiceAndroid on mobile
  final DownloadForegroundService _foregroundService =
      DownloadForegroundService();
  final AndroidStorageService _storageService = AndroidStorageService();
  final LoggingService _logger = LoggingService();

  final List<DownloadItem> _downloads = [];
  final Map<String, StreamController<double>> _progressControllers = {};
  final Map<String, String> _processToDownloadId = {};
  StreamSubscription<Map<String, dynamic>>? _nativeEventsSubscription;
  Box<DownloadItem>? _historyBox;

  bool _isInitialized = false;
  int _maxConcurrentDownloads = 3;

  MobileDownloadProvider({
    required this.ytdlpService,
    CookieService? cookieService, // kept for signature compatibility
  });

  List<DownloadItem> get downloads => List.unmodifiable(_downloads);
  List<DownloadItem> get activeDownloads => _downloads
      .where(
        (d) =>
            d.status == DownloadStatus.downloadingVideo ||
            d.status == DownloadStatus.downloadingAudio ||
            d.status == DownloadStatus.merging ||
            d.status == DownloadStatus.pending ||
            d.status == DownloadStatus.queued,
      )
      .toList();
  List<DownloadItem> get completedDownloads =>
      _downloads.where((d) => d.status == DownloadStatus.completed).toList();
  List<DownloadItem> get failedDownloads =>
      _downloads.where((d) => d.status == DownloadStatus.failed).toList();

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

    try {
      await _initHistoryStorage();
      await _initBackground();
      _isInitialized = true;
      _logger.info(
        'MobileDownloadProvider initialized',
        component: 'MobileDownloadProvider',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize MobileDownloadProvider',
        component: 'MobileDownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _initHistoryStorage() async {
    _historyBox ??= await Hive.openBox<DownloadItem>(_historyBoxName);
    final persistedHistory = _historyBox!.values.toList()
      ..sort(
        (a, b) => (b.completedDate ?? DateTime(1970)).compareTo(
          a.completedDate ?? DateTime(1970),
        ),
      );

    final activeItems = _downloads.where((d) => !_isTerminalStatus(d.status));
    _downloads
      ..clear()
      ..addAll(activeItems)
      ..addAll(persistedHistory);
    notifyListeners();
  }

  Future<void> _persistHistoryItem(DownloadItem item) async {
    final box = _historyBox;
    if (box == null) return;
    await box.put(item.id, item);
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

    if (PlatformUtils.isAndroid) {
      try {
        await _storageService.requestStoragePermission();
      } on PlatformException catch (e, stackTrace) {
        _logger.warning(
          'Storage permission request deferred due to concurrent permission flow: $e',
          component: 'MobileDownloadProvider',
        );
        _logger.debug(
          'Permission concurrency stack: $stackTrace',
          component: 'MobileDownloadProvider',
        );
      }
    }
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
  }) async {
    try {
      final downloadId = DateTime.now().millisecondsSinceEpoch.toString();

      String saveDir;
      if (outputPath != null) {
        saveDir = outputPath;
      } else {
        saveDir = mode == DownloadMode.audioOnly
            ? await _storageService.getAudioDirectory()
            : await _storageService.getVideoDirectory();
      }

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
      );

      _downloads.add(downloadItem);
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

  void _processQueue() {
    final availableSlots = _maxConcurrentDownloads - runningDownloadsCount;
    if (availableSlots <= 0) return;

    final queuedItems = _downloads
        .where(
          (d) =>
              d.status == DownloadStatus.queued ||
              d.status == DownloadStatus.pending,
        )
        .take(availableSlots)
        .toList();

    for (final item in queuedItems) {
      _startDownload(item);
    }
  }

  Future<void> _startDownload(DownloadItem item) async {
    try {
      _updateDownloadStatus(
        item.id,
        item.audioOnly
            ? DownloadStatus.downloadingAudio
            : DownloadStatus.downloadingVideo,
      );

      try {
        await _foregroundService.startDownload(
          downloadId: item.id,
          url: item.url,
          outputPath: item.outputPath,
          title: item.title,
          format: null,
          cookiesPath: null,
          userAgent: null,
        );
      } catch (e) {
        _logger.warning(
          'Foreground service notification failed (non-fatal): $e',
          component: 'MobileDownloadProvider',
        );
      }

      _progressControllers[item.id] = StreamController<double>.broadcast();
      _processToDownloadId[item.id] = item.id;

      if (ytdlpService is! YtdlpServiceAndroid) {
        throw UnsupportedError(
          'Only YtdlpServiceAndroid is supported on mobile',
        );
      }

      final service = ytdlpService as YtdlpServiceAndroid;

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
        archivePath: item.useDownloadArchive ? item.outputPath : null,
        embedSubtitles: item.embedSubtitles,
        subtitleLanguages: item.subtitleLanguages,
      );

      if (processId != null) {
        _processToDownloadId[processId] = item.id;

        final latest = _downloads.firstWhere(
          (d) => d.id == item.id,
          orElse: () => item,
        );
        if (!_isTerminalStatus(latest.status)) {
          await _completeDownload(item.id);
        }
      } else {
        throw Exception('yt-dlp returned failure - check device logs');
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Download failed: ${item.title}',
        component: 'MobileDownloadProvider',
        error: e,
        stackTrace: stackTrace,
      );
      await _failDownload(item.id, e.toString());
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
      final rawProgress = (event['progress'] as num?)?.toDouble() ?? -1.0;
      final eta = (event['eta'] as num?)?.toInt() ?? item.eta;
      final line = (event['line'] ?? '').toString();
      final parsedProgress = rawProgress >= 0
          ? (rawProgress / 100.0).clamp(0.0, 1.0)
          : item.progress;

      final parsedSpeed = _extractSpeedBytesPerSecond(line) ?? item.speed;
      final status = _statusFromNativeLine(line, item);

      _downloads[index] = item.copyWith(
        progress: parsedProgress < item.progress
            ? item.progress
            : parsedProgress,
        speed: parsedSpeed,
        eta: eta < 0 ? item.eta : eta,
        status: status,
      );

      _progressControllers[downloadId]?.add(_downloads[index].progress);
      _foregroundService.updateProgress(
        downloadId: downloadId,
        progress: _downloads[index].progress,
        speed: parsedSpeed,
        statusText: line.isNotEmpty ? line : null,
      );
      notifyListeners();
      return;
    }

    if (type == 'completed') {
      _completeDownload(downloadId);
      return;
    }

    if (type == 'error') {
      final error = (event['error'] ?? 'Native download failed').toString();
      _failDownload(downloadId, error);
      return;
    }

    if (type == 'cancelled') {
      cancelDownload(downloadId);
    }
  }

  void _updateDownloadStatus(String downloadId, DownloadStatus status) {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index != -1) {
      _downloads[index] = _downloads[index].copyWith(
        status: status,
        progress: _downloads[index].progress,
      );
      notifyListeners();
    }
  }

  Future<void> _completeDownload(String downloadId) async {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
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
      await _persistHistoryItem(_downloads[index]);
      notifyListeners();
    }

    await _foregroundService.completeDownload(downloadId);

    _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
    _processToDownloadId.remove(downloadId);
    _processQueue();

    _logger.info(
      'Download completed: $downloadId',
      component: 'MobileDownloadProvider',
    );
  }

  Future<void> _failDownload(String downloadId, String error) async {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index != -1) {
      _downloads[index] = _downloads[index].copyWith(
        status: DownloadStatus.failed,
        error: error,
        completedDate: DateTime.now(),
      );
      await _persistHistoryItem(_downloads[index]);
      notifyListeners();
    }

    await _foregroundService.cancelDownload(downloadId);

    _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
    _processToDownloadId.remove(downloadId);
    _processQueue();

    _logger.error(
      'Download failed: $downloadId',
      component: 'MobileDownloadProvider',
      error: error,
    );
  }

  Future<void> cancelDownload(String downloadId) async {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index != -1) {
      _downloads[index] = _downloads[index].copyWith(
        status: DownloadStatus.cancelled,
        completedDate: DateTime.now(),
      );
      await _persistHistoryItem(_downloads[index]);
      notifyListeners();
    }

    await _foregroundService.cancelDownload(downloadId);

    _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
    _processToDownloadId.remove(downloadId);
    _processQueue();

    _logger.info(
      'Download cancelled: $downloadId',
      component: 'MobileDownloadProvider',
    );
  }

  Future<void> removeDownload(String downloadId) async {
    _downloads.removeWhere((d) => d.id == downloadId);
    _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
    _processToDownloadId.remove(downloadId);
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
    notifyListeners();

    _processQueue();
  }

  Stream<double>? getProgressStream(String downloadId) {
    return _progressControllers[downloadId]?.stream;
  }

  void clearCompleted() {
    _downloads.removeWhere((d) => d.status == DownloadStatus.completed);
    unawaited(_removeHistoryByStatus(DownloadStatus.completed));
    notifyListeners();
  }

  void clearFailed() {
    _downloads.removeWhere((d) => d.status == DownloadStatus.failed);
    unawaited(_removeHistoryByStatus(DownloadStatus.failed));
    notifyListeners();
  }

  void clearCancelled() {
    _downloads.removeWhere((d) => d.status == DownloadStatus.cancelled);
    unawaited(_removeHistoryByStatus(DownloadStatus.cancelled));
    notifyListeners();
  }

  @override
  void dispose() {
    _nativeEventsSubscription?.cancel();
    _nativeEventsSubscription = null;

    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();

    _foregroundService.cancelAll();

    super.dispose();
  }

  bool _isTerminalStatus(DownloadStatus status) {
    return status == DownloadStatus.completed ||
        status == DownloadStatus.failed ||
        status == DownloadStatus.cancelled;
  }

  double? _extractSpeedBytesPerSecond(String line) {
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

  Future<File?> _findDownloadedFile(DownloadItem item) async {
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        final dir = Directory(item.outputPath);
        if (await dir.exists()) {
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
          if (candidates.isNotEmpty) {
            final normalizedTitle = item.title.toLowerCase();
            final titleMatch = candidates.where((f) {
              final name = f.path
                  .split(Platform.pathSeparator)
                  .last
                  .toLowerCase();
              return normalizedTitle
                  .split(' ')
                  .where((w) => w.trim().isNotEmpty)
                  .take(4)
                  .every((w) => name.contains(w));
            }).toList();

            final pool = titleMatch.isNotEmpty ? titleMatch : candidates;
            pool.sort(
              (a, b) =>
                  b.lastModifiedSync().millisecondsSinceEpoch -
                  a.lastModifiedSync().millisecondsSinceEpoch,
            );
            return pool.first;
          }
        }
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
      pool.sort(
        (a, b) =>
            b.lastModifiedSync().millisecondsSinceEpoch -
            a.lastModifiedSync().millisecondsSinceEpoch,
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
}
