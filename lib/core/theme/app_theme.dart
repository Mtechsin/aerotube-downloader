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

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme.apply(fontFamily: _fontFamily);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        onPrimary: onPrimary,
        surface: darkSurface,
        onSurface: onSurface,
        secondary: primaryPurple,
        outline: darkOutline,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: onSurface,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: darkBackground,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      textTheme: baseTextTheme
          .copyWith(
            displayLarge: const TextStyle(
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
            displayMedium: const TextStyle(
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
            displaySmall: const TextStyle(
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
            headlineLarge: const TextStyle(
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
            headlineMedium: const TextStyle(
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
            headlineSmall: const TextStyle(
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
            titleLarge: const TextStyle(
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
            bodyLarge: const TextStyle(color: onSurface),
            bodyMedium: const TextStyle(color: onSurface),
            labelLarge: const TextStyle(fontWeight: FontWeight.w600),
          ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: darkSurface,
        selectedIconTheme: const IconThemeData(color: primaryPurple),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF9C9CA1)),
        labelType: NavigationRailLabelType.none,
        selectedLabelTextStyle: const TextStyle(
          color: primaryPurple,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelTextStyle: const TextStyle(color: Color(0xFF9C9CA1), fontSize: 11),
        groupAlignment: 0.0,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkOutline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFFB5B5B8),
        textColor: onSurface,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryPurple;
          return const Color(0xFF8A8A8D);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryPurple.withValues(alpha: 0.45);
          }
          return const Color(0xFF2A2A2D);
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryPurple,
        thumbColor: primaryPurple,
        inactiveTrackColor: primaryPurple.withValues(alpha: 0.2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        hintStyle: const TextStyle(color: Color(0xFF94949A)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryPurple, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme.apply(fontFamily: _fontFamily);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryPurple,
        onPrimary: onPrimary,
        surface: lightSurface,
        onSurface: lightOnSurface,
        secondary: primaryPurple,
        surfaceContainer: Colors.white,
        outline: lightOutline,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightOnSurface,
        elevation: 0,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: lightOnSurface,
        displayColor: lightOnSurface,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: lightSurface,
        selectedIconTheme: const IconThemeData(color: primaryPurple),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF6D6D72)),
        labelType: NavigationRailLabelType.none,
        selectedLabelTextStyle: const TextStyle(
          color: primaryPurple,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelTextStyle: const TextStyle(color: Color(0xFF6D6D72), fontSize: 11),
        groupAlignment: 0.0,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lightOutline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF707075),
        textColor: lightOnSurface,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryPurple;
          return const Color(0xFF9B9BA0);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryPurple.withValues(alpha: 0.2);
          }
          return const Color(0xFFE7E7EA);
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryPurple,
        thumbColor: primaryPurple,
        inactiveTrackColor: primaryPurple.withValues(alpha: 0.1),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.03),
        hintStyle: const TextStyle(color: Color(0xFF8A8A90)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryPurple, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color: lightOnSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFF3A3A3F),
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }
}
