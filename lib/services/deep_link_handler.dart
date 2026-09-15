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
import '../ui/screens/mobile_result_screen.dart';

class DeepLinkHandler {
  final DeepLinkService _deepLinkService = DeepLinkService();
  StreamSubscription<String>? _subscription;
  String? _lastHandledLink;

  void init(BuildContext context) {
    if (!PlatformUtils.isMobile || _subscription != null) return;
    final loggingService = context.read<LoggingService>();
    _subscription = _deepLinkService.links.listen(
      (link) {
        if (context.mounted) handleLink(context, link);
      },
      onError: (error) {
        loggingService.warning('Deep link stream error: $error', component: 'DeepLink');
      },
    );
    _deepLinkService.getInitialLink().then((initialLink) {
      if (initialLink != null && context.mounted) handleLink(context, initialLink);
    }).catchError((e) {
      loggingService.warning('Failed to read initial deep link: $e', component: 'DeepLink');
    });
  }

  void handleLink(BuildContext context, String link) {
    final url = _deepLinkService.normalizeMediaUrl(link);
    if (url == null || url == _lastHandledLink) return;
    _lastHandledLink = url;
    if (url.contains('list=') || url.contains('/playlist')) {
      context.read<NavigationProvider>().setIndex(2); // Playlist tab
      context.read<PlaylistProvider>().fetchPlaylist(url);
    } else {
      final videoProvider = context.read<VideoProvider>();
      videoProvider.fetchVideoInfo(url);
      videoProvider.setAudioOnly(false);
      if (PlatformUtils.isMobile) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const MobileResultScreen(),
          ),
        );
      } else {
        context.read<NavigationProvider>().switchToHome();
      }
    }
    context.read<NotificationService>().show(title: 'Link opened', body: 'Fetching media');
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
