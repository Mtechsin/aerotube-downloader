import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/app_settings.dart';

class SettingsService {
  static const String keyYtdlpPath = AppConstants.prefYtdlpPath;
  static const String keyFfmpegPath = AppConstants.prefFfmpegPath;
  static const String keyIsYtdlpManaged = AppConstants.prefIsYtdlpManaged;
  static const String keyOutputPath = AppConstants.prefOutputPath;
  static const String keyMaxConcurrentDownloads =
      AppConstants.prefMaxConcurrentDownloads;
  static const String keyDefaultQuality = AppConstants.prefDefaultQuality;
  static const String keyEmbedThumbnail = AppConstants.prefEmbedThumbnail;
  static const String keyEmbedMetadata = AppConstants.prefEmbedMetadata;
  static const String keyAutoMergeStreams = AppConstants.prefAutoMergeStreams;
  static const String keyDefaultSubtitleLanguage =
      AppConstants.prefDefaultSubtitleLanguage;
  static const String keyThemeMode = AppConstants.prefThemeMode;
  static const String keyAccentColor = AppConstants.prefAccentColor;
  static const String keyEnableAnimations = AppConstants.prefEnableAnimations;
  static const String keyEnableCookies = AppConstants.prefEnableCookies;
  static const String keyCookiePath = AppConstants.prefCookiePath;
  static const String keyCookieBrowser = AppConstants.prefCookieBrowser;
  static const String keyYoutubeProfileImageUrl =
      AppConstants.prefYoutubeProfileImageUrl;
  static const String keyEnableNotifications =
      AppConstants.prefEnableNotifications;
  static const String keyAutoCheckUpdates = AppConstants.prefAutoCheckUpdates;
  static const String keySponsorBlockEnabled =
      AppConstants.prefSponsorBlockEnabled;
  static const String keyUseDownloadArchive =
      AppConstants.prefUseDownloadArchive;
  static const String keyEnableLogging = AppConstants.prefEnableLogging;
  static const String keyOnboardingComplete =
      AppConstants.prefOnboardingComplete;
  static const String keyYtdlpAutoUpdated = AppConstants.prefYtdlpAutoUpdated;

  late SharedPreferences _prefs;
  AppSettings _settings = AppSettings();

  AppSettings get settings => _settings;

