import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/ytdlp_service.dart';
import '../services/ytdlp_service_android.dart';
import '../services/ffmpeg_service.dart';
import '../services/ffmpeg_service_android.dart';
import '../services/cookie_service.dart';
import '../services/logging_service.dart';
import '../core/utils/platform_utils.dart';
import '../services/android_storage_service.dart';

/// Platform-aware settings provider with Android-specific defaults
class PlatformSettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService;
  final dynamic _ytdlpService; // Can be YtdlpService or YtdlpServiceAndroid
  final dynamic _ffmpegService; // Can be FfmpegService or FfmpegServiceAndroid
  final CookieService _cookieService;
  final AndroidStorageService _androidStorageService = AndroidStorageService();

  bool _isInitialized = false;
  bool _isYtdlpAvailable = false;
  bool _isFfmpegAvailable = false;
  String? _ytdlpVersion;
  String? _ffmpegVersion;
  DateTime? _cookieFileLastModified;
  String? _cookieFileName;
  bool _isYouTubeLoggedIn = false;
  DateTime? _youTubeLoginTime;
  bool _isBatteryOptimizationIgnored = false;
  bool _isCheckingBatteryOptimization = false;

  PlatformSettingsProvider({
    required SettingsService settingsService,
    required dynamic ytdlpService,
    required dynamic ffmpegService,
    required CookieService cookieService,
  }) : _settingsService = settingsService,
       _ytdlpService = ytdlpService,
       _ffmpegService = ffmpegService,
       _cookieService = cookieService;

  AppSettings get settings => _settingsService.settings;
  bool get isInitialized => _isInitialized;
  bool get isYtdlpAvailable => _isYtdlpAvailable;
  bool get isFfmpegAvailable => _isFfmpegAvailable;
  String? get ytdlpVersion => _ytdlpVersion;
  String? get ffmpegVersion => _ffmpegVersion;
  String get activeYtdlpPath => _ytdlpService.ytdlpPath;
  String? get activeFfmpegPath {
    if (_ffmpegService is FfmpegServiceAndroid) {
      return null;
    }
    return _ffmpegService.ffmpegPath;
  }

  ThemeMode get themeMode => settings.themeMode;
  DateTime? get cookieFileLastModified => _cookieFileLastModified;
  String? get cookieFileName => _cookieFileName;
  bool get isYouTubeLoggedIn => _isYouTubeLoggedIn;
  String? get youtubeProfileImageUrl => settings.youtubeProfileImageUrl;
  DateTime? get youTubeLoginTime => _youTubeLoginTime;
  CookieService get cookieService => _cookieService;
  dynamic get ytdlpService => _ytdlpService;
  bool get enableCookies => settings.enableCookies;
  bool get enableLogging => settings.enableLogging;
  bool get isBatteryOptimizationIgnored =>
      PlatformUtils.isAndroid ? _isBatteryOptimizationIgnored : true;
  bool get isCheckingBatteryOptimization =>
      PlatformUtils.isAndroid ? _isCheckingBatteryOptimization : false;

  String get cookieStatus {
    if (_isYouTubeLoggedIn) {
      return 'Signed in via WebView (Limited)';
    }
    if (settings.cookieBrowser != null && settings.cookieBrowser != 'none') {
      return 'Using ${settings.cookieBrowser![0].toUpperCase()}${settings.cookieBrowser!.substring(1)} browser';
    }
    if (settings.cookiePath != null) {
      return 'Using cookies.txt: ${cookieFileName ?? "File Loaded"}';
    }
    return 'None';
  }

  bool get isCookieActive =>
      settings.enableCookies &&
      (_isYouTubeLoggedIn ||
          (settings.cookieBrowser != null &&
              settings.cookieBrowser != 'none') ||
          settings.cookiePath != null);

  /// Get default output path based on platform
  Future<String> getDefaultOutputPath() async {
    if (PlatformUtils.isAndroid) {
      return await _androidStorageService.getDownloadDirectory();
    } else {
      // Windows/Desktop - use user's Downloads directory
      final homeDir =
          Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          '';
      return p.join(homeDir, 'Downloads', 'AeroTube');
    }
  }

  Future<void> init() async {
    await _settingsService.init();

    // Set default output path if not set
    if (settings.outputPath == null || settings.outputPath!.isEmpty) {
      final defaultPath = await getDefaultOutputPath();
      await setOutputPath(defaultPath);
    }

    // Update services with saved paths
    if (settings.ytdlpPath != null) {
      _ytdlpService.ytdlpPath = settings.ytdlpPath!;
    }
    if (settings.ffmpegPath != null) {
      if (_ffmpegService is FfmpegService) {
        (_ffmpegService).ffmpegPath = settings.ffmpegPath!;
      }
      if (_ytdlpService is YtdlpService) {
        (_ytdlpService).ffmpegPath = settings.ffmpegPath!;
      }
    }
    if (settings.cookiePath != null) {
      if (_ytdlpService is YtdlpService) {
        (_ytdlpService).cookiePath = settings.cookiePath;
      } else if (_ytdlpService is YtdlpServiceAndroid) {
        (_ytdlpService).cookiePath = settings.cookiePath;
      }
      _updateCookieFileMetadata(settings.cookiePath!);
    }
    if (settings.cookieBrowser != null) {
      if (_ytdlpService is YtdlpService) {
        (_ytdlpService).cookieBrowser = settings.cookieBrowser;
      }
    }
    if (_ytdlpService is YtdlpService) {
      (_ytdlpService).enableCookies = settings.enableCookies;
    } else if (_ytdlpService is YtdlpServiceAndroid) {
      (_ytdlpService).enableCookies = settings.enableCookies;
    }

    // Request storage permissions on Android
    if (PlatformUtils.isAndroid) {
      await _androidStorageService.requestStoragePermission();
    }

    _isInitialized = true;
    notifyListeners();

    // Warm tools and fetch availability after first paint instead of blocking init.
    Future.microtask(() async {
      await _initializeToolsAsync();
      await checkToolsAvailability();
      await refreshBatteryOptimizationStatus();

      if (_isFfmpegAvailable && settings.ffmpegPath == null) {
        if (_ytdlpService is YtdlpService && _ffmpegService is FfmpegService) {
          (_ytdlpService).ffmpegPath = (_ffmpegService).ffmpegPath;
        }
      }
    });

    // Check YouTube login status in background (don't block cold boot)
    Future.microtask(_checkYouTubeLoginAsync);
  }

  /// Check if user is logged into YouTube via WebView cookies
  Future<void> checkYouTubeLoginStatus() async {
    _isYouTubeLoggedIn = await _cookieService.isLoggedIn;
    _youTubeLoginTime = await _cookieService.lastLoginTime;

      // If logged in via WebView, configure ytdlp to use the WebView profile directly
      if (_isYouTubeLoggedIn) {
        final userAgent = await _cookieService.userAgent;

        if (_ytdlpService is YtdlpService) {
          final webViewPath = await _cookieService.webViewPath;
          (_ytdlpService).webViewPath = webViewPath;
          (_ytdlpService).userAgent = userAgent;
          // Clear other cookie methods to ensure WebView takes precedence
          (_ytdlpService).cookiePath = null;
          (_ytdlpService).cookieBrowser = null;

          LoggingService().info(
            'YouTube WebView login detected',
            component: 'PlatformSettingsProvider',
          );
          LoggingService().debug(
            'WebView profile path: $webViewPath',
            component: 'PlatformSettingsProvider',
          );
          LoggingService().debug(
            'yt-dlp will use: --cookies-from-browser edge:$webViewPath',
            component: 'PlatformSettingsProvider',
          );
        } else if (_ytdlpService is YtdlpServiceAndroid) {
          // For Android, also pass the user agent from WebView
          (_ytdlpService).userAgent = userAgent;
          LoggingService().info(
            'Android: Set user agent from WebView for yt-dlp',
            component: 'PlatformSettingsProvider',
          );
        }
    }

    notifyListeners();
  }

  /// Check YouTube login in background without blocking
  Future<void> _checkYouTubeLoginAsync() async {
    await checkYouTubeLoginStatus();
  }

  /// Called after successful YouTube login
  Future<void> onYouTubeLoginComplete() async {
    await checkYouTubeLoginStatus();
  }

  /// Logout from YouTube (clear saved cookies)
  Future<void> logoutFromYouTube() async {
    await _cookieService.clearCookies();
    _isYouTubeLoggedIn = false;
    _youTubeLoginTime = null;
    await setYoutubeProfileImageUrl(null);

    // Clear cookie path from ytdlp and settings if it was using the WebView cookies
    final cookiePath = await _cookieService.cookieFilePath;
    if (_ytdlpService is YtdlpService &&
        (_ytdlpService).cookiePath == cookiePath) {
      (_ytdlpService).cookiePath = null;
      (_ytdlpService).userAgent = null;
      await _settingsService.setCookiePath(null);
    } else if (_ytdlpService is YtdlpServiceAndroid) {
      (_ytdlpService).userAgent = null;
    }

    notifyListeners();
  }

  Future<void> checkToolsAvailability() async {
    _isYtdlpAvailable = await _ytdlpService.isAvailable();

    if (_ffmpegService is FfmpegServiceAndroid) {
      _isFfmpegAvailable = (_ffmpegService).isAvailable;
    } else {
      _isFfmpegAvailable = (_ffmpegService as FfmpegService).isAvailable;
    }

    if (_isYtdlpAvailable) {
      _ytdlpVersion = await _ytdlpService.getVersion();
    }
    if (_isFfmpegAvailable) {
      if (_ffmpegService is FfmpegServiceAndroid) {
        _ffmpegVersion = await (_ffmpegService).getVersion();
      } else {
        _ffmpegVersion = await (_ffmpegService as FfmpegService).getVersion();
      }
    }

    notifyListeners();
  }

  /// Initialize tools in background without blocking
  Future<void> _initializeToolsAsync() async {
    try {
      await _ytdlpService.initialize();
      await _ffmpegService.initialize();
    } catch (e) {
      // Log but don't block - tools can be initialized on-demand later
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _settingsService.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setYtdlpPath(String? path) async {
    await _settingsService.setYtdlpPath(path);
    if (path != null) {
      _ytdlpService.ytdlpPath = path;
    } else {
      // Re-initialize to restore managed path
      await _ytdlpService.initialize(force: true);
    }
    await checkToolsAvailability();
  }

  Future<void> setFfmpegPath(String? path) async {
    await _settingsService.setFfmpegPath(path);
    if (_ffmpegService is FfmpegService) {
      (_ffmpegService).ffmpegPath = path;
    }
    if (_ytdlpService is YtdlpService) {
      (_ytdlpService).ffmpegPath = path;
    }
    await checkToolsAvailability();
  }

  Future<void> setOutputPath(String path) async {
    await _settingsService.setOutputPath(path);
    notifyListeners();
  }

  Future<void> setCookiePath(String? path) async {
    await _settingsService.setCookiePath(path);
    if (_ytdlpService is YtdlpService) {
      (_ytdlpService).cookiePath = path;
    } else if (_ytdlpService is YtdlpServiceAndroid) {
      (_ytdlpService).cookiePath = path;
    }
    if (path != null) {
      _updateCookieFileMetadata(path);
    } else {
      _cookieFileLastModified = null;
      _cookieFileName = null;
    }
    notifyListeners();
  }

  void _updateCookieFileMetadata(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        _cookieFileLastModified = file.lastModifiedSync();
        _cookieFileName = file.path.split(Platform.pathSeparator).last;
      }
    } catch (e) {
      LoggingService().error(
        'Failed to get cookie file metadata: $e',
        component: 'PlatformSettingsProvider',
      );
    }
  }

  Future<void> setCookieBrowser(String? browser) async {
    await _settingsService.setCookieBrowser(browser);
    if (_ytdlpService is YtdlpService) {
      (_ytdlpService).cookieBrowser = browser;
      if (browser != null) {
        (_ytdlpService).cookiePath = null;
      }
    }
    notifyListeners();
  }

  Future<void> setYoutubeProfileImageUrl(String? url) async {
    await _settingsService.setYoutubeProfileImageUrl(url);
    notifyListeners();
  }

  Future<void> setDefaultQuality(String quality) async {
    await _settingsService.setDefaultQuality(quality);
    notifyListeners();
  }

  Future<void> setEmbedThumbnail(bool value) async {
    await _settingsService.setEmbedThumbnail(value);
    notifyListeners();
  }

  Future<void> setEmbedMetadata(bool value) async {
    await _settingsService.setEmbedMetadata(value);
    notifyListeners();
  }

  Future<void> setEnableCookies(bool value) async {
    await _settingsService.setEnableCookies(value);
    if (_ytdlpService is YtdlpService) {
      (_ytdlpService).enableCookies = value;
    } else if (_ytdlpService is YtdlpServiceAndroid) {
      (_ytdlpService).enableCookies = value;
    }
    notifyListeners();
  }

  Future<void> refreshBatteryOptimizationStatus() async {
    if (!PlatformUtils.isAndroid) {
      _isBatteryOptimizationIgnored = true;
      return;
    }

    _isCheckingBatteryOptimization = true;
    notifyListeners();

    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      _isBatteryOptimizationIgnored = status.isGranted;
    } catch (e) {
      _isBatteryOptimizationIgnored = false;
    } finally {
      _isCheckingBatteryOptimization = false;
      notifyListeners();
    }
  }

  Future<bool> requestBatteryOptimizationExemption() async {
    if (!PlatformUtils.isAndroid) return false;

    _isCheckingBatteryOptimization = true;
    notifyListeners();

    try {
      final result = await Permission.ignoreBatteryOptimizations.request();
      _isBatteryOptimizationIgnored = result.isGranted;
      return result.isGranted;
    } catch (e) {
      return false;
    } finally {
      _isCheckingBatteryOptimization = false;
      notifyListeners();
    }
  }

  // Getters for new settings
  bool get isYtdlpManaged => settings.isYtdlpManaged;
  String? get outputPath => settings.outputPath;
  int get maxConcurrentDownloads => settings.maxConcurrentDownloads;
  String get defaultQuality => settings.defaultQuality;
  bool get embedThumbnail => settings.embedThumbnail;
  bool get embedMetadata => settings.embedMetadata;
  bool get autoMergeStreams => settings.autoMergeStreams;
  String get defaultSubtitleLanguage => settings.defaultSubtitleLanguage;

  Color? get accentColor => settings.accentColorValue != null
      ? Color(settings.accentColorValue!)
      : null;

  bool get enableNotifications => settings.enableNotifications;
  bool get autoCheckUpdates => settings.autoCheckUpdates;
  bool get sponsorBlockEnabled => settings.sponsorBlockEnabled;
  bool get useDownloadArchive => settings.useDownloadArchive;

  // New Setters
  Future<void> setIsYtdlpManaged(bool value) async {
    await _settingsService.setIsYtdlpManaged(value);
    notifyListeners();
  }

  Future<void> setMaxConcurrentDownloads(int value) async {
    await _settingsService.setMaxConcurrentDownloads(value);
    notifyListeners();
  }

  Future<void> setAutoMergeStreams(bool value) async {
    await _settingsService.setAutoMergeStreams(value);
    notifyListeners();
  }

  Future<void> setDefaultSubtitleLanguage(String languageCode) async {
    await _settingsService.setDefaultSubtitleLanguage(languageCode);
    notifyListeners();
  }

  Future<void> setAccentColor(Color? color) async {
    await _settingsService.setAccentColor(color?.toARGB32());
    notifyListeners();
  }

  Future<void> setEnableNotifications(bool value) async {
    await _settingsService.setEnableNotifications(value);
    notifyListeners();
  }

  Future<void> setAutoCheckUpdates(bool value) async {
    await _settingsService.setAutoCheckUpdates(value);
    notifyListeners();
  }

  Future<void> setSponsorBlockEnabled(bool value) async {
    await _settingsService.setSponsorBlockEnabled(value);
    notifyListeners();
  }

  Future<void> setEnableLogging(bool value) async {
    await _settingsService.setEnableLogging(value);
    await LoggingService().setEnabled(value);
    notifyListeners();
  }

  Future<void> setUseDownloadArchive(bool value) async {
    await _settingsService.setUseDownloadArchive(value);
    notifyListeners();
  }

  Future<bool> updateYtdlp() async {
    await _ytdlpService.initialize();
    final success = await _ytdlpService.update();
    await checkToolsAvailability();
    return success;
  }

  Future<bool> updateFfmpeg() async {
    await _ffmpegService.initialize();
    final success = await _ffmpegService.update();
    await checkToolsAvailability();
    return success;
  }

  /// Helper to install tools if missing
  Future<bool> installYtdlp() async {
    await _ytdlpService.initialize(force: true);
    await checkToolsAvailability();
    return _isYtdlpAvailable;
  }

  Future<bool> installFfmpeg() async {
    await _ffmpegService.initialize();
    await checkToolsAvailability();
    return _isFfmpegAvailable;
  }

  /// Get Android storage info
  Future<Map<String, dynamic>> getAndroidStorageInfo() async {
    if (!PlatformUtils.isAndroid) {
      return {'platform': 'Not Android'};
    }
    return await _androidStorageService.getStorageInfo();
  }

  /// Check if running on mobile
  bool get isMobile => PlatformUtils.isMobile;

  /// Check if running on Android
  bool get isAndroid => PlatformUtils.isAndroid;
}
