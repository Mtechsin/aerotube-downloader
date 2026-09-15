import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/platform_utils.dart';
import 'logging_service.dart';

/// Android-specific storage service handling scoped storage
/// Manages file paths appropriately for Android 10+ (API 29+)
class AndroidStorageService {
  final LoggingService _logger = LoggingService();
  static const _permissionRequestInProgressCode =
      'PermissionHandler.PermissionManager';

  /// Get the appropriate download directory based on Android version.
  /// Returns a writable path: public Downloads/AeroTube when possible,
  /// otherwise app-specific storage.
  Future<String> getDownloadDirectory() async {
    if (!PlatformUtils.isAndroid) {
      throw UnsupportedError('This service is for Android only');
    }

    try {
      return await getSafeDownloadDirectory();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get download directory',
        component: 'AndroidStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      // Last resort fallback to app-specific directory
      return getAppSpecificDownloadDirectory();
    }
  }

  /// Get the preferred download directory without requesting permissions.
  ///
  /// This is used for default path initialization so startup stays quiet.
  Future<String> getPreferredDownloadDirectory() async {
    if (!PlatformUtils.isAndroid) {
      throw UnsupportedError('This service is for Android only');
    }

    // Prefer public Downloads when already writable; otherwise use a path
    // that does not require a permission prompt so boot stays quiet.
    if (await canWritePublicDownloads()) {
      try {
        return await _getPublicDownloadPath();
      } catch (_) {}
    }
    return getAppSpecificDownloadDirectory();
  }

