import 'ffmpeg_service.dart';

/// Abstract interface for FFmpeg tool management.
/// Implemented by both [FfmpegService] (desktop) and [FfmpegServiceAndroid].
abstract class FfmpegToolService {
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
