class FfmpegUpdateInfo {
  final String currentVersion;
  final String? latestVersion;
  final String? downloadUrl;
  final DateTime? publishedAt;
  final String releaseNotes;

  FfmpegUpdateInfo({
    required this.currentVersion,
    this.latestVersion,
    this.downloadUrl,
    this.publishedAt,
    required this.releaseNotes,
  });
}

abstract class FfmpegToolService {
  String? get ffmpegPath;
  set ffmpegPath(String? path);
  bool get isAvailable;
  Future<void> initialize({bool force = false});
  Future<String?> getVersion();
  Future<FfmpegUpdateInfo?> checkForUpdate();
  Future<bool> update({
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
    bool Function()? isCancelled,
  });
  Future<bool> downloadAndInstall({
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
    bool Function()? isCancelled,
  });
}
