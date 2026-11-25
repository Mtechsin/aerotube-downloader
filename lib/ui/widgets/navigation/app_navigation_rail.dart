import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/tokens/colors.dart';
import '../../../core/theme/tokens/radius.dart';
import '../../../core/theme/tokens/typography.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/platform_settings_provider.dart';

class _DesktopNavItemConfig {
  final IconData iconOutlined;
  final IconData iconFilled;
  final String label;
  final String shortcut;
  final bool showBadge;

  const _DesktopNavItemConfig({
    required this.iconOutlined,
    required this.iconFilled,
    required this.label,
    required this.shortcut,
    this.showBadge = false,
  });
}

/// One persistent desktop sidebar. All geometry uses the same expansion value.
class AppNavigationRail extends StatelessWidget {
  final AnimationController entranceController;
  const AppNavigationRail({super.key, required this.entranceController});

  static const _navItems = [
    _DesktopNavItemConfig(
      iconOutlined: Symbols.home_rounded,
      iconFilled: Symbols.home_rounded,
      label: 'Home',
      shortcut: 'Ctrl+1',
    ),
    _DesktopNavItemConfig(
      iconOutlined: Symbols.search_rounded,
      iconFilled: Symbols.search_rounded,
      label: 'Search',
      shortcut: 'Ctrl+2',
    ),
    _DesktopNavItemConfig(
      iconOutlined: Symbols.download_rounded,
      iconFilled: Symbols.download_rounded,
      label: 'Library',
      shortcut: 'Ctrl+3',
      showBadge: true,
    ),
    _DesktopNavItemConfig(
      iconOutlined: Symbols.settings_rounded,
      iconFilled: Symbols.settings_rounded,
      label: 'Settings',
      shortcut: 'Ctrl+4, Ctrl+,',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final settings = context.watch<PlatformSettingsProvider>();
    final wideWindow = MediaQuery.sizeOf(context).width >= 1000;
    final isExpanded = settings.isSidebarExpanded && wideWindow;
    final nav = context.watch<NavigationProvider>();
    final activeCount = context.select<DownloadProvider, int>(
      (p) => p.activeCount,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAmoled = isDark && settings.amoledDark;
    final themeLabel = isAmoled ? 'AMOLED' : (isDark ? 'Dark' : 'Light');
    final loggedIn = settings.isYouTubeLoggedIn;
    final statusColor = loggedIn
        ? colors.success
        : settings.isCookieActive
        ? colors.info
        : colors.onSurfaceFaint;

    return TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: isExpanded ? 1 : 0,
            end: isExpanded ? 1 : 0,
          ),
          duration: appMotionDuration(context, AppMotion.medium),
          curve: AppMotion.emphasized,
          builder: (context, expansion, _) => Container(
            width: 72 + 160 * expansion,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: colors.surface1,
              border: Border(right: BorderSide(color: colors.outline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The same header button, logo and wordmark stay mounted in both states.
                Tooltip(
                  message: wideWindow
                      ? (isExpanded ? 'Collapse sidebar' : 'Expand sidebar')
                      : 'Widen the window to show labels',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: wideWindow
                          ? () => settings.setSidebarExpanded(!isExpanded)
                          : null,
                      child: Container(
                        height: 56,
                        padding: EdgeInsets.symmetric(
                          horizontal: 19.5 - 6 * expansion,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: colors.outline),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colors.primary,
                                    colors.primary.withValues(alpha: 0.75),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Symbols.play_arrow_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                            Expanded(
                              child: _RailDetails(
                                expansion: expansion,
                                width: 172,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'Aero',
                                              style: TextStyle(
                                                fontFamily: 'Manrope',
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: colors.onSurface,
                                                letterSpacing: -0.4,
                                              ),
                                            ),
                                            TextSpan(
                                              text: 'Tube',
                                              style: TextStyle(
                                                fontFamily: 'Manrope',
                                                fontSize: 18,
                                                fontWeight: FontWeight.w400,
                                                color: colors.primary,
                                                letterSpacing: -0.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Symbols.menu_open_rounded,
                                      size: 18,
                                      color: colors.onSurfaceMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 10 + 26 * expansion,
                  child: _RailDetails(
                    expansion: expansion,
                    width: 232,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        'WORKSPACE',
                        style: AeroText.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurfaceFaint,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    itemCount: _navItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = _navItems[index];
                      final selected = nav.currentIndex == index;
                      final count = item.showBadge ? activeCount : 0;
                      return _RailRow(
                        key: ValueKey('sidebar-${item.label}'),
                        expansion: expansion,
                        selected: selected,
                        tooltip: '${item.label} (${item.shortcut})',
                        onTap: () => nav.setIndex(index),
                        icon: Icon(
                          selected ? item.iconFilled : item.iconOutlined,
                          fill: selected ? 1 : 0,
                          size: 20,
                          color: selected
                              ? colors.primary
                              : colors.onSurfaceMuted,
                        ),
                        badgeCount: count,
                        details: Row(
                          children: [
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AeroText.bodySm.copyWith(
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: selected
                                      ? colors.primary
                                      : colors.onSurface,
                                ),
                              ),
                            ),
                            if (count == 0)
                              _Shortcut(
                                text: item.shortcut.split(',').first.trim(),
                              ),
                            // The single badge is positioned by _RailRow throughout the animation.
                            if (count > 0) const SizedBox(width: 28),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.outline)),
                  ),
                  child: Column(
                    children: [
                      _RailRow(
                        key: const ValueKey('sidebar-account'),
                        expansion: expansion,
                        height: 44,
                        tooltip: loggedIn
                            ? 'Signed in (Cookies active)'
                            : 'Guest Account',
                        onTap: () => nav.setIndex(3),
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.surface2,
                                border: Border.all(color: colors.outline),
                              ),
                              child: ClipOval(
                                child:
                                    loggedIn &&
                                        settings.youtubeProfileImageUrl != null
                                    ? Image.network(
                                        settings.youtubeProfileImageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Symbols.person_rounded,
                                          size: 15,
                                          color: colors.primary,
                                        ),
                                      )
                                    : Icon(
                                        loggedIn
                                            ? Symbols.person_rounded
                                            : Symbols.person_rounded,
                                        size: 15,
                                        color: colors.onSurfaceMuted,
                                      ),
                              ),
                            ),
                            Positioned(
                              right: -1,
                              bottom: -1,
                              child: Container(
                                width: 7.5,
                                height: 7.5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusColor,
                                  border: Border.all(
                                    color: colors.surface1,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        details: Row(
                          children: [
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loggedIn ? 'YouTube User' : 'Guest',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AeroText.bodySm.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  Text(
                                    loggedIn
                                        ? 'Signed in'
                                        : settings.isCookieActive
                                        ? 'Cookies active'
                                        : 'Not signed in',
                                    maxLines: 1,
                                    style: AeroText.caption.copyWith(
                                      fontSize: 10,
                                      height: 1.2,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Symbols.chevron_right_rounded,
                              size: 16,
                              color: colors.onSurfaceFaint,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      _RailRow(
                        key: const ValueKey('sidebar-theme'),
                        expansion: expansion,
                        height: 38,
                        tooltip: 'Toggle theme ($themeLabel)',
                        onTap: () => settings.setThemeMode(
                          isDark ? ThemeMode.light : ThemeMode.dark,
                        ),
                        icon: Icon(
                          isAmoled
                              ? Symbols.contrast_rounded
                              : isDark
                              ? Symbols.dark_mode_rounded
                              : Symbols.light_mode_rounded,
                          size: 18,
                          color: colors.onSurfaceMuted,
                        ),
                        details: Row(
                          children: [
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$themeLabel Theme',
                                maxLines: 1,
                                style: AeroText.caption.copyWith(
                                  fontSize: 12,
                                  color: colors.onSurfaceMuted,
                                ),
                              ),
                            ),
                            _Shortcut(text: themeLabel),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(controller: entranceController)
        .fadeIn(
          duration: appMotionDuration(context, 150.ms),
          curve: AppMotion.decelerate,
        )
        .slideX(
          begin: settings.enableAnimations ? -0.06 : 0,
          end: 0,
          duration: appMotionDuration(context, 180.ms),
          curve: AppMotion.decelerate,
        );
  }
}

/// Fixed-width text stays mounted and fades within its shrinking slot.
class _RailDetails extends StatelessWidget {
  final double expansion;
  final double width;
  final Widget child;
  const _RailDetails({
    required this.expansion,
    required this.child,
    this.width = 162,
  });
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    excluding: expansion < 1,
    child: IgnorePointer(
      ignoring: expansion < 1,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: width,
          maxWidth: width,
          child: Opacity(
            opacity: expansion,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

class _RailRow extends StatefulWidget {
  final double expansion;
  final double height;
  final bool selected;
  final int badgeCount;
  final String tooltip;
  final VoidCallback onTap;
  final Widget icon;
  final Widget details;
  const _RailRow({
    super.key,
    required this.expansion,
    required this.tooltip,
    required this.onTap,
    required this.icon,
    required this.details,
    this.height = 42,
    this.selected = false,
    this.badgeCount = 0,
  });
  @override
  State<_RailRow> createState() => _RailRowState();
}

class _RailRowState extends State<_RailRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AeroRadius.smBorderRadius,
            onTap: widget.onTap,
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.selected
                    ? colors.primarySoft
                    : _hovered
                    ? colors.surface2
                    : Colors.transparent,
                borderRadius: AeroRadius.smBorderRadius,
                border: Border.all(
                  color: widget.selected
                      ? colors.primary.withValues(alpha: 0.28)
                      : _hovered
                      ? colors.outline.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  if (widget.selected)
                    Positioned(
                      left: 0,
                      top: 8,
                      bottom: 8,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.5 - widget.expansion,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: Center(child: widget.icon),
                        ),
                        Expanded(
                          child: _RailDetails(
                            expansion: widget.expansion,
                            child: widget.details,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.badgeCount > 0)
                    Positioned(
                      right: 4 + 6 * widget.expansion,
                      top: 2 + 10 * widget.expansion,
                      child: _Shortcut(
                        text: widget.badgeCount > 99
                            ? '99+'
                            : '${widget.badgeCount}',
                        badge: true,
                      ),
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

class _Shortcut extends StatelessWidget {
  final String text;
  final bool badge;
  const _Shortcut({required this.text, this.badge = false});
  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: badge ? colors.primary : colors.surface2,
        borderRadius: BorderRadius.circular(badge ? 12 : 4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: badge ? 'Manrope' : 'Consolas',
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: badge ? colors.onPrimary : colors.onSurfaceFaint,
        ),
      ),
    );
  }
}
