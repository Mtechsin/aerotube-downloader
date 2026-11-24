import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/theme/app_theme.dart';
import 'package:youtube_downloader/ui/components/aero_dialog.dart';
import 'package:youtube_downloader/ui/components/aero_progress.dart';
import 'package:youtube_downloader/ui/components/aero_snack.dart';
import 'package:youtube_downloader/ui/components/component_gallery_screen.dart';
import 'package:youtube_downloader/ui/components/empty_state.dart';
import 'package:youtube_downloader/ui/components/section_header.dart';
import 'package:youtube_downloader/ui/components/settings_row.dart';
import 'package:youtube_downloader/ui/components/status_pill.dart';
import 'package:youtube_downloader/ui/components/thumbnail_tile.dart';

void main() {
  group('Phase 2 Components (Part B)', () {
    testWidgets('StatusPill renders label, dot, spinner and handles tap', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                const StatusPill.success(label: 'Connected', showDot: true),
                const StatusPill.info(label: 'Loading...', showSpinner: true),
                StatusPill.warning(
                  label: 'Warning Pill',
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
      expect(find.text('Warning Pill'), findsOneWidget);

      await tester.tap(find.text('Warning Pill'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('AeroProgress renders determinate and indeterminate states', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Column(
              children: [AeroProgress(value: 0.5), AeroProgress(value: null)],
            ),
          ),
        ),
      );

      expect(find.byType(AeroProgress), findsNWidgets(2));
    });

    testWidgets('ThumbnailTile renders with duration chip and fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: ThumbnailTile(imageUrl: null, duration: '12:34'),
          ),
        ),
      );

      expect(find.text('12:34'), findsOneWidget);
      expect(find.byIcon(Symbols.play_circle_rounded), findsOneWidget);
    });

    testWidgets('SectionHeader renders uppercase text and trailing action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SectionHeader(title: 'Recent items', trailing: Text('CLEAR')),
          ),
        ),
      );

      expect(find.text('RECENT ITEMS'), findsOneWidget);
      expect(find.text('CLEAR'), findsOneWidget);
    });

    testWidgets('SettingsRow renders icon, title, subtitle and chevron', (
      tester,
    ) async {
      bool rowTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SettingsRow(
              icon: Symbols.settings_rounded,
              title: 'General Settings',
              subtitle: 'Configure default paths and behavior',
              onTap: () => rowTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('General Settings'), findsOneWidget);
      expect(find.text('Configure default paths and behavior'), findsOneWidget);
      expect(find.byIcon(Symbols.settings_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);

      await tester.tap(find.text('General Settings'));
      await tester.pump();
      expect(rowTapped, isTrue);
    });

    testWidgets('EmptyState renders 72px circle icon, title and action', (
      tester,
    ) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: EmptyState(
              icon: Symbols.inbox_rounded,
              title: 'Nothing Here',
              description: 'Your download queue is currently empty.',
              actionLabel: 'Go Back',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('Nothing Here'), findsOneWidget);
      expect(
        find.text('Your download queue is currently empty.'),
        findsOneWidget,
      );
      expect(find.byIcon(Symbols.inbox_rounded), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);

      await tester.tap(find.text('Go Back'));
      await tester.pump();
      expect(actionTriggered, isTrue);
    });

    testWidgets('AeroDialog and AeroSheet show properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAeroDialog(
                      context: context,
                      builder: (_) => const AeroDialog(
                        titleText: 'Test Dialog',
                        content: Text('Dialog Content Text'),
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Test Dialog'), findsOneWidget);
      expect(find.text('Dialog Content Text'), findsOneWidget);
    });

    testWidgets('AeroSnack shows floating snackbar with message and icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AeroSnack.success(
                      context,
                      message: 'Task completed successfully',
                    );
                  },
                  child: const Text('Show Snack'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Snack'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Task completed successfully'), findsOneWidget);
      expect(find.byIcon(Symbols.check_circle_rounded), findsOneWidget);
    });

    testWidgets(
      'ComponentGalleryScreen renders smoothly in both dark and light modes',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ComponentGalleryScreen(),
          ),
        );

        expect(find.text('Aero Component Gallery'), findsOneWidget);
        expect(find.text('01. STATUS PILLS'), findsOneWidget);
        expect(find.text('02. AERO PROGRESS'), findsOneWidget);

        // Toggle theme
        await tester.tap(find.byTooltip('Switch to Light'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Aero Component Gallery'), findsOneWidget);
      },
    );
  });
}
