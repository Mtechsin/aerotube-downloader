import 'dart:async';

import 'package:flutter/services.dart';

class DeepLinkService {
  static const MethodChannel _channel = MethodChannel(
    'com.aerotube.youtube_downloader/deep_links',
  );
  static const EventChannel _eventsChannel = EventChannel(
    'com.aerotube.youtube_downloader/deep_links/events',
  );

  static const int _maxRecursionDepth = 5;

  Stream<String> get links => _eventsChannel
      .receiveBroadcastStream()
      .where((event) => event is String && event.trim().isNotEmpty)
      .cast<String>();

  Future<String?> getInitialLink() async {
    final link = await _channel.invokeMethod<String>('getInitialLink');
    if (link == null || link.trim().isEmpty) return null;
    return link;
  }

  String? normalizeMediaUrl(String link) {
    return _normalizeMediaUrlWithDepth(link, 0);
  }

  String? _normalizeMediaUrlWithDepth(String link, int depth) {
    if (depth > _maxRecursionDepth) return null;

    final uri = Uri.tryParse(link.trim());
    if (uri == null) return null;

    if (uri.scheme == 'aerotube') {
      final nestedUrl = uri.queryParameters['url'];
      if (nestedUrl == null || nestedUrl.trim().isEmpty) return null;
      return _normalizeMediaUrlWithDepth(nestedUrl, depth + 1);
    }

    // Accept any http(s) media URL — yt-dlp supports hundreds of extractors.
    // YouTube remains the primary target, but Vimeo/Twitter/etc. also work.
    final scheme = uri.scheme.toLowerCase();
    if ((scheme == 'http' || scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.host.contains('.')) {
      return uri.toString();
    }

    return null;
  }
}
