import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/core/constants/app_constants.dart';
import 'package:youtube_downloader/core/utils/platform_utils.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/models/download_mode.dart';
import 'package:youtube_downloader/providers/mobile_download_provider.dart';
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

  const permissionsChannel = 'com.aerotube.youtube_downloader/permissions';
  const downloadServiceChannel = 'com.aerotube.youtube_downloader/download_service';
  const ytdlpChannel = 'com.aerotube.youtube_downloader/ytdlp_android';

  late Directory tempDir;
  late Directory downloadsDir;
  final List<MethodCall> permissionsCalls = [];
  final List<MethodCall> serviceCalls = [];
  final List<MethodCall> ytdlpCalls = [];

  String mockManufacturer = 'Xiaomi';
  bool mockAutostartSuccess = true;
  bool mockBatteryOptimizationIgnored = false;

  setUpAll(() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DownloadStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(DownloadItemAdapter());
    }
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mobile_download_persistence_test_');
    downloadsDir = Directory('${tempDir.path}/Download/AeroTube');
    await downloadsDir.create(recursive: true);

    Hive.init(tempDir.path);

    permissionsCalls.clear();
    serviceCalls.clear();
    ytdlpCalls.clear();
    mockManufacturer = 'Xiaomi';
    mockAutostartSuccess = true;
    mockBatteryOptimizationIgnored = false;
    PlatformUtils.isAndroidOverride = true;

    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(permissionsChannel),
      (MethodCall call) async {
        permissionsCalls.add(call);
        switch (call.method) {
          case 'getExternalDownloadDir':
            return downloadsDir.path;
          case 'getApiLevel':
            return 33;
          case 'getFreeSpace':
            return 10 * 1024 * 1024 * 1024; // 10 GB
          case 'scanMediaFile':
            return true;
          case 'getDeviceManufacturer':
            return mockManufacturer;
          case 'openOemAutostartSettings':
            return mockAutostartSuccess;
          case 'isIgnoringBatteryOptimizations':
            return mockBatteryOptimizationIgnored;
          case 'requestIgnoreBatteryOptimizations':
            return true;
          case 'openBatteryOptimizationSettings':
            return true;
          default:
            return null;
        }
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(downloadServiceChannel),
      (MethodCall call) async {
        serviceCalls.add(call);
        return true;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(ytdlpChannel),
      (MethodCall call) async {
        ytdlpCalls.add(call);
        switch (call.method) {
          case 'downloadVideo':
            final id = call.arguments?['process_id'] ?? 'mock_process_1';
            return '{"success": true, "process_id": "$id", "message": "Download started"}';
          case 'cancelDownload':
            return true;
          default:
            return true;
        }
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall call) async {
        if (call.method == 'checkPermissionStatus') {
          return 1; // PermissionStatus.granted
        }
        if (call.method == 'requestPermissions') {
          final requested = (call.arguments as List?) ?? [];
          return {for (var p in requested) p: 1};
        }
        return 1;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall call) async {
        return true;
      },
    );
  });

  tearDown(() async {
    PlatformUtils.isAndroidOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(permissionsChannel), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(downloadServiceChannel), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(ytdlpChannel), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/permissions/methods'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dexterous.com/flutter/local_notifications'), null);

    try {
      await Hive.close();
    } catch (_) {}

    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  group('Active Downloads Box Persistence on Enqueue', () {
    test('enqueued downloads are immediately saved into active_downloads_mobile box', () async {
      final ytdlpService = YtdlpServiceAndroid();
      final provider = MobileDownloadProvider(ytdlpService: ytdlpService);
      await provider.initialize();

      expect(provider.activeBox, isNotNull);
      expect(provider.activeBox!.isOpen, isTrue);
      expect(provider.activeBox!.isEmpty, isTrue);

      await provider.addDownload(
        url: 'https://www.youtube.com/watch?v=enqueue_test_1',
        title: 'Enqueue Test Video 1',
        mode: DownloadMode.videoWithAudio,
        outputPath: downloadsDir.path,
      );

      // Verify in-memory state
      expect(provider.downloads.length, equals(1));
      final enqueuedItem = provider.downloads.first;
      expect(enqueuedItem.title, equals('Enqueue Test Video 1'));

      // Verify persistence in Hive active box
      final box = provider.activeBox!;
      expect(box.containsKey(enqueuedItem.id), isTrue);
      final persisted = box.get(enqueuedItem.id);
      expect(persisted, isNotNull);
      expect(persisted!.id, equals(enqueuedItem.id));
      expect(persisted.title, equals('Enqueue Test Video 1'));
      expect(persisted.url, equals('https://www.youtube.com/watch?v=enqueue_test_1'));

      provider.dispose();
    });

    test('multiple active downloads are maintained simultaneously in active box', () async {
      final ytdlpService = YtdlpServiceAndroid();
      final provider = MobileDownloadProvider(ytdlpService: ytdlpService);
      await provider.initialize();

      await provider.addDownload(
        url: 'https://www.youtube.com/watch?v=multi_1',
        title: 'Video 1',
        mode: DownloadMode.videoWithAudio,
        outputPath: downloadsDir.path,
      );
      await provider.addDownload(
        url: 'https://www.youtube.com/watch?v=multi_2',
        title: 'Video 2',
        mode: DownloadMode.videoWithAudio,
        outputPath: downloadsDir.path,
      );
      await provider.addDownload(
        url: 'https://www.youtube.com/watch?v=multi_3',
        title: 'Video 3',
        mode: DownloadMode.videoWithAudio,
        outputPath: downloadsDir.path,
      );

      final box = provider.activeBox!;
      expect(box.length, equals(3));
      for (final item in provider.downloads) {
        expect(box.containsKey(item.id), isTrue);
      }

      provider.dispose();
    });
  });

  group('Process Kill Recovery & Orphan Restoration', () {
    test('in-flight downloads interrupted by app kill are restored as paused on startup', () async {
      // 1. Simulate previous session before process kill:
      // Open active box directly and populate it with simulated in-flight and paused items
      final preKillActiveBox = await Hive.openBox<DownloadItem>(
        AppConstants.mobileActiveDownloadsBox,
      );

      final itemDownloadingVideo = DownloadItem(
        id: 'item_in_flight_video',
        title: 'In-Flight Video Download',
        url: 'https://www.youtube.com/watch?v=video1',
        outputPath: downloadsDir.path,
        status: DownloadStatus.downloadingVideo,
        progress: 0.42,
        speed: 1024 * 1024 * 2.5,
        eta: 15,
      );

      final itemDownloadingAudio = DownloadItem(
        id: 'item_in_flight_audio',
        title: 'In-Flight Audio Download',
        url: 'https://www.youtube.com/watch?v=audio1',
        outputPath: downloadsDir.path,
        status: DownloadStatus.downloadingAudio,
        progress: 0.67,
      );

      final itemQueued = DownloadItem(
        id: 'item_queued',
        title: 'Queued Download',
        url: 'https://www.youtube.com/watch?v=queued1',
        outputPath: downloadsDir.path,
        status: DownloadStatus.queued,
        progress: 0.0,
      );

      final itemAlreadyPaused = DownloadItem(
        id: 'item_paused',
        title: 'Already Paused Download',
        url: 'https://www.youtube.com/watch?v=paused1',
        outputPath: downloadsDir.path,
        status: DownloadStatus.paused,
        progress: 0.25,
        statusText: 'Paused by user',
      );

      await preKillActiveBox.put(itemDownloadingVideo.id, itemDownloadingVideo);
      await preKillActiveBox.put(itemDownloadingAudio.id, itemDownloadingAudio);
      await preKillActiveBox.put(itemQueued.id, itemQueued);
      await preKillActiveBox.put(itemAlreadyPaused.id, itemAlreadyPaused);

      // Create a simulated .part file on disk to confirm partial download files are preserved
      final partialFile = File('${downloadsDir.path}/In-Flight Video Download.mp4.part');
      await partialFile.writeAsString('partial video data payload');
      expect(await partialFile.exists(), isTrue);

      await preKillActiveBox.close();

      // 2. Start app afresh: instantiate MobileDownloadProvider and initialize
      final ytdlpService = YtdlpServiceAndroid();
      final provider = MobileDownloadProvider(ytdlpService: ytdlpService);
      await provider.initialize();

      // 3. Verify all items were restored
      expect(provider.downloads.length, equals(4));

      // The in-flight video item must be transitioned to paused with informative message
      final restoredVideo = provider.downloads.firstWhere((d) => d.id == 'item_in_flight_video');
      expect(restoredVideo.status, equals(DownloadStatus.paused));
      expect(restoredVideo.progress, equals(0.42)); // Progress retained
      expect(restoredVideo.speed, equals(0.0));
      expect(restoredVideo.statusText, contains('Interrupted by app close - tap to resume'));
      expect(restoredVideo.error, contains('Interrupted by app close - tap to resume'));

      // The in-flight audio item must also be transitioned to paused
      final restoredAudio = provider.downloads.firstWhere((d) => d.id == 'item_in_flight_audio');
      expect(restoredAudio.status, equals(DownloadStatus.paused));
      expect(restoredAudio.progress, equals(0.67));
      expect(restoredAudio.statusText, contains('Interrupted by app close - tap to resume'));

      // The queued item was in-flight and transitions to paused
      final restoredQueued = provider.downloads.firstWhere((d) => d.id == 'item_queued');
      expect(restoredQueued.status, equals(DownloadStatus.paused));

      // The already-paused item remains paused
      final restoredPaused = provider.downloads.firstWhere((d) => d.id == 'item_paused');
      expect(restoredPaused.status, equals(DownloadStatus.paused));
      expect(restoredPaused.progress, equals(0.25));

      // 4. Verify the active box on disk reflects the paused state
      final box = provider.activeBox!;
      final boxVideo = box.get('item_in_flight_video');
      expect(boxVideo?.status, equals(DownloadStatus.paused));

      // 5. Verify partial file on disk was retained untouched
      expect(await partialFile.exists(), isTrue);
      expect(await partialFile.readAsString(), equals('partial video data payload'));

      provider.dispose();
    });
  });

  group('Lifecycle State Flush', () {
    test('WidgetsBindingObserver flushes active downloads to box on paused and detached', () async {
      final ytdlpService = YtdlpServiceAndroid();
      final provider = MobileDownloadProvider(ytdlpService: ytdlpService);
      await provider.initialize();

      await provider.addDownload(
        url: 'https://www.youtube.com/watch?v=lifecycle_test',
        title: 'Lifecycle Test Video',
        mode: DownloadMode.videoWithAudio,
        outputPath: downloadsDir.path,
      );

      final box = provider.activeBox!;
      expect(box.containsKey(provider.downloads.first.id), isTrue);

      // Simulate AppLifecycleState.paused
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(box.containsKey(provider.downloads.first.id), isTrue);

      // Simulate AppLifecycleState.detached
      provider.didChangeAppLifecycleState(AppLifecycleState.detached);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(box.containsKey(provider.downloads.first.id), isTrue);

      provider.dispose();
    });
  });

  group('Terminal Status Transitions Remove from Active Box', () {
    test('completed download is removed from active box and persisted to history', () async {
      // Pre-create the output file so yt-dlp simulation finds the downloaded file on completion
      final completedFile = File('${downloadsDir.path}/Completed Video.mp4');
      await completedFile.writeAsString('video content done');

      final ytdlpService = YtdlpServiceAndroid();
      final provider = MobileDownloadProvider(ytdlpService: ytdlpService);
      await provider.initialize();

      await provider.addDownload(
        url: 'https://www.youtube.com/watch?v=completion_test',
        title: 'Completed Video',
        mode: DownloadMode.videoWithAudio,
        outputPath: downloadsDir.path,
      );

      final item = provider.downloads.first;
      // Give async completion a brief moment
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify item transitioned to completed and was removed from active box
      expect(provider.activeBox!.containsKey(item.id), isFalse);
      expect(provider.completedDownloads.any((d) => d.id == item.id), isTrue);

      // Verify item was persisted to history box
      final historyBox = await Hive.openBox<DownloadItem>(AppConstants.mobileDownloadsHistoryBox);
      expect(historyBox.containsKey(item.id), isTrue);
      expect(historyBox.get(item.id)?.status, equals(DownloadStatus.completed));

      provider.dispose();
    });

    test('cancelled download is removed from active box and saved to history', () async {
      final ytdlpService = YtdlpServiceAndroid();
      final provider = MobileDownloadProvider(ytdlpService: ytdlpService);
      await provider.initialize();

      await provider.addDownload(
        url: 'https://www.youtube.com/watch?v=cancel_test',
        title: 'Cancel Video',
        mode: DownloadMode.videoWithAudio,
        outputPath: downloadsDir.path,
      );

      final item = provider.downloads.first;
      expect(provider.activeBox!.containsKey(item.id), isTrue);

      await provider.cancelDownload(item.id);

      // Item should be removed from active box
      expect(provider.activeBox!.containsKey(item.id), isFalse);

      // Item is now in history as cancelled
      expect(provider.completedDownloads.isEmpty, isTrue);
      expect(provider.downloads.any((d) => d.id == item.id && d.status == DownloadStatus.cancelled), isTrue);

      // History box in Hive contains the item
      final historyBox = await Hive.openBox<DownloadItem>(AppConstants.mobileDownloadsHistoryBox);
      expect(historyBox.containsKey(item.id), isTrue);
      expect(historyBox.get(item.id)?.status, equals(DownloadStatus.cancelled));

      provider.dispose();
    });

    test('pause and resume downloads update active box state', () async {
      final ytdlpService = YtdlpServiceAndroid();
      final provider = MobileDownloadProvider(ytdlpService: ytdlpService);
      await provider.initialize();

      await provider.addDownload(
        url: 'https://www.youtube.com/watch?v=pause_resume_test',
        title: 'Pause Resume Video',
        mode: DownloadMode.videoWithAudio,
        outputPath: downloadsDir.path,
      );

      final item = provider.downloads.first;
      expect(provider.activeBox!.containsKey(item.id), isTrue);

      // Pause
      await provider.pauseDownload(item.id);
      expect(provider.activeBox!.get(item.id)?.status, equals(DownloadStatus.paused));
      expect(provider.downloads.first.status, equals(DownloadStatus.paused));

      // Resume
      await provider.resumeDownload(item.id);
      expect(provider.activeBox!.get(item.id)?.status, equals(DownloadStatus.pending));
      expect(provider.downloads.first.status, equals(DownloadStatus.pending));

      provider.dispose();
    });
  });

  group('OEM Manufacturer Detection & Autostart Settings', () {
    test('detects aggressive OEM manufacturers accurately', () async {
      final settingsService = SettingsService();
      final platformSettings = PlatformSettingsProvider(
        settingsService: settingsService,
        ytdlpService: YtdlpServiceAndroid(),
        ffmpegService: FfmpegServiceAndroid(),
        cookieService: _MockCookieService(),
      );

      // Test Xiaomi
      mockManufacturer = 'Xiaomi';
      await platformSettings.getDeviceManufacturer();
      expect(platformSettings.deviceManufacturer, equals('Xiaomi'));
      expect(platformSettings.isAggressiveOem, isTrue);

      // Test Oppo
      mockManufacturer = 'OPPO';
      final oppoProvider = PlatformSettingsProvider(
        settingsService: settingsService,
        ytdlpService: YtdlpServiceAndroid(),
        ffmpegService: FfmpegServiceAndroid(),
        cookieService: _MockCookieService(),
      );
      await oppoProvider.getDeviceManufacturer();
      expect(oppoProvider.isAggressiveOem, isTrue);

      // Test Vivo
      mockManufacturer = 'vivo';
      final vivoProvider = PlatformSettingsProvider(
        settingsService: settingsService,
        ytdlpService: YtdlpServiceAndroid(),
        ffmpegService: FfmpegServiceAndroid(),
        cookieService: _MockCookieService(),
      );
      await vivoProvider.getDeviceManufacturer();
      expect(vivoProvider.isAggressiveOem, isTrue);

      // Test Huawei
      mockManufacturer = 'HUAWEI';
      final huaweiProvider = PlatformSettingsProvider(
        settingsService: settingsService,
        ytdlpService: YtdlpServiceAndroid(),
        ffmpegService: FfmpegServiceAndroid(),
        cookieService: _MockCookieService(),
      );
      await huaweiProvider.getDeviceManufacturer();
      expect(huaweiProvider.isAggressiveOem, isTrue);

      // Test non-aggressive OEM (Google Pixel)
      mockManufacturer = 'Google';
      final pixelProvider = PlatformSettingsProvider(
        settingsService: settingsService,
        ytdlpService: YtdlpServiceAndroid(),
        ffmpegService: FfmpegServiceAndroid(),
        cookieService: _MockCookieService(),
      );
      await pixelProvider.getDeviceManufacturer();
      expect(pixelProvider.isAggressiveOem, isFalse);

      // Test Samsung
      mockManufacturer = 'samsung';
      final samsungProvider = PlatformSettingsProvider(
        settingsService: settingsService,
        ytdlpService: YtdlpServiceAndroid(),
        ffmpegService: FfmpegServiceAndroid(),
        cookieService: _MockCookieService(),
      );
      await samsungProvider.getDeviceManufacturer();
      expect(samsungProvider.isAggressiveOem, isFalse);
    });

    test('openOemAutostartSettings invokes platform channel and returns result', () async {
      final settingsService = SettingsService();
      final platformSettings = PlatformSettingsProvider(
        settingsService: settingsService,
        ytdlpService: YtdlpServiceAndroid(),
        ffmpegService: FfmpegServiceAndroid(),
        cookieService: _MockCookieService(),
      );

      mockAutostartSuccess = true;
      final result = await platformSettings.openOemAutostartSettings();
      expect(result, isTrue);
      expect(
        permissionsCalls.any((c) => c.method == 'openOemAutostartSettings'),
        isTrue,
      );

      // AndroidStorageService delegation test
      final storageService = AndroidStorageService();
      final storageResult = await storageService.openOemAutostartSettings();
      expect(storageResult, isTrue);

      final manufacturer = await storageService.getDeviceManufacturer();
      expect(manufacturer, equals(mockManufacturer));
    });
  });
}
