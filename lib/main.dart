import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_windows/webview_windows.dart';
import 'app.dart';
import 'services/ytdlp_service.dart';
import 'services/ffmpeg_service.dart';
import 'services/settings_service.dart';
import 'services/storage_service.dart';
import 'services/cookie_service.dart';
import 'services/notification_service.dart';
import 'services/logging_service.dart';
import 'providers/settings_provider.dart';
import 'providers/video_provider.dart';
import 'providers/download_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/update_provider.dart';
import 'providers/tool_update_provider.dart';

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
  final cookieService = CookieService();
  final storageService = StorageService();
  final notificationService = NotificationService();
  final loggingService = LoggingService();

  await Future.wait([
    settingsService.init(),
    cookieService.init(),
    storageService.init(),
    notificationService.init(),
    loggingService.init(),
  ]);

  loggingService.info('Application starting...', component: 'Main');

  // Only use WebView path if there's an active login (now using cached property)
  final isLoggedIn = await cookieService.isLoggedIn;
  final webViewPath = await cookieService.webViewPath;

  if (webViewPath != null) {
    try {
      await WebviewController.initializeEnvironment(userDataPath: webViewPath);
    } catch (_) {
      // Ignore if already initialized
    }
  }

  final effectiveWebViewPath = isLoggedIn ? webViewPath : null;

  final ytdlpService = YtdlpService(
    ytdlpPath: settingsService.settings.ytdlpPath,
    cookiePath: settingsService.settings.cookiePath,
    cookieBrowser: settingsService.settings.cookieBrowser,
    webViewPath: effectiveWebViewPath,
    ffmpegPath: settingsService.settings.ffmpegPath,
    notificationService: notificationService,
  );

  final ffmpegService = FfmpegService(
    ffmpegPath: settingsService.settings.ffmpegPath,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(
            settingsService: settingsService,
            ytdlpService: ytdlpService,
            ffmpegService: ffmpegService,
            cookieService: cookieService,
          )..init(),
        ),
        ChangeNotifierProvider(create: (_) => VideoProvider(ytdlpService)),
        ChangeNotifierProvider(
          create: (_) => DownloadProvider(ytdlpService, notificationService),
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
        Provider<CookieService>.value(value: cookieService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<LoggingService>.value(value: loggingService),
      ],
      child: const App(),
    ),
  );
}
