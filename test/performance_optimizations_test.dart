import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/core/theme/app_theme.dart';
import 'package:youtube_downloader/providers/mobile_download_provider.dart';
import 'package:youtube_downloader/providers/search_provider.dart';
import 'package:youtube_downloader/services/core/logging_service.dart';
import 'package:youtube_downloader/services/ytdlp/ytdlp_service_android.dart';
import 'package:youtube_downloader/ui/components/thumbnail_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Performance optimizations', () {
    testWidgets(
      'ThumbnailTile renders missing local file fallback cleanly and disposes shimmer',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: ThumbnailTile(
                imagePath: '/nonexistent/path/missing_thumb.jpg',
                imageUrl: null,
                duration: '04:20',
              ),
            ),
          ),
        );

        // Let real OS FileImage I/O fail and trigger errorBuilder fallback
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();

        expect(find.text('04:20'), findsOneWidget);
        expect(find.byIcon(Symbols.play_circle_rounded), findsOneWidget);

        // Now test network shimmer mount & unmount (should dispose cleanly)
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: ThumbnailTile(
                imageUrl: 'https://example.invalid/thumb.jpg',
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        // Unmount ThumbnailTile — must not throw ticker-still-active assertions
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    test('LoggingService buffered writes persist on flush()', () async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = await Directory.systemTemp.createTemp('log_flush_test_');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationSupportDirectory') {
          return tempDir.path;
        }
        return null;
      });

      try {
        final logger = LoggingService();
        await logger.init();

        logger.info('Buffered line 1', component: 'PerfTest');
        logger.info('Buffered line 2', component: 'PerfTest');
        await logger.flush();

        final logFile = File(logger.logFilePath);
        expect(await logFile.exists(), isTrue);
        final contents = await logFile.readAsString();
        expect(contents, contains('Buffered line 1'));
        expect(contents, contains('Buffered line 2'));
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('SearchProvider.search(immediate: true) starts without debounce delay', () async {
      final provider = SearchProvider();
      // Start immediate search (do not await network; check synchronous state transition)
      final future = provider.search('flutter', immediate: true);
      expect(provider.isLoading, isTrue);
      expect(provider.lastQuery, 'flutter');
      provider.dispose();
      // Swallow any post-dispose completion
      await future.catchError((_) {});
    });

    test('MobileDownloadProvider.historyDownloads returns identity-stable cached list', () {
      final provider = MobileDownloadProvider(
        ytdlpService: YtdlpServiceAndroid(),
      );

      final first = provider.historyDownloads;
      final second = provider.historyDownloads;
      expect(identical(first, second), isTrue);

      provider.dispose();
    });
  });
}
