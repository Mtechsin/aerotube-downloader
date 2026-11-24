import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';

/// Helper for URL input widgets across desktop and mobile.
class UrlInputHelper {
  /// Returns the appropriate icon for a fetch/loading status message.
  static IconData getStatusIcon(String status) {
    if (status.contains('Connecting')) {
      return Symbols.wifi_rounded;
    } else if (status.contains('Fetching') || status.contains('Loading')) {
      return Symbols.cloud_download_rounded;
    } else if (status.contains('Processing')) {
      return Symbols.settings_rounded;
    } else if (status.contains('Found playlist')) {
      return Symbols.playlist_play_rounded;
    } else if (status.contains('Retrying')) {
      return Symbols.refresh_rounded;
    }
    return Symbols.hourglass_empty_rounded;
  }
}
