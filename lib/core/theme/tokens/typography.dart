import 'package:flutter/material.dart';

class AeroText {
  static const String fontFamily = 'Manrope';

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const TextStyle titleSm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 21 / 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 19 / 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  static const TextStyle mono = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    fontFamily: 'monospace',
    fontFamilyFallback: <String>[
      'Consolas',
      'Courier New',
      'Courier',
      'monospace',
    ],
  );

  /// Helper to return a TextStyle with tabular figures enabled for counters, ETA, speed, etc.
  static TextStyle tabularFigures(TextStyle style) {
    return style.copyWith(
      fontFeatures: [
        ...?style.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );
  }

  /// Builds a complete Material TextTheme mapped from the Aero design scale.
  static TextTheme createTextTheme(Color onSurfaceColor) {
    return TextTheme(
      displayLarge: display.copyWith(color: onSurfaceColor),
      displayMedium: display.copyWith(
        fontSize: 34,
        height: 38 / 34,
        color: onSurfaceColor,
      ),
      displaySmall: headline.copyWith(color: onSurfaceColor),
      headlineLarge: headline.copyWith(color: onSurfaceColor),
      headlineMedium: headline.copyWith(
        fontSize: 24,
        height: 30 / 24,
        color: onSurfaceColor,
      ),
      headlineSmall: title.copyWith(color: onSurfaceColor),
      titleLarge: title.copyWith(color: onSurfaceColor),
      titleMedium: titleSm.copyWith(color: onSurfaceColor),
      titleSmall: titleSm.copyWith(
        fontSize: 14,
        height: 20 / 14,
        color: onSurfaceColor,
      ),
      bodyLarge: body.copyWith(
        fontSize: 16,
        height: 24 / 16,
        color: onSurfaceColor,
      ),
      bodyMedium: body.copyWith(color: onSurfaceColor),
      bodySmall: bodySm.copyWith(color: onSurfaceColor),
      labelLarge: label.copyWith(
        fontSize: 14,
        height: 18 / 14,
        color: onSurfaceColor,
      ),
      labelMedium: label.copyWith(color: onSurfaceColor),
      labelSmall: caption.copyWith(color: onSurfaceColor),
    );
  }
}

extension AeroTextStyleExtension on TextStyle {
  TextStyle withTabularFigures() => AeroText.tabularFigures(this);
}
