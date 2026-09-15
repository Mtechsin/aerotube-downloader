import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/utils/platform_utils.dart';
import 'package:youtube_downloader/services/core/android_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.aerotube.youtube_downloader/permissions';
  late AndroidStorageService storageService;
  final List<MethodCall> methodCalls = [];
  String? mockNativeDownloadDir;
  int mockApiLevel = 33;
  bool mockScanSuccess = true;
  bool mockCanWritePublic = true;
  bool mockHasStorageAccess = true;
  bool mockRequestStorage = true;
  String mockAppSpecificDir =
      '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download';

  setUp(() {
    storageService = AndroidStorageService();
    methodCalls.clear();
    mockNativeDownloadDir = '/storage/emulated/0/Download/AeroTube';
    mockApiLevel = 33;
    mockScanSuccess = true;
    mockCanWritePublic = true;
    mockHasStorageAccess = true;
    mockRequestStorage = true;
    mockAppSpecificDir =
        '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download';
    PlatformUtils.isAndroidOverride = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(channelName),
      (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'getExternalDownloadDir':
            return mockNativeDownloadDir;
          case 'getApiLevel':
            return mockApiLevel;
          case 'scanMediaFile':
            return mockScanSuccess;
          case 'canWritePublicDownloads':
            return mockCanWritePublic;
          case 'hasStorageAccess':
            return mockHasStorageAccess;
          case 'requestStoragePermission':
            return mockRequestStorage;
          case 'getAppSpecificDownloadDir':
            return mockAppSpecificDir;
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

  group('AndroidStorageService Public Storage', () {
    test('resolves public AeroTube download directory directly', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download/AeroTube';
      final dir = await storageService.getDownloadDirectory();

      expect(dir.replaceAll('\\', '/'), equals('/storage/emulated/0/Download/AeroTube'));
      expect(
        methodCalls.any((c) => c.method == 'getExternalDownloadDir'),
        isTrue,
      );
    });

    test('appends AeroTube when native directory is top-level Download', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download';
      final dir = await storageService.getDownloadDirectory();

      expect(dir.replaceAll('\\', '/'), equals('/storage/emulated/0/Download/AeroTube'));
    });

    test('avoids duplicate AeroTube suffix if already present in path', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download/AeroTube';
      final dir = await storageService.getDownloadDirectory();

      expect(dir.replaceAll('\\', '/'), isNot(contains('AeroTube/aerotube')));
      expect(dir.replaceAll('\\', '/'), isNot(contains('AeroTube/AeroTube')));
      expect(dir.replaceAll('\\', '/'), equals('/storage/emulated/0/Download/AeroTube'));
    });

    test('bypasses /Android/data/ if native returns app-specific path', () async {
      mockNativeDownloadDir =
          '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download';
      final dir = await storageService.getDownloadDirectory();

      final normalized = dir.replaceAll('\\', '/').toLowerCase();
      expect(normalized, isNot(contains('/android/data/')));
      expect(normalized, contains('download/aerotube'));
    });

    test('falls back to app-specific dir when public Downloads is not writable', () async {
      mockCanWritePublic = false;
      mockNativeDownloadDir = null;
      final dir = await storageService.getDownloadDirectory();

      final normalized = dir.replaceAll('\\', '/').toLowerCase();
      expect(normalized, contains('/android/data/'));
    });

    test('requestStoragePermission returns native grant result without faking', () async {
      mockCanWritePublic = false;
      mockRequestStorage = false;
      mockHasStorageAccess = false;
      final granted = await storageService.requestStoragePermission();
      expect(granted, isFalse);
      expect(
        methodCalls.any((c) => c.method == 'requestStoragePermission'),
        isTrue,
      );
    });

    test('requestStoragePermission returns true when already writable', () async {
      mockCanWritePublic = true;
      final granted = await storageService.requestStoragePermission();
      expect(granted, isTrue);
      expect(
        methodCalls.any((c) => c.method == 'requestStoragePermission'),
        isFalse,
      );
    });

    test('getVideoDirectory creates Videos subfolder under public AeroTube path', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download/AeroTube';
      final videoDir = await storageService.getVideoDirectory();

      expect(
        videoDir.replaceAll('\\', '/'),
        equals('/storage/emulated/0/Download/AeroTube/Videos'),
      );
    });

    test('getAudioDirectory creates Audio subfolder under public AeroTube path', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download/AeroTube';
      final audioDir = await storageService.getAudioDirectory();

      expect(
        audioDir.replaceAll('\\', '/'),
        equals('/storage/emulated/0/Download/AeroTube/Audio'),
      );
    });
  });

  group('AndroidStorageService MediaScanner', () {
    test('scanMediaFile invokes method channel with correct filePath', () async {
      const testPath = '/storage/emulated/0/Download/AeroTube/sample_video.mp4';
      final result = await storageService.scanMediaFile(testPath);

      expect(result, isTrue);
      final scanCall = methodCalls.firstWhere((c) => c.method == 'scanMediaFile');
      expect(scanCall.arguments, equals({'filePath': testPath}));
    });

    test('scanMediaFile handles false result from native channel', () async {
      mockScanSuccess = false;
      const testPath = '/storage/emulated/0/Download/AeroTube/sample_video.mp4';
      final result = await storageService.scanMediaFile(testPath);

      expect(result, isFalse);
    });

    test('scanMediaFile returns false when not on Android', () async {
      PlatformUtils.isAndroidOverride = false;
      const testPath = '/storage/emulated/0/Download/AeroTube/sample_video.mp4';
      final result = await storageService.scanMediaFile(testPath);

      expect(result, isFalse);
      expect(methodCalls.any((c) => c.method == 'scanMediaFile'), isFalse);
    });
  });
}
