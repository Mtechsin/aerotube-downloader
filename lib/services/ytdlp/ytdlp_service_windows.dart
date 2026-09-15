import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/download_item.dart';
import '../../models/video_info.dart';
import '../../models/playlist_info.dart';
import '../notification/notification_service.dart';
import '../core/logging_service.dart';
import '../core/download_helper.dart';
import 'ytdlp_tool_service.dart';
import '../core/certificate_pinning_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/utils/url_validator.dart';
import '../../core/utils/version_utils.dart';
import '../../core/utils/error_helper.dart';

export 'ytdlp_tool_service.dart' show YtdlpUpdateInfo;

class YtdlpService implements YtdlpToolService {
  String _ytdlpPath;
  String? _cookiePath;
  String? _cookieBrowser;
  String? _webViewPath;
  String? _ffmpegPath;
  String? _userAgent;
  bool _enableCookies = false;
  bool _isInitialized = false;
  final NotificationService? _notificationService;
  final CertificatePinningService _certPinningService = CertificatePinningService();
  String? _cachedLatestVersion;
  DateTime? _cacheTime;
  static DateTime? _lastFetchAttempt;
  static const Duration _cacheExpiry = Duration(minutes: 60);
  static const Duration _throttleWindow = Duration(seconds: 60);
  final _videoInfoCache = <String, VideoInfo>{};
  static const int _maxCacheSize = 30;
  String? _cachedVersion;
  HttpClient? _pinnedClient;

  String? _getGithubToken() {
    try {
      final env = Platform.environment['GITHUB_TOKEN'];
      if (env != null && env.isNotEmpty) return env;
    } catch (_) {}
    const fromEnv = String.fromEnvironment('GITHUB_TOKEN');
    if (fromEnv.isNotEmpty) return fromEnv;
    return null;
  }

