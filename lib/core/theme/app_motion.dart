import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/platform_settings_provider.dart';

/// Motion tokens following the Material 3 Expressive motion hierarchy:
/// transitions use continuous linear motion while small
/// feedback stays quick and subtle. Durations and curves should come from
/// here (or [appMotionDuration]) so the hierarchy stays consistent app-wide.
abstract final class AppMotion {
  /// Quick feedback: press-down, small state flips.
  static const Duration fast = Duration(milliseconds: 90);

  /// Component-level transitions: chip/status swaps, glow borders.
  static const Duration short = Duration(milliseconds: 120);

  /// Standard spatial transitions: tab switches, morphs, card entrances.
  static const Duration medium = Duration(milliseconds: 190);

  /// Large transitions: page pushes, hero sections.
  static const Duration long = Duration(milliseconds: 260);

  /// Decisive ease-out spatial transitions.
  static const Curve emphasized = Curves.easeOutCubic;

  /// Smooth entrance transitions.
  static const Curve decelerate = Curves.easeOutQuart;

  /// Crisp exit transitions.
  static const Curve accelerate = Curves.easeInCubic;

  /// Constant-speed motion shared by continuous progress and shimmer indicators.
  static const Curve linear = Curves.linear;
}

/// Resolves the effective duration for an animation, honoring the user's
/// `enableAnimations` setting and the OS reduce-motion accessibility flag.
/// Returns [Duration.zero] — which makes implicit animations jump instantly —
/// when either is off. Call from `build` so the provider dependency is
/// registered there. Contexts without the settings provider (tests, isolated
/// previews) default to animations enabled.
Duration appMotionDuration(BuildContext context, Duration base) {
  bool enabled = true;
  try {
    enabled = context.select<PlatformSettingsProvider, bool>(
      (p) => p.enableAnimations,
    );
  } catch (_) {
    try {
      enabled = Provider.of<PlatformSettingsProvider>(
        context,
        listen: false,
      ).enableAnimations;
    } catch (_) {
      enabled = true;
    }
  }
  if (!enabled) return Duration.zero;
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return reduceMotion ? Duration.zero : base;
}
