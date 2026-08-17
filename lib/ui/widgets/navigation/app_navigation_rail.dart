import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/platform_settings_provider.dart';

class AppNavigationRail extends StatelessWidget {
  final AnimationController entranceController;

  const AppNavigationRail({super.key, required this.entranceController});

  static const _navItems = [
    _NavItemConfig(icon: Icons.home_outlined, label: 'Home'),
    _NavItemConfig(icon: Icons.search_outlined, label: 'Search'),
    _NavItemConfig(icon: Icons.download_outlined, label: 'Library', showBadge: true),
    _NavItemConfig(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
          width: 80,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              right: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                width: 1.0,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: Column(
              children: [
                const Spacer(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_navItems.length, (index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < _navItems.length - 1 ? 32.0 : 0,
                      ),
                      child: _NavItem(
                        index: index,
                        config: _navItems[index],
                        entranceController: entranceController,
                      ),
                    );
                  }),
                ),
                const Spacer(),
                _UserAvatar(entranceController: entranceController),
              ],
            ),
          ),
        )
        .animate(controller: entranceController)
        .fadeIn(duration: 220.ms, curve: Curves.easeOut)
        .slideX(begin: -0.08, end: 0, duration: 280.ms, curve: Curves.easeOutCubic);
  }
}

class _UserAvatar extends StatelessWidget {
  final AnimationController entranceController;
  const _UserAvatar({required this.entranceController});

  @override
  Widget build(BuildContext context) {
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
              textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                                errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFF8B5CF6), size: 20),
                              ),
                            )
                          : const Icon(Icons.person, color: Color(0xFF8B5CF6), size: 20))
                      : const Text('G', style: TextStyle(color: Color(0xFF9E9EA4), fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            )
            .animate(controller: entranceController)
            .fadeIn(delay: 500.ms, duration: 400.ms)
            .scale(delay: 500.ms, duration: 400.ms, curve: Curves.easeOutBack);
      },
    );
  }
}

class _NavItem extends StatefulWidget {
  final int index;
  final _NavItemConfig config;
  final AnimationController entranceController;
  const _NavItem({required this.index, required this.config, required this.entranceController});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config.hashCode != oldWidget.config.hashCode) {}
    final isSelected = context.read<NavigationProvider>().currentIndex == widget.index;
    final wasSelected = false;
    if (isSelected && !wasSelected) _bounceController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.select<NavigationProvider, int>((p) => p.currentIndex);
    final isSelected = currentIndex == widget.index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final badgeCount = widget.config.showBadge
        ? context.select<DownloadProvider, int>((p) => p.activeCount)
        : 0;

    const activeColor = Color(0xFF8B5CF6);
    final inactiveColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final hoverColor = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusScope.of(context).unfocus();
            final nav = context.read<NavigationProvider>();
            if (nav.currentIndex != widget.index) nav.setIndex(widget.index);
          },
          child: Tooltip(
            message: widget.config.label,
            waitDuration: const Duration(milliseconds: 500),
            preferBelow: false,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 8)],
            ),
            textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.16)
                    : (_isHovered
                        ? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04))
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? activeColor.withValues(alpha: 0.4) : Colors.transparent),
              ),
              transform: Matrix4.diagonal3Values(
                _isHovered && !isSelected ? 1.05 : 1.0,
                _isHovered && !isSelected ? 1.05 : 1.0,
                1.0,
              ),
              transformAlignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: AnimatedBuilder(
                      animation: _bounceController,
                      builder: (context, child) {
                        final bounceValue = Curves.elasticOut.transform(_bounceController.value);
                        final scale = 1.0 + (bounceValue * 0.15 * (1 - _bounceController.value));
                        final rotation = widget.index == 3 && isSelected ? bounceValue * 0.5 : 0.0;
                        return Transform.scale(
                          scale: scale,
                          child: Transform.rotate(angle: rotation, child: child),
                        );
                      },
                      child: Icon(
                        widget.config.icon,
                        color: isSelected ? activeColor : (_isHovered ? hoverColor : inactiveColor),
                        size: 24,
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: _Badge(count: badgeCount, theme: theme),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final ThemeData theme;
  const _Badge({required this.count, required this.theme});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: Container(
        key: ValueKey(count),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.colorScheme.error, theme.colorScheme.error.withValues(alpha: 0.85)],
          ),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: theme.colorScheme.error.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Center(
          child: Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _NavItemConfig {
  final IconData icon;
  final String label;
  final bool showBadge;
  const _NavItemConfig({required this.icon, required this.label, this.showBadge = false});
}
