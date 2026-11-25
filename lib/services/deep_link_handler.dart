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
import '../ui/screens/playlist_screen.dart';

class DeepLinkHandler {
  final DeepLinkService _deepLinkService = DeepLinkService();
  StreamSubscription<String>? _subscription;
  String? _lastHandledLink;
  DateTime? _lastHandledAt;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// H15: only ignore an identical URL received within this window
  /// (prevents double-handling of the same launch event, without
  /// permanently blocking a link the user opens again later).
  static const Duration _dedupWindow = Duration(seconds: 3);

  void init(BuildContext context, {GlobalKey<NavigatorState>? navigatorKey}) {
    _navigatorKey = navigatorKey ?? _navigatorKey;
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
    if (url == null) return;
    final now = DateTime.now();
    if (url == _lastHandledLink &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < _dedupWindow) {
      return;
    }
    _lastHandledLink = url;
    _lastHandledAt = now;
    // H14: treat as playlist only for a real /playlist path, or when
    // list= is present AND v= is absent (same heuristic as mobile home).
    // A watch URL that also carries list= is still a single video.
    final uri = Uri.tryParse(url);
    final path = uri?.path.toLowerCase() ?? '';
    final isPlaylistPath = path.contains('/playlist');
    final hasListParam =
        uri?.queryParameters['list'] != null &&
        (uri?.queryParameters['list'] ?? '').isNotEmpty;
    final hasVideoParam = uri?.queryParameters.containsKey('v') == true;
    if (isPlaylistPath || (hasListParam && !hasVideoParam)) {
      if (PlatformUtils.isMobile) {
        // MobileShell index 2 is Library, not a playlist tab. Playlist
        // results live on MobileResultScreen, same as the home fetch flow.
        context.read<VideoProvider>().fetchPlaylistInfo(url);
        _push(const MobileResultScreen());
      } else {
        context.read<PlaylistProvider>().fetchPlaylist(url);
        _push(const PlaylistScreen());
      }
    } else {
      final videoProvider = context.read<VideoProvider>();
      videoProvider.fetchVideoInfo(url);
      videoProvider.setAudioOnly(false);
      if (PlatformUtils.isMobile) {
        // context here is above MaterialApp, so Navigator.of(context) throws.
        _push(const MobileResultScreen());
      } else {
        context.read<NavigationProvider>().switchToHome();
      }
    }
    context.read<NotificationService>().show(title: 'Link opened', body: 'Fetching media');
  }

  void _push(Widget page) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      LoggingService().warning(
        'Deep link ignored: navigator is not ready',
        component: 'DeepLink',
      );
      return;
    }
    navigator.push(MaterialPageRoute(builder: (_) => page));
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
