class AppConstants {
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
}