  bool _isRateLimitError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('rate limit') ||
        msg.contains('403') ||
        msg.contains('429');
  }

  static const String _windowsDownloadUrl =
      AppConstants.ytdlpWindowsDownloadUrl;
  static const String _linuxDownloadUrl =
      AppConstants.ytdlpLinuxDownloadUrl;
  static const String _macosDownloadUrl =
      AppConstants.ytdlpMacosDownloadUrl;

  YtdlpService({
    String? ytdlpPath,
    String? cookiePath,
    String? cookieBrowser,
    String? webViewPath,
    String? ffmpegPath,
    NotificationService? notificationService,
  }) : _ytdlpPath = ytdlpPath ?? 'yt-dlp',
       _cookiePath = cookiePath,
       _cookieBrowser = cookieBrowser,
       _webViewPath = webViewPath,
       _ffmpegPath = ffmpegPath,
       _notificationService = notificationService;

  @override
  set ytdlpPath(String path) {
    if (_ytdlpPath != path) {
      _ytdlpPath = path;
      _cachedVersion = null;
    }
  }
  @override
  String get ytdlpPath => _ytdlpPath;
  @override
  set cookiePath(String? path) => _cookiePath = path;
  @override
  String? get cookiePath => _cookiePath;
  @override
  set cookieBrowser(String? browser) => _cookieBrowser = browser;
  @override
  String? get cookieBrowser => _cookieBrowser;
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

  bool get isUsingCookies =>
      _enableCookies &&
      ((_cookiePath != null && File(_cookiePath!).existsSync()) ||
          (_cookieBrowser != null && _cookieBrowser != 'none') ||
          (_webViewPath != null));

  String? get activeCookieSource => _cookiePath != null
      ? 'file'
      : (_cookieBrowser != 'none'
            ? 'browser'
            : (_webViewPath != null ? 'webview' : null));

  /// Initialize the service: locate or download yt-dlp
  @override
  Future<void> initialize({bool force = false}) async {
    if (_isInitialized && !force) return;
    if (force) {
      _isInitialized = false;
      _cachedVersion = null;
    }

    try {
      final dir = await getApplicationSupportDirectory();
      final executableName = PlatformUtils.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
      final localPath = p.join(dir.path, 'bin', executableName);
      final localFile = File(localPath);

      // If the current path is NOT the default 'yt-dlp' AND not our managed local path,
      // it means the user (or settings) provided a custom path. We should respect it.
      if (_ytdlpPath != 'yt-dlp' && _ytdlpPath != localPath) {
        // Verify if it exists, if not, try adding .exe on Windows
        if (!await File(_ytdlpPath).exists()) {
          if (PlatformUtils.isWindows &&
              !_ytdlpPath.toLowerCase().endsWith('.exe')) {
            final withExe = '$_ytdlpPath.exe';
            if (await File(withExe).exists()) {
              // Use public setter so cache is invalidated on path change
              ytdlpPath = withExe;
            }
          }
        }
        _isInitialized = true;
        return;
      }

      if (await localFile.exists()) {
        // Use public setter so the availability cache is cleared when
        // the resolved local path differs from the current value.
        ytdlpPath = localPath;
      } else {
        // If not in local path and not in system PATH, download it
        if (await isAvailable()) {
          _isInitialized = true;
          return;
        }

        await _downloadYtdlp(localFile);
        // Use setter to ensure cache is cleared after download
        ytdlpPath = localPath;
      }

      _isInitialized = true;
    } catch (e) {
      // Fallback to system PATH if initialization fails
    }
  }

  /// Download yt-dlp binary (runs in a background isolate for full speed)
  Future<void> _downloadYtdlp(File targetFile) async {
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    final url = PlatformUtils.isWindows
        ? _windowsDownloadUrl
        : PlatformUtils.isMacOS
            ? _macosDownloadUrl
            : _linuxDownloadUrl;
    // Use a private temp directory with a random suffix (O_EXCL semantics)
    // instead of a guessable millisecond-timestamp name in the shared temp
    // dir, which was vulnerable to predicted-name symlink/hijack races (M11).
    final tempDir = await Directory.systemTemp.createTemp('yt-dlp-dl-');
    final tempFileName = PlatformUtils.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
    final tempPath = p.join(tempDir.path, tempFileName);

    try {
      await downloadInBackground(url: url, destPath: tempPath);

      // Atomic replace: copy to .new then rename, preserving original until new is ready (B16)
      if (await targetFile.exists()) {
        final backupFile = File('${targetFile.path}.bak');
        final newFile = File('${targetFile.path}.new');
        // Clean stale temp files
        try { if (await backupFile.exists()) await backupFile.delete(); } catch (_) {}
        try { if (await newFile.exists()) await newFile.delete(); } catch (_) {}
        await File(tempPath).copy(newFile.path);
        await targetFile.rename(backupFile.path);
        try {
          await newFile.rename(targetFile.path);
          await backupFile.delete();
        } catch (e) {
          // Restore original on failure
          try { if (await targetFile.exists()) await targetFile.delete(); } catch (_) {}
          try { await backupFile.rename(targetFile.path); } catch (_) {}
          try { if (await newFile.exists()) await newFile.delete(); } catch (_) {}
          throw YtdlpException('Failed to copy temp file: $e');
        }
      } else {
        // No existing binary: copy via temp .new then rename for atomicity
        final newFile = File('${targetFile.path}.new');
        try { if (await newFile.exists()) await newFile.delete(); } catch (_) {}
        await File(tempPath).copy(newFile.path);
        await newFile.rename(targetFile.path);
      }

      if (!PlatformUtils.isWindows) {
        await Process.run('chmod', ['+x', targetFile.path]);
      }
    } catch (e) {
      throw YtdlpException('Failed to download yt-dlp: $e');
    } finally {
      try {
        // Recursively delete the private temp directory (binary + anything
        // written alongside it).
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      } catch (e) {
        LoggingService().debug(
          'Failed to delete temp yt-dlp binary: $e',
          component: 'YtdlpService',
        );
      }
    }
  }

  @override
  Future<bool> update() async {
    try {
      final result = await Process.run(_ytdlpPath, ['-U']).timeout(
        const Duration(seconds: 45),
      );
      if (result.exitCode == 0) {
        _cachedVersion = null;
        return true;
      }
      LoggingService().warning(
        'yt-dlp -U exited with code ${result.exitCode}, falling back to direct release download',
        component: 'YtdlpService',
      );
    } catch (e) {
      LoggingService().warning(
        'yt-dlp -U failed: $e, falling back to direct release download',
        component: 'YtdlpService',
      );
    }

    // Direct binary download fallback
    return downloadAndInstallUpdate(
      AppConstants.ytdlpWindowsDownloadUrl,
      onProgress: (_) {},
      onStatus: (_) {},
    );
  }

  /// Check if yt-dlp is available.
  ///
  /// NOTE: No result caching here on purpose — caching `false` before
  /// [initialize] resolves the managed binary path would produce a permanent
  /// false-negative that persists for the lifetime of the service.  The probe
  /// is a simple `--version` call (~5 ms) so the cost is negligible.
  @override
  Future<bool> isAvailable() async {
    try {
      // First try with current path
      var result = await Process.run(_ytdlpPath, ['--version']);
      if (result.exitCode == 0) {
        _cachedVersion = (result.stdout as String).trim();
        return true;
      }

      // On Windows, retry with .exe suffix if the bare name failed
      if (PlatformUtils.isWindows && !_ytdlpPath.toLowerCase().endsWith('.exe')) {
        result = await Process.run('$_ytdlpPath.exe', ['--version']);
        if (result.exitCode == 0) {
          ytdlpPath = '$_ytdlpPath.exe'; // setter clears version cache
          _cachedVersion = (result.stdout as String).trim();
          return true;
        }
      }

      return false;
    } catch (e) {
      // If process launch fails on Windows, retry with .exe
      if (PlatformUtils.isWindows && !_ytdlpPath.toLowerCase().endsWith('.exe')) {
        try {
          final result = await Process.run('$_ytdlpPath.exe', ['--version']);
          if (result.exitCode == 0) {
            ytdlpPath = '$_ytdlpPath.exe'; // setter clears version cache
            _cachedVersion = (result.stdout as String).trim();
            return true;
          }
        } catch (e) {
          LoggingService().warning(
            'yt-dlp .exe fallback check failed: $e',
            component: 'YtdlpService',
          );
        }
      }
      return false;
    }
  }

  /// Lightweight binary check for background isolate (compute).
  /// Returns version string if available, null otherwise.
  static Future<String?> checkBinaryAvailable(String path) async {
    try {
      var result = await Process.run(path, ['--version']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
      if (PlatformUtils.isWindows && !path.toLowerCase().endsWith('.exe')) {
        result = await Process.run('$path.exe', ['--version']);
        if (result.exitCode == 0) {
          return (result.stdout as String).trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Called after background isolate confirms binary works.
  /// Skips full initialize() I/O.
  @override
  void markReady(String version) {
    _cachedVersion = version;
    _isInitialized = true;
  }

  @override
  Future<String?> getVersion() async {
    if (_cachedVersion != null) return _cachedVersion;
    try {
      final result = await Process.run(_ytdlpPath, ['--version']);
      if (result.exitCode == 0) {
        _cachedVersion = (result.stdout as String).trim();
        return _cachedVersion;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if a newer version of yt-dlp is available on GitHub
  @override
  Future<String?> getLatestVersion({bool forceRefresh = false}) async {
    final now = DateTime.now();

    // ── Throttle: at most once per 60s (prevents hammering under VPN shared IP)
    if (!forceRefresh &&
        _lastFetchAttempt != null &&
        now.difference(_lastFetchAttempt!) < _throttleWindow) {
      if (_cachedLatestVersion != null) {
        LoggingService().debug(
          'getLatestVersion throttled, returning cached $_cachedLatestVersion',
          component: 'YtdlpService',
        );
        return _cachedLatestVersion;
      }
      // No cache yet but still throttled -> avoid network hammer
      LoggingService().debug(
        'getLatestVersion throttled, no cache yet',
        component: 'YtdlpService',
      );
      return null;
    }

    // ── Cache expiry: 60 minutes
    if (!forceRefresh &&
        _cachedLatestVersion != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheExpiry) {
      return _cachedLatestVersion;
    }

    // Mark attempt time BEFORE network (prevents concurrent hammering)
    _lastFetchAttempt = now;

    final token = _getGithubToken();

    Future<String?> tryFetch(HttpClient client) async {
      final request = await client.getUrl(
        Uri.parse(AppConstants.ytdlpLatestReleaseApiUrl),
      );
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      request.headers.set('User-Agent', 'AeroTube-Updater');
      if (token != null && token.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $token');
      }
      final httpResponse = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final responseBody = await httpResponse.transform(utf8.decoder).join();
      if (httpResponse.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final tagName = data['tag_name'] as String?;
        if (tagName != null && tagName.isNotEmpty) {
          _cachedLatestVersion = tagName;
          _cacheTime = DateTime.now();
          return tagName;
        }
        return null;
      } else if (httpResponse.statusCode == 403 ||
          httpResponse.statusCode == 429) {
        final snippet = responseBody.length > 300
            ? '${responseBody.substring(0, 300)}...'
            : responseBody;
        throw YtdlpException(
          'GitHub API rate limit (${httpResponse.statusCode}). $snippet Try again in a few minutes or check manually at https://github.com/yt-dlp/yt-dlp/releases',
        );
      } else {
        throw YtdlpException(
          'GitHub API error ${httpResponse.statusCode}: $responseBody',
        );
      }
    }

    try {
      _pinnedClient ??= _certPinningService.createPinnedHttpClient();
      final result = await tryFetch(_pinnedClient!);
      return result;
    } catch (e) {
      // Rate-limit -> return cached if available instead of hammering with fallback
      if (_isRateLimitError(e)) {
        if (_cachedLatestVersion != null) {
          LoggingService().warning(
            'Rate limited but returning cached version $_cachedLatestVersion: $e',
            component: 'YtdlpService',
          );
          return _cachedLatestVersion;
        }
        rethrow;
      }
      LoggingService().warning(
        'Pinned client failed, falling back to plain HttpClient: $e',
        component: 'YtdlpService',
      );
      // Fallback: plain client only for non-rate-limit failures (e.g. cert quirks)
      HttpClient? fallback;
      try {
        fallback = HttpClient();
        final result = await tryFetch(fallback);
        fallback.close(force: true);
        return result;
      } catch (e2) {
        fallback?.close(force: true);
        if (_isRateLimitError(e2) && _cachedLatestVersion != null) {
          LoggingService().warning(
            'Fallback rate limited but returning cached $_cachedLatestVersion',
            component: 'YtdlpService',
          );
          return _cachedLatestVersion;
        }
        if (e2 is YtdlpException) rethrow;
        LoggingService().warning(
          'Fallback client also failed: $e2',
          component: 'YtdlpService',
        );
        throw YtdlpException('Failed to check latest version: $e2');
      }
    }
  }

  bool isNewerVersion(String current, String latest) =>
      VersionUtils.isNewerVersion(current, latest);

  /// Detect if an error suggests yt-dlp is broken or outdated
  bool isBrokenError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('outdated') ||
        lowerError.contains('update') ||
        lowerError.contains('signature') ||
        lowerError.contains('decipher') ||
        lowerError.contains('extraction failed');
  }

  // ── VPN helpers ──────────────────────────────────────────────────────
  bool _isVpnNetworkError(String msg) {
    final l = msg.toLowerCase();
    return l.contains('temporary failure in name resolution') ||
        l.contains('unable to download webpage') ||
        l.contains('unable to download json') ||
        l.contains('unable to download api') ||
        l.contains('connection timed out') ||
        l.contains('timed out') ||
        l.contains('operation timed out') ||
        l.contains('socket timeout') ||
        l.contains('read timed out') ||
        l.contains('failed to resolve') ||
        l.contains('getaddrinfo failed') ||
        l.contains('name or service not known') ||
        l.contains('name not known') ||
        l.contains('network is unreachable') ||
        l.contains('no address associated with hostname') ||
        l.contains('failed host lookup') ||
        l.contains('connection reset') ||
        l.contains('connection refused') ||
        l.contains('network is down') ||
        l.contains('no route to host') ||
        l.contains('ssl:') && l.contains('timeout') ||
        l.contains('errno 110') ||
        l.contains('errno -3');
  }

  bool _isCookieRelatedError(String msg) {
    final l = msg.toLowerCase();
    return l.contains('dpapi') ||
        l.contains('failed to decrypt') ||
        l.contains('permission denied') && l.contains('cookie') ||
        l.contains('could not copy chrome cookie') ||
        l.contains('could not copy edge cookie') ||
        l.contains('cookies database is locked');
  }

  String _vpnFriendlyMessage(String original) {
    if (_isVpnNetworkError(original)) {
      return '$original\n\nTip: VPN may be slowing or blocking the connection (adds latency/packet loss). Try disabling VPN, switching server, or retrying in a few seconds.';
    }
    if (original.toLowerCase().contains('timed out')) {
      return '$original\n\nTip: Fetch timed out — VPN may be slowing connection. Try again or disable VPN temporarily.';
    }
    return original;
  }

  List<String> _buildVideoInfoArgsWithoutCookies(String url) {
    final validated = _validateUrl(url);
    final args = <String>[
      '--ignore-config',
      '--newline',
      '--no-playlist',
      '--skip-download',
      '--retries',
      '4',
      '--extractor-retries',
      '3',
      '--socket-timeout',
      '30',
      '--retry-sleep',
      'linear=1:3',
      '--no-warnings',
      '--dump-single-json',
    ];
    if (_ffmpegPath != null && _ffmpegPath != 'ffmpeg') {
      args.addAll(['--ffmpeg-location', _ffmpegPath!]);
    }
    if (_userAgent != null) args.addAll(['--user-agent', _userAgent!]);
    args.addAll(['--', validated]);
    return args;
  }

  List<String> _buildVpnFallbackArgs(String url) {
    final validated = _validateUrl(url);
    final args = <String>[
      '--ignore-config',
      '--newline',
      '--no-playlist',
      '--skip-download',
      '--retries',
      '4',
      '--extractor-retries',
      '3',
      '--socket-timeout',
      '30',
      '--retry-sleep',
      'linear=1:3',
      '--force-ipv4',
      '--no-warnings',
      // YouTube-only extractor hint — harmless elsewhere but skip for non-YT.
      if (UrlValidator.isYouTubeUrl(url)) ...[
        '--extractor-args',
        'youtube:player_client=android',
      ],
      '--dump-single-json',
    ];
    if (_ffmpegPath != null && _ffmpegPath != 'ffmpeg') {
      args.addAll(['--ffmpeg-location', _ffmpegPath!]);
    }
    if (_userAgent != null) args.addAll(['--user-agent', _userAgent!]);
    args.addAll(['--', validated]);
    return args;
  }

  // Active process for cancellation support
  Process? _activeVideoProcess;
  Process? _activePlaylistProcess;
  int _videoFetchGen = 0;

  @override
  Future<void> cancelFetch() async {
    _videoFetchGen++;
    final vProc = _activeVideoProcess;
    final pProc = _activePlaylistProcess;
    _activeVideoProcess = null;
    _activePlaylistProcess = null;
    for (final proc in [vProc, pProc]) {
      if (proc != null) {
        try {
          proc.kill(ProcessSignal.sigkill);
        } catch (_) {}
        try {
          proc.kill();
        } catch (_) {}
      }
    }
    LoggingService().info('Fetch cancelled by user', component: 'YtdlpService');
  }

  /// Fetch video information from URL with retry logic for authentication
  /// VPN-resilient: per-attempt 45s, overall 120s, retries without cookies & ipv4 fallback
  Future<VideoInfo> getVideoInfo(
    String url, {
    Function(String status)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    final cacheKey = _buildVideoInfoCacheKey(url);
    final cachedInfo = _videoInfoCache[cacheKey];
    if (cachedInfo != null) {
      onProgress?.call('Using cached video metadata...');
      _videoInfoCache.remove(cacheKey);
      _videoInfoCache[cacheKey] = cachedInfo;
      return cachedInfo;
    }

    // Cancellation: bump generation, kill previous process
    final myGen = ++_videoFetchGen;
    try {
      _activeVideoProcess?.kill(ProcessSignal.sigkill);
    } catch (_) {}
    try {
      _activeVideoProcess?.kill();
    } catch (_) {}

    onProgress?.call('Connecting...');
    onProgress?.call('Fetching video metadata...');

    final stopwatch = Stopwatch()..start();
    const overallTimeout = Duration(seconds: 120);
    const perAttemptTimeout = Duration(seconds: 45);
    Duration remainingOverall() {
      final r = overallTimeout - stopwatch.elapsed;
      return r.isNegative ? Duration.zero : r;
    }

    // Helper to run args with remaining-aware timeout + active process tracking
    Future<ProcessResult> runTracked(List<String> args, String timeoutMsg) async {
      if (myGen != _videoFetchGen) throw YtdlpException('Cancelled');
      final effTimeout = remainingOverall();
      if (effTimeout.inSeconds < 5) throw YtdlpException('Fetch timed out — VPN may be slowing connection, try again or disable VPN.');
      final timeout = effTimeout < perAttemptTimeout ? effTimeout : perAttemptTimeout;
      LoggingService().debug(
        'Executing info fetch: $_ytdlpPath ${args.join(' ')} (timeout ${timeout.inSeconds}s)',
        component: 'YtdlpService',
      );
      try {
        final result = await _runWithTimeoutTracked(
          args,
          timeout,
          timeoutMessage: timeoutMsg,
          myGen: myGen,
        );
        return result;
      } on YtdlpException catch (e) {
        // Enrich timeout / VPN errors with friendly tip
        if (e.message.toLowerCase().contains('timed out') || _isVpnNetworkError(e.message)) {
          throw YtdlpException(_vpnFriendlyMessage(e.message));
        }
        rethrow;
      }
    }

    ProcessResult? result;
    String lastError = '';

    // ── Attempt 1: full args (with cookies) ───────────────────────────────
    try {
      result = await runTracked(
        _buildVideoInfoArgs(url),
        'yt-dlp timed out fetching video info (45 s). VPN may be slowing connection, try again or disable VPN.',
      );
      if (result.exitCode == 0) {
        return _parseAndCacheVideoInfo(result.stdout as String, cacheKey, onProgress);
      }
      lastError = (result.stderr as String).trim();
      LoggingService().warning('Attempt 1 failed: $lastError', component: 'YtdlpService');
    } on YtdlpException catch (e) {
      lastError = e.message;
      if (e.message.contains('Cancelled')) rethrow;
      // fall through to retry logic (VPN/auth handled below)
    }

    // Early auth check on lastError — if it's clearly auth, try player_client fallback before VPN fallback
    // (YouTube-only: player_client extractor args are YT-specific).
    if (lastError.isNotEmpty && UrlValidator.isYouTubeUrl(url)) {
      final authError = checkAuthenticationErrors(lastError);
      if (authError != null) {
        if (lastError.contains('Sign in to confirm you') || lastError.contains('bot')) {
          onProgress?.call('Retrying with alternative player client...');
          try {
            final retryArgs = <String>[
              '--ignore-config',
              '--newline',
              '--no-playlist',
              '--skip-download',
              '--no-warnings',
              if (_ffmpegPath != null) ...['--ffmpeg-location', _ffmpegPath!],
              if (_userAgent != null) ...['--user-agent', _userAgent!],
              if (_cookiePath != null && File(_cookiePath!).existsSync()) ...[
                '--cookies',
                _cookiePath!,
              ],
              '--extractor-args',
              'youtube:player_client=web,mweb,android,ios;player-skip=webpage,configs',
              '--dump-single-json',
              _validateUrl(url),
            ];
            final r2 = await runTracked(retryArgs, 'yt-dlp auth retry timed out (45 s).');
            if (r2.exitCode == 0) {
              return _parseAndCacheVideoInfo(r2.stdout as String, cacheKey, onProgress);
            }
            lastError = (r2.stderr as String).trim();
          } catch (e) {
            lastError = e.toString();
          }
        }
        // If still auth, don't throw yet — try VPN fallback which may bypass bot check via android client
        // but if overall time is low, throw
        if (remainingOverall().inSeconds < 10 && _isVpnNetworkError(lastError)) {
          throw YtdlpException(_vpnFriendlyMessage(lastError));
        }
        // For pure auth without network hint, throw but with VPN tip if cookies were involved
        if (!_isVpnNetworkError(lastError) && !_isCookieRelatedError(lastError)) {
          // still try cookie-stripped retry before giving up (below)
        }
      }
    }

    // ── Determine if we should retry without cookies / VPN fallback ──────
    final shouldRetryWithoutCookies = lastError.isNotEmpty &&
        (_isVpnNetworkError(lastError) ||
            _isCookieRelatedError(lastError) ||
            lastError.toLowerCase().contains('timed out') ||
            lastError.contains('DPAPI') ||
            lastError.contains('Failed to decrypt') ||
            (isUsingCookies && _isVpnNetworkError(lastError)));

    // ── Attempt 2: without cookies (fixes LevelDB lock behind VPN, DPAPI) ─
    if (shouldRetryWithoutCookies || (isUsingCookies && lastError.isNotEmpty)) {
      if (remainingOverall().inSeconds < 5) {
        throw YtdlpException(_vpnFriendlyMessage(lastError.isEmpty ? 'Fetch timed out' : lastError));
      }
      onProgress?.call('Retrying without browser cookies (VPN/DPAPI fallback)...');
      LoggingService().info('Retrying getVideoInfo without cookies due to: $lastError', component: 'YtdlpService');
      try {
        final noCookieArgs = _buildVideoInfoArgsWithoutCookies(url);
        result = await runTracked(
          noCookieArgs,
          'yt-dlp retry (no cookies) timed out (45 s). VPN may be slowing connection.',
        );
        if (result.exitCode == 0) {
          return _parseAndCacheVideoInfo(result.stdout as String, cacheKey, onProgress);
        }
        lastError = (result.stderr as String).trim();
        LoggingService().warning('Attempt 2 (no cookies) failed: $lastError', component: 'YtdlpService');
      } on YtdlpException catch (e) {
        if (e.message.contains('Cancelled')) rethrow;
        lastError = e.message;
      }
    }

    // ── Attempt 3: VPN fallback — force-ipv4 + android player client ─────
    if (lastError.isNotEmpty && (_isVpnNetworkError(lastError) || lastError.toLowerCase().contains('timed out'))) {
      if (remainingOverall().inSeconds < 5) {
        throw YtdlpException(_vpnFriendlyMessage(lastError));
      }
      onProgress?.call('Retrying with VPN-tolerant settings (IPv4 + Android client)...');
      LoggingService().info('Retrying getVideoInfo with VPN fallback due to: $lastError', component: 'YtdlpService');
      try {
        final vpnArgs = _buildVpnFallbackArgs(url);
        result = await runTracked(
          vpnArgs,
          'yt-dlp VPN fallback timed out (45 s). Try disabling VPN.',
        );
        if (result.exitCode == 0) {
          return _parseAndCacheVideoInfo(result.stdout as String, cacheKey, onProgress);
        }
        lastError = (result.stderr as String).trim();
      } on YtdlpException catch (e) {
        if (e.message.contains('Cancelled')) rethrow;
        lastError = e.message;
      }
    }

    // ── Final DPAPI fallback if not already tried and error matches ──────
    if (lastError.isNotEmpty && (lastError.contains('DPAPI') || lastError.contains('Failed to decrypt')) && _cookieBrowser != null) {
      onProgress?.call('Retrying without browser cookies...');
      try {
        final argsWithoutBrowser = <String>[
          '--ignore-config',
          '--newline',
          '--no-playlist',
          '--skip-download',
          '--no-warnings',
          if (_ffmpegPath != null) ...['--ffmpeg-location', _ffmpegPath!],
          if (_cookiePath != null && File(_cookiePath!).existsSync()) ...[
            '--cookies',
            _cookiePath!,
          ],
          '--dump-single-json',
          _validateUrl(url),
        ];
        result = await runTracked(argsWithoutBrowser, 'yt-dlp retry timed out (45 s).');
        if (result.exitCode == 0) {
          return _parseAndCacheVideoInfo(result.stdout as String, cacheKey, onProgress);
        }
        final retryError = (result.stderr as String).trim();
        throw YtdlpException(
          'Failed to fetch video info: $retryError\n\nNote: Browser cookie extraction failed due to DPAPI. Try exporting cookies to a file or closing your browser.',
        );
      } on YtdlpException {
        rethrow;
      }
    }

    // ── All attempts exhausted ───────────────────────────────────────────
    final finalErr = lastError.isEmpty ? 'Unknown error' : lastError;
    if (_isVpnNetworkError(finalErr) || finalErr.toLowerCase().contains('timed out')) {
      throw YtdlpException(_vpnFriendlyMessage('Failed to fetch video info: $finalErr'));
    }
    final authErr = checkAuthenticationErrors(finalErr);
    if (authErr != null) throw YtdlpException(authErr);
    throw YtdlpException('Failed to fetch video info: $finalErr');
  }

  VideoInfo _parseAndCacheVideoInfo(String stdout, String cacheKey, Function(String status)? onProgress) {
    onProgress?.call('Processing video formats...');
    final trimmed = stdout.trim();
    if (trimmed.isEmpty) {
      throw YtdlpException('Failed to fetch video info: Empty output from yt-dlp');
    }
    final lines = trimmed.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      throw YtdlpException('Failed to fetch video info: No valid JSON lines in output');
    }
    String? jsonLine;
    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('{')) {
        jsonLine = t;
        break;
      }
    }
    if (jsonLine == null) {
      throw YtdlpException('Failed to fetch video info: No JSON object found in output');
    }
    final json = jsonDecode(jsonLine) as Map<String, dynamic>;
    final info = VideoInfo.fromJson(json);
    if (_videoInfoCache.length >= _maxCacheSize) {
      _videoInfoCache.remove(_videoInfoCache.keys.first);
    }
    _videoInfoCache[cacheKey] = info;
    _notificationService?.show(title: 'Fetch Complete', body: info.title);
    return info;
  }

  static String _validateUrl(String url) {
    try {
      return UrlValidator.validate(url);
    } on UrlValidationException catch (e) {
      throw YtdlpException(e.message);
    }
  }

  // VPN-friendly defaults: longer socket timeout, more retries, retry sleep
  List<String> _buildVideoInfoArgs(String url) {
    final args = <String>[
      '--ignore-config',
      '--newline',
      '--no-playlist',
      '--skip-download',
      '--retries',
      '4',
      '--extractor-retries',
      '3',
      '--socket-timeout',
      '30',
      '--retry-sleep',
      'linear=1:3',
      '--no-warnings',
      '--dump-single-json',
    ];

    if (_ffmpegPath != null && _ffmpegPath != 'ffmpeg') {
      args.addAll(['--ffmpeg-location', _ffmpegPath!]);
    }

    if (_userAgent != null) {
      args.addAll(['--user-agent', _userAgent!]);
    }

    if (_enableCookies) {
      if (_webViewPath != null) {
        args.addAll(['--cookies-from-browser', 'edge:$_webViewPath']);
      } else if (_cookiePath != null && File(_cookiePath!).existsSync()) {
        args.addAll(['--cookies', _cookiePath!]);
      } else if (_cookieBrowser != null && _cookieBrowser != 'none') {
        args.addAll(['--cookies-from-browser', _cookieBrowser!.toLowerCase()]);
      }
    }

    args.addAll(['--', _validateUrl(url)]);
    return args;
  }

  String _buildVideoInfoCacheKey(String url) {
    return [
      url.trim(),
      _enableCookies.toString(),
      _cookiePath ?? '',
      _cookieBrowser ?? '',
      _webViewPath ?? '',
      _userAgent ?? '',
    ].join('|');
  }

  /// Runs yt-dlp and guarantees the OS process is killed on timeout.
  ///
  /// Previous code used `Process.run(...).timeout(...)` which only throws
  /// a Dart exception but leaves the native `yt-dlp.exe` running orphaned,
  /// locking the cookie file and writing lingering `.part` files (B1).
  /// This helper uses `Process.start`, waits for `exitCode` with a timeout,
  /// and calls `process.kill()` on timeout before rethrowing as
  /// [YtdlpException]. VPN-friendly timeout message appended.
  // ignore: unused_element - kept for backwards compatibility / tests
  Future<ProcessResult> _runWithTimeout(
    List<String> args,
    Duration timeout, {
    String? timeoutMessage,
  }) async {
    return _runWithTimeoutTracked(args, timeout, timeoutMessage: timeoutMessage, myGen: null);
  }

  Future<ProcessResult> _runWithTimeoutTracked(
    List<String> args,
    Duration timeout, {
    String? timeoutMessage,
    int? myGen,
  }) async {
    final process = await Process.start(_ytdlpPath, args);
    // Track for cancellation support
    if (myGen != null && myGen == _videoFetchGen) {
      _activeVideoProcess = process;
    }

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final stdoutSub = process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);
    final stderrSub = process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

    int exitCode;
    try {
      exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          try {
            process.kill(ProcessSignal.sigkill);
          } catch (_) {}
          try {
            process.kill();
          } catch (_) {}
          throw TimeoutException(
            timeoutMessage ??
                'yt-dlp timed out after ${timeout.inSeconds}s. VPN may be slowing connection, try again or disable VPN.',
            timeout,
          );
        },
      );
    } on TimeoutException catch (e) {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
      try {
        process.kill();
      } catch (_) {}
      try {
        await stdoutSub.cancel();
      } catch (_) {}
      try {
        await stderrSub.cancel();
      } catch (_) {}
      if (myGen != null && myGen == _videoFetchGen) _activeVideoProcess = null;
      final msg = e.message;
      if (msg != null && msg.isNotEmpty) {
        // Ensure VPN hint if not already present
        final enriched = msg.toLowerCase().contains('vpn') ? msg : '$msg\n\nTip: VPN may be slowing connection, try again or disable VPN.';
        throw YtdlpException(enriched);
      }
      throw YtdlpException(
        timeoutMessage ?? 'yt-dlp timed out after ${timeout.inSeconds}s. VPN may be slowing connection.',
      );
    }

    try {
      await Future.wait<void>([
        stdoutSub.asFuture<void>(),
        stderrSub.asFuture<void>(),
      ]).timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => [],
      );
    } catch (_) {}
    if (myGen != null && myGen == _videoFetchGen) _activeVideoProcess = null;

    return ProcessResult(
      process.pid,
      exitCode,
      stdoutBuffer.toString(),
      stderrBuffer.toString(),
    );
  }

  List<String> _buildPlaylistArgs(String url, {bool stripCookies = false, bool vpnFallback = false}) {
    final base = _buildCommonArgs();
    base.remove('--no-playlist');
    if (stripCookies) {
      base.removeWhere((e) => e == '--cookies' || e == '--cookies-from-browser');
      // also remove the value following those flags if present
      // _buildCommonArgs builds cookies as two entries; we need to strip pattern.
      // Rebuild clean without cookies.
      final clean = <String>[
        '--newline',
        '--retries',
        '5',
        '--fragment-retries',
        '5',
        '--file-access-retries',
        '3',
        '--extractor-retries',
        '3',
        '--socket-timeout',
        '30',
        '--retry-sleep',
        'linear=1:3',
        '--concurrent-fragments',
        '16',
        '--buffer-size',
        '16K',
        '--http-chunk-size',
        '10M',
        '--no-warnings',
      ];
      if (_ffmpegPath != null && _ffmpegPath != 'ffmpeg') clean.addAll(['--ffmpeg-location', _ffmpegPath!]);
      if (_userAgent != null) clean.addAll(['--user-agent', _userAgent!]);
      if (vpnFallback) clean.add('--force-ipv4');
      clean.addAll(['--flat-playlist', '--extractor-args', 'youtubetab:skip=authcheck', '--dump-json', '--', _validateUrl(url)]);
      return clean;
    }
    if (vpnFallback) base.add('--force-ipv4');
    base.addAll([
      '--flat-playlist',
      '--extractor-args',
      'youtubetab:skip=authcheck',
      '--dump-json',
      '--',
      _validateUrl(url),
    ]);
    return base;
  }

  /// Fetch playlist information from URL — VPN resilient
  Future<PlaylistInfo> getPlaylistInfo(
    String url, {
    Function(String status)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    onProgress?.call('Connecting...');

    Future<PlaylistInfo> runWithArgs(List<String> args) async {
      onProgress?.call('Fetching playlist metadata...');
      final process = await Process.start(_ytdlpPath, args).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw YtdlpException(
          'yt-dlp timed out starting playlist fetch (60 s). VPN may be slowing connection, try again or disable VPN.',
        ),
      );
      _activePlaylistProcess = process;
      final videos = <PlaylistVideoItem>[];
      Map<String, dynamic>? playlistMetadata;
      final stderrBuffer = StringBuffer();
      String? playlistTitle;
      int? expectedCount;

      final stdoutFuture = process.stdout
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.trim().isEmpty) return;
            try {
              final json = jsonDecode(line) as Map<String, dynamic>;
              if (json['_type'] == 'playlist') {
                playlistMetadata = json;
                playlistTitle = json['title'] as String?;
                expectedCount = (json['playlist_count'] as int?) ?? (json['n_entries'] as int?);
                if (playlistTitle != null) onProgress?.call('Found playlist: $playlistTitle');
              } else {
                final video = PlaylistVideoItem.fromJson(json);
                videos.add(video);
                final videoTitle = video.title.length > 40 ? '${video.title.substring(0, 40)}...' : video.title;
                final countStr = expectedCount != null ? '${videos.length}/$expectedCount' : '${videos.length}';
                onProgress?.call('Loading video $countStr: $videoTitle');
              }
            } catch (e) {
              LoggingService().warning(
                'Failed to parse playlist JSON line: $e | line: ${line.length > 200 ? '${line.substring(0, 200)}...' : line}',
                component: 'YtdlpService',
              );
            }
          })
          .asFuture();

      final stderrFuture = process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        stderrBuffer.write(data);
      }).asFuture();

      int exitCode;
      try {
        exitCode = await process.exitCode.timeout(
          const Duration(minutes: 6),
          onTimeout: () {
            try { process.kill(ProcessSignal.sigkill); } catch (_) {}
            throw YtdlpException('Playlist fetch timed out (6 min). VPN may be slowing connection or playlist may be too large.');
          },
        );
      } on YtdlpException {
        _activePlaylistProcess = null;
        rethrow;
      } catch (e) {
        _activePlaylistProcess = null;
        throw YtdlpException(_vpnFriendlyMessage(e.toString()));
      }
      try {
        await Future.wait<void>([stdoutFuture, stderrFuture]).timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => [],
        );
      } catch (_) {}
      _activePlaylistProcess = null;

      if (exitCode != 0) {
        final error = stderrBuffer.toString().trim();
        final authError = checkAuthenticationErrors(error);
        if (authError != null) throw YtdlpException(authError);
        if (_isVpnNetworkError(error) || _isCookieRelatedError(error) || error.toLowerCase().contains('timed out')) {
          throw YtdlpException(_vpnFriendlyMessage('Failed to fetch playlist info: $error'));
        }
        throw YtdlpException('Failed to fetch playlist info: $error');
      }

      if (videos.isEmpty) throw YtdlpException('No videos found in playlist');

      onProgress?.call('Processing ${videos.length} videos...');

      final info = PlaylistInfo(
        id: playlistMetadata?['id'] ?? '',
        title: playlistMetadata?['title'] ?? 'Playlist',
        uploader: playlistMetadata?['uploader'] ?? playlistMetadata?['uploader_id'] ?? 'Unknown',
        description: playlistMetadata?['description'],
        videoCount: videos.length,
        videos: videos,
      );
      _notificationService?.show(title: 'Playlist Fetched', body: '${info.title} (${info.videoCount} videos)');
      return info;
    }

    // Attempt 1: normal
    try {
      return await runWithArgs(_buildPlaylistArgs(url));
    } on YtdlpException catch (e) {
      final msg = e.message;
      final isVpn = _isVpnNetworkError(msg) || msg.toLowerCase().contains('timed out');
      final isCookie = _isCookieRelatedError(msg);
      if (isVpn || isCookie) {
        LoggingService().warning('Playlist fetch failed ($msg), retrying without cookies/VPN fallback', component: 'YtdlpService');
        onProgress?.call('Retrying without browser cookies (VPN fallback)...');
        try {
          return await runWithArgs(_buildPlaylistArgs(url, stripCookies: true));
        } catch (e2) {
          if (_isVpnNetworkError(e2.toString())) {
            onProgress?.call('Retrying with VPN-tolerant settings...');
            try {
              return await runWithArgs(_buildPlaylistArgs(url, stripCookies: true, vpnFallback: true));
            } catch (_) {}
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  /// Download video with specified format
  Future<Process> downloadVideo({
    required String url,
    required String outputPath,
    String? formatId,
    String? audioFormatId,
    bool audioOnly = false,
    String? audioQuality, // '0' (best) to '9' (worst)
    int? targetHeight,
    bool embedThumbnail = true,
    bool embedMetadata = true,
    List<String>? subtitleLanguages,
    bool embedSubtitles = false,
    bool sponsorBlock = false,
    String? archivePath,
    Function(double progress, double speed, int eta)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    final args = _buildCommonArgs(
      sponsorBlock: sponsorBlock,
      archivePath: archivePath,
    );
    args.addAll(['-o', outputPath]);

    // Embed thumbnail and metadata (requires FFmpeg)
    if (_ffmpegPath != null) {
      if (embedThumbnail) args.add('--embed-thumbnail');
      if (embedMetadata) args.add('--embed-metadata');
    }

    // Subtitles
    if (subtitleLanguages != null && subtitleLanguages.isNotEmpty) {
      args.add('--write-subs');
      if (embedSubtitles && _ffmpegPath != null) {
        args.add('--embed-subs');
      }
      for (final lang in subtitleLanguages) {
        args.addAll(['--sub-lang', lang]);
      }
    }

    // Always write thumbnail to disk for History UI optimization
    args.add('--write-thumbnail');

    if (audioOnly) {
      // Audio only mode
      if (audioFormatId != null) {
        // Only force format if it's not a generic 'best' selection
        // to avoid redundant transcoding.
        if (audioFormatId != 'bestaudio' && audioFormatId != 'best') {
           args.addAll(['-f', audioFormatId]);
        }
      }
      args.addAll([
        '-x', // Extract audio
        '--audio-format', 'mp3',
        '--audio-quality', audioQuality ?? '0', // Default to 0 (Best)
      ]);
    } else if (formatId != null && audioFormatId != null) {
      // Separate video and audio streams - strictly use selected formats
      args.addAll(['-f', '$formatId+$audioFormatId']);

      // Ensure merge output format matches the destination extension if it's a standard container
      final ext = p.extension(outputPath).replaceAll('.', '').toLowerCase();
      if (ext.isNotEmpty &&
          ['mp4', 'mkv', 'ogg', 'webm', 'flv'].contains(ext)) {
        args.addAll(['--merge-output-format', ext]);
      }
    } else if (formatId != null) {
      // Single format with fallback - skip if it's a live stream format (9x range)
      final isLikelyLiveFormat =
          int.tryParse(formatId) != null &&
          int.parse(formatId) >= 90 &&
          int.parse(formatId) <= 99;
      if (isLikelyLiveFormat) {
        // Use best quality instead of live stream format
        args.addAll([
          '-f',
          'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best',
        ]);
      } else {
        // Strictly use the specified single format
        args.addAll(['-f', formatId]);
      }
    } else if (targetHeight != null) {
      // User specified max resolution - apply height filter
      args.addAll([
        '-f',
        'bestvideo[height<=$targetHeight][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$targetHeight]+bestaudio/best[height<=$targetHeight][ext=mp4]/best[height<=$targetHeight]',
      ]);
    } else {
      // Best quality default with comprehensive fallback chain
      args.addAll([
        '-f',
        'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best',
      ]);
    }

    args.addAll(['--', _validateUrl(url)]);

    final process = await Process.start(_ytdlpPath, args);
    return process;
  }

  /// Build common arguments for yt-dlp including cookies and ffmpeg location
  /// VPN-resilient: increased timeouts/retries, linear retry sleep
  List<String> _buildCommonArgs({
    bool sponsorBlock = false,
    String? archivePath,
  }) {
    final args = <String>[
      '--newline',
      '--no-playlist',
      // Titles with | : * ? " < > \ break NTFS writes. yt-dlp replaces them
      // with underscores when this flag is set (e.g. "Axiom | Module_7").
      '--windows-filenames',
      '--retries',
      '5',
      '--fragment-retries',
      '5',
      '--file-access-retries',
      '3',
      '--extractor-retries',
      '3',
      '--socket-timeout',
      '30',
      '--retry-sleep',
      'linear=1:3',
      '--concurrent-fragments',
      '16',
      '--buffer-size',
      '16K',
      '--http-chunk-size',
      '10M',
      '--no-warnings',
    ];

    if (_ffmpegPath != null && _ffmpegPath != 'ffmpeg') {
      args.addAll(['--ffmpeg-location', _ffmpegPath!]);
    }

    if (_userAgent != null) {
      args.addAll(['--user-agent', _userAgent!]);
    }

    // SponsorBlock
    if (sponsorBlock) {
      args.add('--sponsorblock-remove');
    }

    // Download archive
    if (archivePath != null && archivePath.isNotEmpty) {
      args.addAll(['--download-archive', archivePath]);
    }

    // Authentication logic: WebView profile > cookies file > browser cookies
    if (_enableCookies) {
      if (_webViewPath != null) {
        args.addAll(['--cookies-from-browser', 'edge:$_webViewPath']);
      } else if (_cookiePath != null) {
        final cookieFile = File(_cookiePath!);

        if (cookieFile.existsSync()) {
          // Using 'web' client with cookies - no need for extra extractor args
          args.addAll(['--cookies', _cookiePath!]);
        }
      } else if (_cookieBrowser != null && _cookieBrowser != 'none') {
        args.addAll(['--cookies-from-browser', _cookieBrowser!.toLowerCase()]);
      }
    }

    return args;
  }

  /// Check for authentication or permission errors in yt-dlp output
  static String? checkAuthenticationErrors(String output) {
    if (output.contains("Sign in to confirm you're not a bot") ||
        output.contains('Sign in to confirm your age') ||
        output.contains('This video is age-restricted') ||
        output.contains('Please sign in to view this video') ||
        output.contains('requires authentication')) {
      return 'Authentication required. Please provide a cookies.txt file or use browser cookies in Settings.';
    }

    if (output.contains('Permission denied') && output.contains('cookie')) {
      return 'Access to browser cookies denied. Please close all windows of specified browser and try again, or use a cookies.txt file.';
    }

    if (output.contains('Incomplete cookies file')) {
      return 'The selected cookies.txt file is incomplete or invalid. Please re-export it using the Netscape format.';
    }

    // Check for specific YouTube authentication errors
    if (output.toLowerCase().contains('authentication') &&
        (output.toLowerCase().contains('failed') ||
            output.toLowerCase().contains('required'))) {
      return 'Authentication failed. Please verify your cookies are valid and up-to-date.';
    }

    if (output.contains('HTTP Error 429') ||
        output.contains('Too Many Requests')) {
      return 'Rate limit exceeded (HTTP 429). Please wait a while before downloading more videos.';
    }

    return null;
  }

  /// Parse progress from yt-dlp output line
  static DownloadProgress? parseProgress(String line) {
    final lowerLine = line.toLowerCase();

    if (line.contains('[download] Destination:')) {
      if (lowerLine.contains('.mp4') ||
          lowerLine.contains('.mkv') ||
          lowerLine.contains('.webm')) {
        return DownloadProgress(
          progress: 0,
          speed: 0,
          eta: 0,
          status: DownloadStatus.downloadingVideo,
        );
      } else if (lowerLine.contains('.m4a') ||
          lowerLine.contains('.audio') ||
          lowerLine.contains('.mp3') ||
          lowerLine.contains('.opus')) {
        return DownloadProgress(
          progress: 0,
          speed: 0,
          eta: 0,
          status: DownloadStatus.downloadingAudio,
        );
      }
    }

    if (line.contains('[download] 100%') || line.contains('has already been downloaded')) {
      return DownloadProgress(progress: 1.0, eta: 0);
    }

    final progressMatch = RegExp(
      r'\[download\]\s+(\d+(?:\.\d+)?)%',
    ).firstMatch(line);

    if (progressMatch == null) {
      if (lowerLine.contains('[merger]') ||
          lowerLine.contains('[ffmpeg]') ||
          lowerLine.contains('merging formats into')) {
        return DownloadProgress(
          progress: 1.0,
          speed: 0,
          eta: 0,
          status: DownloadStatus.merging,
        );
      }

      return null;
    }

    final percent = double.parse(progressMatch.group(1)!) / 100;
    final speedMatch = RegExp(
      r'at\s+(\d+(?:\.\d+)?)\s*([KMG]?i?)B/s',
      caseSensitive: false,
    ).firstMatch(line);
    final etaMatch = RegExp(r'ETA\s+(?:(\d+):)?(\d+):(\d+)').firstMatch(line);

    double? speed;
    if (speedMatch != null) {
      final parsedSpeed = double.parse(speedMatch.group(1)!);
      final unit = (speedMatch.group(2) ?? '').toLowerCase();
      speed =
          parsedSpeed *
          switch (unit) {
            'ki' => 1024,
            'mi' => 1024 * 1024,
            'gi' => 1024 * 1024 * 1024,
            _ => 1,
          };
    }

    int? eta;
    if (etaMatch != null) {
      final hours = int.tryParse(etaMatch.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(etaMatch.group(2) ?? '0') ?? 0;
      final seconds = int.tryParse(etaMatch.group(3) ?? '0') ?? 0;
      eta = hours * 3600 + minutes * 60 + seconds;
    }

    return DownloadProgress(
      progress: percent.clamp(0.0, 1.0),
      speed: speed,
      eta: eta,
    );
  }

  static String formatDownloadError(String output, int exitCode) {
    return ErrorHelper.formatDownloadError(output, exitCode);
  }

  /// Get best format for a specific resolution
  static String? getBestFormatForResolution(
    VideoInfo video,
    int targetHeight, {
    bool videoOnly = false,
  }) {
    final formats = videoOnly ? video.videoOnlyFormats : video.formats;

    // Find formats matching or closest to target height
    final matchingFormats = formats
        .where((f) => f.hasVideo && f.height != null)
        .toList();

    if (matchingFormats.isEmpty) return null;

    // Sort by how close they are to target, preferring higher quality
    matchingFormats.sort((a, b) {
      final diffA = (a.height! - targetHeight).abs();
      final diffB = (b.height! - targetHeight).abs();
      if (diffA != diffB) return diffA.compareTo(diffB);
      return (b.height ?? 0).compareTo(a.height ?? 0);
    });

    return matchingFormats.first.formatId;
  }

  /// Get best audio format
  static String? getBestAudioFormat(VideoInfo video) {
    final audioFormats = video.audioOnlyFormats;
    if (audioFormats.isEmpty) return null;
    return audioFormats.first.formatId;
  }

  /// Test authentication with a simple YouTube video to verify cookies are working
  Future<bool> testAuthentication() async {
    try {
      // Use a simple, non-age-restricted video for testing
      final testVideoUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

      // Try to fetch video info - this will fail if authentication is not working
      await getVideoInfo(testVideoUrl);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check for updates and return update info with download URL
  /// Returns null ONLY if yt-dlp is not available or version check failed
  /// Returns YtdlpUpdateInfo with same current/latest version when up to date
  @override
  Future<YtdlpUpdateInfo?> checkForUpdateWithProgress() async {
    final logger = LoggingService();
    logger.info('Checking for yt-dlp updates...', component: 'YtdlpService');

    try {
      final currentVersion = await getVersion();
      if (currentVersion == null) {
        logger.warning(
          'Cannot check for updates: yt-dlp not available',
          component: 'YtdlpService',
        );
        return null;
      }

      final latestVersion = await getLatestVersion();
      if (latestVersion == null) {
        logger.warning(
          'Cannot check for updates: failed to fetch latest version',
          component: 'YtdlpService',
        );
        // Still return info with current version so UI knows yt-dlp is installed
        return YtdlpUpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion, // Same as current means up to date
          downloadUrl: _windowsDownloadUrl,
          publishedAt: DateTime.now(),
          releaseNotes: 'Up to date',
        );
      }

      final hasUpdate = isNewerVersion(currentVersion, latestVersion);

      logger.info(
        'Update check complete: current=$currentVersion, latest=$latestVersion, updateAvailable=$hasUpdate',
        component: 'YtdlpService',
      );

      // Always return info - this lets the caller know yt-dlp is available
      return YtdlpUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl: _windowsDownloadUrl,
        publishedAt: DateTime.now(),
        releaseNotes: hasUpdate
            ? 'New version available: $latestVersion'
            : 'Up to date',
      );
    } catch (e, stackTrace) {
      // Propagate rate-limit so UI can show specific message instead of silent "Not found"
      if (e.toString().toLowerCase().contains('rate limit') ||
          e.toString().contains('403') ||
          e.toString().contains('429')) {
        logger.warning(
          'Rate limited while checking yt-dlp updates: $e',
          component: 'YtdlpService',
        );
        rethrow;
      }
      logger.error(
        'Failed to check for yt-dlp updates',
        component: 'YtdlpService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Download and install update with progress callback.
  /// The download runs in a background isolate for full network throughput.
  @override
  Future<bool> downloadAndInstallUpdate(
    String downloadUrl, {
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
    bool Function()? isCancelled,
  }) async {
    final logger = LoggingService();
    File? tempFile;
    Directory? tempDir;

    try {
      // Ensure managed path is resolved before we decide where to install
      await initialize();
      onStatus('Downloading latest yt-dlp...');
      logger.info(
        'Starting yt-dlp update download (background isolate) -> $downloadUrl',
        component: 'YtdlpService',
      );

      // Private temp directory with a random suffix (O_EXCL semantics) to
      // avoid predicted-name symlink/hijack races in the shared temp dir (M11).
      tempDir = await Directory.systemTemp.createTemp('yt-dlp-update-');
      tempFile = File(p.join(tempDir.path, 'yt-dlp.exe'));

      // Download via multi-connection curl (8 parallel connections)
      await downloadInBackground(
        url: downloadUrl,
        destPath: tempFile.path,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      logger.info('yt-dlp download complete', component: 'YtdlpService');
      final downloadedSize = await tempFile.length();
      if (downloadedSize < 1024 * 1024) {
        // Read first bytes to diagnose HTML error page vs binary
        String snippet = '';
        try {
          final head = await tempFile.openRead(0, 500).transform(utf8.decoder).join();
          snippet = head.substring(0, head.length > 200 ? 200 : head.length);
        } catch (_) {}
        throw Exception(
          'Downloaded file too small ($downloadedSize bytes), likely not a valid binary. Snippet: $snippet',
        );
      }

      if (isCancelled?.call() == true) {
        onStatus('Update cancelled');
        return false;
      }

      onStatus('Installing update...');
      logger.info(
        'Download complete, installing update to $_ytdlpPath',
        component: 'YtdlpService',
      );

      // Backup current binary
      final currentFile = File(_ytdlpPath);
      final backupPath = '$_ytdlpPath.backup';

      if (await currentFile.exists()) {
        try {
          await currentFile.copy(backupPath);
        } catch (e) {
          logger.warning('Backup copy failed (may be locked): $e', component: 'YtdlpService');
        }
      }

      try {
        // On Windows the exe may be locked if a download is in progress – retry deletion
        for (int i = 0; i < 3; i++) {
          try {
            if (await currentFile.exists()) await currentFile.delete();
            break;
          } catch (e) {
            if (i == 2) rethrow;
            await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
          }
        }
        await tempFile.copy(_ytdlpPath);
        // Clear version cache so next getVersion reads new binary
        _cachedVersion = null;
        logger.info('Update installed successfully', component: 'YtdlpService');

        final backupFile = File(backupPath);
        if (await backupFile.exists()) await backupFile.delete();

        onStatus('Update complete!');
        return true;
      } catch (e) {
        logger.error(
          'Failed to install update, restoring backup',
          component: 'YtdlpService',
          error: e,
        );
        final backupFile = File(backupPath);
        if (await backupFile.exists()) {
          try {
            if (await currentFile.exists()) await currentFile.delete();
          } catch (_) {}
          await backupFile.copy(_ytdlpPath);
          try {
            await backupFile.delete();
          } catch (_) {}
        }
        throw Exception('Failed to install update: $e');
      }
    } catch (e, stackTrace) {
      if (e.toString().contains('Cancelled')) {
        onStatus('Update cancelled');
        return false;
      }
      logger.error(
        'Update download/install failed',
        component: 'YtdlpService',
        error: e,
        stackTrace: stackTrace,
      );
      onStatus('Update failed: $e');
      return false;
    } finally {
      if (tempDir != null && tempDir.existsSync()) {
        try {
          // Recursively delete the private temp directory (binary + anything
          // written alongside it).
          await tempDir.delete(recursive: true);
        } catch (e) {
          LoggingService().debug(
            'Failed to delete temp update file: $e',
            component: 'YtdlpService',
          );
        }
      }
    }
  }
}

class DownloadProgress {
  final double progress;
  final double? speed;
  final int? eta;
  final DownloadStatus? status;

  DownloadProgress({required this.progress, this.speed, this.eta, this.status});
}

class YtdlpException implements Exception {
  final String message;
  YtdlpException(this.message);

  @override
  String toString() => 'YtdlpException: $message';
}
