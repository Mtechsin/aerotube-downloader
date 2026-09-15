import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/video_info.dart';
import '../../models/playlist_info.dart';
import '../notification/notification_service.dart';
import '../core/logging_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/version_utils.dart';
import '../../core/utils/error_helper.dart';
import 'native_ytdlp_android.dart';
import 'ytdlp_tool_service.dart';

export 'ytdlp_tool_service.dart' show YtdlpUpdateInfo;

/// Android yt-dlp service powered by youtubedl-android native library
class YtdlpServiceAndroid implements YtdlpToolService {
  String? _cookiePath;
  String? _webViewPath;
  String? _ffmpegPath;
  String? _userAgent;
  bool _enableCookies = false;
  bool _isInitialized = false;
  String? _cachedLatestVersion;
  DateTime? _cacheTime;
  static DateTime? _lastFetchAttempt;
  static const Duration _cacheExpiry = Duration(minutes: 60);
  static const Duration _throttleWindow = Duration(seconds: 60);

  final LoggingService _logger = LoggingService();

  String? _getGithubToken() {
    try {
      final env = Platform.environment['GITHUB_TOKEN'];
      if (env != null && env.isNotEmpty) return env;
    } catch (_) {}
    const fromEnv = String.fromEnvironment('GITHUB_TOKEN');
    if (fromEnv.isNotEmpty) return fromEnv;
    return null;
  }

  bool _isRateLimit(Object e) {
    final m = e.toString().toLowerCase();
    return m.contains('rate limit') || m.contains('403') || m.contains('429');
  }

  // Cancellation support (mirrors Windows)
  int _fetchGen = 0;

  @override
  Future<void> cancelFetch() async {
    _fetchGen++;
    _logger.info('Android fetch cancelled by user (gen $_fetchGen)', component: 'YtdlpServiceAndroid');
  }

  YtdlpServiceAndroid({
    String? cookiePath,
    String? webViewPath,
    String? ffmpegPath,
    NotificationService? notificationService,
  }) : _cookiePath = cookiePath,
       _webViewPath = webViewPath,
       _ffmpegPath = ffmpegPath;

  @override
  String get ytdlpPath => 'yt-dlp';
  @override
  set ytdlpPath(String v) {}
  @override
  void markReady(String version) {}

  @override
  set cookiePath(String? path) => _cookiePath = path;
  @override
  String? get cookiePath => _cookiePath;
  @override
  String? get cookieBrowser => null;
  @override
  set cookieBrowser(String? v) {}
  @override
  set webViewPath(String? path) => _webViewPath = path;
  @override
  String? get webViewPath => _webViewPath;
  @override
  set ffmpegPath(String? path) => _ffmpegPath = path;
  @override
  String? get ffmpegPath => _ffmpegPath;
  @override
  set userAgent(String? ua) => _userAgent = ua;
  @override
  String? get userAgent => _userAgent;
  @override
  set enableCookies(bool value) => _enableCookies = value;
  @override
  bool get enableCookies => _enableCookies;

  bool get isUsingCookies => _enableCookies && _cookiePath != null;
  String? get activeCookieSource => null;

