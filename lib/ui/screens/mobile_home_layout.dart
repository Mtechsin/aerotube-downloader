import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../core/utils/platform_utils.dart';
import 'package:flutter/services.dart';
import 'mobile_home_screen.dart';

class MobileShell extends StatefulWidget {
  final List<Widget> screens;

  const MobileShell({super.key, required this.screens});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (navigationProvider.currentIndex != 0) {
          navigationProvider.setIndex(0);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: IndexedStack(
          index: navigationProvider.currentIndex,
          children: widget.screens,
        ),
        bottomNavigationBar: _buildBottomNavBar(
          context,
          theme,
          navigationProvider,
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(
    BuildContext context,
    ThemeData theme,
    NavigationProvider navProvider,
  ) {
    final activeDownloads = PlatformUtils.isAndroid
        ? context.watch<MobileDownloadProvider>().activeDownloadsCount
        : context.watch<DownloadProvider>().activeCount;

    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.scaffoldBackgroundColor;
    final isDark = theme.brightness == Brightness.dark;
    final systemBottomInset = MediaQuery.of(context).viewPadding.bottom;
    final bottomSpacing = PlatformUtils.isAndroid ? 2.0 : 6.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomSpacing + systemBottomInset,
      ),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.14),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: navProvider.currentIndex == 0,
                  color: primaryColor,
                  onTap: () => navProvider.setIndex(0),
                ),
                _NavItem(
                  icon: Icons.search_outlined,
                  activeIcon: Icons.search_rounded,
                  label: 'Search',
                  isSelected: navProvider.currentIndex == 1,
                  color: primaryColor,
                  onTap: () => navProvider.setIndex(1),
                ),
                _NavItem(
                  icon: Icons.download_outlined,
                  activeIcon: Icons.download_rounded,
                  label: 'Files',
                  isSelected: navProvider.currentIndex == 2,
                  color: primaryColor,
                  badge: activeDownloads > 0 ? activeDownloads : null,
                  onTap: () => navProvider.setIndex(2),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: navProvider.currentIndex == 3,
                  color: primaryColor,
                  onTap: () => navProvider.setIndex(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final Color color;
  final int? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconScale = widget.isSelected ? 1.04 : 1.0;
    final iconOffsetY = widget.isSelected ? -1.0 : 0.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSlide(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  offset: Offset(0, iconOffsetY / 24),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    scale: iconScale,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? widget.color.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.isSelected ? widget.activeIcon : widget.icon,
                        color: widget.isSelected ? widget.color : textColor,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                if (widget.badge != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        widget.badge! > 9 ? '9+' : '${widget.badge}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 10,
                fontWeight: widget.isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isDark
                    ? Colors.white
                    : (widget.isSelected ? Colors.black : Colors.black87),
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MobileHomeLayout extends StatelessWidget {
  const MobileHomeLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return const MobileHomeScreen();
  }
}
