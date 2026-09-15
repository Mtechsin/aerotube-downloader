import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/utils/platform_utils.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/services/core/file_action_service.dart';
import 'package:youtube_downloader/ui/screens/downloads_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sampleFile;
  final List<MethodCall> methodCalls = [];
  dynamic methodChannelHandlerResult = true;

  setUp(() async {
    methodCalls.clear();
    methodChannelHandlerResult = true;
    PlatformUtils.isAndroidOverride = true;

    tempDir = await Directory.systemTemp.createTemp('card_stress_test_');
    sampleFile = File('${tempDir.path}/test_download.mp4');
    await sampleFile.writeAsString('sample content');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(FileActionService.channelName),
      (MethodCall call) async {
        methodCalls.add(call);
        if (methodChannelHandlerResult is Exception) {
          throw methodChannelHandlerResult;
        }
        return methodChannelHandlerResult;
      },
    );
  });

  tearDown(() async {
    PlatformUtils.isAndroidOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(FileActionService.channelName), null);

    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Widget buildTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    );
  }

  DownloadItem createItemWithStatus(
    DownloadStatus status, {
    String? savePath,
    String? outputPath,
    String? error,
  }) {
    return DownloadItem(
      id: 'item-${status.name}',
      title: 'Test Video - ${status.name}',
      url: 'https://youtube.com/watch?v=12345',
      outputPath: outputPath ?? tempDir.path,
      savePath: savePath ?? (status == DownloadStatus.completed ? sampleFile.path : null),
      status: status,
      progress: status == DownloadStatus.completed ? 1.0 : 0.5,
      totalBytes: 25 * 1024 * 1024,
      audioOnly: false,
      error: error,
    );
  }

  group('CHALLENGE 1: Status Matrix & Action Button Visibility', () {
    final nonCompletedStatuses = [
      DownloadStatus.pending,
      DownloadStatus.queued,
      DownloadStatus.downloadingVideo,
      DownloadStatus.downloadingAudio,
      DownloadStatus.merging,
      DownloadStatus.paused,
      DownloadStatus.cancelled,
      DownloadStatus.failed,
    ];

    for (final status in nonCompletedStatuses) {
      testWidgets('status=${status.name}: Completed actions NEVER appear and card tap is inert', (tester) async {
        final item = createItemWithStatus(
          status,
          error: status == DownloadStatus.failed ? 'Network timeout occurred' : null,
        );

        await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
        await tester.pumpAndSettle();

        // 1. None of the completed action buttons should exist
        expect(find.byTooltip('Open'), findsNothing,
            reason: 'Open button should NOT appear for ${status.name}');
        expect(find.byTooltip('Share'), findsNothing,
            reason: 'Share button should NOT appear for ${status.name}');
        expect(find.byTooltip('Show in folder'), findsNothing,
            reason: 'Show in folder button should NOT appear for ${status.name}');
        expect(find.byTooltip('More actions'), findsNothing,
            reason: 'More actions button should NOT appear for ${status.name}');

        // 2. Tapping the card should NOT trigger any file action
        await tester.tap(find.text(item.title));
        await tester.pumpAndSettle();

        expect(methodCalls.isEmpty, isTrue,
            reason: 'Tapping card body should be inert for status ${status.name}');

        // 3. Status-specific validation
        if (status == DownloadStatus.paused) {
          expect(find.text('Resume'), findsOneWidget);
          expect(find.text('Paused'), findsOneWidget);
        } else if (status == DownloadStatus.downloadingVideo ||
                   status == DownloadStatus.downloadingAudio ||
                   status == DownloadStatus.merging ||
                   status == DownloadStatus.pending ||
                   status == DownloadStatus.queued) {
          expect(find.text('Pause'), findsOneWidget);
        } else if (status == DownloadStatus.failed) {
          expect(find.text('Network timeout occurred'), findsOneWidget);
        }
      });
    }

    testWidgets('status=completed: All actions appear and card tap triggers openFile', (tester) async {
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Open'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
      expect(find.byTooltip('Show in folder'), findsOneWidget);
      expect(find.byTooltip('More actions'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Card tap triggers openFile
      await tester.tap(find.text(item.title));
      await tester.pumpAndSettle();

      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('openFile'));
      expect(methodCalls.first.arguments['filePath'], equals(sampleFile.path));
      expect(methodCalls.first.arguments['useChooser'], isFalse);
    });
  });

  group('CHALLENGE 2: More Actions Popup Menu Full Verification', () {
    testWidgets('More actions exposes Open, Open with, Share, Show in folder, and Delete', (tester) async {
      bool deleteCalled = false;
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(
        item: item,
        onDelete: () => deleteCalled = true,
      )));
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Open with...'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Show in folder'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Test Delete item selection
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
    });

    testWidgets('More actions "open" item launches openFile without chooser', (tester) async {
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('openFile'));
      expect(methodCalls.first.arguments['useChooser'], isFalse);
    });

    testWidgets('More actions "open_with" item launches openFile with useChooser=true', (tester) async {
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open with...'));
      await tester.pumpAndSettle();

      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('openFile'));
      expect(methodCalls.first.arguments['useChooser'], isTrue);
    });

    testWidgets('More actions "share" item launches shareFile', (tester) async {
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('shareFile'));
      expect(methodCalls.first.arguments['filePath'], equals(sampleFile.path));
    });

    testWidgets('More actions "show_folder" item launches openFolder', (tester) async {
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show in folder'));
      await tester.pumpAndSettle();

      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('openFolder'));
      expect(methodCalls.first.arguments['folderPath'], equals(tempDir.path));
    });
  });

  group('CHALLENGE 3: Error Feedback SnackBars', () {
    testWidgets('Shows SnackBar when file is missing from disk', (tester) async {
      final nonExistentPath = '${tempDir.path}/deleted_by_user.mp4';
      final item = createItemWithStatus(DownloadStatus.completed, savePath: nonExistentPath);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      // Open on missing file
      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('File not found on device.'), findsOneWidget);

      // Dismiss previous snackbar
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Share on missing file
      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('File not found on device.'), findsOneWidget);
    });

    testWidgets('Shows SnackBar when path is empty string', (tester) async {
      final item = createItemWithStatus(
        DownloadStatus.completed,
        savePath: '',
        outputPath: '',
      );

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('File path cannot be empty.'), findsOneWidget);
    });

    testWidgets('Shows SnackBar when folder path is empty string', (tester) async {
      final item = createItemWithStatus(
        DownloadStatus.completed,
        savePath: '',
        outputPath: '',
      );

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Show in folder'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Folder path cannot be empty.'), findsOneWidget);
    });

    testWidgets('Shows SnackBar when native channel throws NO_APP_FOUND on openFile', (tester) async {
      methodChannelHandlerResult = PlatformException(
        code: 'NO_APP_FOUND',
        message: 'No activity found to handle Intent',
      );
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('No application found to open this file.'), findsOneWidget);
    });

    testWidgets('Shows SnackBar when native channel throws NO_APP_FOUND on shareFile', (tester) async {
      methodChannelHandlerResult = PlatformException(
        code: 'NO_APP_FOUND',
        message: 'No activity found to handle Intent',
      );
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('No application found to share this file.'), findsOneWidget);
    });

    testWidgets('Shows SnackBar when native channel throws NO_APP_FOUND on openFolder', (tester) async {
      methodChannelHandlerResult = PlatformException(
        code: 'NO_APP_FOUND',
        message: 'No activity found to handle Intent',
      );
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Show in folder'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('No file manager found on device.'), findsOneWidget);
    });

    testWidgets('Shows SnackBar when native channel throws FILE_NOT_FOUND on openFile', (tester) async {
      methodChannelHandlerResult = PlatformException(
        code: 'FILE_NOT_FOUND',
        message: 'Native reported missing file',
      );
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('File not found on device.'), findsOneWidget);
    });

    testWidgets('Shows SnackBar with message on arbitrary PlatformException', (tester) async {
      methodChannelHandlerResult = PlatformException(
        code: 'PERMISSION_DENIED',
        message: 'Security manager denied read access',
      );
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Security manager denied read access'), findsOneWidget);
    });

    testWidgets('Shows SnackBar when native channel returns false (generic failure)', (tester) async {
      methodChannelHandlerResult = false;
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Failed to open file.'), findsOneWidget);
    });
  });

  group('CHALLENGE 4: Fallback Paths, Unicode Filenames & Stress Harness', () {
    testWidgets('Fallback: When savePath is null, uses outputPath as fallback', (tester) async {
      final item = DownloadItem(
        id: 'fallback-1',
        title: 'Fallback Test Video',
        url: 'https://youtube.com/watch?v=xyz',
        outputPath: sampleFile.path, // points to valid file
        savePath: null,              // null savePath
        status: DownloadStatus.completed,
        progress: 1.0,
        audioOnly: false,
      );

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('openFile'));
      expect(methodCalls.first.arguments['filePath'], equals(sampleFile.path));
    });

    testWidgets('Fallback: When savePath is null and outputPath is directory, openFolder targets directory safely', (tester) async {
      final item = DownloadItem(
        id: 'fallback-dir-1',
        title: 'Fallback Dir Video',
        url: 'https://youtube.com/watch?v=xyz',
        outputPath: tempDir.path, // directory
        savePath: null,
        status: DownloadStatus.completed,
        progress: 1.0,
        audioOnly: false,
      );

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Show in folder'));
      await tester.pumpAndSettle();

      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('openFolder'));
      expect(methodCalls.first.arguments['folderPath'], equals(tempDir.path));

      // Attempting to open a directory as a file cleanly shows SnackBar without crash
      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('File not found on device.'), findsOneWidget);
    });

    testWidgets('Handles unicode, spaces, and special symbols in file path correctly', (tester) async {
      final unicodeFile = File('${tempDir.path}/日本語 🎵 [1080p] #1 - test (official).mp4');
      unicodeFile.writeAsStringSync('unicode test payload');

      final item = DownloadItem(
        id: 'unicode-1',
        title: '日本語 🎵 [1080p] #1 - test (official)',
        url: 'https://youtube.com/watch?v=unicode',
        outputPath: tempDir.path,
        savePath: unicodeFile.path,
        status: DownloadStatus.completed,
        progress: 1.0,
        audioOnly: false,
      );

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.arguments['filePath'], equals(unicodeFile.path));

      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();

      expect(methodCalls.length, equals(2));
      expect(methodCalls.last.arguments['filePath'], equals(unicodeFile.path));
      expect(methodCalls.last.arguments['title'], equals('日本語 🎵 [1080p] #1 - test (official)'));
    });

    testWidgets('Rapid stress tapping on Open does not cause crash or duplicate unhandled exceptions', (tester) async {
      final item = createItemWithStatus(DownloadStatus.completed);

      await tester.pumpWidget(buildTestApp(MobileDownloadItem(item: item)));
      await tester.pumpAndSettle();

      // Fire 5 rapid taps in quick succession
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('Open'));
      }
      await tester.pumpAndSettle();

      expect(methodCalls.length, equals(5));
      expect(methodCalls.every((c) => c.method == 'openFile'), isTrue);
    });
  });
}
