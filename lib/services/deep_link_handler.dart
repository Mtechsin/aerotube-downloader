import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/video_provider.dart';
import 'core/deep_link_service.dart';
import 'notification/notification_service.dart';
import 'core/logging_service.dart';
import '../core/utils/platform_utils.dart';

class DeepLinkHandler {
  final DeepLinkService _deepLinkService = DeepLinkService();
  StreamSubscription<String>? _subscription;
  String? _lastHandledLink;

  void init(BuildContext context) {
    if (!PlatformUtils.isMobile || _subscription != null) return;
    final loggingService = context.read<LoggingService>();
    _subscription = _deepLinkService.links.listen(
      (link) => handleLink(context, link),
      onError: (error) {
        loggingService.warning('Deep link stream error: $error', component: 'DeepLink');
      },
    );
    _deepLinkService.getInitialLink().then((initialLink) {
      if (initialLink != null) handleLink(context, initialLink);
    }).catchError((e) {
      loggingService.warning('Failed to read initial deep link: $e', component: 'DeepLink');
    });
  }

  void handleLink(BuildContext context, String link) {
    final url = _deepLinkService.normalizeMediaUrl(link);
    if (url == null || url == _lastHandledLink) return;
    _lastHandledLink = url;
    context.read<NavigationProvider>().switchToHome();
    if (url.contains('list=') || url.contains('/playlist')) {
      context.read<PlaylistProvider>().fetchPlaylist(url);
      context.read<VideoProvider>().fetchPlaylistInfo(url);
    } else {
      final videoProvider = context.read<VideoProvider>();
      videoProvider.fetchVideoInfo(url);
      videoProvider.setAudioOnly(false);
    }
    context.read<NotificationService>().show(title: 'Link opened', body: 'Fetching YouTube content');
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
