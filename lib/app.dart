import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'core/theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'providers/download_provider.dart';
import 'providers/update_provider.dart';
import 'services/notification_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/downloads_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/youtube_login_screen.dart';
import 'ui/widgets/gradient_background.dart';
import 'ui/widgets/update_dialog.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentIndex = 0;

  final _screens = const [HomeScreen(), DownloadsScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    // Check for updates after the app is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    final updateProvider = context.read<UpdateProvider>();
    await updateProvider.checkOnStartup();

    // If update is available, show dialog
    if (updateProvider.hasUpdate && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const UpdateDialog(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final notificationService = context.read<NotificationService>();

    return MaterialApp(
      scaffoldMessengerKey: notificationService.scaffoldMessengerKey,
      title: 'YouTube Downloader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsProvider.themeMode,
      routes: {'/youtube_login': (context) => const YoutubeLoginScreen()},
      home: GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              // Custom Glassmorphic Navigation Rail
              _buildCustomNavigationRail(),

              // Content
              Expanded(
                child: IndexedStack(index: _currentIndex, children: _screens),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomNavigationRail() {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _buildNavItem(
            index: 0,
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
          ),
          const SizedBox(height: 32),
          _buildNavItem(
            index: 1,
            icon: Icons.download_outlined,
            selectedIcon: Icons.download_rounded,
            label: 'Downloads',
            showBadge: true,
          ),
          const SizedBox(height: 32),
          _buildNavItem(
            index: 2,
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: 'Settings',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    bool showBadge = false,
  }) {
    final isSelected = _currentIndex == index;

    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, child) {
        final badgeCount = showBadge ? downloadProvider.activeCount : 0;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior:
                HitTestBehavior.translucent, // Capture taps on empty space
            onTap: () {
              FocusScope.of(context).unfocus(); // Dismiss keyboard/input focus
              setState(() => _currentIndex = index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200), // Slightly faster
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                vertical: 4,
              ), // Add vertical touch padding
              child: Row(
                children: [
                  // Selection indicator - vertical bar on the left
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: 3,
                    height: isSelected ? 40 : 0,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Icon and label
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedScale(
                              scale: isSelected ? 1.0 : 0.9,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              child: Icon(
                                isSelected ? selectedIcon : icon,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                size: 32,
                              ),
                            ),
                            if (badgeCount > 0)
                              Positioned(
                                right: -6,
                                top: -4,
                                child:
                                    Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 18,
                                            minHeight: 18,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$badgeCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                        .animate(
                                          onPlay: (controller) =>
                                              controller.repeat(reverse: true),
                                        )
                                        .scale(
                                          begin: const Offset(1, 1),
                                          end: const Offset(1.15, 1.15),
                                          duration: const Duration(
                                            milliseconds: 800,
                                          ),
                                          curve: Curves.easeInOut,
                                        ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                          child: Text(label),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
