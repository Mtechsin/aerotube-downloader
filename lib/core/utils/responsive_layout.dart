import 'package:flutter/material.dart';

/// Responsive layout helper that adapts to different screen sizes
class ResponsiveLayout {
  /// Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Get screen type
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return ScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return ScreenType.tablet;
    } else if (width < desktopBreakpoint) {
      return ScreenType.desktop;
    }
    return ScreenType.largeDesktop;
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getPadding(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return const EdgeInsets.all(16);
      case ScreenType.tablet:
        return const EdgeInsets.all(24);
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return const EdgeInsets.all(32);
    }
  }

  /// Get responsive max width for content
  static double? getMaxWidth(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return null; // Use full width
      case ScreenType.tablet:
        return 700;
      case ScreenType.desktop:
        return 900;
      case ScreenType.largeDesktop:
        return 1100;
    }
  }

  /// Get responsive card size
  static CardSize getCardSize(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return CardSize.small;
      case ScreenType.tablet:
        return CardSize.medium;
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return CardSize.large;
    }
  }

  /// Build responsive grid view
  static Widget buildResponsiveGrid({
    required List<Widget> children,
    required BuildContext context,
    double childAspectRatio = 1.0,
    double mainAxisSpacing = 16,
    double crossAxisSpacing = 16,
  }) {
    final screenType = getScreenType(context);
    int crossAxisCount;

    switch (screenType) {
      case ScreenType.mobile:
        crossAxisCount = 1;
        break;
      case ScreenType.tablet:
        crossAxisCount = 2;
        break;
      case ScreenType.desktop:
        crossAxisCount = 3;
        break;
      case ScreenType.largeDesktop:
        crossAxisCount = 4;
        break;
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }

  /// Check if we should show sidebar
  static bool shouldShowSidebar(BuildContext context) {
    final screenType = getScreenType(context);
    return screenType == ScreenType.desktop || screenType == ScreenType.largeDesktop;
  }

  /// Get responsive font scale
  static double getFontScale(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return 0.9;
      case ScreenType.tablet:
        return 1.0;
      case ScreenType.desktop:
        return 1.0;
      case ScreenType.largeDesktop:
        return 1.1;
    }
  }
}

/// Screen type enum
enum ScreenType {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}

/// Card size enum
enum CardSize {
  small,
  medium,
  large,
}

/// Responsive wrapper widget
class ResponsiveWidget extends StatelessWidget {
  final Widget? mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? largeDesktop;
  final Widget? fallback;

  const ResponsiveWidget({
    super.key,
    this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final screenType = ResponsiveLayout.getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return mobile ?? fallback ?? const SizedBox.shrink();
      case ScreenType.tablet:
        return tablet ?? mobile ?? fallback ?? const SizedBox.shrink();
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile ?? fallback ?? const SizedBox.shrink();
      case ScreenType.largeDesktop:
        return largeDesktop ?? desktop ?? tablet ?? mobile ?? fallback ?? const SizedBox.shrink();
    }
  }
}

/// Mobile-optimized button with proper touch targets
class MobileButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double? width;
  final double minHeight;
  final EdgeInsetsGeometry? padding;

  const MobileButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.width,
    this.minHeight = 48,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: Size(width ?? double.infinity, minHeight),
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Mobile list tile with proper touch target
class MobileListTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;

  const MobileListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading != null
          ? SizedBox(
              width: 40,
              height: 40,
              child: leading,
            )
          : null,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minTileHeight: 56, // Minimum 56dp for comfortable touch
      dense: false,
    );
  }
}
