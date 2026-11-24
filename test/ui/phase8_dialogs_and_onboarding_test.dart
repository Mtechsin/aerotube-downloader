import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/core/theme/app_theme.dart';
import 'package:youtube_downloader/core/utils/error_helper.dart';
import 'package:youtube_downloader/providers/update_provider.dart';
import 'package:youtube_downloader/services/core/update_service.dart';
import 'package:youtube_downloader/ui/components/aero_button.dart';
import 'package:youtube_downloader/ui/components/aero_chip.dart';
import 'package:youtube_downloader/ui/components/aero_dialog.dart';
import 'package:youtube_downloader/ui/components/aero_progress.dart';
import 'package:youtube_downloader/ui/screens/onboarding_screen.dart';
import 'package:youtube_downloader/ui/widgets/error_details_dialog.dart';
import 'package:youtube_downloader/ui/widgets/update_dialog.dart';

class _MockUpdateService extends Fake implements UpdateService {
  UpdateInfo? stubInfo;

  @override
  Future<String> getCurrentVersion() async => '2.4.0';

  bool isNewerVersion(String latest, String current) => true;

  @override
  Future<UpdateInfo?> checkForUpdate(
    String currentVersion, {
    bool force = false,
  }) async {
    return stubInfo;
  }

  Completer<String>? downloadCompleter;

  @override
  Future<String> downloadUpdate(
    String downloadUrl,
    void Function(double progress) onProgress, {
    String? expectedSha256,
    bool Function()? isCancelled,
  }) async {
    onProgress(0.65);
    if (downloadCompleter != null) {
      return downloadCompleter!.future;
    }
    return '/tmp/aerotube.apk';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(theme: AppTheme.darkTheme, home: child);
  }

