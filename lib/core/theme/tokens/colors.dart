import 'package:flutter/material.dart';

@immutable
class AeroColors extends ThemeExtension<AeroColors> {
  final Color bg;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color outline;
  final Color outlineStrong;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color onSurfaceFaint;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color primaryGlow;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  const AeroColors({
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.outline,
    required this.outlineStrong,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.onSurfaceFaint,
    required this.primary,
    this.onPrimary = Colors.white,
    required this.primarySoft,
    required this.primaryGlow,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  static const dark = AeroColors(
    bg: Color(0xFF101116),
    surface1: Color(0xFF181A22),
    surface2: Color(0xFF20232D),
    surface3: Color(0xFF2A2E3A),
    outline: Color(0x1AFFFFFF), // 10%
    outlineStrong: Color(0x33FFFFFF), // 20%
    onSurface: Color(0xFFF5F5F5),
    onSurfaceMuted: Color(0xFFA1A1A8),
    onSurfaceFaint: Color(0xFF9297A6),
    primary: Color(0xFFA78BFA),
    onPrimary: Color(0xFF181022),
    primarySoft: Color(0x298B5CF6), // 16%
    primaryGlow: Color(0x598B5CF6), // 35%
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    info: Color(0xFF60A5FA),
  );

  static const light = AeroColors(
    bg: Color(0xFFF5F6FA),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFF0F1F7),
    surface3: Color(0xFFE6E8F0),
    outline: Color(0x14000000), // 8%
    outlineStrong: Color(0x29000000), // 16%
    onSurface: Color(0xFF111111),
    onSurfaceMuted: Color(0xFF6B6B72),
    onSurfaceFaint: Color(0xFF737889),
    primary: Color(0xFF7C3AED),
    primarySoft: Color(0x1A7C3AED), // 10%
    primaryGlow: Color(0x407C3AED), // 25%
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
  );

  /// AMOLED dark palette: pure-black background so OLED pixels stay fully
  /// off (saves battery and blends into the bezel). Surfaces step up in
  /// near-black neutrals instead of the grey-blue used by [dark].
  static const amoled = AeroColors(
    bg: Color(0xFF000000),
    surface1: Color(0xFF0A0A0D),
    surface2: Color(0xFF141417),
    surface3: Color(0xFF1E1E23),
    outline: Color(0x1AFFFFFF), // 10%
    outlineStrong: Color(0x33FFFFFF), // 20%
    onSurface: Color(0xFFF5F5F5),
    onSurfaceMuted: Color(0xFFA1A1A8),
    onSurfaceFaint: Color(0xFF9297A6),
    primary: Color(0xFFA78BFA),
    onPrimary: Color(0xFF181022),
    primarySoft: Color(0x298B5CF6), // 16%
    primaryGlow: Color(0x598B5CF6), // 35%
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    info: Color(0xFF60A5FA),
  );

  @override
  AeroColors copyWith({
    Color? bg,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? outline,
    Color? outlineStrong,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? onSurfaceFaint,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? primaryGlow,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return AeroColors(
      bg: bg ?? this.bg,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      outline: outline ?? this.outline,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      onSurfaceFaint: onSurfaceFaint ?? this.onSurfaceFaint,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryGlow: primaryGlow ?? this.primaryGlow,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  AeroColors lerp(ThemeExtension<AeroColors>? other, double t) {
    if (other is! AeroColors) return this;
    return AeroColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      onSurfaceFaint: Color.lerp(onSurfaceFaint, other.onSurfaceFaint, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primaryGlow: Color.lerp(primaryGlow, other.primaryGlow, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

extension AeroColorsBuildContext on BuildContext {
  AeroColors get aero =>
      Theme.of(this).extension<AeroColors>() ?? AeroColors.dark;
}
