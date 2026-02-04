
import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';

class NotificationService {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Future<void> init() async {
    await localNotifier.setup(
      appName: 'YouTube Downloader',
      // shortcutPolicy: ShortcutPolicy.requireCreate,
    );
  }

  void show({
    required String title,
    required String body,
    bool isError = false,
    VoidCallback? onTap,
  }) {
    // 1. Show System Notification
    final notification = LocalNotification(
      title: title,
      body: body,
    );

    notification.onClick = () {
      onTap?.call();
    };
    
    // ignore: avoid_print
    notification.onShow = () => print('Notification shown: $title');
    
    notification.show();

    // 2. Show In-App SnackBar
    final currentState = scaffoldMessengerKey.currentState;
    if (currentState != null) {
      // Safely check for context to get theme if possible, but for now use custom styling
      // that matches the app's aesthetic (dark mode compatible)
      
      currentState.hideCurrentSnackBar();
      currentState.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isError ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                  color: isError ? Colors.redAccent : Colors.greenAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          elevation: 8,
          duration: const Duration(seconds: 4),
          action: onTap != null ? SnackBarAction(
            label: 'OPEN',
            textColor: Colors.blueAccent,
            onPressed: onTap,
          ) : null,
        ),
      );
    }
  }
}
