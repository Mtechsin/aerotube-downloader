import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/utils/platform_utils.dart';
import 'logging_service.dart';

/// Android Foreground Service for managing long-running downloads
/// Handles Doze mode, battery optimization, and persistent notifications
class DownloadForegroundService {
  static const int _notificationId = 1000;
  static const String _channelId = 'download_service';
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

  /// Initialize the foreground service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permission on Android 13+
      if (PlatformUtils.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final result = await Permission.notification.request();
          if (!result.isGranted) {
            _logger.warning(
              'Notification permission denied',
              component: 'DownloadForegroundService',
            );
            return;
          }
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

  /// Request to ignore battery optimizations for this app
  Future<void> _requestIgnoreBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        final result = await Permission.ignoreBatteryOptimizations.request();
        if (result.isGranted) {
          _logger.info(
            'Battery optimization ignored',
            component: 'DownloadForegroundService',
          );
        } else {
          _logger.warning(
            'Battery optimization ignore request denied',
            component: 'DownloadForegroundService',
          );
        }
      }
    } catch (e) {
      _logger.warning(
        'Failed to request battery optimization ignore: $e',
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
      _activeDownloads[downloadId] = existing.copyWith(
        progress: progress,
        speed: speed,
        statusText: statusText ?? existing.statusText,
      );

      // Update notification
      await _updateDownloadNotification();
    }
  }

  /// Complete a download
  Future<void> completeDownload(String downloadId) async {
    _activeDownloads.remove(downloadId);

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
    await _notifications.cancel(_notificationId);
    _logger.info(
      'Download service stopped',
      component: 'DownloadForegroundService',
    );
  }

  /// Cancel a download
  Future<void> cancelDownload(String downloadId) async {
    _activeDownloads.remove(downloadId);
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
    if (_activeDownloads.isEmpty) {
      // Cancel notification if no active downloads
      await _notifications.cancel(_notificationId);
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
  }

  /// Show notification for single download
  Future<void> _showSingleDownloadNotification(
    DownloadProgress download,
  ) async {
    final progressPercent = (download.progress * 100).toInt();
    final statusText = download.statusText ?? 'Downloading...';

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
      '$statusText • $progressPercent%',
      notificationDetails,
    );
  }

  /// Show notification for multiple downloads
  Future<void> _showMultiDownloadNotification() async {
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
    }
    await _notifications.cancelAll();
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
