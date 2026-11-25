import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'core/utils/platform_utils.dart';
import 'providers/update_provider.dart';
import 'ui/components/components.dart';

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
      duration: const Duration(milliseconds: 200),
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
      _deepLinkHandler.init(context, navigatorKey: _navigatorKey);
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
    final amoledDark = context.select<PlatformSettingsProvider, bool>(
      (p) => p.amoledDark,
    );
    final needsOnboarding =
        PlatformUtils.isAndroid &&
        context.select<PlatformSettingsProvider, bool>(
          (p) => !p.onboardingComplete && !_onboardingComplete,
        );
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: notificationService.scaffoldMessengerKey,
      title: 'AeroTube',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme:
          amoledDark && themeMode != ThemeMode.light
              ? AppTheme.amoledDarkTheme
              : AppTheme.darkTheme,
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
                    CallbackShortcuts(
                      bindings: <ShortcutActivator, VoidCallback>{
                        const SingleActivator(
                          LogicalKeyboardKey.digit1,
                          control: true,
                        ): () {
                          context.read<NavigationProvider>().switchToHome();
                        },
                        const SingleActivator(
                          LogicalKeyboardKey.digit2,
                          control: true,
                        ): () {
                          context.read<NavigationProvider>().switchToSearch();
                        },
                        const SingleActivator(
                          LogicalKeyboardKey.keyF,
                          control: true,
                        ): () {
                          context.read<NavigationProvider>().switchToSearch();
                        },
                        const SingleActivator(
                          LogicalKeyboardKey.digit3,
                          control: true,
                        ): () {
                          context.read<NavigationProvider>().switchToLibrary();
                        },
                        const SingleActivator(
                          LogicalKeyboardKey.digit4,
                          control: true,
                        ): () {
                          context.read<NavigationProvider>().switchToSettings();
                        },
                        const SingleActivator(
                          LogicalKeyboardKey.comma,
                          control: true,
                        ): () {
                          context.read<NavigationProvider>().switchToSettings();
                        },
                      },
                      child: Focus(
                        autofocus: true,
                        child: Scaffold(
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          body: Row(
                            children: [
                              AppNavigationRail(
                                entranceController: _entranceController,
                              ),
                              Expanded(
                                child: Selector<NavigationProvider, int>(
                                  selector: (_, p) => p.currentIndex,
                                  builder: (context, currentIndex, _) {
                                    return Column(
                                      children: [
                                        // 48 px transparent top strip with breadcrumb and StatusPills
                                        AeroDesktopTopStrip(
                                          currentIndex: currentIndex,
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 1100,
                                              ),
                                              child: _SmoothIndexedStack(
                                                index: currentIndex,
                                                duration: appMotionDuration(
                                                  context,
                                                  AppMotion.short,
                                                ),
                                                children: _screens,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Mini download tray docked at bottom of content
                                        const MiniDownloadTray(),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // PF8: RepaintBoundary isolates overlay repaints from main scaffold
                    Selector<NavigationProvider, int>(
                      selector: (_, p) => p.currentIndex,
                      builder: (context, idx, _) => idx == 3
                          ? const SizedBox.shrink()
                          : const RepaintBoundary(
                              child: FloatingProgressOverlay(
                                showDownloadProgress: false,
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

/// Keeps all tab subtrees alive in an [IndexedStack] for instant 0 ms tab
/// switches while running a lightweight fade on tab changes.
class _SmoothIndexedStack extends StatefulWidget {
  final int index;
  final Duration duration;
  final List<Widget> children;

  const _SmoothIndexedStack({
    required this.index,
    required this.duration,
    required this.children,
  });

  @override
  State<_SmoothIndexedStack> createState() => _SmoothIndexedStackState();
}

class _SmoothIndexedStackState extends State<_SmoothIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
    _opacity = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.decelerate),
    );
  }

  @override
  void didUpdateWidget(covariant _SmoothIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.index != widget.index) {
      if (widget.duration == Duration.zero) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: IndexedStack(
        index: widget.index,
        children: widget.children,
      ),
    );
  }
}
