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

  const channelName = FileActionService.channelName;
  late FileActionService service;
  late Directory tempDir;
  late File sampleFile;
  late File sampleWithSpaces;
  final List<MethodCall> methodCalls = [];
  bool mockMethodResult = true;
  String? mockErrorCode;
  String? mockErrorMessage;

  setUp(() async {
    service = FileActionService();
    methodCalls.clear();
    mockMethodResult = true;
    mockErrorCode = null;
    mockErrorMessage = null;
    PlatformUtils.isAndroidOverride = true;

    tempDir = await Directory.systemTemp.createTemp('file_action_adversarial_');
    sampleFile = File('${tempDir.path}/sample_download.mp4');
    await sampleFile.writeAsString('adversarial test payload');

    sampleWithSpaces = File('${tempDir.path}/AeroTube Video With Spaces & Symbols (1080p).mkv');
    await sampleWithSpaces.writeAsString('video with spaces payload');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(channelName),
      (MethodCall call) async {
        methodCalls.add(call);
        if (mockErrorCode != null) {
          throw PlatformException(
            code: mockErrorCode!,
            message: mockErrorMessage ?? 'Mock native failure',
          );
        }
        return mockMethodResult;
      },
    );
  });

  tearDown(() async {
    PlatformUtils.isAndroidOverride = null;
    PlatformUtils.isWindowsOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channelName), null);

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CHALLENGE 1: Whitespace Paths and Boundary Conditions', () {
    test('rejects empty string across all actions', () async {
      expect(await service.openFile(''), isFalse);
      expect(service.lastError, equals('File path cannot be empty.'));

      expect(await service.shareFile(''), isFalse);
      expect(service.lastError, equals('File path cannot be empty.'));

      expect(await service.openFolder(''), isFalse);
      expect(service.lastError, equals('Folder path cannot be empty.'));

      expect(methodCalls, isEmpty);
    });

    test('rejects pure whitespace variations (spaces, tabs, newlines)', () async {
      final whitespaceInputs = [' ', '   ', '\t', '\n', '\r\n', '  \t  \n  '];
      for (final input in whitespaceInputs) {
        expect(await service.openFile(input), isFalse, reason: 'Failed for: "$input"');
        expect(service.lastError, equals('File path cannot be empty.'));

        expect(await service.shareFile(input), isFalse, reason: 'Failed for: "$input"');
        expect(service.lastError, equals('File path cannot be empty.'));

        expect(await service.openFolder(input), isFalse, reason: 'Failed for: "$input"');
        expect(service.lastError, equals('Folder path cannot be empty.'));
      }
      expect(methodCalls, isEmpty);
    });

    test('successfully handles file paths containing spaces and symbols', () async {
      expect(sampleWithSpaces.existsSync(), isTrue);

      final openResult = await service.openFile(sampleWithSpaces.path);
      expect(openResult, isTrue);
      expect(methodCalls.last.method, equals('openFile'));
      expect(methodCalls.last.arguments['filePath'], equals(sampleWithSpaces.path));

      final shareResult = await service.shareFile(sampleWithSpaces.path, title: 'Title With Spaces');
      expect(shareResult, isTrue);
      expect(methodCalls.last.method, equals('shareFile'));
      expect(methodCalls.last.arguments['filePath'], equals(sampleWithSpaces.path));
      expect(methodCalls.last.arguments['title'], equals('Title With Spaces'));
    });

    test('safely rejects path with untrimmed outer whitespace if file not found', () async {
      final untrimmedPath = '   ${sampleFile.path}   ';
      final result = await service.openFile(untrimmedPath);
      expect(result, isFalse);
      expect(service.lastError, equals('File not found on device.'));
      expect(methodCalls, isEmpty);
    });
  });

  group('CHALLENGE 2: Missing Files and Race Conditions', () {
    test('rejects completely non-existent files without IPC calls', () async {
      final ghostPath = '${tempDir.path}/does_not_exist_anywhere.mp4';
      expect(File(ghostPath).existsSync(), isFalse);

      final openResult = await service.openFile(ghostPath);
      expect(openResult, isFalse);
      expect(service.lastError, equals('File not found on device.'));

      final shareResult = await service.shareFile(ghostPath);
      expect(shareResult, isFalse);
      expect(service.lastError, equals('File not found on device.'));

      expect(methodCalls, isEmpty);
    });

    test('handles file deleted immediately before action invocation (TOCTOU race)', () async {
      final ephemeralFile = File('${tempDir.path}/ephemeral.mp4');
      await ephemeralFile.writeAsString('temp');
      expect(ephemeralFile.existsSync(), isTrue);

      // Delete file to simulate user or cleaner removing file right before tap
      await ephemeralFile.delete();
      expect(ephemeralFile.existsSync(), isFalse);

      final res = await service.openFile(ephemeralFile.path);
      expect(res, isFalse);
      expect(service.lastError, equals('File not found on device.'));
      expect(methodCalls, isEmpty);
    });

    test('openFolder creates non-existent directory automatically before IPC', () async {
      final missingFolder = '${tempDir.path}/subfolder_created_on_demand';
      expect(Directory(missingFolder).existsSync(), isFalse);

      final res = await service.openFolder(missingFolder);
      expect(res, isTrue);
      expect(Directory(missingFolder).existsSync(), isTrue);
      expect(methodCalls.last.method, equals('openFolder'));
      expect(methodCalls.last.arguments['folderPath'], equals(missingFolder));
    });

    test('openFolder extracts parent directory when given an existing file path', () async {
      final res = await service.openFolder(sampleFile.path);
      expect(res, isTrue);
      expect(methodCalls.last.method, equals('openFolder'));
      expect(methodCalls.last.arguments['folderPath'], equals(tempDir.path));
    });
  });

  group('CHALLENGE 3: Null Paths and Untyped Input Robustness', () {
    test('throws ArgumentError or NoSuchMethodError when null passed dynamically to openFile', () async {
      expect(
        () async => await service.openFile(null as dynamic),
        throwsA(isA<TypeError>().having((e) => e.toString(), 'error', contains('Null'))),
      );
    });

    test('throws ArgumentError or NoSuchMethodError when null passed dynamically to shareFile', () async {
      expect(
        () async => await service.shareFile(null as dynamic),
        throwsA(isA<TypeError>().having((e) => e.toString(), 'error', contains('Null'))),
      );
    });

    test('throws ArgumentError or NoSuchMethodError when null passed dynamically to openFolder', () async {
      expect(
        () async => await service.openFolder(null as dynamic),
        throwsA(isA<TypeError>().having((e) => e.toString(), 'error', contains('Null'))),
      );
    });

    testWidgets('UI download item with null savePath safely falls back to outputPath', (tester) async {
      final item = DownloadItem(
        id: 'null-savepath-item',
        title: 'Item With Null SavePath',
        url: 'https://youtube.com/watch?v=123456',
        outputPath: sampleFile.path, // savePath is null, outputPath is valid file
        savePath: null,
        status: DownloadStatus.completed,
        progress: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileDownloadItem(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(methodCalls.any((c) => c.method == 'openFile'), isTrue);
      final call = methodCalls.firstWhere((c) => c.method == 'openFile');
      expect(call.arguments['filePath'], equals(sampleFile.path));
    });

    testWidgets('UI download item with null savePath and missing outputPath displays SnackBar gracefully', (tester) async {
      final item = DownloadItem(
        id: 'missing-paths-item',
        title: 'Item With Missing File',
        url: 'https://youtube.com/watch?v=123456',
        outputPath: '${tempDir.path}/missing_output.mp4',
        savePath: null,
        status: DownloadStatus.completed,
        progress: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileDownloadItem(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('File not found on device.'), findsOneWidget);
      expect(methodCalls, isEmpty);
    });

    testWidgets('UI download item with null savePath and empty outputPath displays empty error SnackBar', (tester) async {
      final item = DownloadItem(
        id: 'empty-path-item',
        title: 'Item With Empty Path',
        url: 'https://youtube.com/watch?v=123456',
        outputPath: '',
        savePath: null,
        status: DownloadStatus.completed,
        progress: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileDownloadItem(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('File path cannot be empty.'), findsOneWidget);
      expect(methodCalls, isEmpty);
    });
  });

  group('CHALLENGE 4: Rapid Consecutive Taps & High Concurrency Stress Harness', () {
    test('stress tests 100 simultaneous concurrent openFile invocations', () async {
      final futures = List.generate(100, (i) => service.openFile(sampleFile.path));
      final results = await Future.wait(futures);

      expect(results.length, equals(100));
      expect(results.every((r) => r == true), isTrue);
      expect(methodCalls.length, equals(100));
      expect(methodCalls.every((c) => c.method == 'openFile'), isTrue);
      expect(service.lastError, isNull);
    });

    test('stress tests 100 simultaneous concurrent shareFile invocations', () async {
      final futures = List.generate(100, (i) => service.shareFile(sampleFile.path, title: 'Share #$i'));
      final results = await Future.wait(futures);

      expect(results.length, equals(100));
      expect(results.every((r) => r == true), isTrue);
      expect(methodCalls.length, equals(100));
      expect(methodCalls.every((c) => c.method == 'shareFile'), isTrue);
      expect(service.lastError, isNull);
    });

    test('stress tests 100 simultaneous concurrent openFolder invocations', () async {
      final futures = List.generate(100, (i) => service.openFolder(tempDir.path));
      final results = await Future.wait(futures);

      expect(results.length, equals(100));
      expect(results.every((r) => r == true), isTrue);
      expect(methodCalls.length, equals(100));
      expect(methodCalls.every((c) => c.method == 'openFolder'), isTrue);
      expect(service.lastError, isNull);
    });

    test('stress tests 150 interleaved concurrent calls across all three operations', () async {
      final List<Future<bool>> futures = [];
      for (int i = 0; i < 50; i++) {
        futures.add(service.openFile(sampleFile.path));
        futures.add(service.shareFile(sampleFile.path, title: 'Batch $i'));
        futures.add(service.openFolder(tempDir.path));
      }

      final results = await Future.wait(futures);
      expect(results.length, equals(150));
      expect(results.every((r) => r == true), isTrue);
      expect(methodCalls.length, equals(150));
      expect(methodCalls.where((c) => c.method == 'openFile').length, equals(50));
      expect(methodCalls.where((c) => c.method == 'shareFile').length, equals(50));
      expect(methodCalls.where((c) => c.method == 'openFolder').length, equals(50));
    });

    testWidgets('survives rapid consecutive UI button taps without crashing or duplicate dialogs', (tester) async {
      final item = DownloadItem(
        id: 'rapid-taps-item',
        title: 'Rapid Taps Video',
        url: 'https://youtube.com/watch?v=rapid123',
        outputPath: tempDir.path,
        savePath: sampleFile.path,
        status: DownloadStatus.completed,
        progress: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileDownloadItem(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rapidly tap Open button 10 times consecutively
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byTooltip('Open'));
      }
      await tester.pumpAndSettle();

      expect(methodCalls.where((c) => c.method == 'openFile').length, equals(10));

      // Rapidly tap Share button 5 times consecutively
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('Share'));
      }
      await tester.pumpAndSettle();

      expect(methodCalls.where((c) => c.method == 'shareFile').length, equals(5));
    });
  });

  group('CHALLENGE 5: Native Platform Channel Error Scenarios', () {
    test('handles native channel returning false gracefully', () async {
      mockMethodResult = false;
      final res = await service.openFile(sampleFile.path);
      expect(res, isFalse);
      expect(service.lastError, equals('Failed to open file.'));
    });

    test('handles native share returning false gracefully', () async {
      mockMethodResult = false;
      final res = await service.shareFile(sampleFile.path);
      expect(res, isFalse);
      expect(service.lastError, equals('Failed to share file.'));
    });

    test('handles native openFolder returning false gracefully', () async {
      mockMethodResult = false;
      final res = await service.openFolder(tempDir.path);
      expect(res, isFalse);
      expect(service.lastError, equals('Could not open folder in file manager.'));
    });

    test('handles SecurityException / PermissionDenied from native channel', () async {
      mockErrorCode = 'SECURITY_EXCEPTION';
      mockErrorMessage = 'Permission Denial: reading com.aerotube.youtube_downloader.fileprovider';

      final res = await service.openFile(sampleFile.path);
      expect(res, isFalse);
      expect(service.lastError, contains('Permission Denial'));
    });

    test('handles FILE_NOT_FOUND error code from native channel', () async {
      mockErrorCode = 'FILE_NOT_FOUND';
      mockErrorMessage = 'File does not exist: /storage/emulated/0/...';

      final res = await service.openFile(sampleFile.path);
      expect(res, isFalse);
      expect(service.lastError, equals('File not found on device.'));
    });

    test('handles NO_APP_FOUND error code on shareFile', () async {
      mockErrorCode = 'NO_APP_FOUND';
      mockErrorMessage = 'No activity found to handle share';

      final res = await service.shareFile(sampleFile.path);
      expect(res, isFalse);
      expect(service.lastError, equals('No application found to share this file.'));
    });

    test('handles NO_APP_FOUND error code on openFolder', () async {
      mockErrorCode = 'NO_APP_FOUND';
      mockErrorMessage = 'No file manager found to open folder';

      final res = await service.openFolder(tempDir.path);
      expect(res, isFalse);
      expect(service.lastError, equals('No file manager found on device.'));
    });
  });
}
