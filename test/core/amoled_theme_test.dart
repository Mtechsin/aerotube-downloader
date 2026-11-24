import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/core/theme/app_theme.dart';
import 'package:youtube_downloader/core/theme/tokens/colors.dart';
import 'package:youtube_downloader/models/app_settings.dart';
import 'package:youtube_downloader/services/core/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AMOLED dark palette', () {
    test('amoled palette is pure black', () {
      expect(AeroColors.amoled.bg, const Color(0xFF000000));
      // Surfaces stay near-black so cards/dialogs read as elevated, not grey.
      expect(AeroColors.amoled.surface1.computeLuminance(), lessThan(0.02));
      expect(AeroColors.amoled.surface2.computeLuminance(), lessThan(0.02));
      expect(AeroColors.amoled.surface1, isNot(AeroColors.amoled.bg));
    });

    test('amoled theme is a dark theme with scaffold background', () {
      final theme = AppTheme.amoledDarkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(theme.colorScheme.brightness, Brightness.dark);
      // Paridade com o tema dark padrão: mesma paleta de accent.
      expect(theme.colorScheme.primary, AppTheme.darkTheme.colorScheme.primary);
    });

    test('regular dark theme keeps its navy-grey background', () {
      expect(AppTheme.darkTheme.scaffoldBackgroundColor, isNot(const Color(0xFF000000)));
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
    });
  });

  group('AppSettings.amoledDark', () {
    test('defaults to false', () {
      expect(AppSettings().amoledDark, false);
    });

    test('copyWith preserves and overrides', () {
      final base = AppSettings();
      final on = base.copyWith(amoledDark: true);
      expect(on.amoledDark, true);
      expect(on.copyWith().amoledDark, true);
      expect(on.copyWith(amoledDark: false).amoledDark, false);
      // Amoled must not disturb themeMode.
      expect(on.themeMode, base.themeMode);
    });
  });

  group('SettingsService.amoledDark persistence', () {
    test('setAmoledDark survives a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SettingsService();
      await service.init();
      expect(service.settings.amoledDark, false);

      await service.setAmoledDark(true);
      expect(service.settings.amoledDark, true);

      // Recreate the service to force a fresh load from storage.
      final reread = SettingsService();
      await reread.init();
      expect(reread.settings.amoledDark, true);
    });
  });
}