  group('Phase 8: OnboardingScreen Tests', () {
    testWidgets(
      'renders 3 pages, Skip button, and advances to last permissions page',
      (tester) async {
        bool completed = false;

        await tester.pumpWidget(
          wrapWithTheme(
            OnboardingScreen(
              onComplete: () {
                completed = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Page 1: Welcome
        expect(find.text('Welcome to AeroTube'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);

        // Tap Skip -> completes immediately
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(completed, isTrue);

        // Re-render and advance through pages
        completed = false;
        await tester.pumpWidget(
          wrapWithTheme(
            OnboardingScreen(
              onComplete: () {
                completed = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to page 2: Formats & Quality
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Formats & Quality'), findsOneWidget);

        // Advance to page 3: Permissions & Setup
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Permissions & Setup'), findsOneWidget);
        expect(find.text('Storage Access'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Get Started'), findsOneWidget);

        // Tap Get Started
        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();
        expect(completed, isTrue);
      },
    );
  });

  group('Phase 8: UpdateDialog Tests', () {
    testWidgets(
      'available state renders AeroDialog with version chip, 3 bullets, and actions',
      (tester) async {
        final mockService = _MockUpdateService();
        final stubInfo = UpdateInfo(
          version: '2.5.0',
          downloadUrl: 'https://example.com/aerotube.apk',
          releaseNotes:
              '- Fix 4K playback extraction\n- Add sponsorblock skipping\n- Improve download speed\n- Extra line',
          publishedAt: DateTime.now(),
          assetSize: 10485760,
        );
        mockService.stubInfo = stubInfo;

        final updateProvider = UpdateProvider(updateService: mockService);
        await updateProvider.checkForUpdates(force: true);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: ChangeNotifierProvider<UpdateProvider>.value(
              value: updateProvider,
              child: const UpdateDialog(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must be wrapped in AeroDialog
        expect(find.byType(AeroDialog), findsOneWidget);

        // Version chip
        expect(find.text('v2.5.0'), findsOneWidget);
        expect(find.byType(AeroChip), findsOneWidget);

        // 3 bullet changelog extracted
        expect(find.text('Fix 4K playback extraction'), findsOneWidget);
        expect(find.text('Add sponsorblock skipping'), findsOneWidget);
        expect(find.text('Improve download speed'), findsOneWidget);

        // Action buttons: Update now & Later
        expect(find.text('Later'), findsOneWidget);
        expect(find.text('Update now'), findsOneWidget);
      },
    );

    testWidgets(
      'downloading state renders inline AeroProgress with tabular numbers',
      (tester) async {
        final mockService = _MockUpdateService();
        final stubInfo = UpdateInfo(
          version: '2.5.0',
          downloadUrl: 'https://example.com/aerotube.apk',
          releaseNotes: 'Release notes',
          publishedAt: DateTime.now(),
          assetSize: 10485760,
        );
        mockService.stubInfo = stubInfo;

        final updateProvider = UpdateProvider(updateService: mockService);
        await updateProvider.checkForUpdates(force: true);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: ChangeNotifierProvider<UpdateProvider>.value(
              value: updateProvider,
              child: const UpdateDialog(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final completer = Completer<String>();
        mockService.downloadCompleter = completer;

        // Trigger download
        final downloadFuture = updateProvider.downloadUpdate();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.byType(AeroDialog), findsOneWidget);
        expect(find.text('Downloading Update'), findsOneWidget);
        expect(find.text('65%'), findsOneWidget);
        expect(find.byType(AeroProgress), findsOneWidget);
        expect(find.text('Cancel Download'), findsOneWidget);

        completer.complete('/tmp/aerotube.apk');
        await downloadFuture;
        await tester.pumpAndSettle();
      },
    );
  });

  group('Phase 8: ErrorDetailsDialog Tests', () {
    testWidgets(
      'renders AeroDialog with human summary and expandable technical details',
      (tester) async {
        final errorHelper = ErrorHelper(
          title: 'Network Timeout',
          friendlyMessage:
              'Could not connect to YouTube servers. Please verify your connection.',
          suggestion:
              'Check your Wi-Fi or mobile data connection and try again.',
          technicalDetails:
              'SocketException: OS Error: Connection timed out, errno = 110',
          category: ErrorCategory.network,
        );

        bool retryCalled = false;

        await tester.pumpWidget(
          wrapWithTheme(
            ErrorDetailsDialog(
              errorHelper: errorHelper,
              onRetry: () {
                retryCalled = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must be wrapped in AeroDialog
        expect(find.byType(AeroDialog), findsOneWidget);

        // Friendly summary and recommendation
        expect(find.text('Network Timeout'), findsOneWidget);
        expect(
          find.text(
            'Could not connect to YouTube servers. Please verify your connection.',
          ),
          findsOneWidget,
        );
        expect(find.text('Recommended Action'), findsOneWidget);

        // Technical details row
        expect(find.text('Technical Details'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);

        // Expand technical details
        await tester.tap(find.text('Technical Details'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'SocketException: OS Error: Connection timed out, errno = 110',
          ),
          findsOneWidget,
        );

        // Retry action button
        expect(find.text('Retry'), findsOneWidget);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(retryCalled, isTrue);
      },
    );
  });

  group('Phase 8: Polish & Accessibility Audit', () {
    testWidgets('AeroButton exposes Semantics and focus ring support', (
      tester,
    ) async {
      bool pressed = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        wrapWithTheme(
          AeroButton(
            focusNode: focusNode,
            text: 'Download Now',
            onPressed: () {
              pressed = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Semantics verify
      expect(find.bySemanticsLabel('Download Now'), findsOneWidget);

      // Request focus
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.tap(find.byType(AeroButton));
      await tester.pump();
      expect(pressed, isTrue);

      focusNode.dispose();
    });

    testWidgets('AeroChip exposes Semantics button and focus detector', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        wrapWithTheme(
          AeroChip(
            text: '1080p MP4',
            selected: true,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1080p MP4'), findsOneWidget);

      await tester.tap(find.byType(AeroChip));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
