import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/models/video_info.dart';
import 'package:youtube_downloader/providers/video_provider.dart';
import 'package:youtube_downloader/services/ytdlp/ytdlp_tool_service.dart';

class MockYtdlpToolService implements YtdlpToolService {
  @override
  String ytdlpPath = 'yt-dlp';
  @override
  String? cookiePath;
  @override
  String? cookieBrowser;
  @override
  String? webViewPath;
  @override
  String? ffmpegPath;
  @override
  String? userAgent;
  @override
  bool enableCookies = false;

  bool available = true;
  int getVideoInfoCalls = 0;
  int downloadAndInstallCalls = 0;
  bool shouldThrowOutdatedOnFirstCall = false;

  @override
  Future<void> initialize({bool force = false}) async {}

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String?> getVersion() async => '2024.01.01';

  @override
  void markReady(String version) {}

  @override
  Future<String?> getLatestVersion({bool forceRefresh = false}) async => '2024.02.01';

  @override
  Future<YtdlpUpdateInfo?> checkForUpdateWithProgress() async {
    return YtdlpUpdateInfo(
      currentVersion: '2024.01.01',
      latestVersion: '2024.02.01',
    );
  }

  @override
  Future<bool> downloadAndInstallUpdate(
    String downloadUrl, {
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
    bool Function()? isCancelled,
  }) async {
    downloadAndInstallCalls++;
    onProgress(0.5);
    onStatus('Downloading...');
    onProgress(1.0);
    onStatus('Update complete!');
    available = true;
    return true;
  }

  @override
  Future<bool> update() async => true;

  @override
  Future<void> cancelFetch() async {}

  Future<VideoInfo> getVideoInfo(
    String url, {
    Function(String status)? onProgress,
  }) async {
    getVideoInfoCalls++;
    if (shouldThrowOutdatedOnFirstCall && getVideoInfoCalls == 1) {
      throw Exception('ERROR: [youtube] Signature extraction failed: update yt-dlp');
    }
    return VideoInfo(
      id: 'test1234567',
      title: 'Seamless Video Test',
      channel: 'Test Channel',
      channelUrl: 'https://youtube.com/test',
      thumbnailUrl: '',
      duration: 120,
      description: '',
      viewCount: 100,
      uploadDate: '2024-01-01',
      url: url,
      formats: [],
      subtitles: [],
    );
  }

  bool isBrokenError(String error) => error.contains('Signature extraction failed');
}

void main() {
  group('VideoProvider Seamless Self-Healing', () {
    test('auto-installs yt-dlp if unavailable before fetching', () async {
      final mock = MockYtdlpToolService()..available = false;
      final provider = VideoProvider(mock);

      await provider.fetchVideoInfo('https://www.youtube.com/watch?v=test1234567');

      expect(mock.downloadAndInstallCalls, 1);
      expect(mock.getVideoInfoCalls, 1);
      expect(provider.videoInfo?.title, 'Seamless Video Test');
      expect(provider.hasError, false);
    });

    test('transparently updates yt-dlp and retries on signature extraction error', () async {
      final mock = MockYtdlpToolService()..shouldThrowOutdatedOnFirstCall = true;
      final provider = VideoProvider(mock);

      await provider.fetchVideoInfo('https://www.youtube.com/watch?v=test1234567');

      // First call fails with signature extraction, triggers autoUpdate, then retries
      expect(mock.downloadAndInstallCalls, 1);
      expect(mock.getVideoInfoCalls, 2);
      expect(provider.videoInfo?.title, 'Seamless Video Test');
      expect(provider.hasError, false);
    });

    test('updateYtdlpAndRetry triggers manual retry with fresh update', () async {
      final mock = MockYtdlpToolService();
      final provider = VideoProvider(mock);

      await provider.fetchVideoInfo('https://www.youtube.com/watch?v=test1234567');
      expect(mock.getVideoInfoCalls, 1);

      await provider.updateYtdlpAndRetry();
      expect(mock.downloadAndInstallCalls, 1);
      expect(mock.getVideoInfoCalls, 2);
    });
  });
}
