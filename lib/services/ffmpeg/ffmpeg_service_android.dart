import '../core/logging_service.dart';
import '../ytdlp/native_ytdlp_android.dart';
import 'ffmpeg_tool_service.dart';

/// Android-specific FFmpeg service.
///
/// FFmpeg is bundled inside the youtubedl-android library and is used
/// automatically by yt-dlp for merging (e.g. bestvideo+bestaudio). This
/// service does not shell out to a separate FFmpeg binary and does not
/// expose merge/convert APIs — those operations are yt-dlp's job.
class FfmpegServiceAndroid implements FfmpegToolService {
  bool _isInitialized = false;
  String? _ffmpegVersion;
  final LoggingService _logger = LoggingService();

  /// Initialize FFmpeg.
  ///
  /// Marks the service ready after a successful native version probe.
  /// A null version does not necessarily mean FFmpeg is unusable — yt-dlp
  /// may still merge via its bundled copy — but we never invent a fake
  /// version string.
  @override
  Future<void> initialize({bool force = false}) async {
    if (_isInitialized && !force) return;

    try {
      // Ask native for the real bundled FFmpeg version. May be null if the
      // native method is unavailable or the library does not expose it.
      _ffmpegVersion = await NativeYtdlpAndroid.getFfmpegVersion();
      _isInitialized = true;

      if (_ffmpegVersion != null) {
        _logger.info(
          'FFmpeg initialized (bundled with youtubedl-android): $_ffmpegVersion',
          component: 'FfmpegServiceAndroid',
        );
      } else {
        _logger.info(
          'FFmpeg marked available after init; native version string was '
          'null (yt-dlp may still use its bundled FFmpeg for merging)',
          component: 'FfmpegServiceAndroid',
        );
      }
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

  /// Real FFmpeg version from native, or null. Never a fake string.
  ///
  /// Native may return a bundled-library label such as "bundled-0.18.1"
  /// rather than an upstream ffmpeg version. Display it as-is; never parse
  /// it as a semantic ffmpeg version for update checks (checkForUpdate is
  /// intentionally a no-op on Android).
  String? get version => _ffmpegVersion;
  @override
  Future<String?> getVersion() async => _ffmpegVersion;

  @override
  String? get ffmpegPath => null;
  @override
  set ffmpegPath(String? _) {}

  /// True after [initialize] completes without throwing.
  ///
  /// A null [getVersion] does not flip this to false: yt-dlp can still
  /// merge streams with its bundled FFmpeg even when no version string
  /// is exposed to Dart.
  @override
  bool get isAvailable => _isInitialized;

  /// Check for FFmpeg updates.
  /// Bundled with youtubedl-android; there is no separate FFmpeg to update.
  @override
  Future<FfmpegUpdateInfo?> checkForUpdate() async {
    return null;
  }

  /// Update FFmpeg.
  /// Bundled with youtubedl-android; returns false because no independent
  /// update path exists.
  @override
  Future<bool> update({
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
    bool Function()? isCancelled,
  }) async {
    _logger.info(
      'FFmpeg is bundled with youtubedl-android; no independent update path',
      component: 'FfmpegServiceAndroid',
    );
    return false;
  }

  /// Download and install FFmpeg.
  /// Bundled with youtubedl-android; returns false because no independent
  /// install path exists.
  @override
  Future<bool> downloadAndInstall({
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
    bool Function()? isCancelled,
  }) async {
    _logger.info(
      'FFmpeg is bundled with youtubedl-android; no independent install path',
      component: 'FfmpegServiceAndroid',
    );
    return false;
  }
}

class FfmpegAndroidException implements Exception {
  final String message;
  FfmpegAndroidException(this.message);
  @override
  String toString() => 'FfmpegAndroidException: $message';
}
