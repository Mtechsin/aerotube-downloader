import 'package:flutter/material.dart';

// part 'app_settings.g.dart'; // We will need to generate this or remove Hive for now

class AppSettings {
  // Tools
  final String? ytdlpPath;
  final String? ffmpegPath;
  final bool isYtdlpManaged;

  // Download Preferences
  final String? outputPath;
  final int maxConcurrentDownloads;
  final String
  defaultQuality; // "Best", "4K", "1080p", "720p", "480p", "Audio Only"
  final bool embedThumbnail;
  final bool embedMetadata;
  final bool autoMergeStreams;
  final String defaultSubtitleLanguage;

  // Appearance
  final ThemeMode themeMode;
  final int? accentColorValue; // Stored as int for easy persistence

  // Authentication
  final bool enableCookies;
  final String? cookiePath;
  final String? cookieBrowser;
  final String? youtubeProfileImageUrl;

  // Advanced
  final bool enableNotifications;
  final bool autoCheckUpdates;
  final bool sponsorBlockEnabled;
  final bool useDownloadArchive;

  // Constructor with defaults
  AppSettings({
    this.ytdlpPath,
    this.ffmpegPath,
    this.isYtdlpManaged = true,

    this.outputPath,
    this.maxConcurrentDownloads = 3,
    this.defaultQuality = 'Best',
    this.embedThumbnail = true,
    this.embedMetadata = true,
    this.autoMergeStreams = true,
    this.defaultSubtitleLanguage = 'auto',

    this.themeMode = ThemeMode.system,
    this.accentColorValue,

    this.enableCookies = false,
    this.cookiePath,
    this.cookieBrowser,
    this.youtubeProfileImageUrl,

    this.enableNotifications = false,
    this.autoCheckUpdates = true,
    this.sponsorBlockEnabled = false,
    this.useDownloadArchive = false,
  });

  // CopyWith for easy updates
  AppSettings copyWith({
    String? ytdlpPath,
    String? ffmpegPath,
    bool? isYtdlpManaged,
    String? outputPath,
    int? maxConcurrentDownloads,
    String? defaultQuality,
    bool? embedThumbnail,
    bool? embedMetadata,
    bool? autoMergeStreams,
    String? defaultSubtitleLanguage,
    ThemeMode? themeMode,
    int? accentColorValue,
    bool? enableCookies,
    String? cookiePath,
    String? cookieBrowser,
    String? youtubeProfileImageUrl,
    bool? enableNotifications,
    bool? autoCheckUpdates,
    bool? sponsorBlockEnabled,
    bool? useDownloadArchive,
  }) {
    return AppSettings(
      ytdlpPath: ytdlpPath ?? this.ytdlpPath,
      ffmpegPath: ffmpegPath ?? this.ffmpegPath,
      isYtdlpManaged: isYtdlpManaged ?? this.isYtdlpManaged,
      outputPath: outputPath ?? this.outputPath,
      maxConcurrentDownloads:
          maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      embedThumbnail: embedThumbnail ?? this.embedThumbnail,
      embedMetadata: embedMetadata ?? this.embedMetadata,
      autoMergeStreams: autoMergeStreams ?? this.autoMergeStreams,
      defaultSubtitleLanguage:
          defaultSubtitleLanguage ?? this.defaultSubtitleLanguage,
      themeMode: themeMode ?? this.themeMode,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      enableCookies: enableCookies ?? this.enableCookies,
      cookiePath: cookiePath ?? this.cookiePath,
      cookieBrowser: cookieBrowser ?? this.cookieBrowser,
      youtubeProfileImageUrl:
          youtubeProfileImageUrl ?? this.youtubeProfileImageUrl,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      autoCheckUpdates: autoCheckUpdates ?? this.autoCheckUpdates,
      sponsorBlockEnabled: sponsorBlockEnabled ?? this.sponsorBlockEnabled,
      useDownloadArchive: useDownloadArchive ?? this.useDownloadArchive,
    );
  }
}
