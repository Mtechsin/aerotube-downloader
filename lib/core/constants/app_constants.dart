class AppConstants {
  // ── GitHub API & App Self-Update ─────────────────────────────────────────
  static const String appRepoOwner = 'Amadoson3001';
  static const String appRepoName = 'aerotube-downloader';
  static const String githubApiBaseUrl = 'https://api.github.com/repos';
  static const String appLatestReleaseApiUrl =
      '$githubApiBaseUrl/$appRepoOwner/$appRepoName/releases/latest';

  // ── yt-dlp URLs ───────────────────────────────────────────────────────────
  static const String ytdlpRepoOwner = 'yt-dlp';
  static const String ytdlpRepoName = 'yt-dlp';
  static const String ytdlpLatestReleaseApiUrl =
      '$githubApiBaseUrl/$ytdlpRepoOwner/$ytdlpRepoName/releases/latest';
  static const String ytdlpWindowsDownloadUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';
  static const String ytdlpLinuxDownloadUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp';
  static const String ytdlpMacosDownloadUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos';
  static const String ytdlpAndroidDownloadUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp';

  // ── FFmpeg URLs ───────────────────────────────────────────────────────────
  static const String ffmpegGyanDReleaseApiUrl =
      'https://api.github.com/repos/GyanD/codexffmpeg/releases/latest';
  static const String ffmpegGyanDDownloadUrl =
      'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';
  static const String ffmpegGyanDWebsiteUrl =
      'https://www.gyan.dev/ffmpeg/builds/';
  static const String ffmpegBtbnDownloadUrl =
      'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip';

  // ── Android ABI self-update ──────────────────────────────────────────────
  /// ABIs we produce split APKs for (must match build.gradle.kts splits block).
  static const List<String> supportedAbis = [
    'arm64-v8a',
    'armeabi-v7a',
    'x86_64',
  ];

  /// Pattern used when naming release assets on GitHub.
  /// Placeholders: {name} = app name, {version} = semver, {abi} = ABI string.
  /// Example: AeroTube-v1.2.0-arm64-v8a-release.apk
  static const String apkAssetPattern = '{name}-v{version}-{abi}-release.apk';

  /// Universal (fat) APK asset name pattern – fallback when no ABI match.
  static const String universalApkPattern =
      '{name}-v{version}-universal-release.apk';

  static const String downloadsHistoryBox = 'downloads_history';
  static const String activeDownloadsBox = 'active_downloads';
  static const String mobileDownloadsHistoryBox = 'downloads_history_mobile';
  static const String mobileActiveDownloadsBox = 'active_downloads_mobile';

  // ── SharedPreferences Preference Keys ──────────────────────────────────
  static const String prefYtdlpPath = 'ytdlp_path';
  static const String prefFfmpegPath = 'ffmpeg_path';
  static const String prefIsYtdlpManaged = 'is_ytdlp_managed';
  static const String prefOutputPath = 'output_path';
  static const String prefMaxConcurrentDownloads = 'max_concurrent_downloads';
  static const String prefDefaultQuality = 'default_quality';
  static const String prefEmbedThumbnail = 'embed_thumbnail';
  static const String prefEmbedMetadata = 'embed_metadata';
  static const String prefAutoMergeStreams = 'auto_merge_streams';
  static const String prefDefaultSubtitleLanguage = 'default_subtitle_language';
  static const String prefThemeMode = 'theme_mode';
  static const String prefAccentColor = 'accent_color';
  static const String prefEnableAnimations = 'enable_animations';
  static const String prefEnableCookies = 'enable_cookies';
  static const String prefCookiePath = 'cookie_path';
  static const String prefCookieBrowser = 'cookie_browser';
  static const String prefYoutubeProfileImageUrl = 'youtube_profile_image_url';
  static const String prefEnableNotifications = 'enable_notifications';
  static const String prefAutoCheckUpdates = 'auto_check_updates';
  static const String prefSponsorBlockEnabled = 'sponsor_block_enabled';
  static const String prefUseDownloadArchive = 'use_download_archive';
  static const String prefEnableLogging = 'enable_logging';
  static const String prefSanitizeUrls = 'sanitize_urls';
  static const String prefOnboardingComplete = 'onboarding_complete';
  static const String prefYtdlpAutoUpdated = 'ytdlp_auto_updated';

  // ── Auth / Session Preference Keys ────────────────────────────────────
  static const String prefAuthTokenExpiry = 'youtube_token_expiry';
  static const String prefAuthIsLoggedIn = 'youtube_is_logged_in';
}
