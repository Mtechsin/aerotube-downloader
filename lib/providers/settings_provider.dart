import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/ytdlp_service.dart';
import '../services/ffmpeg_service.dart';
import '../services/cookie_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService;
  final YtdlpService _ytdlpService;
  final FfmpegService _ffmpegService;
  final CookieService _cookieService;
  
  bool _isInitialized = false;
  bool _isYtdlpAvailable = false;
  bool _isFfmpegAvailable = false;
  String? _ytdlpVersion;
  String? _ffmpegVersion;
  DateTime? _cookieFileLastModified;
  String? _cookieFileName;
  bool _isYouTubeLoggedIn = false;
  DateTime? _youTubeLoginTime;

  SettingsProvider({
    required SettingsService settingsService,
    required YtdlpService ytdlpService,
    required FfmpegService ffmpegService,
    required CookieService cookieService,
  })  : _settingsService = settingsService,
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
  String? get activeFfmpegPath => _ffmpegService.ffmpegPath;
  ThemeMode get themeMode => settings.themeMode;
  DateTime? get cookieFileLastModified => _cookieFileLastModified;
  String? get cookieFileName => _cookieFileName;
  bool get isYouTubeLoggedIn => _isYouTubeLoggedIn;
  DateTime? get youTubeLoginTime => _youTubeLoginTime;
  CookieService get cookieService => _cookieService;
  YtdlpService get ytdlpService => _ytdlpService;
  bool get enableCookies => settings.enableCookies;

  String get cookieStatus {
    if (_isYouTubeLoggedIn) {
       // Ideally we should track if it's "valid" or "partial" here too, 
       // but for now let's just indicate the source clearly.
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

  bool get isCookieActive => settings.enableCookies && 
                            (_isYouTubeLoggedIn || 
                            (settings.cookieBrowser != null && settings.cookieBrowser != 'none') || 
                            settings.cookiePath != null);

  Future<void> init() async {
    await _settingsService.init();
    
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

    // Initialize tools (download if needed)
    // We do this concurrently to save time
    await Future.wait([
      _ytdlpService.initialize(),
      _ffmpegService.initialize(),
    ]);

    // Check tool availability
    await checkToolsAvailability();
    
    // Ensure ytdlp knows about ffmpeg if we auto-detected it
    if (_isFfmpegAvailable && settings.ffmpegPath == null) {
      _ytdlpService.ffmpegPath = _ffmpegService.ffmpegPath;
    }
    
    // Check YouTube login status
    await checkYouTubeLoginStatus();
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Check if user is logged into YouTube via WebView cookies
  Future<void> checkYouTubeLoginStatus() async {
    _isYouTubeLoggedIn = await _cookieService.isLoggedIn;
    _youTubeLoginTime = await _cookieService.lastLoginTime;
    
    // If logged in via WebView, configure ytdlp to use the WebView profile directly
    // This is because HttpOnly cookies (like SAPISID) cannot be extracted via JavaScript
    if (_isYouTubeLoggedIn) {
      final webViewPath = await _cookieService.webViewPath;
      _ytdlpService.webViewPath = webViewPath;
      _ytdlpService.userAgent = await _cookieService.userAgent;
      // Clear other cookie methods to ensure WebView takes precedence
      _ytdlpService.cookiePath = null;
      _ytdlpService.cookieBrowser = null;
      
      print('[SettingsProvider] YouTube WebView login detected');
      print('[SettingsProvider] WebView profile path: $webViewPath');
      print('[SettingsProvider] yt-dlp will use: --cookies-from-browser edge:$webViewPath');
    }
    
    notifyListeners();
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
    
    // Clear cookie path from ytdlp and settings if it was using the WebView cookies
    final cookiePath = await _cookieService.cookieFilePath;
    if (_ytdlpService.cookiePath == cookiePath) {
      _ytdlpService.cookiePath = null;
      _ytdlpService.userAgent = null;
      await _settingsService.setCookiePath(null);
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
    
    notifyListeners();
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
      _ytdlpService.initialize(force: true);
    }
    await checkToolsAvailability();
  }

  Future<void> setFfmpegPath(String? path) async {
    await _settingsService.setFfmpegPath(path);
    if (path != null) {
      _ffmpegService.ffmpegPath = path;
      _ytdlpService.ffmpegPath = path;
    } else {
      _ffmpegService.ffmpegPath = null;
      _ytdlpService.ffmpegPath = null;
    }
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
      _ytdlpService.cookieBrowser = null;
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
      print('Failed to get cookie file metadata: $e');
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
    await _settingsService.setEmbedMetadata(value);
    notifyListeners();
  }

  Future<void> setEnableCookies(bool value) async {
    await _settingsService.setEnableCookies(value);
    _ytdlpService.enableCookies = value;
    notifyListeners();
  }

  // Getters for new settings
  bool get isYtdlpManaged => settings.isYtdlpManaged;
  String? get outputPath => settings.outputPath;
  int get maxConcurrentDownloads => settings.maxConcurrentDownloads;
  String get defaultQuality => settings.defaultQuality;
  bool get embedThumbnail => settings.embedThumbnail;
  bool get embedMetadata => settings.embedMetadata;
  bool get autoMergeStreams => settings.autoMergeStreams;
  
  Color? get accentColor => settings.accentColorValue != null ? Color(settings.accentColorValue!) : null;
  
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
    // Potentially update ytdlp service if it has a related setting (it doesn't directly, handled in download logic)
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
  
  Future<void> setUseDownloadArchive(bool value) async {
    await _settingsService.setUseDownloadArchive(value);
    notifyListeners();
  }

  Future<bool> updateYtdlp() async {
    // Ensure we are initialized so we have a valid path (or download it if missing)
    await _ytdlpService.initialize();
    
    // Attempt update
    final success = await _ytdlpService.update();
    
    // Refresh version info
    await checkToolsAvailability();
    
    return success;
  }

  Future<bool> updateFfmpeg() async {
    // Ensure initialized
    await _ffmpegService.initialize();
    
    final success = await _ffmpegService.update();
    
    // Refresh version info
    await checkToolsAvailability();
    
    return success;
  }
  
  /// Helper to install tools if missing
  Future<bool> installYtdlp() async {
     await _ytdlpService.initialize(force: true); // This downloads it if missing
     await checkToolsAvailability();
     return _isYtdlpAvailable;
  }
  
  Future<bool> installFfmpeg() async {
     await _ffmpegService.initialize(); // This downloads/setups if implemented
     await checkToolsAvailability();
     return _isFfmpegAvailable;
  }
}
