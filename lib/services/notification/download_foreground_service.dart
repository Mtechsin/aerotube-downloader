import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/platform_utils.dart';
import '../core/logging_service.dart';

/// Android Foreground Service for managing long-running downloads
/// Handles Doze mode, battery optimization, and persistent notifications
class DownloadForegroundService {
  // B26 fix: use distinct ID and unified channel to avoid fighting with
  // native DownloadService (which owns ID 1000 via startForeground).
  // Dart previously used 1000 + 'download_service' causing duplicate
  // channels and system "running in background" placeholder on cancel.
  // Now: 1001 (Dart) vs 1000 (native), shared channel 'download_service_channel'.
  // On Android Dart delegates notification ownership entirely to native.
  static const int _notificationId = 1001;
  static const String _channelId = 'download_service_channel';
  static const String _channelName = 'Active Downloads';
  static const String _channelDescription = 'Shows active download progress';
  static const MethodChannel _serviceChannel = MethodChannel(
    'com.aerotube.youtube_downloader/download_service',
  );

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final LoggingService _logger = LoggingService();

  bool _isInitialized = false;
  final Map<String, DownloadProgress> _activeDownloads = {};

  // R4 throttle: yt-dlp can emit several progress events per second; each one
  // becomes a native notification re-post. Skip sends unless the rounded
  // percentage moved or the status text changed, with a minimum interval.
  static const Duration _minSendInterval = Duration(milliseconds: 400);
  final Map<String, int> _lastSentPercent = {};
  final Map<String, DateTime> _lastSentAt = {};
  final Map<String, String> _lastSentStatus = {};

  /// Initialize the foreground service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permission on Android 13+. Denied is non-fatal —
      // still initialize so battery-opt and channels can be set up.
      if (PlatformUtils.isAndroid) {
        try {
          final status = await Permission.notification.status;
          if (!status.isGranted) {
            final result = await Permission.notification.request();
            if (!result.isGranted) {
              _logger.warning(
                'Notification permission denied; continuing init without popup notifications',
                component: 'DownloadForegroundService',
              );
            }
          }
        } catch (e) {
          _logger.warning(
            'Notification permission request failed: $e',
            component: 'DownloadForegroundService',
          );
        }

        // Request ignore battery optimization for background downloads
        await _requestIgnoreBatteryOptimizations();
      }

      // Initialize notifications
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(initializationSettings);

      // Create notification channel
      if (PlatformUtils.isAndroid) {
        await _createDownloadChannel();
      }

      _isInitialized = true;
      _logger.info(
        'DownloadForegroundService initialized',
        component: 'DownloadForegroundService',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize DownloadForegroundService',
        component: 'DownloadForegroundService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Create notification channel for downloads
  Future<void> _createDownloadChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low,
      showBadge: false,
      playSound: false,
      enableVibration: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _logger.info(
      'Download notification channel created',
      component: 'DownloadForegroundService',
    );
  }

