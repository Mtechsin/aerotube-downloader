import 'logging_service.dart';

/// Android-specific FFmpeg service
/// FFmpeg is bundled with youtubedl-android library, no separate installation needed
class FfmpegServiceAndroid {
  bool _isInitialized = false;
  String? _ffmpegVersion;
  final LoggingService _logger = LoggingService();

  /// Initialize FFmpeg - with youtubedl-android, FFmpeg is bundled
  Future<void> initialize({bool force = false}) async {
    if (_isInitialized && !force) return;

    try {
      // FFmpeg is bundled with youtubedl-android library
      // Just mark as initialized - the actual FFmpeg is managed by the library
      _isInitialized = true;
      _ffmpegVersion = 'Bundled with youtubedl-android';

      _logger.info(
        'FFmpeg initialized (bundled with youtubedl-android)',
        component: 'FfmpegServiceAndroid',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize FFmpeg',
        component: 'FfmpegServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      throw FfmpegAndroidException('Failed to initialize FFmpeg: $e');
    }
  }

  /// Get FFmpeg version
  String? get version => _ffmpegVersion;
  Future<String?> getVersion() async => _ffmpegVersion;

  /// Android uses bundled FFmpeg from youtubedl-android, so there is no external binary path.
  String? get ffmpegPath => null;
  set ffmpegPath(String? _) {}

  /// Check if FFmpeg is available
  bool get isAvailable => _isInitialized;

  /// Merge video and audio streams
  /// Note: With youtubedl-android, merging is handled by yt-dlp internally
  Future<bool> mergeVideoAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    bool copyCodecs = true,
    Map<String, String>? extraOptions,
    Function(double progress)? onProgress,
    Function(String log)? onLog,
  }) async {
    try {
      // With youtubedl-android, this should be handled by yt-dlp's internal FFmpeg
      // This method is kept for compatibility but merging should be done via yt-dlp
      _logger.info(
        'Video/audio merging should be handled by yt-dlp internally',
        component: 'FfmpegServiceAndroid',
      );
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to merge video and audio',
        component: 'FfmpegServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Convert video to different format
  /// Note: With youtubedl-android, conversion is handled by yt-dlp
  Future<bool> convertVideo({
    required String inputPath,
    required String outputPath,
    String? videoCodec,
    String? audioCodec,
    String? container,
    int? bitrate,
    int? targetHeight,
    Function(double progress)? onProgress,
    Function(String log)? onLog,
  }) async {
    try {
      _logger.info(
        'Video conversion should be handled by yt-dlp internally',
        component: 'FfmpegServiceAndroid',
      );
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to convert video',
        component: 'FfmpegServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Check for FFmpeg updates
  /// Note: On Android, FFmpeg is bundled and updated with the library
  Future<FfmpegAndroidUpdateInfo?> checkForUpdate() async {
    return null;
  }

  /// Update FFmpeg
  /// Note: On Android, FFmpeg is bundled and updated with the library
  Future<bool> update({
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    _logger.info(
      'FFmpeg is updated automatically with the library on Android',
      component: 'FfmpegServiceAndroid',
    );
    return false;
  }

  /// Download and install FFmpeg
  /// Note: On Android, FFmpeg is bundled and updated with the library
  Future<bool> downloadAndInstall({
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
  }) async {
    _logger.info(
      'FFmpeg is updated automatically with the library on Android',
      component: 'FfmpegServiceAndroid',
    );
    return false;
  }
}

class FfmpegAndroidUpdateInfo {
  final String currentVersion;
  final String? latestVersion;
  
  FfmpegAndroidUpdateInfo({
    required this.currentVersion,
    this.latestVersion,
  });
}

class FfmpegAndroidException implements Exception {
  final String message;
  FfmpegAndroidException(this.message);
  @override
  String toString() => 'FfmpegAndroidException: $message';
}
