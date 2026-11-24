import 'package:flutter/material.dart';

/// Density configuration for Aero components.
/// - [comfortable]: 48dp+ touch targets, 56dp inputs, optimized for touch / Android.
/// - [compact]: 40px controls, 48px inputs, optimized for pointer / Windows.
enum AeroDensity {
  comfortable,
  compact;

  /// Whether this density is compact.
  bool get isCompact => this == AeroDensity.compact;

  /// Resolves the effective [AeroDensity].
  ///
  /// If [explicit] is specified, it takes precedence. Otherwise:
  /// - Desktop platforms (Windows, macOS, Linux) resolve to [compact].
  /// - Mobile platforms (Android, iOS) resolve to [comfortable].
  static AeroDensity resolve(BuildContext context, [AeroDensity? explicit]) {
    if (explicit != null) return explicit;
    final platform = Theme.of(context).platform;
    final isDesktop =
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS;
    return isDesktop ? AeroDensity.compact : AeroDensity.comfortable;
  }
}
