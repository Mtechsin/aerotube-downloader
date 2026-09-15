import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_motion.dart';
import 'providers/platform_settings_provider.dart';
import 'providers/navigation_provider.dart';
import 'services/notification/notification_service.dart';
import 'services/deep_link_handler.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/search_screen.dart';
import 'ui/screens/downloads_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/youtube_login_screen.dart';
import 'ui/screens/mobile_home_layout.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/widgets/update_dialog.dart';
import 'ui/widgets/navigation/app_navigation_rail.dart';
import 'ui/widgets/floating_progress_overlay.dart';
import 'core/utils/responsive_layout.dart';
import 'core/utils/platform_utils.dart';
import 'providers/update_provider.dart';

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with TickerProviderStateMixin {
  bool _hasAnimatedIn = false;
  bool _onboardingComplete = false;
  bool _hasCheckedUpdates = false;
  late final AnimationController _entranceController;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _deepLinkHandler = DeepLinkHandler();
  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    DownloadsScreen(),
    SettingsScreen(),
  ];
  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    if (PlatformUtils.isAndroid) {
      _onboardingComplete = context
          .read<PlatformSettingsProvider>()
          .onboardingComplete;
    } else {
      _onboardingComplete = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasAnimatedIn) {
        _entranceController.forward();
        _hasAnimatedIn = true;
      }
      _deepLinkHandler.init(context);
    });
  }

  @override
  void dispose() {
    _deepLinkHandler.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;
    final updateProvider = context.read<UpdateProvider>();
    await updateProvider.checkOnStartup();
    if (!mounted) return;
    final navContext = _navigatorKey.currentContext;
    if (updateProvider.hasUpdate && navContext != null && navContext.mounted) {
      showDialog(
        context: navContext,
        barrierDismissible: false,
        builder: (_) => const UpdateDialog(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = context.read<NotificationService>();
    final themeMode = context.select<PlatformSettingsProvider, ThemeMode>(
      (p) => p.themeMode,
    );
    final needsOnboarding =
        PlatformUtils.isAndroid &&
        context.select<PlatformSettingsProvider, bool>(
          (p) => !p.onboardingComplete && !_onboardingComplete,
        );
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: notificationService.scaffoldMessengerKey,
      title: 'YouTube Downloader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routes: {'/youtube_login': (context) => const YoutubeLoginScreen()},
      home: needsOnboarding
          ? OnboardingScreen(
              onComplete: () async {
                await context
                    .read<PlatformSettingsProvider>()
                    .setOnboardingComplete(true);
                if (mounted) setState(() => _onboardingComplete = true);
              },
            )
          : Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_hasCheckedUpdates) {
                    _hasCheckedUpdates = true;
                    _checkForUpdates();
                  }
                });
                if (PlatformUtils.isMobile) {
                  return Stack(
                    children: [
                      const MobileShell(
                        screens: [
                          MobileHomeLayout(),
                          SearchScreen(),
                          DownloadsScreen(),
                          SettingsScreen(),
                        ],
                      ),
                      // PF8: RepaintBoundary isolates overlay repaints from main scaffold
                      // Hide when SettingsScreen is active (local overlay already handles it)
                      Selector<NavigationProvider, int>(
                        selector: (_, p) => p.currentIndex,
                        builder: (context, idx, _) => idx == 3
                            ? const SizedBox.shrink()
                            : const RepaintBoundary(
                                child: FloatingProgressOverlay(),
                              ),
                      ),
                    ],
                  );
                }
                return Stack(
                  children: [
                    Scaffold(
                      backgroundColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor,
                      body: Row(
                        children: [
                          if (ResponsiveLayout.shouldShowSidebar(context))
                            AppNavigationRail(
                              entranceController: _entranceController,
                            )
                          else
                            const SizedBox.shrink(),
                          Expanded(
                            child: Selector<NavigationProvider, int>(
                              selector: (_, p) => p.currentIndex,
                              builder: (context, currentIndex, _) {
                                return AnimatedSwitcher(
                                  duration: appMotionDuration(
                                    context,
                                    AppMotion.short,
                                  ),
                                  switchInCurve: AppMotion.decelerate,
                                  switchOutCurve: AppMotion.accelerate,
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0.02, 0),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      ),
                                  child: _screens[currentIndex],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // PF8: RepaintBoundary isolates overlay repaints from main scaffold
                    Selector<NavigationProvider, int>(
                      selector: (_, p) => p.currentIndex,
                      builder: (context, idx, _) => idx == 3
                          ? const SizedBox.shrink()
                          : const RepaintBoundary(
                              child: FloatingProgressOverlay(),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
