/// Unified update information for yt-dlp (shared across desktop and Android).
class YtdlpUpdateInfo {
  final String currentVersion;
  final String? latestVersion;
  final String? downloadUrl;
  final DateTime? publishedAt;
  final String? releaseNotes;

  YtdlpUpdateInfo({
    required this.currentVersion,
    this.latestVersion,
    this.downloadUrl,
    this.publishedAt,
    this.releaseNotes,
  });
}

/// Abstract interface for yt-dlp tool management.
/// Implemented by both [YtdlpService] (desktop) and [YtdlpServiceAndroid].
abstract class YtdlpToolService {
  String get ytdlpPath;
  set ytdlpPath(String path);
  String? get cookiePath;
  set cookiePath(String? path);
  String? get cookieBrowser;
  set cookieBrowser(String? browser);
  String? get webViewPath;
  set webViewPath(String? path);
  String? get ffmpegPath;
  set ffmpegPath(String? path);
  String? get userAgent;
  set userAgent(String? value);
  bool get enableCookies;
  set enableCookies(bool value);
  Future<void> initialize({bool force = false});
  Future<bool> isAvailable();
  Future<String?> getVersion();
  void markReady(String version);
  Future<String?> getLatestVersion({bool forceRefresh = false});
  Future<YtdlpUpdateInfo?> checkForUpdateWithProgress();
  Future<bool> downloadAndInstallUpdate(
    String downloadUrl, {
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
    bool Function()? isCancelled,
  });
  Future<bool> update();
  Future<void> cancelFetch();
}
