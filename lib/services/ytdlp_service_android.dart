import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/video_info.dart';
import '../models/playlist_info.dart';
import 'notification_service.dart';
import 'logging_service.dart';
import 'native_ytdlp_android.dart';

/// Android yt-dlp service powered by youtubedl-android native library
class YtdlpServiceAndroid {
  String? _cookiePath;
  String? _webViewPath;
  String? _ffmpegPath;
  String? _userAgent;
  bool _enableCookies = false;
  bool _isInitialized = false;
  String? _cachedLatestVersion;

  final NotificationService? _notificationService;
  final LoggingService _logger = LoggingService();

  YtdlpServiceAndroid({
    String? cookiePath,
    String? webViewPath,
    String? ffmpegPath,
    NotificationService? notificationService,
  }) : _cookiePath = cookiePath,
       _webViewPath = webViewPath,
       _ffmpegPath = ffmpegPath,
       _notificationService = notificationService;

  set cookiePath(String? path) => _cookiePath = path;
  String? get cookiePath => _cookiePath;
  set webViewPath(String? path) => _webViewPath = path;
  String? get webViewPath => _webViewPath;
  set ffmpegPath(String? path) => _ffmpegPath = path;
  String? get ffmpegPath => _ffmpegPath;
  set userAgent(String? ua) => _userAgent = ua;
  String? get userAgent => _userAgent;
  set enableCookies(bool value) => _enableCookies = value;

  bool get isUsingCookies => _enableCookies && _cookiePath != null;
  String? get activeCookieSource => null;

  /// Initialize the service
  Future<void> initialize({bool force = false}) async {
    if (_isInitialized && !force) return;

    _logger.info(
      'Starting Android yt-dlp initialization (native library)',
      component: 'YtdlpServiceAndroid',
    );

    try {
      // Check if we have a cookie file path
      // Note: On Android, we often use NativeYtdlpAndroid which handles its own initialization

      // Log the current yt-dlp version for debugging
      final version = await NativeYtdlpAndroid.getVersion();
      _logger.info(
        'yt-dlp version: $version',
        component: 'YtdlpServiceAndroid',
      );

      _isInitialized = true;
      _logger.info(
        'Android yt-dlp service initialized',
        component: 'YtdlpServiceAndroid',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize Android yt-dlp service',
        component: 'YtdlpServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      throw YtdlpAndroidException('Initialization failed: $e');
    }
  }

  /// Check if yt-dlp is available
  Future<bool> isAvailable() async {
    try {
      final version = await NativeYtdlpAndroid.getVersion();
      return version != null;
    } catch (e) {
      _logger.error(
        'Error checking yt-dlp availability',
        component: 'YtdlpServiceAndroid',
        error: e,
      );
      return false;
    }
  }

  /// Get yt-dlp version
  Future<String?> getVersion() async {
    try {
      return await NativeYtdlpAndroid.getVersion();
    } catch (e) {
      return null;
    }
  }

  /// Get latest available version - uses GitHub API
  Future<String?> getLatestVersion({bool forceRefresh = false}) async {
    // Return cached version if available and not forcing refresh
    if (!forceRefresh && _cachedLatestVersion != null) {
      return _cachedLatestVersion;
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String tagName = data['tag_name'] as String;
        _cachedLatestVersion = tagName;
        return tagName;
      }
    } catch (e) {
      _logger.error(
        'Failed to get latest version from GitHub',
        component: 'YtdlpServiceAndroid',
        error: e,
      );
    }
    return null;
  }

