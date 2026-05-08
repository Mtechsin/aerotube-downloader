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
  /// Returns user-accessible Downloads/aerotube folder by default
  Future<String> getDownloadDirectory() async {
    if (!PlatformUtils.isAndroid) {
      throw UnsupportedError('This service is for Android only');
    }

    try {
      final androidVersion = await _getAndroidApiLevel();

      // Android 10+ (API 29+) can use public Downloads folder via Scoped Storage
      // No special permissions needed for writing to /Android/media or /Download
      if (androidVersion >= 29) {
        return await _getPublicDownloadPath();
      }

      // Android 9 and below - use legacy public storage
      return await _getLegacyStoragePath();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get download directory',
        component: 'AndroidStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      // Last resort fallback to app-specific directory
      final appDir = await getApplicationDocumentsDirectory();
      return p.join(appDir.path, 'downloads', 'aerotube');
    }
  }

  /// Get the preferred download directory without requesting permissions.
  ///
  /// This is used for default path initialization so startup stays quiet.
  Future<String> getPreferredDownloadDirectory() async {
    if (!PlatformUtils.isAndroid) {
      throw UnsupportedError('This service is for Android only');
    }

    final androidVersion = await _getAndroidApiLevel();
    if (androidVersion >= 29) {
      return await _getPublicDownloadPath();
    }

    return await _getLegacyStoragePath();
  }

  /// Get the public Downloads/aerotube folder.
  /// This is accessible to users and media scanners
  Future<String> _getPublicDownloadPath() async {
    // Use standard Android Download directory with aerotube subfolder
    const downloadPath = '/storage/emulated/0/Download/aerotube';
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
          return p.join(appDir.path, 'downloads', 'aerotube');
        }
      }

      // Use public Downloads directory (same as modern Android)
      const downloadPath = '/storage/emulated/0/Download/aerotube';
      await _ensureDirectoryExists(downloadPath);
      return downloadPath;
    } catch (e) {
      _logger.warning(
        'Failed to get legacy storage path: $e',
        component: 'AndroidStorageService',
      );
      final appDir = await getApplicationDocumentsDirectory();
      return p.join(appDir.path, 'downloads', 'aerotube');
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

    // Android 11+ (API 30+) needs MANAGE_EXTERNAL_STORAGE for broad file access
    if (androidVersion >= 30) {
      final hasBroadAccess = await requestManageExternalStorage();
      if (hasBroadAccess) {
        return true;
      }
      // On Android 13+ try granular media permissions as fallback
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
      return false;
    }

    // Android 10 (API 29) - scoped storage with legacy flag
    if (androidVersion >= 29) {
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
