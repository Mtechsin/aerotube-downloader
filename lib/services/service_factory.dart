import '../core/utils/platform_utils.dart';
import 'ytdlp/ytdlp_service_windows.dart';
import 'ytdlp/ytdlp_service_android.dart';
import 'ytdlp/ytdlp_tool_service.dart';
import 'ffmpeg/ffmpeg_service_windows.dart';
import 'ffmpeg/ffmpeg_service_android.dart';
import 'ffmpeg/ffmpeg_tool_service.dart';
import 'cookie/cookie_service.dart';
import 'cookie/cookie_service_android.dart';
import 'notification/notification_service.dart';
import 'notification/notification_service_android.dart';
import 'core/auth_service.dart';

class Services {
  static final Services _instance = Services._internal();
  factory Services() => _instance;
  Services._internal();

  YtdlpService? _ytdlpServiceWindows;
  YtdlpServiceAndroid? _ytdlpServiceAndroid;
  FfmpegService? _ffmpegServiceWindows;
  FfmpegServiceAndroid? _ffmpegServiceAndroid;
  CookieService? _cookieServiceWindows;
  CookieServiceAndroid? _cookieServiceAndroid;
  NotificationService? _notificationServiceWindows;
  NotificationServiceAndroid? _notificationServiceAndroid;
  AuthService? _authService;

  YtdlpToolService get ytdlpService {
    if (PlatformUtils.isAndroid) {
      _ytdlpServiceAndroid ??= YtdlpServiceAndroid();
      return _ytdlpServiceAndroid!;
    } else {
      _ytdlpServiceWindows ??= YtdlpService();
      return _ytdlpServiceWindows!;
    }
  }

  FfmpegToolService get ffmpegService {
    if (PlatformUtils.isAndroid) {
      _ffmpegServiceAndroid ??= FfmpegServiceAndroid();
      return _ffmpegServiceAndroid!;
    } else {
      _ffmpegServiceWindows ??= FfmpegService();
      return _ffmpegServiceWindows!;
    }
  }

  CookieService get cookieService {
    if (PlatformUtils.isAndroid) {
      _cookieServiceAndroid ??= CookieServiceAndroid();
      return _cookieServiceAndroid!;
    } else {
      _cookieServiceWindows ??= CookieService();
      return _cookieServiceWindows!;
    }
  }

  NotificationService get notificationService {
    if (PlatformUtils.isAndroid) {
      _notificationServiceAndroid ??= NotificationServiceAndroid();
      return _notificationServiceAndroid!;
    } else {
      _notificationServiceWindows ??= NotificationService();
      return _notificationServiceWindows!;
    }
  }

  AuthService get authService {
    _authService ??= AuthService();
    return _authService!;
  }

  Future<void> initializeAll() async {
    if (PlatformUtils.isAndroid) {
      await (cookieService as CookieServiceAndroid).init();
      await (notificationService as NotificationServiceAndroid).init();
    } else {
      await notificationService.init();
      await cookieService.init();
    }
  }
}

final services = Services();
