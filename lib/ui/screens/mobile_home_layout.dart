import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/download_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../components/mini_download_tray.dart';
import 'mobile_home_screen.dart';

/// Destination specification for navigation items
class _NavDestinationItem {
  final IconData iconOutlined;
  final IconData iconFilled;
  final String label;
  final bool hasBadge;

  const _NavDestinationItem({
    required this.iconOutlined,
    required this.iconFilled,
    required this.label,
    this.hasBadge = false,
  });
}

const List<_NavDestinationItem> _destinations = [
  _NavDestinationItem(
    iconOutlined: Symbols.home_rounded,
    iconFilled: Symbols.home_rounded,
    label: 'Home',
  ),
  _NavDestinationItem(
    iconOutlined: Symbols.search_rounded,
    iconFilled: Symbols.search_rounded,
    label: 'Search',
  ),
  _NavDestinationItem(
    iconOutlined: Symbols.download_rounded,
    iconFilled: Symbols.download_rounded,
    label: 'Library',
    hasBadge: true,
  ),
  _NavDestinationItem(
    iconOutlined: Symbols.settings_rounded,
    iconFilled: Symbols.settings_rounded,
    label: 'Settings',
  ),
];

/// Adaptive shell for Android and mobile platforms.
///
/// Features:
/// - Screen width < 600: BottomNavigationBar (height 64 + safe area, surface1 background,
///   hairline top border, pill indicator behind active icon, always-visible 11 sp label).
/// - Screen width >= 600 (Tablet / Foldable): NavigationRail with visible labels
///   (compact < 600, medium 600-1023, expanded >= 1024).
/// - Persistent 56 dp mini download tray docked above bottom nav.
/// - PopScope behavior: Back from non-Home returns to Home, then exits.
class MobileShell extends StatelessWidget {
  final List<Widget> screens;

  const MobileShell({super.key, required this.screens});

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final currentIndex = navigationProvider.currentIndex;
    final colors = context.aero;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTabletOrWide = screenWidth >= 600;

    // C8: On Home (index 0) back exits the app. On secondary tabs, back returns to Home first.
    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (navigationProvider.currentIndex != 0) {
          navigationProvider.setIndex(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: isTabletOrWide
            ? Row(
                children: [
                  _MobileNavigationRail(
                    currentIndex: currentIndex,
                    onDestinationSelected: navigationProvider.setIndex,
                    isExpanded: screenWidth >= 1024,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: IndexedStack(
                            index: currentIndex,
                            children: screens,
                          ),
                        ),
                        const MiniDownloadTray(),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: IndexedStack(index: currentIndex, children: screens),
                  ),
                  // Persistent 56 dp mini download tray docked directly above the bottom navigation bar
                  const MiniDownloadTray(),
                ],
              ),
        bottomNavigationBar: isTabletOrWide
            ? null
            : _AeroBottomNavBar(
                currentIndex: currentIndex,
                onTap: navigationProvider.setIndex,
              ),
      ),
    );
  }
}

/// Custom Bottom Navigation Bar matching redesign spec 6.1:
/// - 4 destinations: Home, Search, Library (with badge for active downloads), Settings.
/// - Height 64 + safe area, surface1 background, hairline top border.
/// - Pill indicator (primarySoft) behind active icon.
/// - Label always visible at 11 sp.
class _AeroBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AeroBottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    // Active download badge count
    final activeCount = PlatformUtils.isAndroid
        ? context.select<MobileDownloadProvider, int>(
            (p) => p.activeDownloads.length,
          )
        : context.select<DownloadProvider, int>((p) => p.activeCount);

    return Container(
      height: 64.0 + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(top: BorderSide(color: colors.outline, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_destinations.length, (index) {
          final item = _destinations[index];
          final isSelected = currentIndex == index;
          final badge = item.hasBadge ? activeCount : 0;

          return Expanded(
            child: Semantics(
              selected: isSelected,
              button: true,
              label: badge > 0
                  ? '${item.label}, $badge active downloads'
                  : item.label,
              child: InkWell(
                onTap: () => onTap(index),
                splashColor: colors.primarySoft,
                highlightColor: Colors.transparent,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon inside a pill indicator when selected
                      AnimatedContainer(
                        duration: appMotionDuration(context, AppMotion.short),
                        curve: AppMotion.linear,
                        width: 52,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primarySoft
                              : Colors.transparent,
                          borderRadius: AeroRadius.fullBorderRadius,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              isSelected ? item.iconFilled : item.iconOutlined,
                              fill: isSelected ? 1 : 0,
                              size: 22,
                              color: isSelected
                                  ? colors.primary
                                  : colors.onSurfaceMuted,
                            ),
                            if (badge > 0)
                              Positioned(
                                top: 2,
                                right: 10,
                                child: _ActiveCountBadge(count: badge),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Label always visible at 11 sp (AeroText.caption)
                      Text(
                        item.label,
                        style: AeroText.caption.copyWith(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? colors.primary
                              : colors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// NavigationRail for Tablet / Foldable (width >= 600) matching redesign spec 6.2
class _MobileNavigationRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isExpanded;

  const _MobileNavigationRail({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;

    final activeCount = PlatformUtils.isAndroid
        ? context.select<MobileDownloadProvider, int>(
            (p) => p.activeDownloads.length,
          )
        : context.select<DownloadProvider, int>((p) => p.activeCount);

    return Container(
      width: isExpanded ? 200 : 72,
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(right: BorderSide(color: colors.outline, width: 0.5)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Header icon/wordmark
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: isExpanded ? Alignment.centerLeft : Alignment.center,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: isExpanded ? 'Aero' : 'A',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      if (isExpanded)
                        TextSpan(
                          text: 'Tube',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            color: colors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Navigation items
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _destinations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = _destinations[index];
                  final isSelected = currentIndex == index;
                  final badge = item.hasBadge ? activeCount : 0;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: AeroRadius.mdBorderRadius,
                      onTap: () => onDestinationSelected(index),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primarySoft
                              : Colors.transparent,
                          borderRadius: AeroRadius.mdBorderRadius,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: isExpanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  isSelected
                                      ? item.iconFilled
                                      : item.iconOutlined,
                                  fill: isSelected ? 1 : 0,
                                  color: isSelected
                                      ? colors.primary
                                      : colors.onSurfaceMuted,
                                  size: 22,
                                ),
                                if (badge > 0)
                                  Positioned(
                                    top: -4,
                                    right: -8,
                                    child: _ActiveCountBadge(count: badge),
                                  ),
                              ],
                            ),
                            if (isExpanded) ...[
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: AeroText.bodySm.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? colors.primary
                                        : colors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge showing count of active downloads
class _ActiveCountBadge extends StatelessWidget {
  final int count;

  const _ActiveCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: AeroRadius.fullBorderRadius,
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
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
