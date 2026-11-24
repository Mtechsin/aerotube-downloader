import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/core/theme/app_theme.dart';
import 'package:youtube_downloader/core/utils/platform_utils.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/models/video_info.dart';
import 'package:youtube_downloader/models/playlist_info.dart';
import 'package:youtube_downloader/providers/download_provider.dart';
import 'package:youtube_downloader/providers/navigation_provider.dart';
import 'package:youtube_downloader/providers/platform_settings_provider.dart';
import 'package:youtube_downloader/providers/search_provider.dart';
import 'package:youtube_downloader/providers/tool_update_provider.dart';
import 'package:youtube_downloader/providers/update_provider.dart';
import 'package:youtube_downloader/providers/video_provider.dart';
import 'package:youtube_downloader/providers/playlist_provider.dart';
import 'package:youtube_downloader/services/cookie/cookie_service.dart';
import 'package:youtube_downloader/services/core/settings_service.dart';
import 'package:youtube_downloader/services/ffmpeg/ffmpeg_tool_service.dart';
import 'package:youtube_downloader/services/ytdlp/ytdlp_tool_service.dart';
import 'package:youtube_downloader/ui/components/aero_desktop_top_strip.dart';
import 'package:youtube_downloader/ui/components/mini_download_tray.dart';
import 'package:youtube_downloader/ui/screens/downloads_screen.dart';
import 'package:youtube_downloader/ui/screens/home_screen.dart';
import 'package:youtube_downloader/ui/screens/search_screen.dart';
import 'package:youtube_downloader/ui/screens/settings_screen.dart';
import 'package:youtube_downloader/ui/screens/playlist_screen.dart';
import 'package:youtube_downloader/ui/widgets/navigation/app_navigation_rail.dart';

class _Ytdlp extends Fake implements YtdlpToolService {
  @override
  String get ytdlpPath => 'yt-dlp';
  @override
  Future<bool> isAvailable() async => true;

  Future<VideoInfo> getVideoInfo(
    String url, {
    void Function(String)? onProgress,
  }) async => VideoInfo(
    id: 'fixture',
    title: 'A walk through the Scottish Highlands',
    channel: 'Field notes',
    channelUrl: '',
    thumbnailUrl: '',
    duration: 842,
    description: 'A quiet afternoon on the trail.',
    viewCount: 284000,
    uploadDate: '20261001',
    url: url,
    subtitles: [],
    formats: [
      for (final height in [1080, 720, 480])
        FormatInfo(
          formatId: '$height',
          height: height,
          width: height * 16 ~/ 9,
          extension: 'mp4',
          videoCodec: 'avc1',
          audioCodec: 'mp4a',
          hasAudio: true,
          hasVideo: true,
          filesize: height * 170000,
          fps: 30,
          tbr: height * 4.0,
        ),
      FormatInfo(
        formatId: 'audio',
        extension: 'm4a',
        audioCodec: 'mp4a',
        hasAudio: true,
        hasVideo: false,
        audioBitrate: 192,
        filesize: 18000000,
      ),
    ],
  );
}

class _Playlist extends ChangeNotifier implements PlaylistProvider {
  final _selected = <String>{'p1', 'p2'};
  @override
  String get currentUrl => 'https://www.youtube.com/playlist?list=example';
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  String? get loadingStatus => null;
  @override
  Set<String> get selectedIds => _selected;
  @override
  int get selectedCount => _selected.length;
  @override
  bool get isAllSelected => _selected.length == 3;
  @override
  bool get audioOnly => false;
  @override
  AudioQuality get audioQuality => AudioQuality.high;
  @override
  String get selectedFormatId => '1080';
  @override
  PlaylistInfo get playlist => PlaylistInfo(
    title: 'Field notes · Scotland',
    uploader: 'Field notes',
    videoCount: 3,
    videos: [
      for (var i = 1; i <= 3; i++)
        PlaylistVideoItem(
          id: 'p$i',
          title: [
            'A walk through the Highlands',
            'Along the coast',
            'Morning in Edinburgh',
          ][i - 1],
          channel: 'Field notes',
          duration: 600 + 42 * i,
          url: 'https://vimeo.com/$i',
        ),
    ],
  );
  @override
  Future<void> cancelFetch() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ffmpeg extends Fake implements FfmpegToolService {
  @override
  String get ffmpegPath => 'ffmpeg';
}

class _Cookies extends Fake implements CookieService {}

class _Settings extends PlatformSettingsProvider {
  _Settings(SettingsService service, _Ytdlp ytdlp, _Ffmpeg ffmpeg)
    : super(
        settingsService: service,
        ytdlpService: ytdlp,
        ffmpegService: ffmpeg,
        cookieService: _Cookies(),
      );
  @override
  bool get isInitialized => true;
  @override
  bool get hasCheckedTools => true;
  @override
  bool get isYtdlpAvailable => true;
  @override
  bool get isFfmpegAvailable => true;
  @override
  String get ytdlpVersion => '2026.10.01';
  @override
  String get ffmpegVersion => '8.0';
}

class _Tools extends ToolUpdateProvider {
  _Tools({
    required super.ytdlpService,
    required super.ffmpegService,
    required super.settingsProvider,
    required this.mobile,
  });
  final bool mobile;

