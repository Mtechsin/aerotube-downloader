import 'dart:io';

import 'package:flutter/services.dart';

import '../core/utils/platform_utils.dart';
import 'logging_service.dart';

/// Service for generating Android content URIs via FileProvider.
///
/// On Android, you cannot share raw file:// URIs with other apps on API 24+.
/// Instead, the FileProvider converts a real file path into a safe
/// content:// URI that grants temporary read access to the receiving app.
///
/// Usage:
/// ```dart
/// final uri = await FileProviderService.getContentUri('/path/to/video.mp4');
/// if (uri != null) {
///   // Pass uri to share_plus, Intent, etc.
/// }
/// ```
class FileProviderService {
  static const MethodChannel _channel = MethodChannel(
    'com.aerotube.youtube_downloader/file_provider',
  );

  static final LoggingService _logger = LoggingService();

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Returns a content:// URI string for [filePath] using the app's
  /// FileProvider, or `null` if the operation fails.
  ///
  /// Only meaningful on Android; returns `null` on other platforms.
  static Future<String?> getContentUri(String filePath) async {
    if (!PlatformUtils.isAndroid) return null;

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _logger.warning(
          'getContentUri: file does not exist: $filePath',
          component: 'FileProviderService',
        );
        return null;
      }

      final uri = await _channel.invokeMethod<String>(
        'getContentUri',
        {'filePath': filePath},
      );

      _logger.info(
        'getContentUri: $filePath → $uri',
        component: 'FileProviderService',
      );
      return uri;
    } on PlatformException catch (e) {
      _logger.error(
        'getContentUri PlatformException: ${e.message}',
        component: 'FileProviderService',
        error: e,
      );
      return null;
    } catch (e, st) {
      _logger.error(
        'getContentUri unexpected error',
        component: 'FileProviderService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Returns content:// URIs for multiple files in a single batch call.
  ///
  /// Files that do not exist or fail conversion are omitted from the result.
  static Future<List<String>> getContentUris(List<String> filePaths) async {
    if (!PlatformUtils.isAndroid) return [];

    final uris = <String>[];
    for (final path in filePaths) {
      final uri = await getContentUri(path);
      if (uri != null) uris.add(uri);
    }
    return uris;
  }

  /// Determines the MIME type for a file based on its extension.
  ///
  /// Falls back to `'application/octet-stream'` for unknown extensions.
  static String getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    const mimeTypes = <String, String>{
      // Video
      'mp4': 'video/mp4',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'avi': 'video/x-msvideo',
      'mov': 'video/quicktime',
      'm4v': 'video/x-m4v',
      // Audio
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'aac': 'audio/aac',
      'ogg': 'audio/ogg',
      'opus': 'audio/opus',
      'flac': 'audio/flac',
      'wav': 'audio/wav',
      // Images
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }
}
