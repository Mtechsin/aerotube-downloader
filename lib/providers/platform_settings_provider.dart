import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../models/app_settings.dart';
import '../services/ytdlp/ytdlp_tool_service.dart';
import '../services/ffmpeg/ffmpeg_tool_service.dart';
import '../services/cookie/cookie_service.dart';
import '../services/core/logging_service.dart';
import '../core/utils/platform_utils.dart';
import '../services/core/android_storage_service.dart';
import '../services/core/settings_service.dart';
import '../services/notification/notification_service.dart';

/// Platform-aware settings provider with Android-specific defaults
class PlatformSettingsProvider extends ChangeNotifier {
  static const MethodChannel _permissionsChannel =
      MethodChannel('com.aerotube.youtube_downloader/permissions');

  final SettingsService _settingsService;
  final YtdlpToolService _ytdlpService;
  final FfmpegToolService _ffmpegService;
  final CookieService _cookieService;
  final AndroidStorageService _androidStorageService = AndroidStorageService();

  bool _isInitialized = false;
  bool _isYtdlpAvailable = false;
  bool _isFfmpegAvailable = false;
  bool _hasCheckedTools = false;
  String? _ytdlpVersion;
  String? _ffmpegVersion;
  DateTime? _cookieFileLastModified;
  String? _cookieFileName;
  bool _isYouTubeLoggedIn = false;
  DateTime? _youTubeLoginTime;
  bool _isBatteryOptimizationIgnored = false;
  bool _isCheckingBatteryOptimization = false;
  String? _deviceManufacturer;

  PlatformSettingsProvider({
    required SettingsService settingsService,
    required YtdlpToolService ytdlpService,
    required FfmpegToolService ffmpegService,
    required CookieService cookieService,
  }) : _settingsService = settingsService,
       _ytdlpService = ytdlpService,
       _ffmpegService = ffmpegService,
       _cookieService = cookieService;

  AppSettings get settings => _settingsService.settings;
  bool get isInitialized => _isInitialized;
  bool get isYtdlpAvailable => _isYtdlpAvailable;
  bool get isFfmpegAvailable => _isFfmpegAvailable;
  /// Whether the async tool availability check has completed at least once.
  /// UI should only show "not found" banners when this is true.
  bool get hasCheckedTools => _hasCheckedTools;
  String? get ytdlpVersion => _ytdlpVersion;
  String? get ffmpegVersion => _ffmpegVersion;
  String get activeYtdlpPath => _ytdlpService.ytdlpPath;
  String? get activeFfmpegPath => _ffmpegService.ffmpegPath;

  ThemeMode get themeMode => settings.themeMode;
  DateTime? get cookieFileLastModified => _cookieFileLastModified;
  String? get cookieFileName => _cookieFileName;
  bool get isYouTubeLoggedIn => _isYouTubeLoggedIn;
  String? get youtubeProfileImageUrl => settings.youtubeProfileImageUrl;
  DateTime? get youTubeLoginTime => _youTubeLoginTime;
  CookieService get cookieService => _cookieService;
  YtdlpToolService get ytdlpService => _ytdlpService;
  FfmpegToolService get ffmpegService => _ffmpegService;
  bool get enableCookies => settings.enableCookies;
  bool get enableLogging => settings.enableLogging;
  bool get isBatteryOptimizationIgnored =>
      PlatformUtils.isAndroid ? _isBatteryOptimizationIgnored : true;
  bool get isCheckingBatteryOptimization =>
      PlatformUtils.isAndroid ? _isCheckingBatteryOptimization : false;
  String? get deviceManufacturer => _deviceManufacturer;

