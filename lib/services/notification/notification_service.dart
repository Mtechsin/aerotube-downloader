import 'package:material_symbols_icons/symbols.dart';

import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import '../core/logging_service.dart';

class NotificationService {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// When false, system notifications are suppressed (in-app snackbars still show).
  bool systemNotificationsEnabled = true;

  Future<void> init() async {
    await localNotifier.setup(
      appName: 'AeroTube',
      // shortcutPolicy: ShortcutPolicy.requireCreate,
    );
  }

  Future<void> show({
    required String title,
    required String body,
    bool isError = false,
    VoidCallback? onTap,
    /// When false, only the in-app SnackBar is shown (no Windows toast).
    /// Use for routine complete/fail so the OS toast does not duplicate
    /// the on-screen SnackBar.
    bool alsoSystemNotification = true,
  }) async {
    // 1. Show System Notification (only when the user has it enabled)
    if (alsoSystemNotification && systemNotificationsEnabled) {
      final notification = LocalNotification(
        title: title,
        body: body,
      );

      notification.onClick = () {
        onTap?.call();
      };

      notification.onShow = () {
        LoggingService().debug(
          'Notification shown: $title',
          component: 'NotificationService',
        );
      };

      notification.show();
    }

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
                  isError ? Symbols.error_rounded : Symbols.check_circle_rounded,
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
