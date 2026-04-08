import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import '../core/utils/platform_utils.dart';
import 'logging_service.dart';

/// Android-specific storage service handling scoped storage
/// Manages file paths appropriately for Android 10+ (API 29+)
class AndroidStorageService {
  final LoggingService _logger = LoggingService();
  static const _permissionRequestInProgressCode =
      'PermissionHandler.PermissionManager';

  /// Get the appropriate download directory based on Android version
  Future<String> getDownloadDirectory() async {
    if (!PlatformUtils.isAndroid) {
      throw UnsupportedError('This service is for Android only');
    }

    try {
      final androidVersion = await _getAndroidApiLevel();

      // For Android 10+ (API 29+), use app-specific directories
      if (androidVersion >= 29) {
        return await _getScopedStoragePath();
      } else {
        // For older Android versions, use legacy external storage
        return await _getLegacyStoragePath();
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get download directory',
        component: 'AndroidStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      // Fallback to app-specific directory
      final appDir = await getApplicationDocumentsDirectory();
      return p.join(appDir.path, 'Downloads');
    }
  }

  /// Get scoped storage path for Android 10+ (API 29+)
  Future<String> _getScopedStoragePath() async {
    // Use public downloads directory (no permission needed for Android 10+)
    // Files here are visible to user and other apps
    final externalDir = await getExternalStorageDirectory();

    if (externalDir != null) {
      // Use app-specific external storage
      final downloadPath = p.join(externalDir.path, 'downloads');
      await _ensureDirectoryExists(downloadPath);
      return downloadPath;
    }

    // Fallback to internal storage
    final appDir = await getApplicationDocumentsDirectory();
    final downloadPath = p.join(appDir.path, 'Downloads');
    await _ensureDirectoryExists(downloadPath);
    return downloadPath;
  }

  /// Get legacy storage path for Android 9 and below
  Future<String> _getLegacyStoragePath() async {
    try {
      // Try to get external storage directory
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        if (!result.isGranted) {
          _logger.warning(
            'Storage permission denied',
            component: 'AndroidStorageService',
          );
          // Fallback to app-specific directory
          final appDir = await getApplicationDocumentsDirectory();
          return p.join(appDir.path, 'Downloads');
        }
      }

      // Use public Downloads directory
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // Try to use public downloads folder
        const publicDownloads = '/storage/emulated/0/Download/AeroTube';
        await _ensureDirectoryExists(publicDownloads);
        return publicDownloads;
      }

      // Fallback
      final appDir = await getApplicationDocumentsDirectory();
      return p.join(appDir.path, 'Downloads');
    } catch (e) {
      _logger.warning(
        'Failed to get legacy storage path: $e',
        component: 'AndroidStorageService',
      );
      final appDir = await getApplicationDocumentsDirectory();
      return p.join(appDir.path, 'Downloads');
    }
  }

  /// Get Android API level
  Future<int> _getAndroidApiLevel() async {
    try {
      // Read from build properties
      final result = await Process.run('getprop', ['ro.build.version.sdk']);
      if (result.exitCode == 0) {
        return int.parse(result.stdout.toString().trim());
      }
    } catch (e) {
      _logger.warning(
        'Failed to get API level: $e',
        component: 'AndroidStorageService',
      );
    }
    // Default to Android 10 (API 29)
    return 29;
  }

  /// Ensure directory exists
  Future<void> _ensureDirectoryExists(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      _logger.info(
        'Created directory: $path',
        component: 'AndroidStorageService',
      );
    }
  }

  /// Request storage permissions
  Future<bool> requestStoragePermission() async {
    if (!PlatformUtils.isAndroid) return true;

    final androidVersion = await _getAndroidApiLevel();

    // Android 13+ (API 33+) uses different permissions
    if (androidVersion >= 33) {
      try {
        final statuses = await [
          Permission.videos,
          Permission.audio,
          Permission.photos,
        ].request();
        return statuses.values.every((status) => status.isGranted);
      } on PlatformException catch (e) {
        if (_isConcurrentPermissionRequestError(e)) {
          await Future.delayed(const Duration(milliseconds: 600));
          final statuses = await Future.wait([
            Permission.videos.status,
            Permission.audio.status,
            Permission.photos.status,
          ]);
          return statuses.every((status) => status.isGranted);
        }
        rethrow;
      }
    }

    // Android 10-12 (API 29-32)
    if (androidVersion >= 29) {
      // For scoped storage, we might not need storage permission
      // Only request if we need broader access
      return true;
    }

    // Android 9 and below
    try {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return true;
    } on PlatformException catch (e) {
      if (_isConcurrentPermissionRequestError(e)) {
        await Future.delayed(const Duration(milliseconds: 600));
        return (await Permission.storage.status).isGranted;
      }
      rethrow;
    }
  }

  bool _isConcurrentPermissionRequestError(PlatformException e) {
    if (e.code != _permissionRequestInProgressCode) return false;
    final message = (e.message ?? '').toLowerCase();
    return message.contains('already running');
  }

  /// Request MANAGE_EXTERNAL_STORAGE permission (Android 11+)
  /// Use sparingly - only when absolutely necessary
  Future<bool> requestManageExternalStorage() async {
    if (!PlatformUtils.isAndroid) return true;

    final androidVersion = await _getAndroidApiLevel();

    // Only available on Android 11+ (API 30+)
    if (androidVersion < 30) return true;

    try {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        final result = await Permission.manageExternalStorage.request();
        return result.isGranted;
      }
      return true;
    } catch (e) {
      _logger.warning(
        'MANAGE_EXTERNAL_STORAGE not available: $e',
        component: 'AndroidStorageService',
      );
      return false;
    }
  }

  /// Get video save path
  Future<String> getVideoSavePath({required String fileName}) async {
    final downloadDir = await getDownloadDirectory();
    final videoDir = p.join(downloadDir, 'Videos');
    await _ensureDirectoryExists(videoDir);
    return p.join(videoDir, fileName);
  }

  /// Get video save DIRECTORY (yt-dlp adds filename itself)
  Future<String> getVideoDirectory() async {
    final downloadDir = await getDownloadDirectory();
    final videoDir = p.join(downloadDir, 'Videos');
    await _ensureDirectoryExists(videoDir);
    return videoDir;
  }

  /// Get audio save path
  Future<String> getAudioSavePath({required String fileName}) async {
    final downloadDir = await getDownloadDirectory();
    final audioDir = p.join(downloadDir, 'Audio');
    await _ensureDirectoryExists(audioDir);
    return p.join(audioDir, fileName);
  }

  /// Get audio save DIRECTORY (yt-dlp adds filename itself)
  Future<String> getAudioDirectory() async {
    final downloadDir = await getDownloadDirectory();
    final audioDir = p.join(downloadDir, 'Audio');
    await _ensureDirectoryExists(audioDir);
    return audioDir;
  }

  /// Get generic save path
  Future<String> getSavePath({required String fileName}) async {
    final downloadDir = await getDownloadDirectory();
    return p.join(downloadDir, fileName);
  }

  /// Check if storage is accessible
  Future<bool> isStorageAccessible() async {
    try {
      final downloadDir = await getDownloadDirectory();
      final dir = Directory(downloadDir);
      return await dir.exists();
    } catch (e) {
      _logger.error(
        'Storage not accessible',
        component: 'AndroidStorageService',
        error: e,
      );
      return false;
    }
  }

  /// Get storage info (available space, etc.)
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final downloadDir = await getDownloadDirectory();
      final dir = Directory(downloadDir);

      if (await dir.exists()) {
        // Get disk space info (not directly available in Dart)
        // This is a placeholder - you might need a plugin for actual disk space
        return {'path': downloadDir, 'exists': true, 'accessible': true};
      }

      return {'path': downloadDir, 'exists': false, 'accessible': false};
    } catch (e) {
      _logger.error(
        'Failed to get storage info',
        component: 'AndroidStorageService',
        error: e,
      );
      return {'exists': false, 'accessible': false, 'error': e.toString()};
    }
  }

  /// Clean up old files (optional utility)
  Future<void> cleanupOldFiles({int daysOld = 30}) async {
    try {
      final downloadDir = await getDownloadDirectory();
      final dir = Directory(downloadDir);

      if (await dir.exists()) {
        final now = DateTime.now();
        final files = dir.listSync(recursive: true);

        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            final age = now.difference(stat.modified).inDays;

            if (age > daysOld) {
              await file.delete();
              _logger.info(
                'Deleted old file: ${file.path} ($age days old)',
                component: 'AndroidStorageService',
              );
            }
          }
        }
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to cleanup old files',
        component: 'AndroidStorageService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