  bool get isAggressiveOem {
    if (!PlatformUtils.isAndroid) return false;
    final m = (_deviceManufacturer ?? '').toLowerCase();
    return m.contains('xiaomi') ||
        m.contains('redmi') ||
        m.contains('poco') ||
        m.contains('oppo') ||
        m.contains('realme') ||
        m.contains('oneplus') ||
        m.contains('vivo') ||
        m.contains('iqoo') ||
        m.contains('huawei') ||
        m.contains('honor');
  }

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
    late final String defaultPath;
    if (PlatformUtils.isAndroid) {
      // Prefer public Downloads/AeroTube when writable; otherwise app-specific
      // storage (never force an unwritable public path).
      defaultPath = await _androidStorageService.getSafeDownloadDirectory();
    } else {
      // Desktop platforms use a dedicated aerotube folder inside Downloads.
      final homeDir =
          Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          '';
      defaultPath = p.join(homeDir, 'Downloads', 'aerotube');
    }

    final dir = Directory(defaultPath);
    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } catch (_) {}
    }
    return defaultPath;
  }

  Future<void> init() async {
    await _settingsService.init();

    // Set or migrate the default output path.
    final currentOutputPath = settings.outputPath;
    if (currentOutputPath == null ||
        currentOutputPath.isEmpty ||
        _shouldMigrateAndroidOutputPath(currentOutputPath)) {      final defaultPath = await getDefaultOutputPath();
      if (currentOutputPath != null &&
          currentOutputPath.isNotEmpty &&
          _shouldMigrateAndroidOutputPath(currentOutputPath) &&
          currentOutputPath != defaultPath) {
        // Migrate any downloaded files from old /Android/data/ path to public directory
        try {
          final oldDir = Directory(currentOutputPath);
          if (await oldDir.exists()) {
            final targetDir = Directory(defaultPath);
            if (!await targetDir.exists()) {
              await targetDir.create(recursive: true);
            }
            await for (final entity in oldDir.list(recursive: false)) {
              if (entity is File) {
                final newFilePath = p.join(defaultPath, p.basename(entity.path));
                final newFile = File(newFilePath);
                if (!await newFile.exists()) {
                  try {
                    await entity.rename(newFilePath);
                  } catch (_) {
                    await entity.copy(newFilePath);
                    await entity.delete();
                  }
                  try {
                    await _androidStorageService.scanMediaFile(newFilePath);
                  } catch (_) {}
                }
              }
            }
          }
        } catch (e) {
          LoggingService().warning(
            'Failed to migrate files from $currentOutputPath to $defaultPath: $e',
            component: 'PlatformSettingsProvider',
          );
        }
      }
      await setOutputPath(defaultPath);
    } else if (PlatformUtils.isAndroid) {
      // A previously saved custom folder may be an SD-card pick (no SAF
      // grant) or otherwise unwritable. Validate on boot and fall back to
      // the public default instead of failing downloads later.
      try {
        final validation = await _androidStorageService
            .validateCustomDirectory(currentOutputPath);
        if (!validation.ok) {
          LoggingService().warning(
            'Saved download folder unusable (${validation.reason}); resetting to default.',
            component: 'PlatformSettingsProvider',
          );
          await setOutputPath(await getDefaultOutputPath());
        }
      } catch (_) {}
    }

    // Update services with saved paths
    if (settings.ytdlpPath != null) {
      _ytdlpService.ytdlpPath = settings.ytdlpPath!;
    }
    if (settings.ffmpegPath != null) {
      _ffmpegService.ffmpegPath = settings.ffmpegPath!;
      _ytdlpService.ffmpegPath = settings.ffmpegPath!;
    }
    if (settings.cookiePath != null) {
      _ytdlpService.cookiePath = settings.cookiePath;
      _updateCookieFileMetadata(settings.cookiePath!);
    }
    if (settings.cookieBrowser != null) {
      _ytdlpService.cookieBrowser = settings.cookieBrowser;
    }
    _ytdlpService.enableCookies = settings.enableCookies;
    // Sync notification toggle with the service on boot.
    try {
      NotificationService().systemNotificationsEnabled =
          settings.enableNotifications;
    } catch (_) {}

    _isInitialized = true;
    notifyListeners();

    // Warm tools and fetch availability after first paint instead of blocking init.
    Future.microtask(() async {
      await _initializeToolsAsync();
      await checkToolsAvailability();
      await refreshBatteryOptimizationStatus();
      await getDeviceManufacturer();

      if (_isFfmpegAvailable && settings.ffmpegPath == null) {
        _ytdlpService.ffmpegPath = _ffmpegService.ffmpegPath;
      }
    });

    // Check YouTube login status in background (don't block cold boot)
    Future.microtask(_checkYouTubeLoginAsync);
  }

  bool _shouldMigrateAndroidOutputPath(String path) {
    if (!PlatformUtils.isAndroid) return false;

    final normalized = path.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/android/data/');
  }

  @visibleForTesting
  bool shouldMigrateAndroidOutputPath(String path) =>
      _shouldMigrateAndroidOutputPath(path);

  /// Check if user is logged into YouTube via WebView cookies
  Future<void> checkYouTubeLoginStatus() async {
    _isYouTubeLoggedIn = await _cookieService.isLoggedIn;
    _youTubeLoginTime = await _cookieService.lastLoginTime;

    // If logged in via WebView, configure ytdlp to use the WebView profile directly
    if (_isYouTubeLoggedIn) {
      final userAgent = await _cookieService.userAgent;
      final webViewPath = await _cookieService.webViewPath;
      if (!PlatformUtils.isAndroid && webViewPath != null) {
        _ytdlpService.webViewPath = webViewPath;
        _ytdlpService.userAgent = userAgent;
        _ytdlpService.cookiePath = null;
        _ytdlpService.cookieBrowser = null;
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
      } else {
        _ytdlpService.userAgent = userAgent;
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
    if (_ytdlpService.cookiePath == cookiePath) {
      _ytdlpService.cookiePath = null;
      _ytdlpService.userAgent = null;
      await _settingsService.setCookiePath(null);
    } else {
      _ytdlpService.userAgent = null;
    }

    notifyListeners();
  }

  Future<void> checkToolsAvailability() async {
    _isYtdlpAvailable = await _ytdlpService.isAvailable();
    _isFfmpegAvailable = _ffmpegService.isAvailable;

    if (_isYtdlpAvailable) {
      _ytdlpVersion = await _ytdlpService.getVersion();
    }
    if (_isFfmpegAvailable) {
      _ffmpegVersion = await _ffmpegService.getVersion();
    }

    _hasCheckedTools = true;
    notifyListeners();
  }

  /// Initialize tools in background without blocking
  Future<void> _initializeToolsAsync() async {
    try {
      await _ytdlpService.initialize();
      await _ffmpegService.initialize();
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Background tool initialization encountered an issue: $e',
        component: 'PlatformSettingsProvider',
        error: e,
        stackTrace: stackTrace,
      );
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
    _ffmpegService.ffmpegPath = path;
    _ytdlpService.ffmpegPath = path;
    await checkToolsAvailability();
  }

  Future<void> setOutputPath(String path) async {
    await _settingsService.setOutputPath(path);
    notifyListeners();
  }

  Future<void> setCookiePath(String? path) async {
    await _settingsService.setCookiePath(path);
    _ytdlpService.cookiePath = path;
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
    _ytdlpService.cookieBrowser = browser;
    if (browser != null) {
      _ytdlpService.cookiePath = null;
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
    _ytdlpService.enableCookies = value;
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
      final ignored = await _permissionsChannel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
      _isBatteryOptimizationIgnored = ignored ?? false;
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Failed to check battery optimization status: $e',
        component: 'PlatformSettingsProvider',
        error: e,
        stackTrace: stackTrace,
      );
      _isBatteryOptimizationIgnored = false;
    } finally {
      _isCheckingBatteryOptimization = false;
      notifyListeners();
    }
  }

  /// Opens the system "Allow unrestricted battery?" dialog and waits for
  /// the user's response. Returns true when the exemption is granted.
  Future<bool> requestBatteryOptimizationExemption() async {
    if (!PlatformUtils.isAndroid) return false;

    _isCheckingBatteryOptimization = true;
    notifyListeners();

    try {
      // The native side uses registerForActivityResult — this Future
      // completes only after the user taps Allow or Deny.
      final granted = await _permissionsChannel
          .invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      _isBatteryOptimizationIgnored = granted ?? false;
      return _isBatteryOptimizationIgnored;
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Failed to request battery optimization exemption: $e',
        component: 'PlatformSettingsProvider',
        error: e,
        stackTrace: stackTrace,
      );
      // Re-check in case the state changed despite the error.
      try {
        final ignored = await _permissionsChannel
            .invokeMethod<bool>('isIgnoringBatteryOptimizations');
        _isBatteryOptimizationIgnored = ignored ?? false;
      } catch (_) {}
      return _isBatteryOptimizationIgnored;
    } finally {
      _isCheckingBatteryOptimization = false;
      notifyListeners();
    }
  }

  /// Opens Android's battery-optimization list page so the user can set the
  /// app to "Unrestricted" manually (needed on OEMs that suppress the direct
  /// dialog). Returns true when the page was opened.
  Future<bool> openBatteryOptimizationSettings() async {
    if (!PlatformUtils.isAndroid) return false;

    try {
      final opened = await _permissionsChannel
          .invokeMethod<bool>('openBatteryOptimizationSettings');
      return opened ?? false;
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Failed to open battery optimization settings: $e',
        component: 'PlatformSettingsProvider',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Query device manufacturer from native layer.
  Future<String?> getDeviceManufacturer() async {
    if (!PlatformUtils.isAndroid) return null;
    if (_deviceManufacturer != null) return _deviceManufacturer;
    try {
      final m = await _permissionsChannel
          .invokeMethod<String>('getDeviceManufacturer');
      _deviceManufacturer = m;
      notifyListeners();
      return m;
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Failed to get device manufacturer: $e',
        component: 'PlatformSettingsProvider',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Launch OEM autostart / battery management activity.
  Future<bool> openOemAutostartSettings() async {
    if (!PlatformUtils.isAndroid) return false;
    try {
      final opened = await _permissionsChannel
          .invokeMethod<bool>('openOemAutostartSettings');
      return opened ?? false;
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Failed to open OEM autostart settings: $e',
        component: 'PlatformSettingsProvider',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
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
  bool get enableAnimations => settings.enableAnimations;

  bool get enableNotifications => settings.enableNotifications;
  bool get autoCheckUpdates => settings.autoCheckUpdates;
  bool get sponsorBlockEnabled => settings.sponsorBlockEnabled;
  bool get useDownloadArchive => settings.useDownloadArchive;
  bool get onboardingComplete => settings.onboardingComplete;
  bool get ytdlpAutoUpdated => settings.ytdlpAutoUpdated;

  // New Setters
  Future<void> setIsYtdlpManaged(bool value) async {
    await _settingsService.setIsYtdlpManaged(value);
    notifyListeners();
  }

  Future<void> setMaxConcurrentDownloads(int value) async {
    if (settings.maxConcurrentDownloads == value) return;
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

  Future<void> setEnableAnimations(bool value) async {
    await _settingsService.setEnableAnimations(value);
    notifyListeners();
  }

  Future<void> setEnableNotifications(bool value) async {
    await _settingsService.setEnableNotifications(value);
    // Propagate to the notification service so system toasts respect the toggle.
    try {
      NotificationService().systemNotificationsEnabled = value;
    } catch (_) {}
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

  Future<void> setOnboardingComplete(bool value) async {
    await _settingsService.setOnboardingComplete(value);
    notifyListeners();
  }

  Future<void> setYtdlpAutoUpdated(bool value) async {
    await _settingsService.setYtdlpAutoUpdated(value);
    notifyListeners();
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
