import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette
  static const Color darkBackground = Color(0xFF0F0F0F); // Very dark grey, almost black
  static const Color darkSurface = Color(0xFF1E1E1E); // Slightly lighter for cards/sidebar
  static const Color primaryPurple = Color(0xFF8B5CF6); // Vibrant Purple
  static const Color onPrimary = Colors.white;
  static const Color onSurface = Color(0xFFEEEEEE); // Light grey/white for text

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      
      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        onPrimary: onPrimary,
        surface: darkSurface,
        onSurface: onSurface,
        secondary: primaryPurple, // Using purple as main accent
      ),

      // Typography
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: const TextStyle(fontWeight: FontWeight.bold, color: onSurface),
        displayMedium: const TextStyle(fontWeight: FontWeight.bold, color: onSurface),
        displaySmall: const TextStyle(fontWeight: FontWeight.bold, color: onSurface),
        headlineLarge: const TextStyle(fontWeight: FontWeight.bold, color: onSurface),
        headlineMedium: const TextStyle(fontWeight: FontWeight.bold, color: onSurface),
        headlineSmall: const TextStyle(fontWeight: FontWeight.bold, color: onSurface),
        titleLarge: const TextStyle(fontWeight: FontWeight.w600, color: onSurface),
        bodyLarge: const TextStyle(color: onSurface),
        bodyMedium: const TextStyle(color: onSurface),
        labelLarge: const TextStyle(fontWeight: FontWeight.w600), // Buttons
      ),

      // Component Themes
      
      // Navigation Rail (Sidebar)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: darkSurface,
        selectedIconTheme: const IconThemeData(color: primaryPurple),
        unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: const TextStyle(color: primaryPurple, fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        groupAlignment: 0.0,
      ),

      // Card
      // Card
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0, // Flat
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: const StadiumBorder(), // Pill shape
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: onPrimary,
          shape: const StadiumBorder(),
        ),
      ),

      // List Tiles
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.grey, // Default icon color
        textColor: onSurface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),

      // Switches & Sliders
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryPurple;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryPurple.withValues(alpha:0.5);
          return Colors.grey.shade800;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryPurple,
        thumbColor: primaryPurple,
        inactiveTrackColor: primaryPurple.withValues(alpha:0.2),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C), // Darker than surface
        hintStyle: TextStyle(color: Colors.grey.shade500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30), // Fully rounded
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: primaryPurple, width: 1.5),
        ),
      ),
      
      // Dialogs & Bottom Sheets
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    const Color lightBackground = Color(0xFFF9FAFB); // Light Grey/White
    const Color lightSurface = Colors.white;
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primaryPurple,
        onPrimary: onPrimary,
        surface: lightSurface,
        onSurface: Color(0xFF1F2937), // Dark grey for text
        secondary: primaryPurple,
        surfaceContainer: Color(0xFFF3F4F6), // Slightly darker for inputs/containers
      ),

      // Typography - Auto-adapts but we ensure color is correct
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: const Color(0xFF1F2937),
        displayColor: const Color(0xFF1F2937),
      ),

      // Component Themes
      
      // Navigation Rail
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: lightSurface,
        selectedIconTheme: const IconThemeData(color: primaryPurple),
        unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: const TextStyle(color: primaryPurple, fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        groupAlignment: 0.0,
      ),

      // Card
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200), // Subtle border for light mode cards
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: onPrimary,
          shape: const StadiumBorder(),
        ),
      ),

      // List Tiles
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.grey,
        textColor: Color(0xFF1F2937),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),

      // Switches & Sliders
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryPurple;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryPurple.withValues(alpha:0.2);
          return Colors.grey.shade200;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryPurple,
        thumbColor: primaryPurple,
        inactiveTrackColor: primaryPurple.withValues(alpha:0.1),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: primaryPurple, width: 1.5),
        ),
      ),
      
      // Dialogs & Bottom Sheets
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(color: Color(0xFF1F2937), fontSize: 20, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(color: Color(0xFF374151), fontSize: 16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
