import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/core/utils/platform_utils.dart';
import 'package:youtube_downloader/providers/platform_settings_provider.dart';
import 'package:youtube_downloader/services/cookie/cookie_service.dart';
import 'package:youtube_downloader/services/core/android_storage_service.dart';
import 'package:youtube_downloader/services/core/settings_service.dart';
import 'package:youtube_downloader/services/ffmpeg/ffmpeg_service_android.dart';
import 'package:youtube_downloader/services/ytdlp/ytdlp_service_android.dart';

class _MockCookieService extends CookieService {
  @override
  Future<bool> get isLoggedIn => Future.value(false);
  @override
  Future<DateTime?> get lastLoginTime => Future.value(null);
  @override
  Future<String?> get userAgent => Future.value(null);
  @override
  Future<String?> get webViewPath => Future.value(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.aerotube.youtube_downloader/permissions';
  late AndroidStorageService storageService;
  final List<MethodCall> methodCalls = [];
  String? mockNativeDownloadDir;
  int mockApiLevel = 33;
  bool mockScanSuccess = true;
  bool throwOnGetExternalDownloadDir = false;
  bool throwOnScanMediaFile = false;

  setUp(() {
    storageService = AndroidStorageService();
    methodCalls.clear();
    mockNativeDownloadDir = '/storage/emulated/0/Download/AeroTube';
    mockApiLevel = 33;
    mockScanSuccess = true;
    throwOnGetExternalDownloadDir = false;
    throwOnScanMediaFile = false;
    PlatformUtils.isAndroidOverride = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(channelName),
      (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'getExternalDownloadDir':
            if (throwOnGetExternalDownloadDir) {
              throw PlatformException(
                code: 'ERROR',
                message: 'Native storage resolution failed',
              );
            }
            return mockNativeDownloadDir;
          case 'getApiLevel':
            return mockApiLevel;
          case 'scanMediaFile':
            if (throwOnScanMediaFile) {
              throw PlatformException(
                code: 'SCAN_ERROR',
                message: 'Native media scanner crashed',
              );
            }
            return mockScanSuccess;
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

  group('CHALLENGE 1: Path Normalization & Edge Cases in AndroidStorageService', () {
    test('handles trailing slash on native Download path without double slashes', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download/';
      final dir = await storageService.getDownloadDirectory();
      final normalized = dir.replaceAll('\\', '/');

      expect(normalized, equals('/storage/emulated/0/Download/AeroTube'));
      expect(normalized, isNot(contains('//')));
    });

    test('handles trailing slash on native AeroTube path without duplicating suffix', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download/AeroTube/';
      final dir = await storageService.getDownloadDirectory();
      final normalized = dir.replaceAll('\\', '/');

      // Should not produce /Download/AeroTube/AeroTube
      expect(normalized, isNot(contains('AeroTube/AeroTube')));
      expect(normalized, isNot(contains('AeroTube/aerotube')));
      expect(normalized.startsWith('/storage/emulated/0/Download/AeroTube'), isTrue);
    });

    test('handles Windows-style backslashes in native path', () async {
      mockNativeDownloadDir = r'\storage\emulated\0\Download\AeroTube';
      final dir = await storageService.getDownloadDirectory();
      final normalized = dir.replaceAll('\\', '/');

      expect(normalized, equals('/storage/emulated/0/Download/AeroTube'));
    });

    test('handles mixed backslashes with trailing backslash', () async {
      mockNativeDownloadDir = r'\storage\emulated\0\Download\';
      final dir = await storageService.getDownloadDirectory();
      final normalized = dir.replaceAll('\\', '/');

      expect(normalized, equals('/storage/emulated/0/Download/AeroTube'));
      expect(normalized, isNot(contains('//')));
    });

    test('handles lowercase aerotube path without duplicating suffix', () async {
      mockNativeDownloadDir = '/storage/emulated/0/download/aerotube';
      final dir = await storageService.getDownloadDirectory();
      final normalized = dir.replaceAll('\\', '/').toLowerCase();

      expect(normalized, equals('/storage/emulated/0/download/aerotube'));
      expect(normalized, isNot(contains('aerotube/aerotube')));
    });

    test('handles UPPERCASE AEROTUBE path without duplicating suffix', () async {
      mockNativeDownloadDir = '/STORAGE/EMULATED/0/DOWNLOAD/AEROTUBE';
      final dir = await storageService.getDownloadDirectory();
      final normalized = dir.replaceAll('\\', '/').toLowerCase();

      expect(normalized, equals('/storage/emulated/0/download/aerotube'));
      expect(normalized, isNot(contains('aerotube/aerotube')));
    });

    test('does NOT falsely match substring "NotAeroTube" and appends AeroTube correctly', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download/NotAeroTube';
      final dir = await storageService.getDownloadDirectory();
      final normalized = dir.replaceAll('\\', '/');

      // Since NotAeroTube != /AeroTube, it should append AeroTube
      expect(normalized, equals('/storage/emulated/0/Download/NotAeroTube/AeroTube'));
    });

    test('does NOT falsely match substring "FakeAeroTube/" with trailing slash', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download/FakeAeroTube/';
      final dir = await storageService.getDownloadDirectory();
      final normalized = dir.replaceAll('\\', '/');

      expect(normalized, equals('/storage/emulated/0/Download/FakeAeroTube/AeroTube'));
    });

    test('idempotence: repeated calls to getPreferredDownloadDirectory yield identical results', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download/AeroTube';

      final results = <String>[];
      for (int i = 0; i < 5; i++) {
        final path = await storageService.getPreferredDownloadDirectory();
        results.add(path.replaceAll('\\', '/'));
      }

      for (int i = 1; i < results.length; i++) {
        expect(results[i], equals(results[0]));
        expect(results[i], equals('/storage/emulated/0/Download/AeroTube'));
      }
    });

    test('repeated calls when native returns top-level /Download remain idempotent', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download';

      final results = <String>[];
      for (int i = 0; i < 5; i++) {
        final path = await storageService.getPreferredDownloadDirectory();
        results.add(path.replaceAll('\\', '/'));
      }

      for (int i = 1; i < results.length; i++) {
        expect(results[i], equals(results[0]));
        expect(results[i], equals('/storage/emulated/0/Download/AeroTube'));
      }
    });