  /// Checks if a directory path is writable using a temporary probe file
  Future<bool> _isPathWritable(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probe = File(
        p.join(dirPath, '.probe_${DateTime.now().microsecondsSinceEpoch}'),
      );
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get the public Downloads/AeroTube folder.
  /// This is accessible to users and media scanners
  Future<String> _getPublicDownloadPath() async {
    try {
      const channel = MethodChannel('com.aerotube.youtube_downloader/permissions');
      final nativePath = await channel.invokeMethod<String>('getExternalDownloadDir');
      if (nativePath != null && nativePath.isNotEmpty) {
        String downloadPath = nativePath;
        final normalized = downloadPath.replaceAll('\\', '/').toLowerCase();

        // Ensure path does not re-trap into /Android/data/
        if (!normalized.contains('/android/data/')) {
          if (!normalized.endsWith('/aerotube') && !normalized.endsWith('/aerotube/')) {
            downloadPath = p.join(downloadPath, 'AeroTube');
          }
          if (await _isPathWritable(downloadPath)) {
            return downloadPath;
          }
          _logger.warning(
            'Native public download directory is not writable: $downloadPath',
            component: 'AndroidStorageService',
          );
        } else {
          _logger.warning(
            'Native download directory returned app-specific path: $nativePath. Bypassing to public Downloads/AeroTube.',
            component: 'AndroidStorageService',
          );
        }
      }
    } catch (e) {
      _logger.warning(
        'Failed to get native download directory: $e',
        component: 'AndroidStorageService',
      );
    }

    // Direct public Download directory fallback (bypassing /Android/data/)
    try {
      const publicPath = '/storage/emulated/0/Download/AeroTube';
      if (await _isPathWritable(publicPath)) {
        return publicPath;
      }
      _logger.warning(
        'Public download directory is not writable: $publicPath',
        component: 'AndroidStorageService',
      );
    } catch (e) {
      _logger.warning(
        'Failed to create public download directory: $e',
        component: 'AndroidStorageService',
      );
    }

    // Fallback: use app-specific directory only as absolute last resort
    return getAppSpecificDownloadDirectory();
  }

  /// Get Android API level
  Future<int> _getAndroidApiLevel() async {
    try {
      const channel = MethodChannel('com.aerotube.youtube_downloader/permissions');
      final apiLevel = await channel.invokeMethod<int>('getApiLevel');
      if (apiLevel != null && apiLevel > 0) {
        return apiLevel;
      }
    } catch (_) {}

    try {
      // Read from build properties
      final result = await Process.run('getprop', ['ro.build.version.sdk']);
      if (result.exitCode == 0) {
        final parsed = int.tryParse(result.stdout.toString().trim());
        if (parsed != null && parsed > 0) return parsed;
      }
    } catch (e) {
      _logger.warning(
        'Failed to get API level: $e',
        component: 'AndroidStorageService',
      );
    }
    // Default to Android 13 (API 33) to be safe for modern permission models if unknown
    return 33;
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

  /// True for removable (SD-card) locations such as `/storage/1234-ABCD/...`.
  /// yt-dlp writes via raw filesystem paths and cannot use SAF tree URIs,
  /// so such locations are rejected up-front with a clear message instead of
  /// failing later mid-download.
  bool isOnRemovableStorage(String path) {
    final normalized = path.replaceAll('\\', '/');
    if (!normalized.startsWith('/storage/')) return false;
    if (normalized.startsWith('/storage/emulated/')) return false;
    if (normalized.startsWith('/storage/self/')) return false;
    final segments =
        normalized.split('/').where((s) => s.isNotEmpty).toList();
    // /storage/<volume>[/...] where a removable volume ID contains a dash
    // (e.g. 1234-ABCD) or is neither emulated nor self.
    if (segments.length >= 2) {
      final volume = segments[1];
      if (volume.contains('-')) return true;
      return true;
    }
    return false;
  }

  /// Validates a user-picked custom download directory on Android.
  /// Returns a record `(ok, reason)`: when `ok` is false, `reason` explains
  /// why the folder cannot be used (SD-card/SAF grant, app-private path,
  /// or failed write test). Does not throw.
  Future<({bool ok, String? reason})> validateCustomDirectory(
    String path,
  ) async {
    if (!PlatformUtils.isAndroid) return (ok: true, reason: null);
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return (ok: false, reason: 'Selected folder is empty.');
    }
    final normalized = trimmed.replaceAll('\\', '/');
    final lower = normalized.toLowerCase();
    // App-specific external dirs are valid fallbacks (always writable, no
    // runtime permission). Only reject them when public Downloads is writable,
    // so users are nudged to the better location when possible.
    if (lower.contains('/android/data/')) {
      if (await canWritePublicDownloads()) {
        return (
          ok: false,
          reason:
              'That folder is app-private (/Android/data/) and gets wiped on uninstall. Pick Downloads/AeroTube instead.'
        );
      }
      // Allow as a working fallback while public storage is blocked.
      try {
        final dir = Directory(trimmed);
        await dir.create(recursive: true);
        final probe = File(
          p.join(trimmed, '.aerotube_write_test_${DateTime.now().microsecondsSinceEpoch}'),
        );
        await probe.writeAsString('ok', flush: true);
        await probe.delete();
        return (ok: true, reason: null);
      } catch (e) {
        return (
          ok: false,
          reason: 'Cannot write to that folder ($e). Pick Downloads/AeroTube instead.'
        );
      }
    }
    if (isOnRemovableStorage(trimmed)) {
      return (
        ok: false,
        reason:
            'SD-card folders need a Storage Access Framework grant, which yt-dlp cannot write to via raw paths. Pick internal Downloads/AeroTube instead.'
      );
    }
    try {
      final dir = Directory(trimmed);
      await dir.create(recursive: true);
      // Probe writability with a real file (create → write → delete).
      final probe = File(
        p.join(trimmed, '.aerotube_write_test_${DateTime.now().microsecondsSinceEpoch}'),
      );
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return (ok: true, reason: null);
    } catch (e) {
      _logger.warning(
        'Custom download directory not writable: $trimmed ($e)',
        component: 'AndroidStorageService',
      );
      return (
        ok: false,
        reason: 'Cannot write to that folder ($e). Pick Downloads/AeroTube instead.'
      );
    }
  }

  /// Check whether MANAGE_EXTERNAL_STORAGE is granted (Android 11+)
  Future<bool> isManageStorageGranted() async {
    if (!PlatformUtils.isAndroid) return true;
    try {
      const channel = MethodChannel('com.aerotube.youtube_downloader/permissions');
      final granted = await channel.invokeMethod<bool>('isExternalStorageManager');
      if (granted != null) return granted;
    } catch (_) {}
    try {
      return await Permission.manageExternalStorage.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Open system settings page to grant "All files access" (MANAGE_EXTERNAL_STORAGE)
  Future<bool> openManageStorageSettings() async {
    if (!PlatformUtils.isAndroid) return false;
    try {
      const channel = MethodChannel('com.aerotube.youtube_downloader/permissions');
      final opened = await channel.invokeMethod<bool>('openManageStorageSettings');
      return opened ?? false;
    } catch (_) {
      return await openAppSettings();
    }
  }

  /// App-specific external files dir (always writable, no runtime permission).
  Future<String> getAppSpecificDownloadDirectory() async {
    try {
      const channel = MethodChannel('com.aerotube.youtube_downloader/permissions');
      final path = await channel.invokeMethod<String>('getAppSpecificDownloadDir');
      if (path != null && path.isNotEmpty) {
        await _ensureDirectoryExists(path);
        return path;
      }
    } catch (e) {
      _logger.warning(
        'getAppSpecificDownloadDir failed: $e',
        component: 'AndroidStorageService',
      );
    }
    final appDir = await getApplicationSupportDirectory();
    final fallback = p.join(appDir.path, 'downloads');
    await _ensureDirectoryExists(fallback);
    return fallback;
  }

  /// True when public Downloads/AeroTube can be created and written.
  Future<bool> canWritePublicDownloads() async {
    if (!PlatformUtils.isAndroid) return true;
    try {
      const channel = MethodChannel('com.aerotube.youtube_downloader/permissions');
      final ok = await channel.invokeMethod<bool>('canWritePublicDownloads');
      if (ok != null) return ok;
    } catch (_) {}
    return _isPathWritable('/storage/emulated/0/Download/AeroTube');
  }

  /// Check whether storage is currently accessible without showing a prompt.
  /// Returns true only when the public Downloads folder is actually writable
  /// (or the platform already has All-files-access / media permission).
  Future<bool> hasStoragePermission() async {
    if (!PlatformUtils.isAndroid) return true;
    try {
      const channel = MethodChannel('com.aerotube.youtube_downloader/permissions');
      final ok = await channel.invokeMethod<bool>('hasStorageAccess');
      if (ok != null) return ok;
    } catch (_) {}

    if (await canWritePublicDownloads()) return true;
    if (await isManageStorageGranted()) return true;

    final androidVersion = await _getAndroidApiLevel();
    if (androidVersion >= 33) {
      try {
        final video = await Permission.videos.isGranted;
        final audio = await Permission.audio.isGranted;
        final images = await Permission.photos.isGranted;
        if (video || audio || images) return true;
      } catch (_) {}
    }
    if (androidVersion <= 29) {
      try {
        final status = await Permission.storage.status;
        return status.isGranted;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Request storage permissions through the native Android flow so the user
  /// actually sees a system dialog (API <= 10 / 13+) or the All-files-access
  /// settings page (API 11–12). Resolves only after the user responds.
  ///
  /// Returns true only when public Downloads are usable or All-files-access /
  /// media permissions are granted. Never fakes a grant.
  Future<bool> requestStoragePermission() async {
    if (!PlatformUtils.isAndroid) return true;

    // Fast path: already writable.
    if (await canWritePublicDownloads()) return true;

    try {
      const channel = MethodChannel('com.aerotube.youtube_downloader/permissions');
      final granted = await channel
          .invokeMethod<bool>('requestStoragePermission')
          .timeout(const Duration(seconds: 90));
      if (granted == true) return true;
    } on PlatformException catch (e) {
      if (_isConcurrentPermissionRequestError(e)) {
        // Another request is in flight; poll briefly for the outcome.
        await Future.delayed(const Duration(milliseconds: 800));
        return hasStoragePermission();
      }
      _logger.warning(
        'Native requestStoragePermission failed: ${e.message}',
        component: 'AndroidStorageService',
      );
    } catch (e) {
      _logger.warning(
        'requestStoragePermission failed: $e',
        component: 'AndroidStorageService',
      );
    }

    // Post-request verification: never trust the dialog result alone.
    if (await canWritePublicDownloads()) return true;
    if (await isManageStorageGranted()) return true;

    final androidVersion = await _getAndroidApiLevel();
    if (androidVersion >= 33) {
      try {
        final video = await Permission.videos.isGranted;
        final audio = await Permission.audio.isGranted;
        if (video || audio) return true;
      } catch (_) {}
    }
    if (androidVersion <= 29) {
      try {
        final status = await Permission.storage.status;
        if (status.isGranted) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Directory that is guaranteed writable for yt-dlp raw path writes.
  /// Prefers public Downloads/AeroTube; falls back to app-specific storage.
  Future<String> getSafeDownloadDirectory() async {
    if (!PlatformUtils.isAndroid) {
      throw UnsupportedError('This service is for Android only');
    }
    if (await canWritePublicDownloads()) {
      try {
        return await _getPublicDownloadPath();
      } catch (_) {}
    }
    final appPath = await getAppSpecificDownloadDirectory();
    _logger.info(
      'Using app-specific download directory: $appPath',
      component: 'AndroidStorageService',
    );
    return appPath;
  }

  /// Copy a finished download into the public Downloads/AeroTube folder via
  /// MediaStore. Works on Android 10+ without All-files-access.
  Future<bool> publishToPublicDownloads({
    required String sourcePath,
    required String displayName,
    String? mimeType,
  }) async {
    if (!PlatformUtils.isAndroid) return false;
    try {
      const channel = MethodChannel('com.aerotube.youtube_downloader/permissions');
      final ok = await channel.invokeMethod<bool>('publishToMediaStoreDownloads', {
        'sourcePath': sourcePath,
        'displayName': displayName,
        'mimeType': mimeType,
      });
      _logger.info(
        'MediaStore publish $displayName → $ok',
        component: 'AndroidStorageService',
      );
      return ok ?? false;
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to publish to public Downloads: $e',
        component: 'AndroidStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Whether [path] is inside app-private external storage
  /// (`/Android/data/...`), which is wiped on uninstall.
  bool isAppPrivatePath(String path) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/android/data/');
  }

  /// Scan a media file so Android MediaStore indexes it immediately
  /// for Gallery and media players.
  Future<bool> scanMediaFile(String filePath) async {
    if (!PlatformUtils.isAndroid) return false;
    try {
      const channel = MethodChannel('com.aerotube.youtube_downloader/permissions');
      final result = await channel.invokeMethod<bool>('scanMediaFile', {'filePath': filePath});
      _logger.info(
        'MediaScanner scanned file: $filePath (success=$result)',
        component: 'AndroidStorageService',
      );
      return result ?? false;
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to scan media file: $filePath ($e)',
        component: 'AndroidStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  bool _isConcurrentPermissionRequestError(PlatformException e) {
    if (e.code != _permissionRequestInProgressCode) return false;
    final message = (e.message ?? '').toLowerCase();
    return message.contains('already running');
  }

  /// Get device manufacturer (e.g. "xiaomi", "samsung", "oppo")
  Future<String?> getDeviceManufacturer() async {
    if (!PlatformUtils.isAndroid) return null;
    try {
      const channel = MethodChannel('com.aerotube.youtube_downloader/permissions');
      return await channel.invokeMethod<String>('getDeviceManufacturer');
    } catch (e) {
      _logger.warning(
        'Failed to get device manufacturer: $e',
        component: 'AndroidStorageService',
      );
      return null;
    }
  }

  /// Launch OEM-specific autostart or background execution settings
  Future<bool> openOemAutostartSettings() async {
    if (!PlatformUtils.isAndroid) return false;
    try {
      const channel = MethodChannel('com.aerotube.youtube_downloader/permissions');
      final result = await channel.invokeMethod<bool>('openOemAutostartSettings');
      return result ?? false;
    } catch (e) {
      _logger.warning(
        'Failed to open OEM autostart settings: $e',
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
        // PF4 fix: avoid listSync blocking main isolate
        final files = await dir.list(recursive: true).toList();

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
