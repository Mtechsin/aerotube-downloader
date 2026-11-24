import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:youtube_downloader/core/theme/tokens/colors.dart';
import 'package:youtube_downloader/models/app_settings.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/providers/navigation_provider.dart';
import 'package:youtube_downloader/providers/download_provider.dart';
import 'package:youtube_downloader/providers/mobile_download_provider.dart';
import 'package:youtube_downloader/providers/platform_settings_provider.dart';
import 'package:youtube_downloader/services/core/settings_service.dart';
import 'package:youtube_downloader/services/cookie/cookie_service.dart';
import 'package:youtube_downloader/services/ffmpeg/ffmpeg_tool_service.dart';
import 'package:youtube_downloader/services/ytdlp/ytdlp_tool_service.dart';
import 'package:youtube_downloader/ui/components/mini_download_tray.dart';
import 'package:youtube_downloader/ui/components/aero_desktop_top_strip.dart';
import 'package:youtube_downloader/ui/widgets/navigation/app_navigation_rail.dart';

class _FakeYtdlpToolService extends Fake implements YtdlpToolService {
  @override
  String get ytdlpPath => 'yt-dlp';
  @override
  set ytdlpPath(String path) {}
  @override
  set cookiePath(String? path) {}
  @override
  set cookieBrowser(String? browser) {}
  @override
  set enableCookies(bool enable) {}
  @override
  set ffmpegPath(String? path) {}
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String?> getVersion() async => '2026.01.01';
  @override
  Future<void> initialize({bool force = false}) async {}
}

class _FakeFfmpegToolService extends Fake implements FfmpegToolService {
  @override
  bool get isAvailable => true;
  @override
  String? get ffmpegPath => 'ffmpeg';
  @override
  set ffmpegPath(String? path) {}
  @override
  Future<String?> getVersion() async => '6.1';
  @override
  Future<void> initialize({bool force = false}) async {}
}

class _FakeCookieService extends Fake implements CookieService {
  @override
  Future<bool> get isLoggedIn async => false;
}

class _FakeSettingsService extends Fake implements SettingsService {
  AppSettings _settings;

  _FakeSettingsService({bool enableAnimations = true})
    : _settings = AppSettings(enableAnimations: enableAnimations);

  @override
  AppSettings get settings => _settings;

  @override
  bool get isSidebarExpanded => _settings.isSidebarExpanded;

  @override
  Future<void> setSidebarExpanded(bool value) async {
    _settings = _settings.copyWith(isSidebarExpanded: value);
  }
}

class _FakeDownloadProvider extends ChangeNotifier implements DownloadProvider {
  final int _activeCount;
  final List<DownloadItem> _activeDownloads;

  _FakeDownloadProvider({
    int activeCount = 0,
    List<DownloadItem>? activeDownloads,
  }) : _activeCount = activeCount,
       _activeDownloads = activeDownloads ?? const [];

  @override
  int get activeCount => _activeCount;

  @override
  List<DownloadItem> get activeDownloads => _activeDownloads;

  @override
  void pauseDownload(String id) {}

  @override
  void resumeDownload(String id) {}

