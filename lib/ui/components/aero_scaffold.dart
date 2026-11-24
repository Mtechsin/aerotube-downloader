import 'package:flutter/material.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/utils/platform_utils.dart';
import 'aero_density.dart';

/// AeroScaffold provides the unified adaptive shell for AeroTube.
///
/// Features:
/// - Adapts layout between mobile (phone) and desktop/tablet based on platform and screen width.
/// - Owns page padding: Android (20 dp) via [AeroSpace.androidPage], Windows (32 px) via [AeroSpace.windowsPage].
/// - Owns max content width: 1100 px centered on desktop/wide screens, unconstrained on mobile.
/// - Slots for [topBar], [bottomBar], [rail], and [floatingTray].
/// - Docking for [floatingTray]: persistent mini download tray docked above [bottomBar]
///   on mobile, or docked at the bottom of the main content column on desktop.
class AeroScaffold extends StatelessWidget {
  /// The main content of the screen.
  final Widget body;

  /// Top strip or app bar slot (e.g. Windows window drag strip or Android top bar).
  final Widget? topBar;

  /// Bottom navigation bar or bottom action bar slot (primarily for mobile/compact).
  final Widget? bottomBar;

  /// Navigation rail or sidebar slot (primarily for desktop/tablet/expanded).
  final Widget? rail;

  /// Floating mini download tray slot, docked above [bottomBar] or at the bottom of content.
  final Widget? floatingTray;

  /// Optional floating action button.
  final Widget? floatingActionButton;

  /// Location of the floating action button.
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Background color of the scaffold. Defaults to [AeroColors.bg].
  final Color? backgroundColor;

  /// Optional custom padding override for the content area.
  final EdgeInsetsGeometry? padding;

  /// Whether to apply responsive page padding (Android 20, Windows 32). Defaults to `true`.
  final bool applyPagePadding;

  /// Maximum content width for centering wide screens. Defaults to 1100.0.
  final double? maxContentWidth;

  /// Whether to enforce [maxContentWidth] on wide screens. Defaults to `true`.
  final bool applyMaxContentWidth;

  /// Whether the body should resize when the on-screen keyboard appears.
  final bool? resizeToAvoidBottomInset;

  /// Whether the body extends under the [bottomBar].
  final bool extendBody;

  /// Whether the body extends under the [topBar].
  final bool extendBodyBehindAppBar;

  /// Whether to wrap content in a [SafeArea]. Defaults to `true`.
  final bool safeArea;

  /// Top safe area inset. Defaults to `true`.
  final bool safeAreaTop;

  /// Bottom safe area inset. Defaults to `true`.
  final bool safeAreaBottom;

  /// Left safe area inset. Defaults to `true`.
  final bool safeAreaLeft;

  /// Right safe area inset. Defaults to `true`.
  final bool safeAreaRight;

  /// Density override (compact for desktop, comfortable for mobile).
  final AeroDensity? density;

  const AeroScaffold({
    super.key,
    required this.body,
    this.topBar,
    this.bottomBar,
    this.rail,
    this.floatingTray,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.padding,
    this.applyPagePadding = true,
    this.maxContentWidth = 1100.0,
    this.applyMaxContentWidth = true,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.safeArea = true,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.safeAreaLeft = true,
    this.safeAreaRight = true,
    this.density,
  });

  /// Breakpoint threshold below which layout is considered compact.
  static const double compactBreakpoint = 600.0;

  /// Standard max content width for wide layouts.
  static const double defaultMaxContentWidth = 1100.0;

  /// Returns whether the given context represents a compact / mobile form factor.
  static bool isCompact(BuildContext context, [AeroDensity? explicitDensity]) {
    final effectiveDensity = AeroDensity.resolve(context, explicitDensity);
    if (effectiveDensity.isCompact) {
      // Pointer/desktop-targeted mode: only compact if window is genuinely narrow
      return MediaQuery.sizeOf(context).width < compactBreakpoint;
    }
    // Touch/mobile-targeted mode
    return MediaQuery.sizeOf(context).width < compactBreakpoint ||
        PlatformUtils.isMobile;
  }

  /// Resolves the responsive page padding for the current environment.
  /// - Android/mobile/compact: 20 dp horizontal padding
  /// - Windows/desktop/expanded: 32 px horizontal padding
  static EdgeInsets pagePaddingOf(
    BuildContext context, [
    AeroDensity? explicitDensity,
  ]) {
    final compact = isCompact(context, explicitDensity);
    final horizontal = compact ? AeroSpace.androidPage : AeroSpace.windowsPage;
    return EdgeInsets.symmetric(horizontal: horizontal);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final compact = isCompact(context, density);

    // Build the content area with max width constraint and page padding
    Widget content = body;

    if (applyPagePadding) {
      final effectivePadding = padding ?? pagePaddingOf(context, density);
      content = Padding(padding: effectivePadding, child: content);
    }

    if (applyMaxContentWidth && !compact && maxContentWidth != null) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth!),
          child: content,
        ),
      );
    }

    // Determine navigation and slot arrangement
    final showRail = !compact && rail != null;
    final showBottomBar =
        (compact && bottomBar != null) || (!showRail && bottomBar != null);
    final showFloatingTrayInBottom = compact && floatingTray != null;
    final showFloatingTrayInContent = !compact && floatingTray != null;

    // Body assembly
    Widget assembledBody;

    if (showRail) {
      // Desktop / Tablet layout: Rail on left, content column on right
      assembledBody = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          rail!,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (topBar != null) topBar!,
                Expanded(child: content),
                if (showFloatingTrayInContent) floatingTray!,
              ],
            ),
          ),
        ],
      );
    } else {
      // Mobile / Compact layout (or single-column desktop layout)
      assembledBody = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topBar != null) topBar!,
          Expanded(child: content),
        ],
      );
    }

    // Apply SafeArea to body if requested
    if (safeArea) {
      assembledBody = SafeArea(
        top: safeAreaTop && !extendBodyBehindAppBar,
        // Bottom safe area is handled by bottomNavigationBar when present
        bottom: showBottomBar ? false : safeAreaBottom,
        left: safeAreaLeft,
        right: safeAreaRight,
        child: assembledBody,
      );
    }

    // Bottom navigation slot (holds docked floating tray + bottom bar on mobile)
    Widget? effectiveBottomNav;
    if (showFloatingTrayInBottom || showBottomBar) {
      effectiveBottomNav = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showFloatingTrayInBottom) floatingTray!,
          if (showBottomBar) bottomBar!,
        ],
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? colors.bg,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      body: assembledBody,
      bottomNavigationBar: effectiveBottomNav,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}
