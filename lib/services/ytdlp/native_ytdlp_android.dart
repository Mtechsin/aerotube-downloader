import 'dart:convert';

import 'package:flutter/services.dart';
import '../core/logging_service.dart';
import '../../core/utils/url_validator.dart';

String _validateUrl(String url) {
  try {
    return UrlValidator.validate(url);
  } on UrlValidationException catch (e) {
    throw Exception(e.message);
  }
}

/// Native bridge to youtubedl-android library via MethodChannel
class NativeYtdlpAndroid {
  static const MethodChannel _channel = MethodChannel(
    'com.aerotube.youtube_downloader/ytdlp_android',
  );
  static const EventChannel _eventsChannel = EventChannel(
    'com.aerotube.youtube_downloader/ytdlp_android/events',
  );

  static Stream<Map<String, dynamic>>? _downloadEvents;

  static Stream<Map<String, dynamic>> get downloadEvents {
    _downloadEvents ??= _eventsChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return event.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    });
    return _downloadEvents!;
  }

  /// Get yt-dlp version from native library
  static Future<String?> getVersion() async {
    try {
      final result = await _channel.invokeMethod<String>('getVersion');
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Get video information using youtubedl-android
  static Future<Map<String, dynamic>> getVideoInfo(
    String url, {
    String? cookiesPath,
    String? userAgent,
  }) async {
    try {
      final validatedUrl = _validateUrl(url);
      LoggingService().debug(
        'getVideoInfo called for: $validatedUrl',
        component: 'NativeYtdlpAndroid',
      );
      LoggingService().debug(
        'cookiesPath: $cookiesPath',
        component: 'NativeYtdlpAndroid',
      );
      LoggingService().debug(
        'userAgent: $userAgent',
        component: 'NativeYtdlpAndroid',
      );

      final result = await _channel.invokeMethod<String>('getVideoInfo', {
        'url': validatedUrl,
        'cookies_path': cookiesPath,
        'user_agent': userAgent,
      });

      if (result == null) {
        throw Exception('Failed to get video info: null response');
      }

      final parsed = jsonDecode(result) as Map<String, dynamic>;

      if (parsed['success'] == false) {
        LoggingService().error(
          'Error: ${parsed['error']}',
          component: 'NativeYtdlpAndroid',
        );
        throw Exception(parsed['error'] ?? 'Unknown error');
      }

      LoggingService().info(
        'Successfully got video info',
        component: 'NativeYtdlpAndroid',
      );
      return parsed;
    } on PlatformException catch (e) {
      throw Exception('Platform error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// Get playlist information using youtubedl-android
  static Future<Map<String, dynamic>> getPlaylistInfo(
    String url, {
    String? cookiesPath,
    String? userAgent,
  }) async {
    try {
      final validatedUrl = _validateUrl(url);
      final result = await _channel.invokeMethod<String>('getPlaylistInfo', {
        'url': validatedUrl,
        'cookies_path': cookiesPath,
        'user_agent': userAgent,
      });

      if (result == null) {
        throw Exception('Failed to get playlist info: null response');
      }

      final parsed = jsonDecode(result) as Map<String, dynamic>;

      if (parsed['success'] == false) {
        throw Exception(parsed['error'] ?? 'Unknown error');
      }

      return parsed;
    } on PlatformException catch (e) {
      throw Exception('Platform error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// Download video with progress tracking
  static Future<Map<String, dynamic>> downloadVideo({
    required String url,
    required String outputPath,
    String? format,
    String? cookiesPath,
    String? userAgent,
    String? processId,
  }) async {
    try {
      final validatedUrl = _validateUrl(url);
      final result = await _channel.invokeMethod<String>('downloadVideo', {
        'url': validatedUrl,
        'output_path': outputPath,
        'format': format,
        'cookies_path': cookiesPath,
        'user_agent': userAgent,
        'process_id': processId,
      });

      if (result == null) {
        throw Exception('Failed to download video: null response');
      }

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      return parsed;
    } on PlatformException catch (e) {
      throw Exception('Platform error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel an active download
  static Future<bool> cancelDownload(String processId) async {
    try {
      final result = await _channel.invokeMethod<bool>('cancelDownload', {
        'process_id': processId,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Update yt-dlp binary
  static Future<Map<String, dynamic>> updateYoutubeDL({
    String updateChannel = 'stable',
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('updateYoutubeDL', {
        'update_channel': updateChannel,
      });

      if (result == null) {
        throw Exception('Failed to update yt-dlp: null response');
      }

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      return parsed;
    } on PlatformException catch (e) {
      throw Exception('Platform error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// Filter download events for a specific process ID
  static Stream<Map<String, dynamic>> progressForProcess(String processId) {
    return downloadEvents.where((event) => event['process_id'] == processId);
  }
}
