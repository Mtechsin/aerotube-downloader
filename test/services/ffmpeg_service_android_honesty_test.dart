import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/services/ffmpeg/ffmpeg_service_android.dart';
import 'package:youtube_downloader/services/ytdlp/native_ytdlp_android.dart';

/// Honesty tests for the Android FFmpeg service and native bridge.
///
/// Contract:
/// - getVersion never invents a placeholder string
/// - mergeVideoAudio / convertVideo do not exist (they used to return true
///   while doing nothing)
/// - NativeYtdlpAndroid.getFfmpegVersion invokes the real native method
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ytdlpChannel = MethodChannel(
    'com.aerotube.youtube_downloader/ytdlp_android',
  );

  final List<MethodCall> nativeCalls = [];
  Object? ffmpegVersionReply;

  setUp(() {
    nativeCalls.clear();
    ffmpegVersionReply = '7.1.1-youtubedl';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ytdlpChannel, (call) async {
      nativeCalls.add(call);
      if (call.method == 'getFfmpegVersion') {
        return ffmpegVersionReply;
      }
      if (call.method == 'getVersion') {
        return '2024.12.13';
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ytdlpChannel, null);
  });

  group('NativeYtdlpAndroid.getFfmpegVersion', () {
    test('returns the real version string from native', () async {
      final version = await NativeYtdlpAndroid.getFfmpegVersion();
      expect(version, '7.1.1-youtubedl');
      expect(nativeCalls.any((c) => c.method == 'getFfmpegVersion'), isTrue);
    });

    test('returns null when native returns null', () async {
      ffmpegVersionReply = null;
      final version = await NativeYtdlpAndroid.getFfmpegVersion();
      expect(version, isNull);
    });

    test('returns null when native returns empty string', () async {
      ffmpegVersionReply = '';
      final version = await NativeYtdlpAndroid.getFfmpegVersion();
      expect(version, isNull);
    });

    test('returns null when the method channel throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ytdlpChannel, (call) async {
        if (call.method == 'getFfmpegVersion') {
          throw PlatformException(code: 'unavailable');
        }
        return null;
      });
      final version = await NativeYtdlpAndroid.getFfmpegVersion();
      expect(version, isNull);
    });
  });

  group('FfmpegServiceAndroid honesty', () {
    test('initialize stores the real native version', () async {
      final service = FfmpegServiceAndroid();
      await service.initialize();

      expect(service.isAvailable, isTrue);
      expect(await service.getVersion(), '7.1.1-youtubedl');
      expect(service.version, '7.1.1-youtubedl');
    });

    test('surfaces a bundled-library label from native as-is', () async {
      // youtubedl-android may report its own packaging label rather than a
      // classic upstream FFmpeg version. That string must pass through
      // unchanged — never rewritten into a fake upstream version.
      ffmpegVersionReply = 'bundled-0.18.1';
      final service = FfmpegServiceAndroid();
      await service.initialize();

      expect(service.isAvailable, isTrue);
      expect(await service.getVersion(), 'bundled-0.18.1');
      expect(service.version, 'bundled-0.18.1');
    });

    test('initialize never invents a placeholder version string', () async {
      ffmpegVersionReply = null;
      final service = FfmpegServiceAndroid();
      await service.initialize();

      final version = await service.getVersion();
      expect(version, isNull);
      expect(version, isNot('Bundled with youtubedl-android'));
      // Still available for yt-dlp internal merge even without a version.
      expect(service.isAvailable, isTrue);
    });

    test('null native version stays null and never becomes a fake upstream',
        () async {
      ffmpegVersionReply = null;
      final service = FfmpegServiceAndroid();
      await service.initialize();

      final version = await service.getVersion();
      expect(version, isNull);
      // Explicit anti-invention contract: common fake/placeholder strings
      // must never be synthesized when native has nothing to report.
      expect(version, isNot('6.0'));
      expect(version, isNot('7.0'));
      expect(version, isNot('7.1.1'));
      expect(version, isNot('n6.0'));
      expect(service.isAvailable, isTrue,
          reason: 'null version must not flip isAvailable after initialize');
    });

    test('empty native version is treated as null, not invented', () async {
      ffmpegVersionReply = '';
      final service = FfmpegServiceAndroid();
      await service.initialize();

      expect(await service.getVersion(), isNull);
      expect(service.isAvailable, isTrue);
    });

    test('does not expose mergeVideoAudio/convertVideo (deleted liars)', () {
      final service = FfmpegServiceAndroid();
      expect(
        () => (service as dynamic).mergeVideoAudio,
        throwsA(isA<NoSuchMethodError>()),
        reason: 'mergeVideoAudio must be deleted — it returned true while '
            'doing nothing',
      );
      expect(
        () => (service as dynamic).convertVideo,
        throwsA(isA<NoSuchMethodError>()),
        reason: 'convertVideo must be deleted — it returned true while '
            'doing nothing',
      );
    });

    test('update and downloadAndInstall return false honestly', () async {
      final service = FfmpegServiceAndroid();
      await service.initialize();

      expect(await service.update(), isFalse);
      expect(
        await service.downloadAndInstall(
          onProgress: (_) {},
          onStatus: (_) {},
        ),
        isFalse,
      );
      expect(await service.checkForUpdate(), isNull);
    });
  });
}
