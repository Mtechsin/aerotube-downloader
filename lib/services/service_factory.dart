import '../core/utils/platform_utils.dart';
import 'ytdlp_service.dart';
import 'ytdlp_service_android.dart';
import 'ffmpeg_service.dart';
import 'ffmpeg_service_android.dart';
import 'cookie_service.dart';
import 'cookie_service_android.dart';
import 'notification_service.dart';
import 'notification_service_android.dart';
import 'auth_service.dart';

/// Unified service factory that provides platform-specific implementations
class Services {
  // Singleton pattern
  static final Services _instance = Services._internal();
  factory Services() => _instance;
  Services._internal();

  // Service instances
  YtdlpService? _ytdlpServiceWindows;
  YtdlpServiceAndroid? _ytdlpServiceAndroid;
  FfmpegService? _ffmpegServiceWindows;
  FfmpegServiceAndroid? _ffmpegServiceAndroid;
  CookieService? _cookieServiceWindows;
  CookieServiceAndroid? _cookieServiceAndroid;
  NotificationService? _notificationServiceWindows;
  NotificationServiceAndroid? _notificationServiceAndroid;
  AuthService? _authService;

  /// Get YtdlpService (platform-specific)
  dynamic get ytdlpService {
    if (PlatformUtils.isAndroid) {
      _ytdlpServiceAndroid ??= YtdlpServiceAndroid();
      return _ytdlpServiceAndroid!;
    } else {
      _ytdlpServiceWindows ??= YtdlpService();
      return _ytdlpServiceWindows!;
    }
  }

  /// Get FfmpegService (platform-specific)
  dynamic get ffmpegService {
    if (PlatformUtils.isAndroid) {
      _ffmpegServiceAndroid ??= FfmpegServiceAndroid();
      return _ffmpegServiceAndroid!;
    } else {
      _ffmpegServiceWindows ??= FfmpegService();
      return _ffmpegServiceWindows!;
    }
  }

  /// Get CookieService (platform-specific)
  CookieService get cookieService {
    if (PlatformUtils.isAndroid) {
      _cookieServiceAndroid ??= CookieServiceAndroid();
      return _cookieServiceAndroid!;
    } else {
      _cookieServiceWindows ??= CookieService();
      return _cookieServiceWindows!;
    }
  }

  /// Get NotificationService (platform-specific)
  NotificationService get notificationService {
    if (PlatformUtils.isAndroid) {
      _notificationServiceAndroid ??= NotificationServiceAndroid();
      return _notificationServiceAndroid!;
    } else {
      _notificationServiceWindows ??= NotificationService();
      return _notificationServiceWindows!;
    }
  }

  /// Get AuthService (available on all platforms, but primarily used on Android)
  AuthService get authService {
    _authService ??= AuthService();
    return _authService!;
  }

  /// Initialize all services
  Future<void> initializeAll() async {
    if (PlatformUtils.isAndroid) {
      // Initialize Android services
      await (cookieService as CookieServiceAndroid).init();
      await (notificationService as NotificationServiceAndroid).init();
    } else {
      // Initialize Windows services
      await notificationService.init();
      await cookieService.init();
    }
  }
}

/// Global service instance for easy access
final services = Services();
