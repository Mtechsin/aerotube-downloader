import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const String keyYtdlpPath = 'ytdlp_path';
  static const String keyFfmpegPath = 'ffmpeg_path';
  static const String keyIsYtdlpManaged = 'is_ytdlp_managed';
  static const String keyOutputPath = 'output_path';
  static const String keyMaxConcurrentDownloads = 'max_concurrent_downloads';
  static const String keyDefaultQuality = 'default_quality';
  static const String keyEmbedThumbnail = 'embed_thumbnail';
  static const String keyEmbedMetadata = 'embed_metadata';
  static const String keyAutoMergeStreams = 'auto_merge_streams';
  static const String keyThemeMode = 'theme_mode';
  static const String keyAccentColor = 'accent_color';
  static const String keyEnableCookies = 'enable_cookies';
  static const String keyCookiePath = 'cookie_path';
  static const String keyCookieBrowser = 'cookie_browser';
  static const String keyEnableNotifications = 'enable_notifications';
  static const String keyAutoCheckUpdates = 'auto_check_updates';
  static const String keySponsorBlockEnabled = 'sponsor_block_enabled';
  static const String keyUseDownloadArchive = 'use_download_archive';

  late SharedPreferences _prefs;
  AppSettings _settings = AppSettings();

  AppSettings get settings => _settings;

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
      
      themeMode: ThemeMode.values[(_readInt(keyThemeMode) ?? ThemeMode.system.index).clamp(0, ThemeMode.values.length - 1)],
      accentColorValue: _readInt(keyAccentColor),
      
      enableCookies: _readBool(keyEnableCookies) ?? false,
      cookiePath: _readString(keyCookiePath),
      cookieBrowser: _readString(keyCookieBrowser),
      
      enableNotifications: _readBool(keyEnableNotifications) ?? false,
      autoCheckUpdates: _readBool(keyAutoCheckUpdates) ?? true,
      sponsorBlockEnabled: _readBool(keySponsorBlockEnabled) ?? false,
      useDownloadArchive: _readBool(keyUseDownloadArchive) ?? false,
    );
  }

  String? _readString(String key) {
    final val = _prefs.get(key);
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

  Future<void> _saveSettings() async {
    await _prefs.setString(keyYtdlpPath, _settings.ytdlpPath ?? '');
    await _prefs.setString(keyFfmpegPath, _settings.ffmpegPath ?? '');
    await _prefs.setBool(keyIsYtdlpManaged, _settings.isYtdlpManaged);
    
    await _prefs.setString(keyOutputPath, _settings.outputPath ?? '');
    await _prefs.setInt(keyMaxConcurrentDownloads, _settings.maxConcurrentDownloads);
    await _prefs.setString(keyDefaultQuality, _settings.defaultQuality);
    await _prefs.setBool(keyEmbedThumbnail, _settings.embedThumbnail);
    await _prefs.setBool(keyEmbedMetadata, _settings.embedMetadata);
    await _prefs.setBool(keyAutoMergeStreams, _settings.autoMergeStreams);
    
    await _prefs.setInt(keyThemeMode, _settings.themeMode.index);
    if (_settings.accentColorValue != null) {
      await _prefs.setInt(keyAccentColor, _settings.accentColorValue!);
    } else {
      await _prefs.remove(keyAccentColor);
    }
    
    await _prefs.setBool(keyEnableCookies, _settings.enableCookies);
    await _prefs.setString(keyCookiePath, _settings.cookiePath ?? '');
    await _prefs.setString(keyCookieBrowser, _settings.cookieBrowser ?? '');
    
    await _prefs.setBool(keyEnableNotifications, _settings.enableNotifications);
    await _prefs.setBool(keyAutoCheckUpdates, _settings.autoCheckUpdates);
    await _prefs.setBool(keySponsorBlockEnabled, _settings.sponsorBlockEnabled);
    await _prefs.setBool(keyUseDownloadArchive, _settings.useDownloadArchive);
  }

  // Setters that update state and persist
  Future<void> setYtdlpPath(String? path) async {
    _settings = _settings.copyWith(ytdlpPath: path);
    if (path == null) {
      await _prefs.remove(keyYtdlpPath);
    } else {
      await _prefs.setString(keyYtdlpPath, path);
    }
  }

  Future<void> setFfmpegPath(String? path) async {
    _settings = _settings.copyWith(ffmpegPath: path);
    if (path == null) {
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
    if (path == null) {
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

  Future<void> setEnableCookies(bool value) async {
    _settings = _settings.copyWith(enableCookies: value);
    await _prefs.setBool(keyEnableCookies, value);
  }

  Future<void> setCookiePath(String? path) async {
    _settings = _settings.copyWith(cookiePath: path);
    if (path == null) {
        await _prefs.remove(keyCookiePath);
    } else {
        await _prefs.setString(keyCookiePath, path);
    }
  }

  Future<void> setCookieBrowser(String? browser) async {
    _settings = _settings.copyWith(cookieBrowser: browser);
    if (browser == null) {
        await _prefs.remove(keyCookieBrowser);
    } else {
        await _prefs.setString(keyCookieBrowser, browser);
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
}
