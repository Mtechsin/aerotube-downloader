import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/utils/platform_utils.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/services/core/file_action_service.dart';
import 'package:youtube_downloader/ui/screens/downloads_screen.dart';
import 'package:youtube_downloader/ui/widgets/download_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sampleFile;
  final List<MethodCall> methodCalls = [];
  bool mockMethodResult = true;

  setUp(() async {
    methodCalls.clear();
    mockMethodResult = true;
    PlatformUtils.isAndroidOverride = true;

    tempDir = await Directory.systemTemp.createTemp('ui_actions_test_');
    sampleFile = File('${tempDir.path}/test_download.mp4');
    await sampleFile.writeAsString('dummy content');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(FileActionService.channelName),
      (MethodCall call) async {
        methodCalls.add(call);
        return mockMethodResult;
      },
    );
  });

  tearDown(() async {
    PlatformUtils.isAndroidOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(FileActionService.channelName), null);

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  DownloadItem createCompletedItem({String? savePath}) {
    return DownloadItem(
      id: 'completed-1',
      title: 'Completed Test Video',
      url: 'https://youtube.com/watch?v=abcdef',
      outputPath: tempDir.path,
      savePath: savePath ?? sampleFile.path,
      status: DownloadStatus.completed,
      progress: 1.0,
      totalBytes: 15 * 1024 * 1024,
      audioOnly: false,
    );
  }

  DownloadItem createActiveItem() {
    return DownloadItem(
      id: 'active-1',
      title: 'Downloading Test Video',
      url: 'https://youtube.com/watch?v=abcdef',
      outputPath: tempDir.path,
      status: DownloadStatus.downloadingVideo,
      progress: 0.45,
      audioOnly: false,
    );
  }

  Widget createWidgetUnderTest(DownloadItem item, {VoidCallback? onDelete}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: MobileDownloadItem(
            item: item,
            onDelete: onDelete,
          ),
        ),
      ),
    );
  }

  group('MobileDownloadItem Completed Card Actions', () {
    testWidgets('renders Open, Share, Show in Folder, and More buttons when completed', (tester) async {
      final item = createCompletedItem();

      await tester.pumpWidget(createWidgetUnderTest(item));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Open'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
      expect(find.byTooltip('Show in folder'), findsOneWidget);
      expect(find.byTooltip('More actions'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('does NOT render completed action buttons when item is active', (tester) async {
      final item = createActiveItem();

      await tester.pumpWidget(createWidgetUnderTest(item));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Open'), findsNothing);
      expect(find.byTooltip('Share'), findsNothing);
      expect(find.byTooltip('Show in folder'), findsNothing);
      expect(find.byTooltip('More actions'), findsNothing);
    });

    testWidgets('tapping Open button triggers FileActionService openFile', (tester) async {
      final item = createCompletedItem();

      await tester.pumpWidget(createWidgetUnderTest(item));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(methodCalls.any((c) => c.method == 'openFile'), isTrue);
      final call = methodCalls.firstWhere((c) => c.method == 'openFile');
      expect(call.arguments['filePath'], equals(sampleFile.path));
      expect(call.arguments['useChooser'], isFalse);
    });

    testWidgets('tapping Share button triggers FileActionService shareFile', (tester) async {
      final item = createCompletedItem();

      await tester.pumpWidget(createWidgetUnderTest(item));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();

      expect(methodCalls.any((c) => c.method == 'shareFile'), isTrue);
      final call = methodCalls.firstWhere((c) => c.method == 'shareFile');
      expect(call.arguments['filePath'], equals(sampleFile.path));
      expect(call.arguments['title'], equals('Completed Test Video'));
    });

    testWidgets('tapping Show in Folder button triggers FileActionService openFolder', (tester) async {
      final item = createCompletedItem();

      await tester.pumpWidget(createWidgetUnderTest(item));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Show in folder'));
      await tester.pumpAndSettle();

      expect(methodCalls.any((c) => c.method == 'openFolder'), isTrue);
      final call = methodCalls.firstWhere((c) => c.method == 'openFolder');
      expect(call.arguments['folderPath'], equals(tempDir.path));
    });

    testWidgets('tapping card body triggers openFile on completed download', (tester) async {
      final item = createCompletedItem();

      await tester.pumpWidget(createWidgetUnderTest(item));
      await tester.pumpAndSettle();

      // Tap the card title area
      await tester.tap(find.text('Completed Test Video'));
      await tester.pumpAndSettle();

      expect(methodCalls.any((c) => c.method == 'openFile'), isTrue);
      final call = methodCalls.firstWhere((c) => c.method == 'openFile');
      expect(call.arguments['filePath'], equals(sampleFile.path));
    });

    testWidgets('tapping More actions opens popup menu with Open with and triggers chooser', (tester) async {
      final item = createCompletedItem();

      await tester.pumpWidget(createWidgetUnderTest(item));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      expect(find.text('Open with...'), findsOneWidget);
      expect(find.text('Show in folder'), findsOneWidget);

      await tester.tap(find.text('Open with...'));
      await tester.pumpAndSettle();

      expect(methodCalls.any((c) => c.method == 'openFile'), isTrue);
      final call = methodCalls.firstWhere((c) => c.method == 'openFile');
      expect(call.arguments['useChooser'], isTrue);
    });

    testWidgets('displays SnackBar when file does not exist on disk', (tester) async {
      final missingFile = '${tempDir.path}/deleted_by_user.mp4';
      final item = createCompletedItem(savePath: missingFile);

      await tester.pumpWidget(createWidgetUnderTest(item));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('File not found on device.'), findsOneWidget);
    });

    testWidgets('displays SnackBar when native channel reports NO_APP_FOUND', (tester) async {
      final item = createCompletedItem();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(FileActionService.channelName),
        (MethodCall call) async {
          methodCalls.add(call);
          throw PlatformException(code: 'NO_APP_FOUND', message: 'No activity found');
        },
      );

      await tester.pumpWidget(createWidgetUnderTest(item));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('No application found to open this file.'), findsOneWidget);
    });

    testWidgets('displays SnackBar when share action fails', (tester) async {
      final item = createCompletedItem();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(FileActionService.channelName),
        (MethodCall call) async {
          methodCalls.add(call);
          throw PlatformException(code: 'SHARE_FAILED', message: 'Could not share');
        },
      );

      await tester.pumpWidget(createWidgetUnderTest(item));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Could not share'), findsOneWidget);
    });

    testWidgets('DownloadItemCard on non-Windows invokes onOpenFolder callback', (tester) async {
      PlatformUtils.isWindowsOverride = false;
      bool onOpenFolderCalled = false;
      final item = createCompletedItem();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadItemCard(
              item: item,
              onOpenFolder: () {
                onOpenFolderCalled = true;
                FileActionService().openFolder(item.savePath ?? item.outputPath);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the folder icon on DownloadItemCard
      final folderButton = find.byIcon(Icons.folder_open_rounded);
      expect(folderButton, findsOneWidget);
      await tester.tap(folderButton);
      await tester.pumpAndSettle();

      expect(onOpenFolderCalled, isTrue);
      expect(methodCalls.any((c) => c.method == 'openFolder'), isTrue);
      final call = methodCalls.firstWhere((c) => c.method == 'openFolder');
      expect(call.arguments['folderPath'], equals(tempDir.path));

      PlatformUtils.isWindowsOverride = null;
    });
  });
}
