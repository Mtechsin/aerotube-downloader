import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'core/theme/app_theme.dart';
import 'providers/platform_settings_provider.dart';
import 'providers/download_provider.dart';
import 'providers/update_provider.dart';
import 'providers/navigation_provider.dart';
import 'services/notification_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/search_screen.dart';
import 'ui/screens/downloads_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/youtube_login_screen.dart';
import 'ui/screens/mobile_home_layout.dart';
import 'ui/screens/mobile_fetch_screen.dart';
import 'ui/widgets/update_dialog.dart';
import 'core/utils/responsive_layout.dart';
import 'core/utils/platform_utils.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with TickerProviderStateMixin {
  int _previousBadgeCount = 0;
  bool _hasAnimatedIn = false;

  late final AnimationController _entranceController;

  final _screens = const [
    HomeScreen(),
    SearchScreen(),
    DownloadsScreen(),
    SettingsScreen(),
  ];

  // Navigation item configuration
  static const List<_NavItemConfig> _navItems = [
    _NavItemConfig(icon: Icons.home_outlined, label: 'Home'),
    _NavItemConfig(icon: Icons.search_outlined, label: 'Search'),
    _NavItemConfig(
      icon: Icons.download_outlined,
      label: 'Library',
      showBadge: true,
    ),
    _NavItemConfig(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // Check for updates after the app is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
      // Trigger entrance animation
      if (!_hasAnimatedIn) {
        _entranceController.forward();
        _hasAnimatedIn = true;
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
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
    final notificationService = context.read<NotificationService>();
    final themeMode = context.select<PlatformSettingsProvider, ThemeMode>(
      (provider) => provider.themeMode,
    );

    return MaterialApp(
      scaffoldMessengerKey: notificationService.scaffoldMessengerKey,
      title: 'YouTube Downloader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routes: {'/youtube_login': (context) => const YoutubeLoginScreen()},
      home: Builder(
        builder: (context) {
          // Use MobileShell for mobile platforms
          if (PlatformUtils.isMobile) {
            return MobileShell(
              screens: const [
                MobileFetchScreen(),
                SearchScreen(),
                DownloadsScreen(),
                SettingsScreen(),
              ],
            );
          }

          // Desktop layout
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Row(
              children: [
                if (ResponsiveLayout.shouldShowSidebar(context))
                  _buildCustomNavigationRail(context)
                else
                  const SizedBox.shrink(),
                // Content
                Expanded(
                  child: Selector<NavigationProvider, int>(
                    selector: (_, provider) => provider.currentIndex,
                    builder: (context, currentIndex, _) {
                      return IndexedStack(
                        index: currentIndex,
                        children: _screens,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomNavigationRail(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate item height for indicator positioning
    const double itemHeight = 48.0;
    const double itemSpacing = 16.0;

    return Container(
          width: 76,
          margin: const EdgeInsets.fromLTRB(16, 24, 0, 24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.14),
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 24.0,
                horizontal: 0.0,
              ),
              child: Column(
                children: [
                  const Spacer(),

                  // Navigation Items
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_navItems.length, (index) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < _navItems.length - 1
                              ? itemSpacing
                              : 0,
                        ),
                        child: _buildNavItem(
                          context: context,
                          index: index,
                          config: _navItems[index],
                          itemHeight: itemHeight,
                        ),
                      );
                    }),
                  ),

                  // Bottom: User Profile Avatar
                  const Spacer(),
                  _buildUserAvatar(),
                ],
              ),
            ),
          ),
        )
        .animate(controller: _entranceController)
        .fadeIn(duration: 220.ms, curve: Curves.easeOut)
        .slideX(
          begin: -0.08,
          end: 0,
          duration: 280.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildUserAvatar() {
    return Consumer<PlatformSettingsProvider>(
      builder: (context, provider, _) {
        final isAuth = provider.isCookieActive;
        final theme = Theme.of(context);

        return Tooltip(
              message: isAuth ? 'YouTube Profile' : 'Guest Account',
              preferBelow: false,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAuth
                      ? theme.colorScheme.primary.withValues(alpha: 0.18)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  border: Border.all(
                    color: isAuth
                        ? theme.colorScheme.primary.withValues(alpha: 0.45)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: isAuth
                      ? (provider.youtubeProfileImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: Image.network(
                                  provider.youtubeProfileImageUrl!,
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.person,
                                        color: Color(0xFF8B5CF6),
                                        size: 20,
                                      ),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Color(0xFF8B5CF6),
                                size: 20,
                              ))
                      : const Text(
                          'G',
                          style: TextStyle(
                            color: Color(0xFF9E9EA4),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            )
            .animate(controller: _entranceController)
            .fadeIn(delay: 500.ms, duration: 400.ms)
            .scale(delay: 500.ms, duration: 400.ms, curve: Curves.easeOutBack);
      },
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required _NavItemConfig config,
    required double itemHeight,
  }) {
    final currentIndex = context.select<NavigationProvider, int>(
      (provider) => provider.currentIndex,
    );
    final isSelected = currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final badgeCount = config.showBadge
        ? context.select<DownloadProvider, int>((provider) => provider.activeCount)
        : 0;
    final badgeIncreased = badgeCount > _previousBadgeCount;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && config.showBadge) {
        _previousBadgeCount = badgeCount;
      }
    });

    return _NavItemWidget(
      index: index,
      icon: config.icon,
      label: config.label,
      isSelected: isSelected,
      isDark: isDark,
      badgeCount: badgeCount,
      badgeIncreased: badgeIncreased,
      itemHeight: itemHeight,
      theme: theme,
      entranceController: _entranceController,
      onTap: () {
        final navProvider = context.read<NavigationProvider>();
        if (navProvider.currentIndex != index) {
          navProvider.setIndex(index);
        }
      },
    );
  }
}

// Configuration class for nav items
class _NavItemConfig {
  final IconData icon;
  final String label;
  final bool showBadge;

  const _NavItemConfig({
    required this.icon,
    required this.label,
    this.showBadge = false,
  });
}

// Stateful widget for individual nav items with hover and animation states
class _NavItemWidget extends StatefulWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final int badgeCount;
  final bool badgeIncreased;
  final double itemHeight;
  final ThemeData theme;
  final AnimationController entranceController;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.index,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.badgeCount,
    required this.badgeIncreased,
    required this.itemHeight,
    required this.theme,
    required this.entranceController,
    required this.onTap,
  });

  @override
  State<_NavItemWidget> createState() => _NavItemWidgetState();
}

class _NavItemWidgetState extends State<_NavItemWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _iconBounceController;

  @override
  void initState() {
    super.initState();
    _iconBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _iconBounceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_NavItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger bounce animation when selected
    if (widget.isSelected && !oldWidget.isSelected) {
      _iconBounceController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF8B5CF6); // Vivid Violet
    final Color inactiveColor = widget.isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280); // Neutral 400/500
    final Color hoverColor = widget.isDark
        ? const Color(0xFFD1D5DB)
        : const Color(0xFF374151); // Neutral 300/700

    return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusScope.of(context).unfocus();
              widget.onTap();
            },
            child: Tooltip(
              message: widget.label,
              waitDuration: const Duration(milliseconds: 500),
              preferBelow: false,
              decoration: BoxDecoration(
                color: widget.theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: widget.theme.colorScheme.primary.withValues(
                      alpha: 0.3,
                    ),
                    blurRadius: 8,
                  ),
                ],
              ),
              textStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? activeColor.withValues(alpha: 0.16)
                      : (_isHovered
                            ? (widget.isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04))
                            : Colors.transparent),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isSelected
                        ? activeColor.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                transform: Matrix4.diagonal3Values(
                  _isHovered && !widget.isSelected ? 1.05 : 1.0,
                  _isHovered && !widget.isSelected ? 1.05 : 1.0,
                  1.0,
                ),
                transformAlignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Icon with animations
                    Center(
                      child: AnimatedBuilder(
                        animation: _iconBounceController,
                        builder: (context, child) {
                          final bounceValue = Curves.elasticOut.transform(
                            _iconBounceController.value,
                          );
                          final scale =
                              1.0 +
                              (bounceValue *
                                  0.15 *
                                  (1 - _iconBounceController.value));

                          // Rotation for settings icon
                          final rotation =
                              widget.index == 3 && widget.isSelected
                              ? bounceValue * 0.5
                              : 0.0;

                          return Transform.scale(
                            scale: scale,
                            child: Transform.rotate(
                              angle: rotation,
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          widget.icon,
                          color: widget.isSelected
                              ? activeColor
                              : (_isHovered ? hoverColor : inactiveColor),
                          size: 24, // slightly sleeker outline
                        ),
                      ),
                    ),
                    // Badge
                    if (widget.badgeCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: _AnimatedBadge(
                          count: widget.badgeCount,
                          increased: widget.badgeIncreased,
                          theme: widget.theme,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(controller: widget.entranceController)
        .fadeIn(
          delay: Duration(milliseconds: 100 + (widget.index * 80)),
          duration: 300.ms,
        )
        .slideY(
          begin: 0.3,
          end: 0,
          delay: Duration(milliseconds: 100 + (widget.index * 80)),
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// Animated badge widget
class _AnimatedBadge extends StatelessWidget {
  final int count;
  final bool increased;
  final ThemeData theme;

  const _AnimatedBadge({
    required this.count,
    required this.increased,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: Container(
        key: ValueKey(count),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.error,
              theme.colorScheme.error.withValues(alpha: 0.85),
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.error.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Center(
          child: Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
