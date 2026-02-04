import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'logging_service.dart';

/// FFmpeg update information
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

class FfmpegService {
  String? _ffmpegPath;
  bool isAvailable = false;
  String? _currentVersion;

  FfmpegService({String? ffmpegPath}) : _ffmpegPath = ffmpegPath;

  set ffmpegPath(String? path) {
    _ffmpegPath = path;
    // Potentially re-check availability if path changes
  }

  String? get ffmpegPath => _ffmpegPath;
  String? get currentVersion => _currentVersion;

  Future<void> initialize() async {
    // If path is not set, check for local managed version first
    if (_ffmpegPath == null) {
      try {
        final appDir = await getApplicationSupportDirectory();
        final executableName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
        final localPath = p.join(appDir.path, 'ffmpeg', executableName);
        if (await File(localPath).exists()) {
          _ffmpegPath = localPath;
        }
      } catch (e) {
        // Ignore errors during directory lookup
      }
    }
    
    // Check if ffmpeg is available at path or in system
    await _checkAvailability();
  }

  Future<bool> update() async {
    final logger = LoggingService();
    logger.info('Updating FFmpeg...', component: 'FfmpegService');

    try {
      // Check for updates first
      final updateInfo = await checkForUpdate();
      
      if (updateInfo == null || updateInfo.latestVersion == null) {
        logger.info('No FFmpeg updates available', component: 'FfmpegService');
        return false;
      }

      // If we have a latest version and it's different from current, download it
      if (updateInfo.latestVersion != null && 
          (currentVersion == null || updateInfo.latestVersion != currentVersion)) {
        
        logger.info('Downloading FFmpeg update from ${updateInfo.latestVersion}', component: 'FfmpegService');
        
        // Use the existing download method
        final success = await downloadAndInstall(
          onProgress: (progress) {
            logger.info('FFmpeg download progress: ${(progress * 100).toStringAsFixed(1)}%', component: 'FfmpegService');
          },
          onStatus: (status) {
            logger.info('FFmpeg status: $status', component: 'FfmpegService');
          }
        );
        
        return success;
      }
      
      return false;
    } catch (e, stackTrace) {
      logger.error(
        'Failed to update FFmpeg',
        component: 'FfmpegService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _checkAvailability() async {
    try {
      final path = _ffmpegPath ?? 'ffmpeg';
      var result = await Process.run(path, ['-version']);
      
      if (result.exitCode != 0 && Platform.isWindows && !path.toLowerCase().endsWith('.exe')) {
        result = await Process.run('$path.exe', ['-version']);
        if (result.exitCode == 0) {
          isAvailable = true;
          if (_ffmpegPath != null) _ffmpegPath = '$_ffmpegPath.exe';
        } else {
          isAvailable = false;
        }
      } else {
        isAvailable = result.exitCode == 0;
      }

      if (isAvailable) {
        // Parse version from first line
        final output = result.stdout.toString();
        final firstLine = output.split('\n').firstOrNull;
        if (firstLine != null) {
          // Extract version number (e.g., "ffmpeg version 6.0-full_build-www.gyan.dev" -> "6.0-full_build-www.gyan.dev")
          final versionMatch = RegExp(r'version\s+(\S+)').firstMatch(firstLine);
          _currentVersion = versionMatch?.group(1) ?? firstLine;
        }
      }
    } catch (e) {
      // If error is "file not found" and we are on Windows, try with .exe
      if (Platform.isWindows) {
        final path = _ffmpegPath ?? 'ffmpeg';
        if (!path.toLowerCase().endsWith('.exe')) {
          try {
            final result = await Process.run('$path.exe', ['-version']);
            if (result.exitCode == 0) {
              isAvailable = true;
              if (_ffmpegPath != null) _ffmpegPath = '$_ffmpegPath.exe';
              
              final output = result.stdout.toString();
              final firstLine = output.split('\n').firstOrNull;
              if (firstLine != null) {
                final versionMatch = RegExp(r'version\s+(\S+)').firstMatch(firstLine);
                _currentVersion = versionMatch?.group(1) ?? firstLine;
              }
              return;
            }
          } catch (_) {}
        }
      }
      isAvailable = false;
    }
  }

  Future<String?> getVersion() async {
    if (!isAvailable) return null;
    return _currentVersion;
  }

  /// Check for FFmpeg updates
  /// Note: FFmpeg doesn't have a simple API for latest version checks
  /// This checks the Gyan.dev builds page for Windows builds
  Future<FfmpegUpdateInfo?> checkForUpdate() async {
    final logger = LoggingService();
    logger.info('Checking for FFmpeg updates...', component: 'FfmpegService');

    try {
      // Check the GitHub releases API for FFmpeg builds
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/GyanD/codexffmpeg/releases/latest',
        ),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'] as String?;
        final publishedAt = data['published_at'] != null 
            ? DateTime.parse(data['published_at'] as String) 
            : null;
        
        // Get download URL for Windows essentials build
        final downloadUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';

        logger.info(
          'FFmpeg update check completed: current=$currentVersion, latest=$latestVersion',
          component: 'FfmpegService',
        );

        return FfmpegUpdateInfo(
          currentVersion: _currentVersion ?? 'Unknown',
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          publishedAt: publishedAt,
          releaseNotes: data['body'] as String? ?? 'New FFmpeg release available',
        );
      }

      return null;
    } catch (e, stackTrace) {
      logger.error(
        'Failed to check for FFmpeg updates',
        component: 'FfmpegService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Download and install FFmpeg with progress
  /// Note: FFmpeg is distributed as a ZIP file that needs extraction
  Future<bool> downloadAndInstall({
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
  }) async {
    final logger = LoggingService();

    try {
      onStatus('Downloading FFmpeg...');
      logger.info('Starting FFmpeg download', component: 'FfmpegService');

      // FFmpeg download URL from Gyan.dev (essentials build - smaller size)
      // Using the essentials build which is smaller and sufficient for most use cases
      const downloadUrl =
          'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (contentLength > 0) {
          onProgress(bytes.length / contentLength);
        }
      }

      onStatus('Extracting FFmpeg...');
      logger.info(
        'Download complete, extracting FFmpeg',
        component: 'FfmpegService',
      );

      // Get app directory
      final appDir = await getApplicationSupportDirectory();
      final ffmpegDir = Directory(p.join(appDir.path, 'ffmpeg'));

      if (!await ffmpegDir.exists()) {
        await ffmpegDir.create(recursive: true);
      }

      // Extract ZIP
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          // Only extract ffmpeg.exe and ffprobe.exe from the bin folder
          if (filename.contains('bin/ffmpeg.exe') ||
              filename.contains('bin/ffprobe.exe')) {
            final data = file.content as List<int>;
            final outFile = File(p.join(ffmpegDir.path, p.basename(filename)));
            await outFile.writeAsBytes(data);
          }
        }
      }

      // Update path
      final ffmpegExe = File(p.join(ffmpegDir.path, 'ffmpeg.exe'));
      if (await ffmpegExe.exists()) {
        _ffmpegPath = ffmpegExe.path;
        await _checkAvailability();

        onStatus('FFmpeg installed successfully!');
        logger.info(
          'FFmpeg installed successfully at ${_ffmpegPath}',
          component: 'FfmpegService',
        );
        return true;
      } else {
        throw Exception('FFmpeg executable not found after extraction');
      }
    } catch (e, stackTrace) {
      logger.error(
        'FFmpeg download/install failed',
        component: 'FfmpegService',
        error: e,
        stackTrace: stackTrace,
      );
      onStatus('Installation failed: $e');
      return false;
    }
  }
}
