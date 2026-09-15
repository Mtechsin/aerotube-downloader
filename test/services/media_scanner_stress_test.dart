import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/utils/platform_utils.dart';
import 'package:youtube_downloader/services/core/android_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.aerotube.youtube_downloader/permissions';
  late AndroidStorageService storageService;
  final List<MethodCall> receivedCalls = [];
  dynamic mockChannelResponse;
  Exception? mockChannelException;

  setUp(() {
    storageService = AndroidStorageService();
    receivedCalls.clear();
    mockChannelResponse = true;
    mockChannelException = null;
    PlatformUtils.isAndroidOverride = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(channelName),
      (MethodCall call) async {
        receivedCalls.add(call);
        if (mockChannelException != null) {
          throw mockChannelException!;
        }
        switch (call.method) {
          case 'scanMediaFile':
            return mockChannelResponse;
          case 'getExternalDownloadDir':
            return mockChannelResponse;
          case 'getApiLevel':
            return 33;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    PlatformUtils.isAndroidOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channelName), null);
  });

  group('Empirical Stress: MediaScanner Special Paths & Edge Cases', () {
    test('handles nonexistent file path gracefully without crashing', () async {
      const nonexistentPath =
          '/storage/emulated/0/Download/AeroTube/ghost_file_does_not_exist.mp4';
      mockChannelResponse = true;

      final result = await storageService.scanMediaFile(nonexistentPath);

      expect(result, isTrue);
      expect(receivedCalls.length, 1);
      expect(receivedCalls.first.method, 'scanMediaFile');
      expect(
        receivedCalls.first.arguments,
        equals({'filePath': nonexistentPath}),
      );
    });

    test('handles paths with spaces and parentheses correctly', () async {
      const spacedPath =
          '/storage/emulated/0/Download/AeroTube/Rick Astley - Never Gonna Give You Up (Official Music Video).mp4';
      mockChannelResponse = true;

      final result = await storageService.scanMediaFile(spacedPath);

      expect(result, isTrue);
      expect(
        receivedCalls.first.arguments,
        equals({'filePath': spacedPath}),
      );
    });

    test(r'handles paths with special symbols (#, &, %, @, !, $, [, ])', () async {
      const specialPath =
          r'/storage/emulated/0/Download/AeroTube/[1080p] #Trending & Top Hits! 100% (2026) @Artist $Free.mkv';
      mockChannelResponse = true;

      final result = await storageService.scanMediaFile(specialPath);

      expect(result, isTrue);
      expect(
        receivedCalls.first.arguments,
        equals({'filePath': specialPath}),
      );
    });

    test('handles unicode, CJK, and emoji characters in filenames', () async {
      const unicodePath =
          '/storage/emulated/0/Download/AeroTube/🎵 音楽 - 初音ミク [4K] ✨.mp4';
      mockChannelResponse = true;

      final result = await storageService.scanMediaFile(unicodePath);

      expect(result, isTrue);
      expect(
        receivedCalls.first.arguments,
        equals({'filePath': unicodePath}),
      );
    });

    test('handles native scan failure (channel returns false)', () async {
      const testPath = '/storage/emulated/0/Download/AeroTube/corrupt.mp4';
      mockChannelResponse = false;

      final result = await storageService.scanMediaFile(testPath);

      expect(result, isFalse);
    });

    test('handles native scan returning null safely', () async {
      const testPath = '/storage/emulated/0/Download/AeroTube/video.mp4';
      mockChannelResponse = null;

      final result = await storageService.scanMediaFile(testPath);

      expect(result, isFalse);
    });

    test('handles PlatformException (e.g. INVALID_ARGUMENT from native) without unhandled throw', () async {
      const emptyPath = '';
      mockChannelException = PlatformException(
        code: 'INVALID_ARGUMENT',
        message: 'filePath is required',
      );

      final result = await storageService.scanMediaFile(emptyPath);

      expect(result, isFalse);
    });

    test('handles MissingPluginException or unexpected channel error safely', () async {
      const testPath = '/storage/emulated/0/Download/AeroTube/video.mp4';
      mockChannelException = MissingPluginException('No implementation found for method scanMediaFile');

      final result = await storageService.scanMediaFile(testPath);

      expect(result, isFalse);
    });

    test('handles whitespace-only paths safely', () async {
      const whitespacePath = '     ';
      mockChannelResponse = true;

      final result = await storageService.scanMediaFile(whitespacePath);

      expect(result, isTrue);
      expect(
        receivedCalls.first.arguments,
        equals({'filePath': whitespacePath}),
      );
    });
  });

  group('Empirical Stress: getExternalDownloadDir Channel Scenarios', () {
    test('handles null native directory response by falling back to public default', () async {
      mockChannelResponse = null;

      final dir = await storageService.getDownloadDirectory();

      final normalized = dir.replaceAll('\\', '/');
      expect(normalized, contains('Download/AeroTube'));
      expect(normalized.toLowerCase(), isNot(contains('/android/data/')));
    });

    test('handles empty native directory response by falling back to public default', () async {
      mockChannelResponse = '';

      final dir = await storageService.getDownloadDirectory();

      final normalized = dir.replaceAll('\\', '/');
      expect(normalized, contains('Download/AeroTube'));
      expect(normalized.toLowerCase(), isNot(contains('/android/data/')));
    });

    test('handles native channel exception when resolving download directory', () async {
      mockChannelException = PlatformException(
        code: 'IO_ERROR',
        message: 'Storage unmounted',
      );

      final dir = await storageService.getDownloadDirectory();

      expect(dir.isNotEmpty, isTrue);
      expect(dir.toLowerCase(), isNot(contains('/android/data/')));
    });

    test('handles paths with trailing slashes cleanly', () async {
      mockChannelResponse = '/storage/emulated/0/Download/AeroTube/';

      final dir = await storageService.getDownloadDirectory();

      final normalized = dir.replaceAll('\\', '/');
      expect(normalized, isNot(contains('AeroTube/AeroTube')));
      expect(normalized, isNot(contains('AeroTube/aerotube')));
    });

    test('handles native path with lowercase aerotube without duplicating', () async {
      mockChannelResponse = '/storage/emulated/0/Download/aerotube';

      final dir = await storageService.getDownloadDirectory();

      final normalized = dir.replaceAll('\\', '/');
      expect(normalized, isNot(contains('aerotube/AeroTube')));
      expect(normalized, isNot(contains('aerotube/aerotube')));
    });
  });
}
