import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/ytdlp_service.dart';
import 'services/ytdlp_service_android.dart';
import 'services/ffmpeg_service.dart';
import 'services/ffmpeg_service_android.dart';
import 'services/settings_service.dart';
import 'services/storage_service.dart';
import 'services/cookie_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/logging_service.dart';
import 'services/service_factory.dart';

import 'providers/platform_settings_provider.dart';
import 'providers/video_provider.dart';
import 'providers/download_provider.dart';
import 'providers/mobile_download_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/update_provider.dart';
import 'providers/tool_update_provider.dart';
import 'providers/search_provider.dart';
import 'providers/navigation_provider.dart';
import 'core/utils/platform_utils.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'models/download_item.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register Adapters
  Hive.registerAdapter(DownloadItemAdapter());
  Hive.registerAdapter(DownloadStatusAdapter());

  // Initialize services
  final settingsService = SettingsService();
  final storageService = StorageService();
  final loggingService = LoggingService();
  final authService = AuthService();

  await Future.wait([
    settingsService.init(),
    storageService.init(),
    loggingService.init(),
  ]);

  loggingService.info('Application starting...', component: 'Main');

  // Limit image cache to reduce memory usage
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      100 * 1024 * 1024; // 100MB

  // Initialize global services singleton
  await services.initializeAll();

  // Platform-specific initialization
  final isAndroid = PlatformUtils.isAndroid;

  loggingService.info(
    'Platform detected: ${PlatformUtils.platformName}',
    component: 'Main',
  );
  loggingService.info('isAndroid = $isAndroid', component: 'Main');

  // Get platform-specific services
  final cookieService = services.cookieService;
  final notificationService = services.notificationService;

  // Only use WebView path if there's an active login
  final isLoggedIn = await cookieService.isLoggedIn;
  String? webViewPath;
  if (!isAndroid) {
    webViewPath = await cookieService.webViewPath;
  }

  final effectiveWebViewPath = isLoggedIn ? webViewPath : null;

  // Create platform-specific yt-dlp and FFmpeg services
  final dynamic ytdlpService;
  final dynamic ffmpegService;

  if (isAndroid) {
    // Android: use yt-dlp binary service
    ytdlpService = YtdlpServiceAndroid(
      cookiePath: settingsService.settings.cookiePath,
      webViewPath: effectiveWebViewPath,
      notificationService: notificationService,
    );

    ffmpegService = FfmpegServiceAndroid();

    loggingService.info('Using Android YtdlpServiceAndroid', component: 'Main');
  } else {
    // Windows/Desktop: use Process-based yt-dlp service
    ytdlpService = YtdlpService(
      ytdlpPath: settingsService.settings.ytdlpPath,
      cookiePath: settingsService.settings.cookiePath,
      cookieBrowser: settingsService.settings.cookieBrowser,
      webViewPath: effectiveWebViewPath,
      notificationService: notificationService,
    );

    ffmpegService = FfmpegService(
      ffmpegPath: settingsService.settings.ffmpegPath,
    );

    loggingService.info('Using Windows services', component: 'Main');
  }

  // Warm yt-dlp in the background so the shell can render immediately.
  ytdlpService.initialize().then((_) {
    loggingService.info('yt-dlp service initialized', component: 'Main');
  }).catchError((e) {
    loggingService.warning(
      'yt-dlp initialization failed: $e',
      component: 'Main',
    );
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PlatformSettingsProvider(
            settingsService: settingsService,
            ytdlpService: ytdlpService,
            ffmpegService: ffmpegService,
            cookieService: cookieService,
          )..init(),
        ),
        ChangeNotifierProvider(create: (_) => VideoProvider(ytdlpService)),
        if (PlatformUtils.isMobile)
          ChangeNotifierProvider<MobileDownloadProvider>(
            create: (_) => MobileDownloadProvider(
              ytdlpService: ytdlpService,
              cookieService: cookieService,
            )..initialize(),
          ),
        ChangeNotifierProvider<DownloadProvider>(
          create: (context) => DownloadProvider(
            ytdlpService,
            notificationService,
            context.read<PlatformSettingsProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PlaylistProvider(ytdlpService: ytdlpService),
        ),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
        ChangeNotifierProvider(
          create: (_) => ToolUpdateProvider(
            ytdlpService: ytdlpService,
            ffmpegService: ffmpegService,
          )..init(),
        ),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        Provider<CookieService>.value(value: cookieService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<LoggingService>.value(value: loggingService),
        Provider<AuthService>.value(value: authService),
      ],
      child: const App(),
    ),
  );
}
