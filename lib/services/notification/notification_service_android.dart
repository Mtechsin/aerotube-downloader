import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/platform_utils.dart';
import '../core/logging_service.dart';

import 'notification_service.dart';

/// Android-specific NotificationService using flutter_local_notifications
class NotificationServiceAndroid extends NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final LoggingService _logger = LoggingService();

  bool _isInitialized = false;
  bool _permissionDenied = false;
  int _notificationIdCounter = 0;

  // Notification channel IDs
  static const String _channelIdDownloads = 'download_progress';
  static const String _channelIdGeneral = 'general_notifications';
  static const String _channelIdErrors = 'error_notifications';

  /// Initialize notification service
  @override
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Request notification permission on Android 13+. Denied is non-fatal —
      // still initialize channels so the plugin works after a later grant.
      if (PlatformUtils.isAndroid) {
        try {
          final status = await Permission.notification.status;
          if (!status.isGranted) {
            final result = await Permission.notification.request();
            if (!result.isGranted) {
              _logger.warning(
                'Notification permission denied; continuing init without popup notifications',
                component: 'NotificationServiceAndroid',
              );
              _permissionDenied = true;
            }
          }
        } catch (e) {
          _logger.warning(
            'Notification permission request failed: $e',
            component: 'NotificationServiceAndroid',
          );
        }
      }

      // Android initialization settings
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize the plugin
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels for Android
      if (PlatformUtils.isAndroid) {
        await _createNotificationChannels();
      }

      _isInitialized = true;
      _logger.info(
        'NotificationServiceAndroid initialized',
        component: 'NotificationServiceAndroid',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize notifications',
        component: 'NotificationServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    const downloadChannel = AndroidNotificationChannel(
      _channelIdDownloads,
      'Download Progress',
      description: 'Notifications for download progress',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    const generalChannel = AndroidNotificationChannel(
      _channelIdGeneral,
      'General Notifications',
      description: 'General app notifications',
      importance: Importance.defaultImportance,
    );

    const errorChannel = AndroidNotificationChannel(
      _channelIdErrors,
      'Error Notifications',
      description: 'Error notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(downloadChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(generalChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(errorChannel);

    _logger.info(
      'Notification channels created',
      component: 'NotificationServiceAndroid',
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      _logger.info(
        'Notification tapped with payload: $payload',
        component: 'NotificationServiceAndroid',
      );
      // Handle navigation or actions based on payload
    }
  }

  /// Show a notification
  @override
  Future<void> show({
    required String title,
    required String body,
    bool isError = false,
    VoidCallback? onTap,
    String? payload,
    String? channelId,
  }) async {
    if (!systemNotificationsEnabled) return;

    if (!_isInitialized && !_permissionDenied) {
      await init();
    }

    if (_permissionDenied) return;

    try {
      _notificationIdCounter++;
      final notificationId = _notificationIdCounter;

      // Determine channel
      final effectiveChannelId =
          channelId ?? (isError ? _channelIdErrors : _channelIdGeneral);
      final effectiveChannelName = isError
          ? 'Error Notifications'
          : 'General Notifications';
      final effectiveChannelDescription = isError
          ? 'Error notifications'
          : 'General app notifications';
      final effectiveImportance = isError
          ? Importance.high
          : Importance.defaultImportance;
      final effectivePriority = isError
          ? Priority.high
          : Priority.defaultPriority;

      // Android notification details
      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        effectiveChannelId,
        effectiveChannelName,
        channelDescription: effectiveChannelDescription,
        importance: effectiveImportance,
        priority: effectivePriority,
        showProgress: false,
        icon: '@mipmap/ic_launcher',
      );

      // iOS notification details
      const iosPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload ?? 'notification_$notificationId',
      );

      _logger.info(
        'Notification shown: $title',
        component: 'NotificationServiceAndroid',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to show notification',
        component: 'NotificationServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Show download progress notification
  Future<void> showDownloadProgress({
    required String title,
    required String body,
    required double progress, // 0.0 to 1.0
    int? maxProgress,
    String? payload,
  }) async {
    if (!_isInitialized && !_permissionDenied) {
      await init();
    }

    if (_permissionDenied) return;

    try {
      final progressPercent = (progress * 100).toInt();
      final maxProg = maxProgress ?? 100;

      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        _channelIdDownloads,
        'Download Progress',
        channelDescription: 'Notifications for download progress',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: maxProg,
        progress: progressPercent,
        ongoing: true,
        autoCancel: false,
        icon: '@mipmap/ic_launcher',
      );

      const iosPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      );

      final notificationDetails = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      // Use a fixed ID for progress notifications to update the same notification
      const progressNotificationId = 999;

      await _flutterLocalNotificationsPlugin.show(
        progressNotificationId,
        title,
        body,
        notificationDetails,
        payload: payload ?? 'download_progress',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to show progress notification',
        component: 'NotificationServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to cancel notification $id (non-fatal): $e',
        component: 'NotificationServiceAndroid',
        stackTrace: stackTrace,
      );
    }
  }

  /// Cancel download progress notification
  Future<void> cancelDownloadProgress() async {
    await cancel(999);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to cancel all notifications (non-fatal): $e',
        component: 'NotificationServiceAndroid',
        stackTrace: stackTrace,
      );
    }
  }

  /// Request notification permission (for Android 13+)
  Future<bool> requestPermission() async {
    if (PlatformUtils.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isGranted) {
        return true;
      }

      final result = await Permission.notification.request();
      return result.isGranted;
    }
    return true;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (PlatformUtils.isAndroid) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    return true;
  }
}
