import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens/colors.dart';
import 'tokens/radius.dart';
import 'tokens/typography.dart';

class AppTheme {
  // Color Palette
  static const Color darkBackground = Color(0xFF101116);
  static const Color darkSurface = Color(0xFF181A22);
  static const Color lightBackground = Color(0xFFF5F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color primaryPurple = Color(0xFFA78BFA);
  static const Color onPrimary = Colors.white;
  static const Color onSurface = Color(0xFFF5F5F5);
  static const Color lightOnSurface = Color(0xFF111111);
  static const Color darkOutline = Color(0x33FFFFFF);
  static const Color lightOutline = Color(0x29000000);

  static const String _fontFamily = AeroText.fontFamily;

  // Radius vocabulary shared by all component themes.
  static const double _radiusTile = AeroRadius.sm;
  static const double _radiusComponent = AeroRadius.md;
  static const double _radiusOverlay = AeroRadius.lg;
  static const double _radiusFab = AeroRadius.lg;

  static ThemeData get darkTheme =>
      _buildTheme(AeroColors.dark, Brightness.dark);

  static ThemeData get lightTheme =>
      _buildTheme(AeroColors.light, Brightness.light);

  /// AMOLED dark variant: pure-black background for OLED power saving.
  /// Same component styling as [darkTheme]; only the palette differs.
  static ThemeData get amoledDarkTheme =>
      _buildTheme(AeroColors.amoled, Brightness.dark);

  /// Single builder so motion and component configuration can never drift
  /// between themes; only colors/alphas differ per palette.
  static ThemeData _buildTheme(AeroColors aero, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = aero.bg;
    final surface = aero.surface1;
    final onSurfaceColor = aero.onSurface;
    final outline = aero.outline;
    final unselectedIconColor = aero.onSurfaceMuted;
    final listTileIconColor = aero.onSurfaceMuted;
    final switchUnselectedThumb = aero.onSurfaceFaint;
    final switchUnselectedTrack = aero.surface3;
    final switchTrackAlpha = isDark ? 0.45 : 0.2;
    final sliderInactiveAlpha = isDark ? 0.2 : 0.1;
    final inputFillColor = aero.surface2;

    final textTheme = AeroText.createTextTheme(onSurfaceColor);

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: aero.primary,
            onPrimary: aero.onPrimary,
            surface: surface,
            onSurface: onSurfaceColor,
            secondary: aero.primary,
            outline: outline,
          )
        : ColorScheme.light(
            primary: aero.primary,
            onPrimary: aero.onPrimary,
            surface: surface,
            onSurface: onSurfaceColor,
            secondary: aero.primary,
            surfaceContainer: aero.surface1,
            outline: outline,
          );

    // M3 Expressive page transition for pushed routes (playlist, login, ...).
    const pageTransitionsTheme = PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      iconTheme: IconThemeData(
        color: onSurfaceColor,
        weight: 400,
        fill: 0,
        opticalSize: 24,
      ),
      pageTransitionsTheme: pageTransitionsTheme,
      extensions: <ThemeExtension<dynamic>>[aero],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurfaceColor,
        elevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarColor: aero.bg,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : null,
      ),
      textTheme: textTheme,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: IconThemeData(color: aero.primary),
        unselectedIconTheme: IconThemeData(color: unselectedIconColor),
        labelType: NavigationRailLabelType.none,
        selectedLabelTextStyle: TextStyle(
          color: aero.primary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: unselectedIconColor,
          fontSize: 11,
        ),
        groupAlignment: 0.0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusComponent),
          side: BorderSide(color: outline),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: surface,
        foregroundColor: onSurfaceColor.withValues(alpha: 0.75),
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusFab),
          side: BorderSide(color: outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: aero.primary,
          foregroundColor: aero.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusComponent),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: aero.primary,
          foregroundColor: aero.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusComponent),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: listTileIconColor,
        textColor: onSurfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_radiusTile)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return aero.primary;
          return switchUnselectedThumb;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return aero.primary.withValues(alpha: switchTrackAlpha);
          }
          return switchUnselectedTrack;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: aero.primary,
        thumbColor: aero.primary,
        inactiveTrackColor: aero.primary.withValues(alpha: sliderInactiveAlpha),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        hintStyle: TextStyle(
          fontFamily: _fontFamily,
          color: aero.onSurfaceFaint,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusComponent),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusComponent),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusComponent),
          borderSide: BorderSide(color: aero.primary, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: aero.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusOverlay),
        ),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: onSurfaceColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: aero.onSurfaceMuted,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: aero.surface1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_radiusOverlay),
          ),
        ),
      ),
    );
  }
}
