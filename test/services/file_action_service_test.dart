import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/utils/platform_utils.dart';
import 'package:youtube_downloader/services/core/file_action_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = FileActionService.channelName;
  late FileActionService service;
  late Directory tempDir;
  late File sampleFile;
  final List<MethodCall> methodCalls = [];
  bool mockMethodResult = true;
  String? mockErrorCode;

  setUp(() async {
    service = FileActionService();
    methodCalls.clear();
    mockMethodResult = true;
    mockErrorCode = null;
    PlatformUtils.isAndroidOverride = true;

    tempDir = await Directory.systemTemp.createTemp('file_action_test_');
    sampleFile = File('${tempDir.path}/test_video.mp4');
    await sampleFile.writeAsString('sample content');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(channelName),
      (MethodCall call) async {
        methodCalls.add(call);
        if (mockErrorCode != null) {
          throw PlatformException(
            code: mockErrorCode!,
            message: 'Mock exception message',
          );
        }
        return mockMethodResult;
      },
    );
  });

  tearDown(() async {
    PlatformUtils.isAndroidOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channelName), null);

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FileActionService Singleton & Basics', () {
    test('maintains singleton instance', () {
      final s1 = FileActionService();
      final s2 = FileActionService();
      expect(identical(s1, s2), isTrue);
    });

    test('validates empty and blank file paths', () async {
      final r1 = await service.openFile('');
      expect(r1, isFalse);
      expect(service.lastError, contains('cannot be empty'));

      final r2 = await service.openFile('   ');
      expect(r2, isFalse);
      expect(service.lastError, contains('cannot be empty'));

      final r3 = await service.shareFile('');
      expect(r3, isFalse);
      expect(service.lastError, contains('cannot be empty'));

      final r4 = await service.openFolder('');
      expect(r4, isFalse);
      expect(service.lastError, contains('cannot be empty'));
    });

    test('validates non-existent file path before native IPC', () async {
      final nonExistent = '${tempDir.path}/does_not_exist.mp4';
      final openRes = await service.openFile(nonExistent);
      expect(openRes, isFalse);
      expect(service.lastError, contains('not found on device'));
      expect(methodCalls.isEmpty, isTrue);

      final shareRes = await service.shareFile(nonExistent);
      expect(shareRes, isFalse);
      expect(service.lastError, contains('not found on device'));
      expect(methodCalls.isEmpty, isTrue);
    });
  });

  group('FileActionService Android Native IPC', () {
    test('openFile sends correct parameters with default chooser=false', () async {
      final result = await service.openFile(sampleFile.path);
      expect(result, isTrue);
      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('openFile'));
      expect(methodCalls.first.arguments['filePath'], equals(sampleFile.path));
      expect(methodCalls.first.arguments['useChooser'], isFalse);
      expect(service.lastError, isNull);
    });

    test('openFile sends useChooser=true when requested', () async {
      final result = await service.openFile(sampleFile.path, useChooser: true);
      expect(result, isTrue);
      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('openFile'));
      expect(methodCalls.first.arguments['useChooser'], isTrue);
    });

    test('openFile translates NO_APP_FOUND error gracefully', () async {
      mockErrorCode = 'NO_APP_FOUND';
      final result = await service.openFile(sampleFile.path);
      expect(result, isFalse);
      expect(service.lastError, contains('No application found'));
    });

    test('openFile handles generic PlatformException gracefully', () async {
      mockErrorCode = 'OPEN_ERROR';
      final result = await service.openFile(sampleFile.path);
      expect(result, isFalse);
      expect(service.lastError, contains('Mock exception message'));
    });

    test('shareFile sends correct arguments including title', () async {
      final result = await service.shareFile(sampleFile.path, title: 'My Great Video');
      expect(result, isTrue);
      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('shareFile'));
      expect(methodCalls.first.arguments['filePath'], equals(sampleFile.path));
      expect(methodCalls.first.arguments['title'], equals('My Great Video'));
      expect(service.lastError, isNull);
    });

    test('shareFile handles NO_APP_FOUND gracefully', () async {
      mockErrorCode = 'NO_APP_FOUND';
      final result = await service.shareFile(sampleFile.path);
      expect(result, isFalse);
      expect(service.lastError, contains('No application found to share'));
    });

    test('openFolder delegates folder path to native channel', () async {
      final result = await service.openFolder(tempDir.path);
      expect(result, isTrue);
      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('openFolder'));
      expect(methodCalls.first.arguments['folderPath'], equals(tempDir.path));
    });

    test('openFolder safely extracts parent folder if file path passed', () async {
      final result = await service.openFolder(sampleFile.path);
      expect(result, isTrue);
      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('openFolder'));
      expect(methodCalls.first.arguments['folderPath'], equals(tempDir.path));
    });

    test('openFolder handles NO_APP_FOUND gracefully', () async {
      mockErrorCode = 'NO_APP_FOUND';
      final result = await service.openFolder(tempDir.path);
      expect(result, isFalse);
      expect(service.lastError, contains('No file manager found'));
    });
  });
}
