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
      // B24 fix: timeout so Dart future never hangs forever if Activity destroyed before Kotlin replies
      final result = await _channel.invokeMethod<String>('getVersion').timeout(const Duration(seconds: 15));
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Get the real FFmpeg version string from the bundled youtubedl-android
  /// library, or null when unavailable.
  static Future<String?> getFfmpegVersion() async {
    try {
      final result = await _channel
          .invokeMethod<String>('getFfmpegVersion')
          .timeout(const Duration(seconds: 10));
      return (result == null || result.isEmpty) ? null : result;
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

      // B24 fix: add 90s timeout matching provider budget
      final result = await _channel.invokeMethod<String>('getVideoInfo', {
        'url': validatedUrl,
        'cookies_path': cookiesPath,
        'user_agent': userAgent,
      }).timeout(const Duration(seconds: 90));

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
    String? playlistItems,
  }) async {
    try {
      final validatedUrl = _validateUrl(url);
      // B24 fix: 90s timeout matching provider budget
      final result = await _channel.invokeMethod<String>('getPlaylistInfo', {
        'url': validatedUrl,
        'cookies_path': cookiesPath,
        'user_agent': userAgent,
        'playlist_items': playlistItems,
      }).timeout(const Duration(seconds: 90));

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

  /// yt-dlp `ytsearchN:query` fallback when youtube_explode search fails.
  static Future<Map<String, dynamic>> searchVideos(
    String query, {
    int limit = 10,
    String? cookiesPath,
    String? userAgent,
  }) async {
    try {
      // Search query is not a URL — validate non-empty only.
      final trimmed = query.trim();
      if (trimmed.isEmpty) {
        throw Exception('Search query is empty');
      }
      final result = await _channel.invokeMethod<String>('searchVideos', {
        'query': trimmed,
        'limit': limit,
        'cookies_path': cookiesPath,
        'user_agent': userAgent,
      }).timeout(const Duration(seconds: 60));

      if (result == null) {
        throw Exception('Failed to search videos: null response');
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

  /// Enqueue a download on the native side and return once the work is
  /// queued — NOT when the download finishes.
  ///
  /// Completes with `{success:true, process_id}` after native accepts the job.
  /// Terminal outcomes (completed / error / cancelled) arrive only via
  /// [downloadEvents]; callers must not treat the method return as success.
  static Future<Map<String, dynamic>> downloadVideo({
    required String url,
    required String outputPath,
    String? format,
    String? cookiesPath,
    String? userAgent,
    String? processId,
    String? archivePath,
    List<String>? subtitleLanguages,
    bool embedSubtitles = false,
    bool sponsorBlock = false,
    bool embedThumbnail = true,
    bool embedMetadata = true,
    bool audioOnly = false,
    int? targetHeight,
    String? audioQuality,
    int? concurrentFragments,
  }) async {
    try {
      final validatedUrl = _validateUrl(url);
      // B24 defense: short call that only enqueues, so a 30s timeout is safe.
      final result = await _channel.invokeMethod<String>('downloadVideo', {
        'url': validatedUrl,
        'output_path': outputPath,
        'format': format,
        'cookies_path': cookiesPath,
        'user_agent': userAgent,
        'process_id': processId,
        'archive_path': archivePath,
        'subtitle_languages': subtitleLanguages,
        'embed_subtitles': embedSubtitles,
        'sponsor_block': sponsorBlock,
        'embed_thumbnail': embedThumbnail,
        'embed_metadata': embedMetadata,
        'audio_only': audioOnly,
        'target_height': targetHeight,
        'audio_quality': audioQuality,
        'concurrent_fragments': concurrentFragments,
      }).timeout(const Duration(seconds: 30));

      if (result == null) {
        throw Exception('Failed to enqueue download: null response');
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
      }).timeout(const Duration(seconds: 10));
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Cancel every active native download.
  ///
  /// Prefers a native `cancelAll` method when the Kotlin side exposes it.
  /// Falls back to cancelling each known [processIds] individually via
  /// [cancelDownload] when cancelAll is unavailable or fails.
  static Future<void> cancelAll({Iterable<String>? processIds}) async {
    var cancelledViaNative = false;
    try {
      final result = await _channel
          .invokeMethod<bool>('cancelAll')
          .timeout(const Duration(seconds: 10));
      cancelledViaNative = result == true;
    } catch (_) {
      // cancelAll not implemented on this native build — fall through.
    }
    if (cancelledViaNative) return;
    if (processIds == null) return;
    for (final id in processIds) {
      if (id.isEmpty) continue;
      await cancelDownload(id);
    }
  }

  /// Update yt-dlp binary
  static Future<Map<String, dynamic>> updateYoutubeDL({
    String updateChannel = 'stable',
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('updateYoutubeDL', {
        'update_channel': updateChannel,
      }).timeout(const Duration(minutes: 5));

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
