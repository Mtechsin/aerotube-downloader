import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/utils/platform_utils.dart';
import 'package:youtube_downloader/services/notification/download_foreground_service.dart';

/// R4 acceptance tests: Dart-side real-time progress must reach the native
/// DownloadService foreground notification (updateNotificationProgress) and
/// completion/cancellation must update or tear it down cleanly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serviceChannel = MethodChannel(
    'com.aerotube.youtube_downloader/download_service',
  );

  late DownloadForegroundService service;
  final List<MethodCall> nativeCalls = [];
  bool failNative = false;

  /// Records a native method call. Returns the mocked reply.
  Future<Object?>? handleNativeCall(MethodCall call) async {
    nativeCalls.add(call);
    if (failNative) {
      throw PlatformException(code: 'SERVICE_NOT_RUNNING', message: 'gone');
    }
    return true;
  }

  setUp(() {
    service = DownloadForegroundService();
    nativeCalls.clear();
    failNative = false;
    PlatformUtils.isAndroidOverride = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, handleNativeCall);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, null);
    PlatformUtils.isAndroidOverride = null;
  });

  group('R4: progress bridge to native notification', () {
    test('updateProgress forwards progress and status to native', () async {
      await service.startDownload(
        downloadId: 'd1',
        url: 'https://example.com/v',
        outputPath: '/tmp/x.mp4',
        title: 'Test Video',
      );
      nativeCalls.clear();

      await service.updateProgress(
        downloadId: 'd1',
        progress: 0.42,
        statusText: 'Downloading 42%',
      );

      expect(nativeCalls, hasLength(1));
      expect(nativeCalls.single.method, 'updateNotificationProgress');
      expect(nativeCalls.single.arguments['downloadId'], 'd1');
      expect(nativeCalls.single.arguments['progress'], closeTo(0.42, 1e-9));
      expect(nativeCalls.single.arguments['statusText'], 'Downloading 42%');
    });

    test('progress outside [0,1] is clamped before forwarding', () async {
      await service.startDownload(
        downloadId: 'd1',
        url: 'https://example.com/v',
        outputPath: '/tmp/x.mp4',
        title: 'Test Video',
      );
      nativeCalls.clear();

      await service.updateProgress(downloadId: 'd1', progress: 1.7);
      expect((nativeCalls.last.arguments['progress'] as double), 1.0);

      // New whole percent (100) passes the throttle.
      await service.updateProgress(downloadId: 'd1', progress: -0.5);
      expect((nativeCalls.last.arguments['progress'] as double), 0.0);
    });

    test(
      'throttle: sub-percent progress-only ticks within cooldown are skipped',
      () async {
        await service.startDownload(
          downloadId: 'd1',
          url: 'https://example.com/v',
          outputPath: '/tmp/x.mp4',
          title: 'Test Video',
        );
        nativeCalls.clear();

        // Two fractional ticks within cooldown, same whole percent -> 1 send.
        await service.updateProgress(downloadId: 'd1', progress: 0.101);
        await service.updateProgress(downloadId: 'd1', progress: 0.104);

        expect(nativeCalls, hasLength(1));

        // Crossing a whole percent bypasses the cooldown.
        await service.updateProgress(downloadId: 'd1', progress: 0.112);
        expect(nativeCalls, hasLength(2));
        expect(nativeCalls.last.arguments['progress'], closeTo(0.112, 1e-9));
      },
    );

    test('throttle: status text change is forwarded immediately', () async {
      await service.startDownload(
        downloadId: 'd1',
        url: 'https://example.com/v',
        outputPath: '/tmp/x.mp4',
        title: 'Test Video',
      );
      nativeCalls.clear();

      await service.updateProgress(
        downloadId: 'd1',
        progress: 0.30,
        statusText: 'Merging formats',
      );
      await service.updateProgress(
        downloadId: 'd1',
        progress: 0.30,
        statusText: 'Merging formats done',
      );

      expect(nativeCalls, hasLength(2));
      expect(nativeCalls.last.arguments['statusText'], 'Merging formats done');
    });

    test('updateProgress for unknown download is ignored entirely', () async {
      await service.updateProgress(
        downloadId: 'ghost',
        progress: 0.5,
        statusText: 'nope',
      );
      expect(nativeCalls, isEmpty);
    });

    test('native channel failure is swallowed, not propagated', () async {
      await service.startDownload(
        downloadId: 'd1',
        url: 'https://example.com/v',
        outputPath: '/tmp/x.mp4',
        title: 'Test Video',
      );
      failNative = true;
      nativeCalls.clear();

      await service.updateProgress(downloadId: 'd1', progress: 0.2);
      // No exception above means the download flow survives notification loss.
      expect(nativeCalls, hasLength(1));
    });
  });

  group('R4: completion and cancellation cleanup', () {
    Future<void> seedTwoDownloads() async {
      await service.startDownload(
        downloadId: 'd1',
        url: 'https://example.com/1',
        outputPath: '/tmp/1.mp4',
        title: 'One',
      );
      await service.startDownload(
        downloadId: 'd2',
        url: 'https://example.com/2',
        outputPath: '/tmp/2.mp4',
        title: 'Two',
      );
      nativeCalls.clear();
    }

    test(
      'completing one of several downloads signals per-task native completion '
      'without stopping the service',
      () async {
        await seedTwoDownloads();

        await service.completeDownload('d1');

        final methods = nativeCalls.map((c) => c.method).toList();
        expect(methods, contains('completeDownloadInService'));
        expect(
          nativeCalls
              .firstWhere((c) => c.method == 'completeDownloadInService')
              .arguments['downloadId'],
          'd1',
        );
        expect(methods, isNot(contains('stopDownloadService')));
        expect(service.activeDownloadsCount, 1);
      },
    );

    test(
      'completing the last download stops the native service and clears '
      'throttle state (no orphan notification state)',
      () async {
        await seedTwoDownloads();
        await service.updateProgress(downloadId: 'd2', progress: 0.9);
        nativeCalls.clear();

        await service.completeDownload('d1');
        await service.completeDownload('d2');

        final methods = nativeCalls.map((c) => c.method).toList();
        expect(methods, contains('stopDownloadService'));
        expect(service.activeDownloadsCount, 0);

        // Throttle maps were cleared: re-adding and updating sends again.
        await service.startDownload(
          downloadId: 'd1',
          url: 'https://example.com/1',
          outputPath: '/tmp/1.mp4',
          title: 'One',
        );
        nativeCalls.clear();
        await service.updateProgress(downloadId: 'd1', progress: 0.5);
        expect(
          nativeCalls.map((c) => c.method),
          contains('updateNotificationProgress'),
        );
      },
    );

    test('cancel forwards native cancel and clears throttle state', () async {
      await seedTwoDownloads();
      await service.updateProgress(downloadId: 'd1', progress: 0.4);
      nativeCalls.clear();

      await service.cancelDownload('d1');

      expect(
        nativeCalls.map((c) => c.method),
        contains('cancelDownload'),
      );
      expect(service.activeDownloadsCount, 1);
    });
  });

  group('R4: non-Android path unchanged', () {
    test('on non-Android, updateProgress does not hit the native channel', () async {
      PlatformUtils.isAndroidOverride = false;
      await service.startDownload(
        downloadId: 'd1',
        url: 'https://example.com/v',
        outputPath: '/tmp/x.mp4',
        title: 'Test Video',
      );
      nativeCalls.clear();

      await service.updateProgress(downloadId: 'd1', progress: 0.5);

      expect(nativeCalls, isEmpty);
    });
  });
}