  /// Initialize the service
  @override
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
  @override
  Future<bool> isAvailable() async {
    try {
      final version = await NativeYtdlpAndroid.getVersion();
      return version != null && version != "Unknown";
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
  @override
  Future<String?> getVersion() async {
    try {
      return await NativeYtdlpAndroid.getVersion();
    } catch (e) {
      return null;
    }
  }

  /// Get latest available version - uses GitHub API (rate-limit friendly)
  @override
  Future<String?> getLatestVersion({bool forceRefresh = false}) async {
    final now = DateTime.now();

    // Throttle: at most once per 60s
    if (!forceRefresh &&
        _lastFetchAttempt != null &&
        now.difference(_lastFetchAttempt!) < _throttleWindow) {
      if (_cachedLatestVersion != null) {
        _logger.debug(
          'Android getLatestVersion throttled, returning cached $_cachedLatestVersion',
          component: 'YtdlpServiceAndroid',
        );
        return _cachedLatestVersion;
      }
      _logger.debug(
        'Android getLatestVersion throttled, no cache yet',
        component: 'YtdlpServiceAndroid',
      );
      return null;
    }

    // Cache expiry: 60 minutes
    if (!forceRefresh &&
        _cachedLatestVersion != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheExpiry) {
      return _cachedLatestVersion;
    }

    _lastFetchAttempt = now;

    final token = _getGithubToken();
    final headers = <String, String>{
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'AeroTube-Updater',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await http
          .get(
            Uri.parse(AppConstants.ytdlpLatestReleaseApiUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tagName = data['tag_name'] as String?;
        if (tagName != null && tagName.isNotEmpty) {
          _cachedLatestVersion = tagName;
          _cacheTime = DateTime.now();
          return tagName;
        }
        return null;
      } else if (response.statusCode == 403 || response.statusCode == 429) {
        if (_cachedLatestVersion != null) {
          _logger.warning(
            'Rate limited but returning cached $_cachedLatestVersion',
            component: 'YtdlpServiceAndroid',
          );
          return _cachedLatestVersion;
        }
        throw Exception(
          'GitHub API rate limit (${response.statusCode}): ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)} '
          'Try again later or set GITHUB_TOKEN for higher limits.',
        );
      } else {
        throw Exception(
            'GitHub API error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (_isRateLimit(e) && _cachedLatestVersion != null) {
        _logger.warning(
          'Rate limit exception but returning cached $_cachedLatestVersion: $e',
          component: 'YtdlpServiceAndroid',
        );
        return _cachedLatestVersion;
      }
      rethrow;
    }
  }

  bool _isNewerVersion(String current, String latest) =>
      VersionUtils.isNewerVersion(current, latest);

  /// Check if a newer version is available - uses GitHub API
  @override
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
          downloadUrl: AppConstants.ytdlpAndroidDownloadUrl,
          publishedAt: DateTime.now(),
          releaseNotes: 'Update check failed',
        );
      }

      final hasUpdate = _isNewerVersion(currentVersion, latestVersion);

      return YtdlpUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl: AppConstants.ytdlpAndroidDownloadUrl,
        publishedAt: DateTime.now(),
        releaseNotes: hasUpdate
            ? 'New version available: $latestVersion'
            : 'Up to date',
      );
    } catch (e, stackTrace) {
      if (e.toString().toLowerCase().contains('rate limit') ||
          e.toString().contains('403') ||
          e.toString().contains('429')) {
        _logger.warning(
          'Rate limited while checking yt-dlp updates: $e',
          component: 'YtdlpServiceAndroid',
        );
        rethrow;
      }
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
  @override
  Future<bool> downloadAndInstallUpdate(
    String downloadUrl, {
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
    bool Function()? isCancelled,
  }) async {
    StreamSubscription<Map<String, dynamic>>? progressSubscription;
    try {
      onStatus('Preparing yt-dlp...');
      await initialize();

      if (isCancelled?.call() == true) {
        onStatus('Cancelled');
        return false;
      }

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
          final ver = result['version'] as String?;
          onStatus(ver != null ? 'Update complete (v$ver)!' : 'Update complete!');
        }
        return true;
      } else {
        final error =
            result['error'] ??
            result['message'] ??
            'Native update failed (status: ${status ?? 'unknown'})';
        final suggestion = result['suggestion'] as String?;
        final displayMsg = suggestion != null
            ? '$error. $suggestion'
            : '$error';
        onStatus('Update failed: $displayMsg');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Update failed',
        component: 'YtdlpServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      final errorHelper = ErrorHelper.parse(e.toString());
      final msg = errorHelper.suggestion != null
          ? '${errorHelper.friendlyMessage}: ${errorHelper.suggestion}'
          : errorHelper.friendlyMessage;
      onStatus('Update failed: $msg');
      return false;
    } finally {
      await progressSubscription?.cancel();
    }
  }

  @override
  Future<bool> update() async {
    return downloadAndInstallUpdate(
      AppConstants.ytdlpAndroidDownloadUrl,
      onProgress: (_) {},
      onStatus: (_) {},
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
    Function(double progress, String line, int eta)? onProgress,
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
            // Kotlin sends `line` as a String (the yt-dlp stdout progress
            // text, e.g. "[download] 45.2% of 150MiB at 5MiB/s ETA 00:30"),
            // NOT a number. Casting to `num?` threw a TypeError on every
            // progress event (M15). Read it as a String instead; callers that
            // need the speed value parse it via the progress-line regex (see
            // MobileDownloadProvider._extractSpeedBytesPerSecond).
            final line = (event['line'] ?? '').toString();
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
        archivePath: archivePath,
        subtitleLanguages: subtitleLanguages,
        embedSubtitles: embedSubtitles,
        sponsorBlock: sponsorBlock,
        embedThumbnail: embedThumbnail,
        embedMetadata: embedMetadata,
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