  ToolUpdateState _state(ToolType tool, String version) => ToolUpdateState(
    tool: tool,
    status: mobile
        ? ToolUpdateStatus.updateAvailable
        : ToolUpdateStatus.upToDate,
    currentVersion: version,
    latestVersion: '$version.1',
    isAvailable: true,
  );

  @override
  ToolUpdateState get ytdlpState => _state(ToolType.ytdlp, '2026.10.01');
  @override
  ToolUpdateState get ffmpegState => _state(ToolType.ffmpeg, '8.0');
}

class _Downloads extends ChangeNotifier implements DownloadProvider {
  _Downloads({this.populated = false, this.withHistory = false});
  final bool populated;
  final bool withHistory;
  late final List<DownloadItem> _items = populated
      ? [
          DownloadItem(
            id: '1',
            title: 'A walk through the Scottish Highlands',
            url: 'https://www.youtube.com/watch?v=example',
            outputPath: 'Downloads',
            status: DownloadStatus.downloadingVideo,
            progress: 0.64,
            speed: 4600000,
            eta: 32,
            totalBytes: 182000000,
            videoQuality: '1080p',
          ),
          DownloadItem(
            id: '2',
            title: 'Piano sessions · Music for a quiet afternoon',
            url: 'https://www.youtube.com/watch?v=example2',
            outputPath: 'Downloads',
            status: DownloadStatus.paused,
            progress: 0.28,
            audioOnly: true,
          ),
        ]
      : [];
  @override
  List<DownloadItem> get activeDownloads => _items;
  @override
  List<DownloadItem> get historyDownloads => withHistory
      ? [
          DownloadItem(
            id: 'recent',
            title: 'Can AI afford a slowdown?',
            url: 'https://vimeo.com/example',
            outputPath: 'Downloads',
            status: DownloadStatus.completed,
            progress: 1,
            videoQuality: '1080p',
            completedDate: DateTime(2026, 9, 17),
          ),
        ]
      : [];
  @override
  List<DownloadItem> get downloads => _items;
  @override
  int get activeCount => _items.length;
  @override
  void pauseDownload(String id) {}
  @override
  void resumeDownload(String id) {}
  @override
  void cancelDownload(String id) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DesktopPreview extends StatefulWidget {
  const _DesktopPreview({required this.page});
  final int page;
  @override
  State<_DesktopPreview> createState() => _DesktopPreviewState();
}

class _DesktopPreviewState extends State<_DesktopPreview>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 1),
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(
      children: [
        AppNavigationRail(entranceController: controller),
        Expanded(
          child: Column(
            children: [
              AeroDesktopTopStrip(
                currentIndex: widget.page < 4 ? widget.page : 0,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: const [
                      HomeScreen(),
                      SearchScreen(),
                      DownloadsScreen(),
                      SettingsScreen(),
                      HomeScreen(),
                      PlaylistScreen(),
                    ][widget.page],
                  ),
                ),
              ),
              const MiniDownloadTray(),
            ],
          ),
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await loader.load();
    final icons =
        FontLoader(
          'packages/material_symbols_icons/MaterialSymbolsRounded',
        )..addFont(
          rootBundle.load(
            'packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf',
          ),
        );
    await icons.load();
    PackageInfo.setMockInitialValues(
      appName: 'AeroTube',
      packageName: 'aerotube',
      version: '1.1.0',
      buildNumber: '2006',
      buildSignature: '',
    );
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.aerotube.youtube_downloader/permissions'),
          (call) async => call.method == 'getApiLevel' ? 35 : true,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.aerotube.youtube_downloader/permissions'),
          null,
        );
  });
  for (final dark in [true, false]) {
    for (final size in [
      const Size(1280, 800),
      const Size(960, 640),
      const Size(640, 720),
      const Size(360, 800),
      const Size(320, 720),
    ]) {
      for (var page = 0; page < 6; page++) {
        final mobile = size.width < 600;
        if (mobile && page != 1 && page != 3) continue;
        final name = [
          'home',
          'search',
          'library',
          'settings',
          'video-options',
          'playlist',
        ][page];
        testWidgets('$name ${dark ? "dark" : "light"} at ${size.width}', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          PlatformUtils.isWindowsOverride = !mobile;
          PlatformUtils.isAndroidOverride = mobile;
          addTearDown(() {
            PlatformUtils.isWindowsOverride = null;
            PlatformUtils.isAndroidOverride = null;
          });
          SharedPreferences.setMockInitialValues({'enable_animations': false});
          final service = SettingsService();
          await service.init();
          final ytdlp = _Ytdlp();
          final ffmpeg = _Ffmpeg();
          final settings = _Settings(service, ytdlp, ffmpeg);
          final nav = NavigationProvider()..setIndex(page < 4 ? page : 0);
          final video = VideoProvider(ytdlp);
          if (page == 4) await video.fetchVideoInfo('https://vimeo.com/123456');
          final key = GlobalKey();
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<PlatformSettingsProvider>(
                  create: (_) => settings,
                ),
                ChangeNotifierProvider<NavigationProvider>(create: (_) => nav),
                ChangeNotifierProvider<DownloadProvider>(
                  create: (_) =>
                      _Downloads(populated: page == 2, withHistory: page == 0),
                ),
                ChangeNotifierProvider<VideoProvider>(create: (_) => video),
                ChangeNotifierProvider<PlaylistProvider>(
                  create: (_) => _Playlist(),
                ),
                ChangeNotifierProvider<SearchProvider>(
                  create: (_) => SearchProvider(ytdlpService: ytdlp),
                ),
                ChangeNotifierProvider<UpdateProvider>(
                  create: (_) => UpdateProvider(),
                ),
                ChangeNotifierProvider<ToolUpdateProvider>(
                  create: (_) => _Tools(
                    ytdlpService: ytdlp,
                    ffmpegService: ffmpeg,
                    settingsProvider: settings,
                    mobile: mobile,
                  ),
                ),
              ],
              child: RepaintBoundary(
                key: key,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        mobile ? 1.5 : (size.width == 640 ? 1.3 : 1),
                      ),
                    ),
                    child: child!,
                  ),
                  home: mobile
                      ? Scaffold(
                          body: page == 1
                              ? const SearchScreen()
                              : const SettingsScreen(),
                        )
                      : _DesktopPreview(page: page),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (!mobile) {
            expect(find.byType(AppNavigationRail), findsOneWidget);
          }
          if (page == 1) {
            expect(find.text('Find something to watch'), findsNothing);
            expect(find.text('Try a search'), findsNothing);
          }
          if (page == 3) {
            if (mobile) {
              expect(find.byTooltip('Update yt-dlp'), findsOneWidget);
              expect(find.byTooltip('Update FFmpeg'), findsOneWidget);
            }
            expect(
              tester.getTopLeft(find.text('TOOLS')).dy,
              lessThan(tester.getTopLeft(find.text('ACCOUNT')).dy),
            );
          }
          if (const bool.fromEnvironment('WRITE_UI_SCREENSHOTS')) {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('docs/ui-screenshots/after')
                ..createSync(recursive: true);
              await File(
                '${dir.path}/$name-${dark ? "dark" : "light"}-${size.width.toInt()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