    test('handles already nested /AeroTube/AeroTube safely without adding a third layer', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download/AeroTube/AeroTube';
      final dir = await storageService.getDownloadDirectory();
      final normalized = dir.replaceAll('\\', '/');

      expect(normalized, equals('/storage/emulated/0/Download/AeroTube/AeroTube'));
      expect(normalized, isNot(contains('AeroTube/AeroTube/AeroTube')));
    });

    test('handles null native path by falling back to public /storage/emulated/0/Download/AeroTube', () async {
      mockNativeDownloadDir = null;
      final dir = await storageService.getDownloadDirectory();
      final normalized = dir.replaceAll('\\', '/');

      expect(normalized, contains('/storage/emulated/0/Download/AeroTube'));
    });

    test('handles empty native path by falling back to public /storage/emulated/0/Download/AeroTube', () async {
      mockNativeDownloadDir = '';
      final dir = await storageService.getDownloadDirectory();
      final normalized = dir.replaceAll('\\', '/');

      expect(normalized, contains('/storage/emulated/0/Download/AeroTube'));
    });

    test('handles native PlatformException by falling back gracefully without crashing', () async {
      throwOnGetExternalDownloadDir = true;
      final dir = await storageService.getDownloadDirectory();
      final normalized = dir.replaceAll('\\', '/');

      expect(normalized, contains('/storage/emulated/0/Download/AeroTube'));
    });

    test('subdirectories (Video & Audio) append cleanly without malformed slashes', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download/AeroTube';
      final videoDir = (await storageService.getVideoDirectory()).replaceAll('\\', '/');
      final audioDir = (await storageService.getAudioDirectory()).replaceAll('\\', '/');

      expect(videoDir, equals('/storage/emulated/0/Download/AeroTube/Videos'));
      expect(audioDir, equals('/storage/emulated/0/Download/AeroTube/Audio'));
      expect(videoDir, isNot(contains('//')));
      expect(audioDir, isNot(contains('//')));
    });
  });

  group('CHALLENGE 2: _shouldMigrateAndroidOutputPath Stress Testing', () {
    late PlatformSettingsProvider provider;

    setUp(() {
      provider = PlatformSettingsProvider(
        settingsService: SettingsService(),
        ytdlpService: YtdlpServiceAndroid(),
        ffmpegService: FfmpegServiceAndroid(),
        cookieService: CookieService(),
      );
    });

    test('flags standard internal app-scoped path', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download',
        ),
        isTrue,
      );
    });

    test('flags internal path with trailing slash', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download/',
        ),
        isTrue,
      );
    });

    test('flags internal path with nested /aerotube folder', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download/aerotube',
        ),
        isTrue,
      );
    });

    test('flags internal path regardless of casing (e.g. UPPERCASE /ANDROID/DATA/)', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/STORAGE/EMULATED/0/ANDROID/DATA/COM.AEROTUBE.YOUTUBE_DOWNLOADER/FILES/DOWNLOAD',
        ),
        isTrue,
      );
    });

    test('flags internal path with Windows backslashes', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          r'C:\Android\data\com.aerotube.youtube_downloader\files\Download',
        ),
        isTrue,
      );
      expect(
        provider.shouldMigrateAndroidOutputPath(
          r'/storage/emulated/0\Android\data\com.aerotube.youtube_downloader\files',
        ),
        isTrue,
      );
    });

    test('flags any arbitrary app-specific package path inside /Android/data/', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Android/data/other.package/cache',
        ),
        isTrue,
      );
    });

    test('does NOT flag public /storage/emulated/0/Download/AeroTube', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Download/AeroTube',
        ),
        isFalse,
      );
    });

    test('does NOT flag public /storage/emulated/0/Download/AeroTube/ with trailing slash', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Download/AeroTube/',
        ),
        isFalse,
      );
    });

    test('does NOT flag top-level public /storage/emulated/0/Download', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Download',
        ),
        isFalse,
      );
    });

    test('does NOT flag public Movies folder /storage/emulated/0/Movies/AeroTube', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Movies/AeroTube',
        ),
        isFalse,
      );
    });

    test('does NOT flag internal app_flutter directory (not inside /Android/data/)', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/data/user/0/com.aerotube.youtube_downloader/app_flutter',
        ),
        isFalse,
      );
    });

    test('does NOT flag any path when PlatformUtils.isAndroid is false', () {
      PlatformUtils.isAndroidOverride = false;
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download',
        ),
        isFalse,
      );
      expect(
        provider.shouldMigrateAndroidOutputPath(
          r'C:\Users\mtech\Downloads\aerotube',
        ),
        isFalse,
      );
    });

    test('repeated evaluation is fully idempotent', () {
      const trapped = '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download';
      const publicPath = '/storage/emulated/0/Download/AeroTube';

      for (int i = 0; i < 10; i++) {
        expect(provider.shouldMigrateAndroidOutputPath(trapped), isTrue);
        expect(provider.shouldMigrateAndroidOutputPath(publicPath), isFalse);
      }
    });
  });

  group('CHALLENGE 3: MediaScanner Robustness & Adversarial Inputs', () {
    test('handles file paths with spaces and punctuation', () async {
      const testPath = '/storage/emulated/0/Download/AeroTube/Rick Astley - Never Gonna Give You Up (Official Music Video) [4K].mp4';
      final success = await storageService.scanMediaFile(testPath);

      expect(success, isTrue);
      final lastCall = methodCalls.last;
      expect(lastCall.method, equals('scanMediaFile'));
      expect(lastCall.arguments, equals({'filePath': testPath}));
    });

    test('handles platform exception without crashing', () async {
      throwOnScanMediaFile = true;
      const testPath = '/storage/emulated/0/Download/AeroTube/broken_scan.mp4';
      final success = await storageService.scanMediaFile(testPath);

      // Should safely return false rather than rethrowing
      expect(success, isFalse);
    });

    test('returns false immediately on non-Android platform without IPC call', () async {
      PlatformUtils.isAndroidOverride = false;
      const testPath = 'C:\\Downloads\\video.mp4';
      final success = await storageService.scanMediaFile(testPath);

      expect(success, isFalse);
      expect(methodCalls.any((c) => c.method == 'scanMediaFile'), isFalse);
    });
  });

  group('CHALLENGE 4: End-to-End Migration Simulation in PlatformSettingsProvider', () {
    late Directory tempDir;
    late Directory oldAppSpecificDir;
    late Directory publicTargetDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aerotube_migration_test_');
      // Create trapped /Android/data/ hierarchy inside temp
      oldAppSpecificDir = Directory(
        '${tempDir.path}/Android/data/com.aerotube.youtube_downloader/files/Download',
      );
      await oldAppSpecificDir.create(recursive: true);

      // Create target public directory inside temp
      publicTargetDir = Directory('${tempDir.path}/Download/AeroTube');
      await publicTargetDir.create(recursive: true);

      mockNativeDownloadDir = publicTargetDir.path;
      PlatformUtils.isAndroidOverride = true;
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('init() migrates existing files from trapped /Android/data/ to public AeroTube', () async {
      // Populate trapped directory with simulated downloaded files
      final file1 = File('${oldAppSpecificDir.path}/video1.mp4');
      await file1.writeAsString('video1 content');
      final file2 = File('${oldAppSpecificDir.path}/song2.mp3');
      await file2.writeAsString('song2 content');

      // Set initial preferences pointing to the trapped path using AppConstants.prefOutputPath ('output_path')
      SharedPreferences.setMockInitialValues({
        'output_path': oldAppSpecificDir.path,
      });

      final settingsService = SettingsService();
      final provider = PlatformSettingsProvider(
        settingsService: settingsService,
        ytdlpService: YtdlpServiceAndroid(),
        ffmpegService: FfmpegServiceAndroid(),
        cookieService: _MockCookieService(),
      );

      // Run init
      await provider.init();

      // Output path must now be the public directory
      final normalizedOutputPath = provider.outputPath?.replaceAll('\\', '/');
      final normalizedTarget = publicTargetDir.path.replaceAll('\\', '/');
      expect(normalizedOutputPath, equals(normalizedTarget));

      // Files must now exist in public target directory
      final migratedFile1 = File('${publicTargetDir.path}/video1.mp4');
      final migratedFile2 = File('${publicTargetDir.path}/song2.mp3');
      expect(await migratedFile1.exists(), isTrue);
      expect(await migratedFile2.exists(), isTrue);
      expect(await migratedFile1.readAsString(), equals('video1 content'));
      expect(await migratedFile2.readAsString(), equals('song2 content'));

      // MediaScanner must have been triggered for migrated files
      final scannedFiles = methodCalls
          .where((c) => c.method == 'scanMediaFile')
          .map((c) => (c.arguments as Map)['filePath'] as String)
          .toList();
      expect(scannedFiles.length, equals(2));

      // Second init() should not trigger migration again
      methodCalls.clear();
      final provider2 = PlatformSettingsProvider(
        settingsService: settingsService,
        ytdlpService: YtdlpServiceAndroid(),
        ffmpegService: FfmpegServiceAndroid(),
        cookieService: _MockCookieService(),
      );
      await provider2.init();

      // Should not call scanMediaFile again because path is already public
      final rescanCalls = methodCalls.where((c) => c.method == 'scanMediaFile');
      expect(rescanCalls, isEmpty);
      expect(provider2.outputPath?.replaceAll('\\', '/'), equals(normalizedTarget));
    });
  });
}


