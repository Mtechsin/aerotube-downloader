import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:youtube_downloader/core/theme/app_theme.dart';
import 'package:youtube_downloader/core/utils/platform_utils.dart';
import 'package:youtube_downloader/models/app_settings.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/models/video_info.dart';
import 'package:youtube_downloader/providers/mobile_download_provider.dart';
import 'package:youtube_downloader/providers/platform_settings_provider.dart';
import 'package:youtube_downloader/providers/video_provider.dart';
import 'package:youtube_downloader/ui/components/aero_chip.dart';
import 'package:youtube_downloader/ui/widgets/mobile_video_configuration_widget.dart';

import '../providers/video_provider_seamless_update_test.dart'
    show MockYtdlpToolService;

class _Settings extends ChangeNotifier implements PlatformSettingsProvider {
  @override
  AppSettings get settings => AppSettings(enableAnimations: false);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Downloads extends ChangeNotifier implements MobileDownloadProvider {
  @override
  List<DownloadItem> get activeDownloads => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Formats extends MockYtdlpToolService {
  @override
  Future<VideoInfo> getVideoInfo(
    String url, {
    Function(String)? onProgress,
  }) async => VideoInfo(
    id: 'mobile',
    title: 'Video',
    channel: 'Channel',
    channelUrl: '',
    thumbnailUrl: '',
    duration: 60,
    description: '',
    viewCount: 0,
    uploadDate: '',
    url: url,
    subtitles: [],
    formats: [
      for (final height in [2160, 1440, 1080, 720, 480, 360, 240, 144])
        FormatInfo(
          formatId: '$height',
          height: height,
          hasVideo: true,
          hasAudio: true,
          videoCodec: 'avc1',
          extension: 'mp4',
          filesize: 100000,
        ),
    ],
  );
}

void main() {
  for (final width in [320.0, 412.0]) {
    testWidgets(
      'Android exposes all qualities without horizontal scrolling at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        PlatformUtils.isAndroidOverride = true;
        PlatformUtils.isWindowsOverride = false;
        addTearDown(() {
          PlatformUtils.isAndroidOverride = null;
          PlatformUtils.isWindowsOverride = null;
        });
        final video = VideoProvider(_Formats());
        await video.fetchVideoInfo('https://example.com/video');
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<VideoProvider>(create: (_) => video),
              ChangeNotifierProvider<PlatformSettingsProvider>(
                create: (_) => _Settings(),
              ),
              ChangeNotifierProvider<MobileDownloadProvider>(
                create: (_) => _Downloads(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: MobileVideoConfigurationWidget(onDownload: () async {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final label in [
          '4K',
          '2K',
          '1080p',
          '720p',
          '480p',
          '360p',
          '240p',
          '144p',
        ]) {
          final chip = find.ancestor(
            of: find.text(label),
            matching: find.byType(FormatChip),
          );
          expect(chip, findsOneWidget);
          final rect = tester.getRect(chip);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
        final first = tester.getRect(find.text('4K'));
        final last = tester.getRect(find.text('144p'));
        expect(last.top, greaterThan(first.top));
        await tester.ensureVisible(find.text('144p'));
        await tester.tap(find.text('144p'));
        await tester.pumpAndSettle();
        expect(video.selectedHeight, 144);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
