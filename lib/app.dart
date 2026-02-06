import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'core/theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'providers/download_provider.dart';
import 'providers/update_provider.dart';
import 'providers/navigation_provider.dart';
import 'services/notification_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/search_screen.dart';
import 'ui/screens/downloads_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/youtube_login_screen.dart';
import 'ui/widgets/gradient_background.dart';
import 'ui/widgets/update_dialog.dart';
import 'ui/widgets/app_logo.dart';


class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with TickerProviderStateMixin {
  int _previousBadgeCount = 0;
  bool _hasAnimatedIn = false;

  late final AnimationController _indicatorController;
  late final AnimationController _entranceController;
  
  final _screens = const [HomeScreen(), SearchScreen(), DownloadsScreen(), SettingsScreen()];
  
  // Navigation item configuration
  static const List<_NavItemConfig> _navItems = [
    _NavItemConfig(icon: Icons.home_rounded, label: 'Home'),
    _NavItemConfig(icon: Icons.search_rounded, label: 'Search'),
    _NavItemConfig(icon: Icons.download_rounded, label: 'Library', showBadge: true),
    _NavItemConfig(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    
    // Animation controllers for smooth navigation transitions
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
    _indicatorController.dispose();
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
      home: Builder(
        builder: (context) {
          return GradientBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Row(
                children: [
                  // Custom Glassmorphic Navigation Rail
                  _buildCustomNavigationRail(context),

                  // Content
                  Expanded(
                    child: IndexedStack(
                      index: context.watch<NavigationProvider>().currentIndex, 
                      children: _screens,
                    ),
                  ),
                ],
              ),
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
    const double itemHeight = 56.0;
    const double itemSpacing = 20.0;
    const double containerPadding = 16.0;
    
    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
      child: Column(
        children: [
          // Brand Logo at the top
          AppLogo(size: 52, showGlow: true)
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
          
          const Spacer(),
          
          // Floating Glass Dock with sliding indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF121212), // Solid dark
                            const Color(0xFF121212),
                          ]
                        : [
                            Colors.white, // Solid white
                            Colors.white,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: containerPadding,
                  horizontal: 10,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Sliding pill indicator
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      top: containerPadding + (context.watch<NavigationProvider>().currentIndex * (itemHeight + itemSpacing)) - 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          width: 52,
                          height: itemHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withValues(alpha: 0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Navigation items
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_navItems.length, (index) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < _navItems.length - 1 ? itemSpacing : 0,
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
                  ],
                ),
              ),
            ),
          ),
          
          const Spacer(),
        ],
      ),
    )
        .animate(controller: _entranceController)
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideX(begin: -0.3, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required _NavItemConfig config,
    required double itemHeight,
  }) {
    final currentIndex = context.watch<NavigationProvider>().currentIndex;
    final isSelected = currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, child) {
        final badgeCount = config.showBadge ? downloadProvider.activeCount : 0;
        final badgeIncreased = badgeCount > _previousBadgeCount;
        
        // Update previous badge count after build
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
                color: widget.theme.colorScheme.primary.withValues(alpha: 0.3),
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
            width: 52,
            height: widget.itemHeight,
            decoration: BoxDecoration(
              color: !widget.isSelected && _isHovered
                  ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            transform: Matrix4.diagonal3Values(
              _isHovered && !widget.isSelected ? 1.08 : 1.0,
              _isHovered && !widget.isSelected ? 1.08 : 1.0,
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
                      final bounceValue = Curves.elasticOut
                          .transform(_iconBounceController.value);
                      final scale = 1.0 + (bounceValue * 0.15 * (1 - _iconBounceController.value));
                      
                      // Rotation for settings icon
                      final rotation = widget.index == 2 && widget.isSelected
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
                          ? Colors.white // Always white on the purple pill
                          : (widget.isDark
                              ? Colors.white.withValues(alpha: 0.8) // White icons in dark mode
                              : Colors.black.withValues(alpha: 0.65)), // Dark icons in white mode
                      size: 26,
                    ),
                  ),
                ),
                // Badge
                if (widget.badgeCount > 0)
                  Positioned(
                    right: 2,
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
        return ScaleTransition(
          scale: animation,
          child: child,
        );
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
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
        ),
        constraints: const BoxConstraints(
          minWidth: 18,
          minHeight: 18,
        ),
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