  /// Checks battery-optimization status without prompting. The actual
  /// exemption request lives in Settings → Unrestricted Battery so the user
  /// never gets an unexpected system dialog in the middle of a download.
  Future<void> _requestIgnoreBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        _logger.info(
          'Battery optimization is active — background downloads may pause. '
          'Enable "Unrestricted Battery" in Settings.',
          component: 'DownloadForegroundService',
        );
      }
    } catch (e) {
      _logger.warning(
        'Failed to check battery optimization status: $e',
        component: 'DownloadForegroundService',
      );
    }
  }

  /// Start a download with actual Android foreground service
  Future<void> startDownload({
    required String downloadId,
    required String url,
    required String outputPath,
    required String title,
    String? format,
    String? cookiesPath,
    String? userAgent,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _activeDownloads[downloadId] = DownloadProgress(
        title: title,
        progress: 0.0,
        statusText: 'Starting download...',
        startTime: DateTime.now(),
      );

      if (PlatformUtils.isAndroid) {
        await _serviceChannel.invokeMethod<bool>('startDownloadService', {
          'downloadId': downloadId,
          'url': url,
          'outputPath': outputPath,
          'format': format,
          'cookiesPath': cookiesPath,
          'userAgent': userAgent,
          'title': title,
        });
      }

      await _updateDownloadNotification();

      _logger.info(
        'Started download service for: $downloadId',
        component: 'DownloadForegroundService',
      );
    } catch (e) {
      _logger.error(
        'Failed to start download service',
        component: 'DownloadForegroundService',
        error: e,
      );
      rethrow;
    }
  }

  /// Update download progress
  Future<void> updateProgress({
    required String downloadId,
    required double progress,
    double? speed,
    String? statusText,
  }) async {
    if (_activeDownloads.containsKey(downloadId)) {
      final existing = _activeDownloads[downloadId]!;
      final effectiveStatus = statusText ?? existing.statusText;
      _activeDownloads[downloadId] = existing.copyWith(
        progress: progress,
        speed: speed,
        statusText: effectiveStatus,
      );

      // R4: On Android the foreground notification (ID 1000) is owned by the
      // native DownloadService. Forward the real Dart-side progress to it via
      // the service channel instead of posting a competing Dart notification.
      if (PlatformUtils.isAndroid) {
        await _forwardProgressToNative(
          downloadId: downloadId,
          progress: progress,
          statusText: effectiveStatus,
        );
        return;
      }

      // Update notification
      await _updateDownloadNotification();
    }
  }

  /// Forward progress to the native DownloadService foreground notification.
  /// Throttled so rapid yt-dlp events don't spam NotificationManager.
  Future<void> _forwardProgressToNative({
    required String downloadId,
    required double progress,
    required String? statusText,
  }) async {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    final now = DateTime.now();
    final lastAt = _lastSentAt[downloadId];
    final statusChanged = statusText != null && statusText != _lastSentStatus[downloadId];
    final percentChanged = percent != _lastSentPercent[downloadId];

    final withinCooldown = lastAt != null && now.difference(lastAt) < _minSendInterval;
    if (withinCooldown && !statusChanged && !percentChanged) return;

    _lastSentPercent[downloadId] = percent;
    _lastSentAt[downloadId] = now;
    if (statusText != null) _lastSentStatus[downloadId] = statusText;

    try {
      await _serviceChannel.invokeMethod<bool>('updateNotificationProgress', {
        'downloadId': downloadId,
        'progress': progress.clamp(0.0, 1.0),
        'statusText': statusText,
      });
    } catch (e) {
      // Progress display is auxiliary; never break the download over it.
      _logger.warning(
        'Failed to forward progress to native notification: $e',
        component: 'DownloadForegroundService',
      );
    }
  }

  /// Complete a download
  Future<void> completeDownload(String downloadId) async {
    _activeDownloads.remove(downloadId);
    _lastSentPercent.remove(downloadId);
    _lastSentAt.remove(downloadId);
    _lastSentStatus.remove(downloadId);

    if (PlatformUtils.isAndroid) {
      if (_activeDownloads.isNotEmpty) {
        // Other downloads still active: tell native to drop just this task so
        // the foreground notification reflects the remaining ones.
        try {
          await _serviceChannel.invokeMethod<bool>('completeDownloadInService', {
            'downloadId': downloadId,
          });
        } catch (e) {
          _logger.warning(
            'Failed to signal native download completion: $e',
            component: 'DownloadForegroundService',
          );
        }
        return;
      }
      // Last download: stopService() below tears down the native foreground
      // notification (stopForeground + stopSelf + cancel in onDestroy).
    }

    // Stop service if no more active downloads
    if (_activeDownloads.isEmpty) {
      await stopService();
    }

    _logger.info(
      'Download completed: $downloadId',
      component: 'DownloadForegroundService',
    );
  }

  /// Stop the foreground service
  Future<void> stopService() async {
    if (PlatformUtils.isAndroid) {
      try {
        await _serviceChannel.invokeMethod<bool>('stopDownloadService');
      } catch (e) {
        _logger.warning(
          'Failed to stop native service bridge: $e',
          component: 'DownloadForegroundService',
        );
      }
    }
    // Notification cleanup is best effort. A release build with an older
    // notification plugin/shrinker configuration must not turn a completed
    // download into a failed one.
    await _cancelNotification();
    _logger.info(
      'Download service stopped',
      component: 'DownloadForegroundService',
    );
  }

  /// Cancel a download
  Future<void> cancelDownload(String downloadId) async {
    _activeDownloads.remove(downloadId);
    _lastSentPercent.remove(downloadId);
    _lastSentAt.remove(downloadId);
    _lastSentStatus.remove(downloadId);
    if (PlatformUtils.isAndroid) {
      try {
        await _serviceChannel.invokeMethod<bool>('cancelDownload', {
          'downloadId': downloadId,
        });
      } catch (e) {
        _logger.warning(
          'Failed to cancel native service download: $e',
          component: 'DownloadForegroundService',
        );
      }
    }
    await _updateDownloadNotification();

    _logger.info(
      'Download cancelled: $downloadId',
      component: 'DownloadForegroundService',
    );
  }

  /// Update the download notification
  Future<void> _updateDownloadNotification() async {
    // B26: On Android the foreground notification (ID 1000) is owned by the
    // native DownloadService via startForeground(). Dart must not post to or
    // cancel that ID, otherwise the system shows "running in background".
    // Dart uses distinct ID 1001 and unified channel, but to avoid duplicate
    // notifications we delegate entirely to native on Android.
    if (PlatformUtils.isAndroid) {
      return;
    }
    try {
      if (_activeDownloads.isEmpty) {
        // Cancel notification if no active downloads
        await _cancelNotification();
        return;
      }

      // If only one download, show it directly
      if (_activeDownloads.length == 1) {
        final download = _activeDownloads.values.first;
        await _showSingleDownloadNotification(download);
      } else {
        // Multiple downloads, show summary
        await _showMultiDownloadNotification();
      }
    } catch (e, stackTrace) {
      // Notifications are auxiliary UI; never fail or change download state
      // because a plugin call failed on a particular Android release.
      _logger.warning(
        'Notification update failed (non-fatal): $e',
        component: 'DownloadForegroundService',
        stackTrace: stackTrace,
      );
    }
  }

  /// Cancel the service notification without allowing plugin errors to escape.
  Future<void> _cancelNotification() async {
    // B26: Native service owns ID 1000. Dart owns 1001; on Android delegate
    // dismissal to native stopForeground/stopSelf to avoid the system
    // placeholder. Still clean up any stale Dart ID 1001 if present.
    if (PlatformUtils.isAndroid) {
      try {
        await _notifications.cancel(_notificationId); // 1001, safe
      } catch (e, stackTrace) {
        _logger.warning(
          'Notification cancellation failed (non-fatal): $e',
          component: 'DownloadForegroundService',
          stackTrace: stackTrace,
        );
      }
      return;
    }
    try {
      await _notifications.cancel(_notificationId);
    } catch (e, stackTrace) {
      _logger.warning(
        'Notification cancellation failed (non-fatal): $e',
        component: 'DownloadForegroundService',
        stackTrace: stackTrace,
      );
    }
  }

  /// Show notification for single download
  Future<void> _showSingleDownloadNotification(
    DownloadProgress download,
  ) async {
    // B26: delegated to native on Android
    if (PlatformUtils.isAndroid) return;
    final progressPercent = (download.progress * 100).toInt();
    final statusText = download.statusText ?? 'Downloading...';

    final showProgress = download.progress > 0;
    final bodyText = showProgress
        ? '$statusText • $progressPercent%'
        : statusText;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: showProgress,
      maxProgress: 100,
      progress: progressPercent,
      icon: '@mipmap/ic_launcher',
      onlyAlertOnce: true,
      showWhen: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationId,
      download.title,
      bodyText,
      notificationDetails,
    );
  }

  /// Show notification for multiple downloads
  Future<void> _showMultiDownloadNotification() async {
    // B26: delegated to native on Android
    if (PlatformUtils.isAndroid) return;
    final totalDownloads = _activeDownloads.length;
    final activeDownloads = _activeDownloads.values
        .where((d) => d.progress < 1.0)
        .toList();

    // Show first active download or "Multiple downloads"
    String title;
    String body;
    int progress;

    if (activeDownloads.isNotEmpty) {
      final first = activeDownloads.first;
      title = '${first.title} +${totalDownloads - 1} more';
      body = first.statusText ?? 'Downloading...';
      progress = (first.progress * 100).toInt();
    } else {
      title = '$totalDownloads downloads active';
      body = 'Processing...';
      progress = 0;
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      icon: '@mipmap/ic_launcher',
      onlyAlertOnce: true,
      showWhen: false,
      styleInformation: const InboxStyleInformation(
        [],
        contentTitle: 'Active Downloads',
        summaryText: '%d downloads',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationId,
      title,
      '$body • $progress%',
      notificationDetails,
    );
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    if (PlatformUtils.isAndroid) {
      try {
        await _serviceChannel.invokeMethod<bool>('stopDownloadService');
      } catch (_) {
        // Best effort; continue local cleanup.
      }
      // B26: don't use cancelAll() on Android — it would clear the native
      // foreground notification (ID 1000) outside its lifecycle. Only clear
      // Dart's distinct ID 1001.
      try {
        await _notifications.cancel(_notificationId);
      } catch (e, stackTrace) {
        _logger.warning(
          'Notification cancellation failed (non-fatal): $e',
          component: 'DownloadForegroundService',
          stackTrace: stackTrace,
        );
      }
      _activeDownloads.clear();
      _logger.info(
        'All notifications cancelled',
        component: 'DownloadForegroundService',
      );
      return;
    }
    try {
      await _notifications.cancelAll();
    } catch (e, stackTrace) {
      _logger.warning(
        'Notification cancellation failed (non-fatal): $e',
        component: 'DownloadForegroundService',
        stackTrace: stackTrace,
      );
    }
    _activeDownloads.clear();
    _logger.info(
      'All notifications cancelled',
      component: 'DownloadForegroundService',
    );
  }

  /// Get active downloads count
  int get activeDownloadsCount => _activeDownloads.length;

  /// Check if service is running
  bool get isRunning => _isInitialized;
}

/// Download progress data class
class DownloadProgress {
  final String title;
  final double progress;
  final double? speed;
  final String? statusText;
  final DateTime startTime;

  const DownloadProgress({
    required this.title,
    required this.progress,
    this.speed,
    this.statusText,
    required this.startTime,
  });

  DownloadProgress copyWith({
    String? title,
    double? progress,
    double? speed,
    String? statusText,
    DateTime? startTime,
  }) {
    return DownloadProgress(
      title: title ?? this.title,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      statusText: statusText ?? this.statusText,
      startTime: startTime ?? this.startTime,
    );
  }

  @override
  String toString() => 'DownloadProgress(title: $title, progress: $progress)';
}
