import 'dart:io';

class FfmpegService {
  String? _ffmpegPath;
  bool isAvailable = false;

  FfmpegService({String? ffmpegPath}) : _ffmpegPath = ffmpegPath;

  set ffmpegPath(String? path) {
    _ffmpegPath = path;
    // Potentially re-check availability if path changes
  }
  
  String? get ffmpegPath => _ffmpegPath;

  Future<void> initialize() async {
    // Check if ffmpeg is available at path or in system
    await _checkAvailability();
  }
  
  Future<void> update() async {
     // TODO: Implement ffmpeg update logic if needed
     await _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    try {
      final path = _ffmpegPath ?? 'ffmpeg';
      final result = await Process.run(path, ['-version']);
      isAvailable = result.exitCode == 0;
    } catch (e) {
      isAvailable = false;
    }
  }

  Future<String?> getVersion() async {
    if (!isAvailable) return null;
    try {
      final path = _ffmpegPath ?? 'ffmpeg';
      final result = await Process.run(path, ['-version']);
      if (result.exitCode == 0) {
        // Parse first line
        final output = result.stdout.toString();
        return output.split('\n').firstOrNull ?? 'Unknown';
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
