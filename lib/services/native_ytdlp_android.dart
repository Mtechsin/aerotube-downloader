import 'dart:convert';

import 'package:flutter/services.dart';

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
      print('[NativeYtdlpAndroid] getVideoInfo called for: $url');
      print('[NativeYtdlpAndroid] cookiesPath: $cookiesPath');
      print('[NativeYtdlpAndroid] userAgent: $userAgent');

      final result = await _channel.invokeMethod<String>('getVideoInfo', {
        'url': url,
        'cookies_path': cookiesPath,
        'user_agent': userAgent,
      });

      if (result == null) {
        throw Exception('Failed to get video info: null response');
      }

      final parsed = jsonDecode(result) as Map<String, dynamic>;

      if (parsed['success'] == false) {
        print('[NativeYtdlpAndroid] Error: ${parsed['error']}');
        throw Exception(parsed['error'] ?? 'Unknown error');
      }

      print('[NativeYtdlpAndroid] Successfully got video info');
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
      final result = await _channel.invokeMethod<String>('getPlaylistInfo', {
        'url': url,
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
      final result = await _channel.invokeMethod<String>('downloadVideo', {
        'url': url,
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
