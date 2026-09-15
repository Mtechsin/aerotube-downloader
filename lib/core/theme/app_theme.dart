import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Color Palette
  static const Color darkBackground = Colors.black;
  static const Color darkSurface = Colors.black;
  static const Color lightBackground = Colors.white;
  static const Color lightSurface = Colors.white;
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color onPrimary = Colors.white;
  static const Color onSurface = Color(0xFFF5F5F5);
  static const Color lightOnSurface = Color(0xFF111111);
  static const Color darkOutline = Color(0x33FFFFFF);
  static const Color lightOutline = Color(0x22000000);

  static const String _fontFamily = 'Manrope';

  // Radius vocabulary shared by all component themes.
  static const double _radiusTile = 12;
  static const double _radiusComponent = 14;
  static const double _radiusOverlay = 16;
  static const double _radiusFab = 18;

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  /// Single builder so motion and component configuration can never drift
  /// between the dark and light themes; only colors/alphas differ below.
  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? darkBackground : lightBackground;
    final surface = isDark ? darkSurface : lightSurface;
    final onSurfaceColor = isDark ? onSurface : lightOnSurface;
    final outline = isDark ? darkOutline : lightOutline;
    final unselectedIconColor = isDark
        ? const Color(0xFF9C9CA1)
        : const Color(0xFF6D6D72);
    final listTileIconColor = isDark
        ? const Color(0xFFB5B5B8)
        : const Color(0xFF707075);
    final switchUnselectedThumb = isDark
        ? const Color(0xFF8A8A8D)
        : const Color(0xFF9B9BA0);
    final switchUnselectedTrack = isDark
        ? const Color(0xFF2A2A2D)
        : const Color(0xFFE7E7EA);
    final switchTrackAlpha = isDark ? 0.45 : 0.2;
    final sliderInactiveAlpha = isDark ? 0.2 : 0.1;
    final inputFillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.03);

    final baseTextTheme = (isDark ? ThemeData.dark() : ThemeData.light())
        .textTheme
        .apply(fontFamily: _fontFamily);

    // Override weight/color per style with copyWith on the existing style —
    // replacing with fresh const TextStyles here would drop the Manrope
    // fontFamily (TextTheme.copyWith replaces whole styles) and silently
    // fall back to the platform default font.
    final textTheme = isDark
        ? baseTextTheme.copyWith(
            displayLarge: baseTextTheme.displayLarge!
                .copyWith(fontWeight: FontWeight.w700, color: onSurface),
            displayMedium: baseTextTheme.displayMedium!
                .copyWith(fontWeight: FontWeight.w700, color: onSurface),
            displaySmall: baseTextTheme.displaySmall!
                .copyWith(fontWeight: FontWeight.w700, color: onSurface),
            headlineLarge: baseTextTheme.headlineLarge!
                .copyWith(fontWeight: FontWeight.w700, color: onSurface),
            headlineMedium: baseTextTheme.headlineMedium!
                .copyWith(fontWeight: FontWeight.w700, color: onSurface),
            headlineSmall: baseTextTheme.headlineSmall!
                .copyWith(fontWeight: FontWeight.w700, color: onSurface),
            titleLarge: baseTextTheme.titleLarge!
                .copyWith(fontWeight: FontWeight.w600, color: onSurface),
            bodyLarge: baseTextTheme.bodyLarge!.copyWith(color: onSurface),
            bodyMedium: baseTextTheme.bodyMedium!.copyWith(color: onSurface),
            labelLarge: baseTextTheme.labelLarge!
                .copyWith(fontWeight: FontWeight.w600),
          )
        : baseTextTheme.apply(
            bodyColor: lightOnSurface,
            displayColor: lightOnSurface,
          );

    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: primaryPurple,
            onPrimary: onPrimary,
            surface: darkSurface,
            onSurface: onSurface,
            secondary: primaryPurple,
            outline: darkOutline,
          )
        : const ColorScheme.light(
            primary: primaryPurple,
            onPrimary: onPrimary,
            surface: lightSurface,
            onSurface: lightOnSurface,
            secondary: primaryPurple,
            surfaceContainer: Colors.white,
            outline: lightOutline,
          );

    // M3 Expressive page transition for pushed routes (playlist, login, ...).
    const pageTransitionsTheme = PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      pageTransitionsTheme: pageTransitionsTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurfaceColor,
        elevation: 0,
        systemOverlayStyle: isDark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarColor: darkBackground,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : null,
      ),
      textTheme: textTheme,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: const IconThemeData(color: primaryPurple),
        unselectedIconTheme: IconThemeData(color: unselectedIconColor),
        labelType: NavigationRailLabelType.none,
        selectedLabelTextStyle: const TextStyle(
          color: primaryPurple,
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
          side: BorderSide(color: onSurfaceColor.withValues(alpha: 0.12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusComponent),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusComponent),
          ),
          textStyle: const TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: listTileIconColor,
        textColor: onSurfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_radiusTile)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryPurple;
          return switchUnselectedThumb;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryPurple.withValues(alpha: switchTrackAlpha);
          }
          return switchUnselectedTrack;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryPurple,
        thumbColor: primaryPurple,
        inactiveTrackColor: primaryPurple.withValues(
          alpha: sliderInactiveAlpha,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        hintStyle: TextStyle(
          fontFamily: _fontFamily,
          color: isDark ? const Color(0xFF94949A) : const Color(0xFF8A8A90),
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
          borderSide: const BorderSide(color: primaryPurple, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusOverlay),
        ),
        titleTextStyle: isDark
            ? null
            : const TextStyle(
                fontFamily: _fontFamily,
                color: lightOnSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
        contentTextStyle: isDark
            ? null
            : const TextStyle(
                fontFamily: _fontFamily,
                color: Color(0xFF3A3A3F),
                fontSize: 14,
              ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_radiusOverlay),
          ),
        ),
      ),
    );
  }
}
