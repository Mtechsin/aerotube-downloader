import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/utils/version_utils.dart';
import '../core/logging_service.dart';
import '../core/download_helper.dart';
import 'ffmpeg_tool_service.dart';

class FfmpegService implements FfmpegToolService {
  String? _ffmpegPath;
  bool _isAvailable = false;
  bool _isInitialized = false;
  String? _currentVersion;

  FfmpegService({String? ffmpegPath}) : _ffmpegPath = ffmpegPath;

  @override
  set ffmpegPath(String? path) {
    _ffmpegPath = path;
  }

  @override
  String? get ffmpegPath => _ffmpegPath;
  String? get currentVersion => _currentVersion;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<void> initialize({bool force = false}) async {
    if (_isInitialized && !force) return;

    // If path is not set, check for local managed version first
    if (_ffmpegPath == null) {
      try {
        final appDir = await getApplicationSupportDirectory();
        final executableName = PlatformUtils.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
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
    _isInitialized = true;
  }

  @override
  Future<bool> update({
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
    bool Function()? isCancelled,
  }) async {
    final logger = LoggingService();
    logger.info('Updating FFmpeg...', component: 'FfmpegService');

    try {
      // Check for updates first
      final updateInfo = await checkForUpdate();
      
      if (updateInfo == null || updateInfo.latestVersion == null) {
        logger.info('No FFmpeg updates available', component: 'FfmpegService');
        return false;
      }

      // If we have a latest version and it's newer than current, download it
      if (updateInfo.latestVersion != null &&
          VersionUtils.isNewerVersion(currentVersion, updateInfo.latestVersion)) {
        
        logger.info('Downloading FFmpeg update from ${updateInfo.latestVersion}', component: 'FfmpegService');
        
        // Use the existing download method
        final success = await downloadAndInstall(
          onProgress: onProgress ?? (progress) {
            logger.info('FFmpeg download progress: ${(progress * 100).toStringAsFixed(1)}%', component: 'FfmpegService');
          },
          onStatus: onStatus ?? (status) {
            logger.info('FFmpeg status: $status', component: 'FfmpegService');
          },
          isCancelled: isCancelled,
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
      
      if (result.exitCode != 0 && PlatformUtils.isWindows && !path.toLowerCase().endsWith('.exe')) {
        result = await Process.run('$path.exe', ['-version']);
        if (result.exitCode == 0) {
          _isAvailable = true;
          if (_ffmpegPath != null) _ffmpegPath = '$_ffmpegPath.exe';
        } else {
          _isAvailable = false;
        }
      } else {
        _isAvailable = result.exitCode == 0;
      }

      if (_isAvailable) {
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
      if (PlatformUtils.isWindows) {
        final path = _ffmpegPath ?? 'ffmpeg';
        if (!path.toLowerCase().endsWith('.exe')) {
          try {
            final result = await Process.run('$path.exe', ['-version']);
            if (result.exitCode == 0) {
              _isAvailable = true;
              if (_ffmpegPath != null) _ffmpegPath = '$_ffmpegPath.exe';
              
              final output = result.stdout.toString();
              final firstLine = output.split('\n').firstOrNull;
              if (firstLine != null) {
                final versionMatch = RegExp(r'version\s+(\S+)').firstMatch(firstLine);
                _currentVersion = versionMatch?.group(1) ?? firstLine;
              }
              return;
            }
          } catch (e) {
            LoggingService().warning('ffmpeg .exe fallback check failed: $e', component: 'FfmpegService');
          }
        }
      }
      _isAvailable = false;
    }
  }

  @override
  Future<String?> getVersion() async {
    if (!isAvailable) return null;
    return _currentVersion;
  }

  /// Check for FFmpeg updates
  /// Note: FFmpeg doesn't have a simple API for latest version checks
  /// This checks the Gyan.dev builds page for Windows builds
  @override
  Future<FfmpegUpdateInfo?> checkForUpdate() async {
    final logger = LoggingService();
    logger.info('Checking for FFmpeg updates...', component: 'FfmpegService');

    try {
      // Check the GitHub releases API for FFmpeg builds
      final response = await http.get(
        Uri.parse(AppConstants.ffmpegGyanDReleaseApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'] as String?;
        final publishedAt = data['published_at'] != null 
            ? DateTime.parse(data['published_at'] as String) 
            : null;
        
        // Get download URL for Windows essentials build
        final downloadUrl = AppConstants.ffmpegGyanDDownloadUrl;

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

  /// Download and install FFmpeg with progress.
  /// The download runs in a background isolate for full network throughput.
  /// Note: FFmpeg is distributed as a ZIP file that needs extraction.
  @override
  Future<bool> downloadAndInstall({
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
    bool Function()? isCancelled,
  }) async {
    final logger = LoggingService();
    File? tempZipFile;
    Directory? tempDirRef;

    try {
      onStatus('Downloading FFmpeg...');

      // BtbN GitHub CDN — fast global CDN, much faster than gyan.dev
      const downloadUrl = AppConstants.ffmpegBtbnDownloadUrl;

      // Use system temp with random suffix to avoid concurrent-install collisions (B11)
      tempDirRef = await Directory.systemTemp.createTemp('ffmpeg-update-');
      final randSuffix = Random().nextInt(0xFFFFFFFF).toRadixString(16);
      tempZipFile = File(
        p.join(tempDirRef.path, 'ffmpeg-update-${DateTime.now().millisecondsSinceEpoch}-$pid-$randSuffix.zip'),
      );

      await downloadInBackground(
        url: downloadUrl,
        destPath: tempZipFile.path,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      logger.info(
        'FFmpeg download complete',
        component: 'FfmpegService',
      );

      if (isCancelled?.call() == true) {
        onStatus('Installation cancelled');
        return false;
      }

      onStatus('Extracting FFmpeg...');
      logger.info('Download complete, extracting FFmpeg', component: 'FfmpegService');

      final appDir = await getApplicationSupportDirectory();
      final ffmpegDir = Directory(p.join(appDir.path, 'ffmpeg'));

      if (!await ffmpegDir.exists()) {
        await ffmpegDir.create(recursive: true);
      }

      // Stream-read zip from disk, avoid loading entire file into memory
      final inputStream = InputFileStream(tempZipFile.path);
      final archive = ZipDecoder().decodeStream(inputStream);

      for (final entry in archive) {
        if (isCancelled?.call() == true) {
          throw Exception('Cancelled');
        }
        final filename = entry.name;
        if (entry.isFile) {
          if (filename.contains('bin/ffmpeg.exe') ||
              filename.contains('bin/ffprobe.exe')) {
            final outFile = File(p.join(ffmpegDir.path, p.basename(filename)));
            if (await outFile.exists()) {
              await outFile.delete();
            }
            // Write decompressed entry directly to disk — no full file in RAM
            final output = OutputFileStream(outFile.path);
            entry.writeContent(output);
            await output.close();
          }
        }
      }
      await inputStream.close();

      final ffmpegExe = File(p.join(ffmpegDir.path, 'ffmpeg.exe'));
      if (await ffmpegExe.exists()) {
        _ffmpegPath = ffmpegExe.path;
        await _checkAvailability();

        onStatus('FFmpeg installed successfully!');
        logger.info(
          'FFmpeg installed successfully at $_ffmpegPath',
          component: 'FfmpegService',
        );
        return true;
      } else {
        throw Exception('FFmpeg executable not found after extraction');
      }
    } catch (e, stackTrace) {
      if (e.toString().contains('Cancelled')) {
        onStatus('Installation cancelled');
        return false;
      }
      logger.error(
        'FFmpeg download/install failed',
        component: 'FfmpegService',
        error: e,
        stackTrace: stackTrace,
      );
      onStatus('Installation failed: $e');
      return false;
    } finally {
      if (tempZipFile != null && await tempZipFile.exists()) {
        try {
          await tempZipFile.delete();
        } catch (e) {
          LoggingService().debug('Failed to delete temp FFmpeg zip: $e', component: 'FfmpegService');
        }
      }
      if (tempDirRef != null && await tempDirRef.exists()) {
        try {
          await tempDirRef.delete(recursive: true);
        } catch (e) {
          LoggingService().debug('Failed to delete temp FFmpeg dir: $e', component: 'FfmpegService');
        }
      }
    }
  }
}