  // Individual getters for direct property access
  String? get ytdlpPath => _settings.ytdlpPath;
  String? get ffmpegPath => _settings.ffmpegPath;
  bool get isYtdlpManaged => _settings.isYtdlpManaged;
  String? get outputPath => _settings.outputPath;
  int get maxConcurrentDownloads => _settings.maxConcurrentDownloads;
  String get defaultQuality => _settings.defaultQuality;
  bool get embedThumbnail => _settings.embedThumbnail;
  bool get embedMetadata => _settings.embedMetadata;
  bool get autoMergeStreams => _settings.autoMergeStreams;
  String get defaultSubtitleLanguage => _settings.defaultSubtitleLanguage;
  ThemeMode get themeMode => _settings.themeMode;
  int? get accentColorValue => _settings.accentColorValue;
  bool get enableAnimations => _settings.enableAnimations;
  bool get enableCookies => _settings.enableCookies;
  String? get cookiePath => _settings.cookiePath;
  String? get cookieBrowser => _settings.cookieBrowser;
  String? get youtubeProfileImageUrl => _settings.youtubeProfileImageUrl;
  bool get enableNotifications => _settings.enableNotifications;
  bool get autoCheckUpdates => _settings.autoCheckUpdates;
  bool get sponsorBlockEnabled => _settings.sponsorBlockEnabled;
  bool get useDownloadArchive => _settings.useDownloadArchive;
  bool get enableLogging => _settings.enableLogging;
  bool get onboardingComplete => _settings.onboardingComplete;
  bool get ytdlpAutoUpdated => _settings.ytdlpAutoUpdated;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadSettings();
  }

  Future<void> loadSettings() async {
    _settings = AppSettings(
      ytdlpPath: _readString(keyYtdlpPath),
      ffmpegPath: _readString(keyFfmpegPath),
      isYtdlpManaged: _readBool(keyIsYtdlpManaged) ?? true,

      outputPath: _readString(keyOutputPath),
      maxConcurrentDownloads: _readInt(keyMaxConcurrentDownloads) ?? 3,
      defaultQuality: _readString(keyDefaultQuality) ?? 'Best',
      embedThumbnail: _readBool(keyEmbedThumbnail) ?? true,
      embedMetadata: _readBool(keyEmbedMetadata) ?? true,
      autoMergeStreams: _readBool(keyAutoMergeStreams) ?? true,
      defaultSubtitleLanguage:
          _readString(keyDefaultSubtitleLanguage) ?? 'auto',

      themeMode:
          ThemeMode.values[(_readInt(keyThemeMode) ?? ThemeMode.system.index)
              .clamp(0, ThemeMode.values.length - 1)],
      accentColorValue: _readInt(keyAccentColor),
      enableAnimations: _readBool(keyEnableAnimations) ?? true,

      enableCookies: _readBool(keyEnableCookies) ?? false,
      cookiePath: _readString(keyCookiePath),
      cookieBrowser: _readString(keyCookieBrowser),
      youtubeProfileImageUrl: _readString(keyYoutubeProfileImageUrl),

      enableNotifications: _readBool(keyEnableNotifications) ?? false,
      autoCheckUpdates: _readBool(keyAutoCheckUpdates) ?? true,
      sponsorBlockEnabled: _readBool(keySponsorBlockEnabled) ?? false,
      useDownloadArchive: _readBool(keyUseDownloadArchive) ?? false,
      enableLogging: _readBool(keyEnableLogging) ?? true,
      onboardingComplete: _readBool(keyOnboardingComplete) ?? false,
      ytdlpAutoUpdated: _readBool(keyYtdlpAutoUpdated) ?? false,
    );
  }

  String? _readString(String key) {
    final val = _prefs.get(key);
    if (val is String && val.isEmpty) return null;
    return val is String ? val : null;
  }

  bool? _readBool(String key) {
    final val = _prefs.get(key);
    return val is bool ? val : null;
  }

  int? _readInt(String key) {
    final val = _prefs.get(key);
    if (val is int) return val;
    if (val is double) return val.toInt();
    return null;
  }

  /// Bulk save settings to SharedPreferences and update in-memory state.
  Future<void> saveSettings([AppSettings? settingsToSave]) async {
    if (settingsToSave != null) {
      _settings = settingsToSave;
    }

    if (_settings.ytdlpPath != null && _settings.ytdlpPath!.isNotEmpty) {
      await _prefs.setString(keyYtdlpPath, _settings.ytdlpPath!);
    } else {
      await _prefs.remove(keyYtdlpPath);
    }

    if (_settings.ffmpegPath != null && _settings.ffmpegPath!.isNotEmpty) {
      await _prefs.setString(keyFfmpegPath, _settings.ffmpegPath!);
    } else {
      await _prefs.remove(keyFfmpegPath);
    }
    await _prefs.setBool(keyIsYtdlpManaged, _settings.isYtdlpManaged);

    if (_settings.outputPath != null && _settings.outputPath!.isNotEmpty) {
      await _prefs.setString(keyOutputPath, _settings.outputPath!);
    } else {
      await _prefs.remove(keyOutputPath);
    }

    await _prefs.setInt(
      keyMaxConcurrentDownloads,
      _settings.maxConcurrentDownloads,
    );
    await _prefs.setString(keyDefaultQuality, _settings.defaultQuality);
    await _prefs.setBool(keyEmbedThumbnail, _settings.embedThumbnail);
    await _prefs.setBool(keyEmbedMetadata, _settings.embedMetadata);
    await _prefs.setBool(keyAutoMergeStreams, _settings.autoMergeStreams);
    await _prefs.setString(
      keyDefaultSubtitleLanguage,
      _settings.defaultSubtitleLanguage,
    );

    await _prefs.setInt(keyThemeMode, _settings.themeMode.index);
    if (_settings.accentColorValue != null) {
      await _prefs.setInt(keyAccentColor, _settings.accentColorValue!);
    } else {
      await _prefs.remove(keyAccentColor);
    }
    await _prefs.setBool(keyEnableAnimations, _settings.enableAnimations);

    await _prefs.setBool(keyEnableCookies, _settings.enableCookies);
    if (_settings.cookiePath != null && _settings.cookiePath!.isNotEmpty) {
      await _prefs.setString(keyCookiePath, _settings.cookiePath!);
    } else {
      await _prefs.remove(keyCookiePath);
    }
    if (_settings.cookieBrowser != null && _settings.cookieBrowser!.isNotEmpty) {
      await _prefs.setString(keyCookieBrowser, _settings.cookieBrowser!);
    } else {
      await _prefs.remove(keyCookieBrowser);
    }
    if (_settings.youtubeProfileImageUrl != null &&
        _settings.youtubeProfileImageUrl!.isNotEmpty) {
      await _prefs.setString(
        keyYoutubeProfileImageUrl,
        _settings.youtubeProfileImageUrl!,
      );
    } else {
      await _prefs.remove(keyYoutubeProfileImageUrl);
    }

    await _prefs.setBool(keyEnableNotifications, _settings.enableNotifications);
    await _prefs.setBool(keyAutoCheckUpdates, _settings.autoCheckUpdates);
    await _prefs.setBool(keySponsorBlockEnabled, _settings.sponsorBlockEnabled);
    await _prefs.setBool(keyUseDownloadArchive, _settings.useDownloadArchive);
    await _prefs.setBool(keyEnableLogging, _settings.enableLogging);
    await _prefs.setBool(keyOnboardingComplete, _settings.onboardingComplete);
    await _prefs.setBool(keyYtdlpAutoUpdated, _settings.ytdlpAutoUpdated);
  }

  // Setters that update state and persist
  Future<void> setYtdlpPath(String? path) async {
    _settings = _settings.copyWith(ytdlpPath: path);
    if (path == null || path.isEmpty) {
      await _prefs.remove(keyYtdlpPath);
    } else {
      await _prefs.setString(keyYtdlpPath, path);
    }
  }

  Future<void> setFfmpegPath(String? path) async {
    _settings = _settings.copyWith(ffmpegPath: path);
    if (path == null || path.isEmpty) {
      await _prefs.remove(keyFfmpegPath);
    } else {
      await _prefs.setString(keyFfmpegPath, path);
    }
  }

  Future<void> setIsYtdlpManaged(bool value) async {
    _settings = _settings.copyWith(isYtdlpManaged: value);
    await _prefs.setBool(keyIsYtdlpManaged, value);
  }

  Future<void> setOutputPath(String? path) async {
    _settings = _settings.copyWith(outputPath: path);
    if (path == null || path.isEmpty) {
      await _prefs.remove(keyOutputPath);
    } else {
      await _prefs.setString(keyOutputPath, path);
    }
  }

  Future<void> setMaxConcurrentDownloads(int value) async {
    _settings = _settings.copyWith(maxConcurrentDownloads: value);
    await _prefs.setInt(keyMaxConcurrentDownloads, value);
  }

  Future<void> setDefaultQuality(String value) async {
    _settings = _settings.copyWith(defaultQuality: value);
    await _prefs.setString(keyDefaultQuality, value);
  }

  Future<void> setEmbedThumbnail(bool value) async {
    _settings = _settings.copyWith(embedThumbnail: value);
    await _prefs.setBool(keyEmbedThumbnail, value);
  }

  Future<void> setEmbedMetadata(bool value) async {
    _settings = _settings.copyWith(embedMetadata: value);
    await _prefs.setBool(keyEmbedMetadata, value);
  }

  Future<void> setAutoMergeStreams(bool value) async {
    _settings = _settings.copyWith(autoMergeStreams: value);
    await _prefs.setBool(keyAutoMergeStreams, value);
  }

  Future<void> setDefaultSubtitleLanguage(String value) async {
    _settings = _settings.copyWith(defaultSubtitleLanguage: value);
    await _prefs.setString(keyDefaultSubtitleLanguage, value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await _prefs.setInt(keyThemeMode, mode.index);
  }

  Future<void> setAccentColor(int? colorValue) async {
    _settings = _settings.copyWith(accentColorValue: colorValue);
    if (colorValue == null) {
      await _prefs.remove(keyAccentColor);
    } else {
      await _prefs.setInt(keyAccentColor, colorValue);
    }
  }

  Future<void> setEnableAnimations(bool value) async {
    _settings = _settings.copyWith(enableAnimations: value);
    await _prefs.setBool(keyEnableAnimations, value);
  }

  Future<void> setEnableCookies(bool value) async {
    _settings = _settings.copyWith(enableCookies: value);
    await _prefs.setBool(keyEnableCookies, value);
  }

  Future<void> setCookiePath(String? path) async {
    _settings = _settings.copyWith(cookiePath: path);
    if (path == null || path.isEmpty) {
      await _prefs.remove(keyCookiePath);
    } else {
      await _prefs.setString(keyCookiePath, path);
    }
  }

  Future<void> setCookieBrowser(String? browser) async {
    _settings = _settings.copyWith(cookieBrowser: browser);
    if (browser == null || browser.isEmpty) {
      await _prefs.remove(keyCookieBrowser);
    } else {
      await _prefs.setString(keyCookieBrowser, browser);
    }
  }

  Future<void> setYoutubeProfileImageUrl(String? url) async {
    _settings = _settings.copyWith(youtubeProfileImageUrl: url);
    if (url == null || url.isEmpty) {
      await _prefs.remove(keyYoutubeProfileImageUrl);
    } else {
      await _prefs.setString(keyYoutubeProfileImageUrl, url);
    }
  }

  Future<void> setEnableNotifications(bool value) async {
    _settings = _settings.copyWith(enableNotifications: value);
    await _prefs.setBool(keyEnableNotifications, value);
  }

  Future<void> setAutoCheckUpdates(bool value) async {
    _settings = _settings.copyWith(autoCheckUpdates: value);
    await _prefs.setBool(keyAutoCheckUpdates, value);
  }

  Future<void> setSponsorBlockEnabled(bool value) async {
    _settings = _settings.copyWith(sponsorBlockEnabled: value);
    await _prefs.setBool(keySponsorBlockEnabled, value);
  }

  Future<void> setUseDownloadArchive(bool value) async {
    _settings = _settings.copyWith(useDownloadArchive: value);
    await _prefs.setBool(keyUseDownloadArchive, value);
  }

  Future<void> setEnableLogging(bool value) async {
    _settings = _settings.copyWith(enableLogging: value);
    await _prefs.setBool(keyEnableLogging, value);
  }

  Future<void> setOnboardingComplete(bool value) async {
    _settings = _settings.copyWith(onboardingComplete: value);
    await _prefs.setBool(keyOnboardingComplete, value);
  }

  Future<void> setYtdlpAutoUpdated(bool value) async {
    _settings = _settings.copyWith(ytdlpAutoUpdated: value);
    await _prefs.setBool(keyYtdlpAutoUpdated, value);
  }
}