  /// Check if a newer version is available - version comparison
  bool _isNewerVersion(String current, String latest) {
    final normCurrent = current.startsWith('v')
        ? current.substring(1)
        : current;
    final normLatest = latest.startsWith('v') ? latest.substring(1) : latest;

    final currentParts = normCurrent.split('.');
    final latestParts = normLatest.split('.');

    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      final c = int.tryParse(currentParts[i]) ?? 0;
      final l = int.tryParse(latestParts[i]) ?? 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Check if a newer version is available - uses GitHub API
  Future<YtdlpUpdateInfo?> checkForUpdateWithProgress() async {
    try {
      final currentVersion = await getVersion();
      if (currentVersion == null) {
        return null;
      }

      final latestVersion = await getLatestVersion(forceRefresh: true);

      if (latestVersion == null) {
        return YtdlpUpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          downloadUrl:
              'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp',
          publishedAt: DateTime.now(),
          releaseNotes: 'Update check failed',
        );
      }

      final hasUpdate = _isNewerVersion(currentVersion, latestVersion);

      return YtdlpUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl:
            'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp',
        publishedAt: DateTime.now(),
        releaseNotes: hasUpdate
            ? 'New version available: $latestVersion'
            : 'Up to date',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check for updates',
        component: 'YtdlpServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Download and install update with progress callback
  Future<bool> downloadAndInstallUpdate(
    String downloadUrl, {
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
    bool Function()? isCancelled,
  }) async {
    StreamSubscription<Map<String, dynamic>>? progressSubscription;
    try {
      onStatus('Updating yt-dlp via native library...');

      progressSubscription = NativeYtdlpAndroid.downloadEvents.listen((event) {
        if (event['event'] == 'progress') {
          final progress = (event['progress'] as num?)?.toDouble() ?? 0.0;
          onProgress(progress);
        }
      });

      final result = await NativeYtdlpAndroid.updateYoutubeDL(
        updateChannel: 'stable',
      );

      onProgress(1.0);

      final status = result['status'] as String?;
      if (result['success'] == true) {
        if (status == 'up_to_date') {
          onStatus('Already up to date!');
        } else {
          onStatus('Update complete!');
        }
        return true;
      } else {
        final error =
            result['error'] ??
            result['message'] ??
            'Native update failed (status: ${status ?? 'unknown'})';
        onStatus('Update failed: $error');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Update failed',
        component: 'YtdlpServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      onStatus('Update failed: $e');
      return false;
    } finally {
      await progressSubscription?.cancel();
    }
  }

  Future<Directory> _getTempDirectory() async {
    return await getTemporaryDirectory();
  }

  /// Update yt-dlp - delegates to native library
  Future<bool> update({
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    return downloadAndInstallUpdate(
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp',
      onProgress: onProgress ?? (_) {},
      onStatus: onStatus ?? (_) {},
    );
  }

  /// Handle "broken" yt-dlp errors by recommending an update
  bool isBrokenError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('signature extraction failed') ||
        lowerError.contains('unable to extract') ||
        lowerError.contains(
          'youtube said: manual proxy of this kind is not allowed',
        );
  }

  /// Fetch video information from URL
  Future<VideoInfo> getVideoInfo(
    String url, {
    Function(String status)? onProgress,
  }) async {
    onProgress?.call('Fetching video information...');

    _logger.info(
      'Getting video info for: $url',
      component: 'YtdlpServiceAndroid',
    );

    try {
      final result = await NativeYtdlpAndroid.getVideoInfo(
        url,
        cookiesPath: _enableCookies ? _cookiePath : null,
        userAgent: _userAgent,
      );

      _logger.debug(
        'Raw video info result: ${result.keys.join(', ')}',
        component: 'YtdlpServiceAndroid',
      );

      final infoData = result['info'];
      if (infoData == null) {
        throw YtdlpAndroidException('No info object found in result');
      }

      return VideoInfo.fromJson(result['info'] as Map<String, dynamic>);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get video info',
        component: 'YtdlpServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Fetch playlist information from URL
  Future<PlaylistInfo> getPlaylistInfo(
    String url, {
    Function(String status)? onProgress,
  }) async {
    onProgress?.call('Fetching playlist information...');

    _logger.info(
      'Getting playlist info for: $url',
      component: 'YtdlpServiceAndroid',
    );

    try {
      final result = await NativeYtdlpAndroid.getPlaylistInfo(
        url,
        cookiesPath: _enableCookies ? _cookiePath : null,
        userAgent: _userAgent,
      );

      _logger.debug(
        'Raw playlist info result keys: ${result.keys.join(', ')}',
        component: 'YtdlpServiceAndroid',
      );

      final playlistData = result['playlist'];
      if (playlistData == null) {
        throw YtdlpAndroidException('No playlist object found in result');
      }

      return PlaylistInfo.fromJson(result['playlist'] as Map<String, dynamic>);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get playlist info',
        component: 'YtdlpServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Download video with specified format
  Future<String?> downloadVideo({
    required String url,
    required String outputPath,
    String? formatId,
    String? audioFormatId,
    String? processId,
    bool audioOnly = false,
    String? audioQuality,
    int? targetHeight,
    bool embedThumbnail = true,
    bool embedMetadata = true,
    List<String>? subtitleLanguages,
    bool embedSubtitles = false,
    bool sponsorBlock = false,
    String? archivePath,
    Function(double progress, double speed, int eta)? onProgress,
  }) async {
    StreamSubscription<Map<String, dynamic>>? progressSubscription;
    try {
      // Build format string
      String? format;
      if (audioOnly) {
        format = audioFormatId ?? 'bestaudio';
      } else if (formatId != null && audioFormatId != null) {
        format = '$formatId+$audioFormatId';
      } else if (formatId != null) {
        format = formatId;
      } else {
        // Default to best video with mp4
        format = 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best';
      }

      // Generate process ID for tracking
      final processIdToUse =
          processId ?? 'download_${DateTime.now().millisecondsSinceEpoch}';

      _logger.info(
        'Starting download: $url -> $outputPath',
        component: 'YtdlpServiceAndroid',
      );

      if (onProgress != null) {
        progressSubscription = NativeYtdlpAndroid.downloadEvents.listen((
          event,
        ) {
          if (event['process_id'] == processIdToUse &&
              event['event'] == 'progress') {
            final progress = (event['progress'] as num?)?.toDouble() ?? 0.0;
            final eta = (event['eta'] as num?)?.toInt() ?? 0;
            final line = (event['line'] as num?)?.toDouble() ?? 0.0;
            onProgress(progress, line, eta);
          }
        });
      }

      final result = await NativeYtdlpAndroid.downloadVideo(
        url: url,
        outputPath: outputPath,
        format: format,
        cookiesPath: _enableCookies ? _cookiePath : null,
        userAgent: _userAgent,
        processId: processIdToUse,
      );

      if (result['success'] != true) {
        final error = result['error'] ?? 'Unknown error';
        _logger.error(
          'Download failed: $error',
          component: 'YtdlpServiceAndroid',
        );
        return null;
      }

      return result['process_id'] as String?;
    } catch (e, stackTrace) {
      _logger.error(
        'Download failed with exception',
        component: 'YtdlpServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      await progressSubscription?.cancel();
    }
  }
}

class YtdlpAndroidException implements Exception {
  final String message;
  YtdlpAndroidException(this.message);
  @override
  String toString() => 'YtdlpAndroidException: $message';
}

class YtdlpUpdateInfo {
  final String currentVersion;
  final String? latestVersion;
  final String? downloadUrl;
  final DateTime? publishedAt;
  final String? releaseNotes;

  YtdlpUpdateInfo({
    required this.currentVersion,
    this.latestVersion,
    this.downloadUrl,
    this.publishedAt,
    this.releaseNotes,
  });
}
