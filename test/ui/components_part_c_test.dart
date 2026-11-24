import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/theme/app_theme.dart';
import 'package:youtube_downloader/core/theme/tokens/spacing.dart';
import 'package:youtube_downloader/ui/components/aero_density.dart';
import 'package:youtube_downloader/ui/components/aero_progress.dart';
import 'package:youtube_downloader/ui/components/aero_scaffold.dart';
import 'package:youtube_downloader/ui/components/url_composer.dart';

void main() {
  group('Phase 2 Components (Part C: AeroScaffold & UrlComposer)', () {
    testWidgets(
      'AeroScaffold renders body, topBar, bottomBar, and floatingTray in compact mode',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: AeroScaffold(
              topBar: const Text('Top Bar Title'),
              bottomBar: const Text('Bottom Nav Bar'),
              floatingTray: const Text('Mini Download Tray'),
              body: const Text('Main Body Content'),
              density: AeroDensity.comfortable,
            ),
          ),
        );

        expect(find.text('Top Bar Title'), findsOneWidget);
        expect(find.text('Bottom Nav Bar'), findsOneWidget);
        expect(find.text('Mini Download Tray'), findsOneWidget);
        expect(find.text('Main Body Content'), findsOneWidget);

        // Verify padding on compact is Android page padding (20 dp)
        expect(
          AeroScaffold.pagePaddingOf(
            tester.element(find.byType(AeroScaffold)),
            AeroDensity.comfortable,
          ).horizontal,
          AeroSpace.androidPage * 2,
        );
      },
    );

    testWidgets(
      'AeroScaffold renders rail, topBar, and docks floatingTray on wide screens',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: AeroScaffold(
              topBar: const Text('Windows Top Strip'),
              rail: const Text('Desktop Left Sidebar'),
              floatingTray: const Text('Docked Download Tray'),
              body: const Text('Desktop Main Content'),
              density: AeroDensity.compact,
            ),
          ),
        );

        expect(find.text('Windows Top Strip'), findsOneWidget);
        expect(find.text('Desktop Left Sidebar'), findsOneWidget);
        expect(find.text('Docked Download Tray'), findsOneWidget);
        expect(find.text('Desktop Main Content'), findsOneWidget);

        // Verify padding on desktop is Windows page padding (32 px)
        expect(
          AeroScaffold.pagePaddingOf(
            tester.element(find.byType(AeroScaffold)),
            AeroDensity.compact,
          ).horizontal,
          AeroSpace.windowsPage * 2,
        );
      },
    );

    testWidgets(
      'UrlComposer state machine: idle, valid, loading, and error states',
      (tester) async {
        final controller = TextEditingController();
        bool fetched = false;
        bool cancelled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return UrlComposer(
                    controller: controller,
                    onFetch: () => fetched = true,
                    onCancel: () => cancelled = true,
                    isLoading: false,
                    errorMessage: null,
                  );
                },
              ),
            ),
          ),
        );

        // 1. Idle state: text is empty, no progress line, no error
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(AeroProgress), findsNothing);

        // 2. Valid state: valid media URL entered
        await tester.enterText(
          find.byType(TextField),
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        );
        await tester.pumpAndSettle();

        // Tap Fetch button
        final fetchButton = find.byIcon(Symbols.arrow_forward_rounded);
        expect(fetchButton, findsOneWidget);
        await tester.tap(fetchButton);
        expect(fetched, isTrue);

        // 3. Loading state: displays inline progress line along bottom edge and cancel button
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: UrlComposer(
                controller: controller,
                onFetch: () {},
                onCancel: () => cancelled = true,
                isLoading: true,
                statusMessage: 'Connecting to YouTube...',
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AeroProgress), findsOneWidget);
        expect(find.text('Connecting to YouTube...'), findsOneWidget);

        final cancelButton = find.byTooltip('Cancel');
        expect(cancelButton, findsOneWidget);
        await tester.tap(cancelButton);
        expect(cancelled, isTrue);

        // 4. Error state: displays inline error below the field
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: UrlComposer(
                controller: controller,
                onFetch: () {},
                isLoading: false,
                errorMessage: 'Could not resolve video metadata.',
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Could not resolve video metadata.'), findsOneWidget);
        expect(find.byIcon(Symbols.error_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'UrlComposer strictly obeys H27 privacy rule and pastes only upon user tap',
      (tester) async {
        int clipboardReadCount = 0;

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.getData') {
              clipboardReadCount++;
              return <String, dynamic>{'text': 'https://youtu.be/test1234'};
            }
            return null;
          },
        );

        final controller = TextEditingController();

        // Init and build component
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: UrlComposer(controller: controller, onFetch: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // H27 Assertion: zero clipboard reads on initialization and render
        expect(clipboardReadCount, equals(0));
        expect(controller.text, isEmpty);

        // Explicit user tap on Paste button
        final pasteButton = find.byIcon(Symbols.content_paste_rounded);
        expect(pasteButton, findsOneWidget);
        await tester.tap(pasteButton);
        await tester.pumpAndSettle();

        // Clipboard was read exactly once upon tap, and text populated
        expect(clipboardReadCount, equals(1));
        expect(controller.text, equals('https://youtu.be/test1234'));
      },
    );
  });
}
