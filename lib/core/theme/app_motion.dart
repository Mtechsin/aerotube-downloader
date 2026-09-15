import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';

import '../../providers/platform_settings_provider.dart';

/// Motion tokens following the Material 3 Expressive motion hierarchy:
/// primary transitions get energetic, spring-based motion while small
/// feedback stays quick and subtle. Durations and curves should come from
/// here (or [appMotionDuration]) so the hierarchy stays consistent app-wide.
abstract final class AppMotion {
  /// Quick feedback: press-down, small state flips.
  static const Duration fast = Duration(milliseconds: 150);

  /// Component-level transitions: chip/status swaps, glow borders.
  static const Duration short = Duration(milliseconds: 200);

  /// Standard spatial transitions: tab switches, morphs, card entrances.
  static const Duration medium = Duration(milliseconds: 350);

  /// Large transitions: page pushes, hero sections.
  static const Duration long = Duration(milliseconds: 500);

  /// M3 emphasized easing for spatial transitions.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Decelerate curve for things entering the screen.
  static const Curve decelerate = Curves.easeOutCubic;

  /// Accelerate curve for things leaving the screen.
  static const Curve accelerate = Curves.easeInCubic;

  /// Gentle overshoot spring for entrances and shape morphs.
  static final SpringDescription spatialSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.9);

  /// Fast spring for press release and other quick returns.
  static final SpringDescription snappySpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 700, ratio: 0.85);

  /// Looser spring reserved for celebratory one-shots (completion pop).
  static final SpringDescription bounceSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 320, ratio: 0.65);

  /// Spring curve sampling [spatialSpring] over [medium].
  static final Curve spatialSpringCurve = SpringCurve(
    spring: spatialSpring,
    duration: medium,
  );

  /// Spring curve sampling [snappySpring] over [fast].
  static final Curve snappySpringCurve = SpringCurve(
    spring: snappySpring,
    duration: fast,
  );

  /// Spring curve sampling [bounceSpring] over [medium].
  static final Curve bounceSpringCurve = SpringCurve(
    spring: bounceSpring,
    duration: medium,
  );
}

/// A [Curve] backed by a real [SpringSimulation]. Lets spring physics plug
/// into TweenAnimationBuilder/AnimatedScale/flutter_animate, which all take
/// curves, without hand-rolling controllers. The [duration] window must be
/// long enough for the spring to settle; the response is normalized so the
/// curve ends exactly at 1 while overshoot is preserved.
class SpringCurve extends Curve {
  final SpringDescription spring;
  final Duration duration;

  SpringCurve({
    required this.spring,
    this.duration = const Duration(milliseconds: 500),
  });

  late final SpringSimulation _simulation = SpringSimulation(spring, 0, 1, 0);

  @override
  double transformInternal(double t) {
    final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
    return _simulation.x(seconds * t) / _simulation.x(seconds);
  }
}

/// Resolves the effective duration for an animation, honoring the user's
/// `enableAnimations` setting and the OS reduce-motion accessibility flag.
/// Returns [Duration.zero] — which makes implicit animations jump instantly —
/// when either is off. Call from `build` so the provider dependency is
/// registered there. Contexts without the settings provider (tests, isolated
/// previews) default to animations enabled.
Duration appMotionDuration(BuildContext context, Duration base) {
  bool enabled;
  try {
    enabled = context.select<PlatformSettingsProvider, bool>(
      (p) => p.enableAnimations,
    );
  } on ProviderNotFoundException {
    enabled = true;
  }
  if (!enabled) return Duration.zero;
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return reduceMotion ? Duration.zero : base;
}
