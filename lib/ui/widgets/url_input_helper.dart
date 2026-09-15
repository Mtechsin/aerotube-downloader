import 'package:flutter/material.dart';

/// Helper for URL input widgets across desktop and mobile.
class UrlInputHelper {
  /// Returns the appropriate icon for a fetch/loading status message.
  static IconData getStatusIcon(String status) {
    if (status.contains('Connecting')) {
      return Icons.wifi_rounded;
    } else if (status.contains('Fetching') || status.contains('Loading')) {
      return Icons.cloud_download_rounded;
    } else if (status.contains('Processing')) {
      return Icons.settings_rounded;
    } else if (status.contains('Found playlist')) {
      return Icons.playlist_play_rounded;
    } else if (status.contains('Retrying')) {
      return Icons.refresh_rounded;
    }
    return Icons.hourglass_empty_rounded;
  }
}