  @override
  void cancelDownload(String id) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMobileDownloadProvider extends ChangeNotifier
    implements MobileDownloadProvider {
  final List<DownloadItem> _activeDownloads;

  _FakeMobileDownloadProvider({List<DownloadItem>? activeDownloads})
    : _activeDownloads = activeDownloads ?? const [];

  @override
  List<DownloadItem> get activeDownloads => _activeDownloads;

  @override
  Future<void> pauseDownload(String id) async {}

  @override
  Future<void> resumeDownload(String id) async {}

  @override
  Future<void> cancelDownload(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapWithProviders({
  required Widget child,
  NavigationProvider? navigationProvider,
  PlatformSettingsProvider? platformSettingsProvider,
  DownloadProvider? downloadProvider,
  MobileDownloadProvider? mobileDownloadProvider,
}) {
  final nav = navigationProvider ?? NavigationProvider();
  final sp =
      platformSettingsProvider ??
      PlatformSettingsProvider(
        settingsService: _FakeSettingsService(),
        ytdlpService: _FakeYtdlpToolService(),
        ffmpegService: _FakeFfmpegToolService(),
        cookieService: _FakeCookieService(),
      );
  final dp = downloadProvider ?? _FakeDownloadProvider();
  final mdp = mobileDownloadProvider ?? _FakeMobileDownloadProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NavigationProvider>.value(value: nav),
      ChangeNotifierProvider<PlatformSettingsProvider>.value(value: sp),
      ChangeNotifierProvider<DownloadProvider>.value(value: dp),
      ChangeNotifierProvider<MobileDownloadProvider>.value(value: mdp),
    ],
    child: MaterialApp(
      theme: ThemeData(extensions: const [AeroColors.dark]),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
  });
  group('Sidebar collapse and expansion', () {
    Future<PlatformSettingsProvider> mountRail(
      WidgetTester tester, {
      bool enableAnimations = true,
      bool reduceMotion = false,
      int activeCount = 0,
    }) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AnimationController(
        vsync: tester,
        value: 1,
        duration: const Duration(milliseconds: 300),
      );
      addTearDown(controller.dispose);
      final settings = PlatformSettingsProvider(
        settingsService: _FakeSettingsService(
          enableAnimations: enableAnimations,
        ),
        ytdlpService: _FakeYtdlpToolService(),
        ffmpegService: _FakeFfmpegToolService(),
        cookieService: _FakeCookieService(),
      );
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        _wrapWithProviders(
          platformSettingsProvider: settings,
          downloadProvider: _FakeDownloadProvider(activeCount: activeCount),
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: Row(
                children: [
                  AppNavigationRail(entranceController: controller),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return settings;
    }

    testWidgets('width and contents animate together in both directions', (
      tester,
    ) async {
      await mountRail(tester);
      final rail = find.byType(AppNavigationRail);
      final homeElement = tester.element(find.byIcon(Symbols.home_rounded));
      final homeRow = tester.element(
        find.byKey(const ValueKey('sidebar-Home')),
      );
      expect(tester.getSize(rail).width, 232);
      await tester.tap(find.byTooltip('Collapse sidebar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.getSize(rail).width, inExclusiveRange(72, 232));
      // Only one set of destinations is mounted while the width animates.
      expect(find.text('Home'), findsOneWidget);
      expect(find.byTooltip('Home (Ctrl+1)'), findsOneWidget);
      expect(find.byIcon(Symbols.home_rounded), findsOneWidget);
      expect(
        find.descendant(of: rail, matching: find.byType(AnimatedSwitcher)),
        findsNothing,
      );
      expect(
        tester.element(find.byIcon(Symbols.home_rounded)),
        same(homeElement),
      );
      expect(
        tester.element(find.byKey(const ValueKey('sidebar-Home'))),
        same(homeRow),
      );
      expect(find.byTooltip('Expand sidebar').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Collapse sidebar').hitTestable(), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.getSize(rail).width, 72);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Home').hitTestable(), findsNothing);
      await tester.tap(find.byTooltip('Expand sidebar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.getSize(rail).width, inExclusiveRange(72, 232));
      expect(find.text('Home'), findsOneWidget);
      expect(find.byTooltip('Home (Ctrl+1)'), findsOneWidget);
      expect(find.byIcon(Symbols.home_rounded), findsOneWidget);
      expect(
        tester.element(find.byIcon(Symbols.home_rounded)),
        same(homeElement),
      );
      expect(
        tester.element(find.byKey(const ValueKey('sidebar-Home'))),
        same(homeRow),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(rail).width, 232);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapid reversal and window resizing settle without overflow', (
      tester,
    ) async {
      final settings = await mountRail(tester);
      final rail = find.byType(AppNavigationRail);
      final rowKeys = [
        'Home',
        'Search',
        'Library',
        'Settings',
        'account',
        'theme',
      ].map((name) => ValueKey('sidebar-$name')).toList();
      final originalRows = [
        for (final key in rowKeys) tester.element(find.byKey(key)),
      ];
      for (final expanded in [false, true, false, true]) {
        await settings.setSidebarExpanded(expanded);
        await tester.pump();
        for (var frame = 0; frame < 5; frame++) {
          await tester.pump(const Duration(milliseconds: 14));
          expect(tester.getSize(rail).width, inInclusiveRange(72, 232));
          for (final destination in [
            'Home (Ctrl+1)',
            'Search (Ctrl+2)',
            'Library (Ctrl+3)',
            'Settings (Ctrl+4, Ctrl+,)',
          ]) {
            expect(find.byTooltip(destination), findsOneWidget);
          }
          expect(find.byIcon(Symbols.home_rounded), findsOneWidget);
          expect(find.byIcon(Symbols.person_rounded), findsOneWidget);
          expect(find.text('Home'), findsOneWidget);
          for (var index = 0; index < rowKeys.length; index++) {
            expect(
              tester.element(find.byKey(rowKeys[index])),
              same(originalRows[index]),
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpAndSettle();
      expect(tester.getSize(rail).width, 232);
      tester.view.physicalSize = const Size(960, 720);
      await tester.pumpAndSettle();
      expect(tester.getSize(rail).width, 72);
      expect(settings.isSidebarExpanded, isTrue);
      tester.view.physicalSize = const Size(1280, 720);
      await tester.pumpAndSettle();
      expect(tester.getSize(rail).width, 232);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'one download badge remains mounted and destinations work when collapsed',
      (tester) async {
        final settings = await mountRail(tester, activeCount: 12);
        final badgeElement = tester.element(find.text('12'));
        await settings.setSidebarExpanded(false);
        await tester.pump();
        for (var frame = 0; frame < 25; frame++) {
          await tester.pump(const Duration(milliseconds: 14));
          expect(find.text('12'), findsOneWidget);
          expect(tester.element(find.text('12')), same(badgeElement));
        }
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Search (Ctrl+2)'));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(AppNavigationRail));
        expect(context.read<NavigationProvider>().currentIndex, 1);
        expect(tester.takeException(), isNull);
      },
    );

    for (final reduceMotion in [false, true]) {
      testWidgets(
        'motion preference skips width and content animation, reduced=$reduceMotion',
        (tester) async {
          final settings = await mountRail(
            tester,
            enableAnimations: reduceMotion,
            reduceMotion: reduceMotion,
          );
          await settings.setSidebarExpanded(false);
          await tester.pump();
          await tester.pump();
          expect(tester.getSize(find.byType(AppNavigationRail)).width, 72);
          expect(find.text('Home'), findsOneWidget);
          expect(find.text('Home').hitTestable(), findsNothing);
          await settings.setSidebarExpanded(true);
          await tester.pump();
          await tester.pump();
          expect(tester.getSize(find.byType(AppNavigationRail)).width, 232);
          expect(find.text('Home'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('Phase 3 Shell & Navigation Tests', () {
    testWidgets('AeroDesktopTopStrip renders breadcrumb and page title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithProviders(child: const AeroDesktopTopStrip(currentIndex: 0)),
      );
      await tester.pump();

      expect(find.text('AeroTube'), findsOneWidget);
      expect(find.text('/'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets(
      'AppNavigationRail renders navigation destinations and wordmark',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 300),
        );

        try {
          await tester.pumpWidget(
            _wrapWithProviders(
              child: AppNavigationRail(entranceController: controller),
            ),
          );
          controller.forward();
          await tester.pump(const Duration(milliseconds: 350));

          // Wordmark is rendered via RichText
          expect(
            find.byWidgetPredicate(
              (w) => w is RichText && w.text.toPlainText().contains('AeroTube'),
            ),
            findsOneWidget,
          );
          expect(find.text('Home'), findsOneWidget);
          expect(find.text('Search'), findsOneWidget);
          expect(find.text('Library'), findsOneWidget);
          expect(find.text('Settings'), findsOneWidget);
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets(
      'MiniDownloadTray returns empty widget when no active downloads',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithProviders(child: const MiniDownloadTray()),
        );
        await tester.pump();

        expect(find.byType(MiniDownloadTray), findsOneWidget);
        expect(find.text('Library'), findsNothing);
      },
    );

    testWidgets('MiniDownloadTray renders active download item and progress', (
      tester,
    ) async {
      final fakeItem = DownloadItem(
        id: 'test-123',
        title: 'Flutter Desktop Tutorial',
        url: 'https://youtube.com/watch?v=123',
        outputPath: '/path/video.mp4',
        progress: 0.45,
        status: DownloadStatus.downloadingVideo,
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          downloadProvider: _FakeDownloadProvider(
            activeCount: 1,
            activeDownloads: [fakeItem],
          ),
          child: const MiniDownloadTray(),
        ),
      );
      await tester.pump();

      expect(find.text('Flutter Desktop Tutorial'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);
      expect(find.byIcon(Symbols.pause_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.close_rounded), findsOneWidget);
    });
  });
}
