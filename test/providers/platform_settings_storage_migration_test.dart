import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/utils/platform_utils.dart';
import 'package:youtube_downloader/providers/platform_settings_provider.dart';
import 'package:youtube_downloader/services/cookie/cookie_service.dart';
import 'package:youtube_downloader/services/core/settings_service.dart';
import 'package:youtube_downloader/services/ffmpeg/ffmpeg_service_android.dart';
import 'package:youtube_downloader/services/ytdlp/ytdlp_service_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.aerotube.youtube_downloader/permissions';
  late PlatformSettingsProvider provider;
  String? mockNativeDownloadDir;
  bool mockCanWritePublic = true;

  setUp(() {
    mockNativeDownloadDir = '/storage/emulated/0/Download/AeroTube';
    mockCanWritePublic = true;
    PlatformUtils.isAndroidOverride = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(channelName),
      (MethodCall call) async {
        switch (call.method) {
          case 'getExternalDownloadDir':
            return mockNativeDownloadDir;
          case 'getApiLevel':
            return 33;
          case 'canWritePublicDownloads':
            return mockCanWritePublic;
          case 'hasStorageAccess':
            return mockCanWritePublic;
          case 'getAppSpecificDownloadDir':
            return '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download';
          default:
            return null;
        }
      },
    );

    provider = PlatformSettingsProvider(
      settingsService: SettingsService(),
      ytdlpService: YtdlpServiceAndroid(),
      ffmpegService: FfmpegServiceAndroid(),
      cookieService: CookieService(),
    );
  });

  tearDown(() {
    PlatformUtils.isAndroidOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channelName), null);
  });

  group('PlatformSettingsProvider Storage Migration & Public Defaults', () {
    test('identifies trapped Android/data/ paths for migration', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download',
        ),
        isTrue,
      );
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download/aerotube',
        ),
        isTrue,
      );
      expect(
        provider.shouldMigrateAndroidOutputPath(
          r'C:\storage\emulated\0\Android\data\com.aerotube.youtube_downloader\files',
        ),
        isTrue,
      );
    });

    test('does not flag public Download paths for migration', () {
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Download/AeroTube',
        ),
        isFalse,
      );
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Download',
        ),
        isFalse,
      );
    });

    test('does not flag migration when not running on Android', () {
      PlatformUtils.isAndroidOverride = false;
      expect(
        provider.shouldMigrateAndroidOutputPath(
          '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download',
        ),
        isFalse,
      );
    });

    test('getDefaultOutputPath returns public storage directory', () async {
      mockNativeDownloadDir = '/storage/emulated/0/Download/AeroTube';
      final defaultPath = await provider.getDefaultOutputPath();

      expect(
        defaultPath.replaceAll('\\', '/'),
        equals('/storage/emulated/0/Download/AeroTube'),
      );
      expect(
        provider.shouldMigrateAndroidOutputPath(defaultPath),
        isFalse,
      );
    });

    test('getDefaultOutputPath falls back to public AeroTube if native returns Android/data/', () async {
      mockNativeDownloadDir =
          '/storage/emulated/0/Android/data/com.aerotube.youtube_downloader/files/Download';
      final defaultPath = await provider.getDefaultOutputPath();

      final normalized = defaultPath.replaceAll('\\', '/').toLowerCase();
      expect(normalized, isNot(contains('/android/data/')));
      expect(normalized, contains('download/aerotube'));
      expect(
        provider.shouldMigrateAndroidOutputPath(defaultPath),
        isFalse,
      );
    });
  });
}
