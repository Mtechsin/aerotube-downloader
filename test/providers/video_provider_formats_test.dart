import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/models/video_info.dart';
import 'package:youtube_downloader/providers/video_provider.dart';

import 'video_provider_seamless_update_test.dart' show MockYtdlpToolService;

class _FormatService extends MockYtdlpToolService {
  final List<FormatInfo> formats;
  _FormatService(this.formats);

  @override
  Future<VideoInfo> getVideoInfo(
    String url, {
    Function(String status)? onProgress,
  }) async => VideoInfo(
    id: 'formats',
    title: 'Format fixture',
    channel: 'Channel',
    channelUrl: '',
    thumbnailUrl: '',
    duration: 60,
    description: '',
    viewCount: 0,
    uploadDate: '',
    url: url,
    subtitles: [],
    formats: formats,
  );
}

FormatInfo _video(String id, int height, {bool audio = false}) => FormatInfo(
  formatId: id,
  height: height,
  extension: 'mp4',
  videoCodec: 'avc1',
  hasVideo: true,
  hasAudio: audio,
  filesize: 1000000,
);

void main() {
  test(
    'retains combined-only resolutions alongside separate video streams',
    () async {
      final provider = VideoProvider(
        _FormatService([
          _video('1080', 1080),
          _video('720', 720),
          _video('18', 360, audio: true),
          FormatInfo(
            formatId: 'audio',
            hasVideo: false,
            hasAudio: true,
            filesize: 100000,
            audioBitrate: 192,
            audioCodec: 'mp4a',
          ),
          FormatInfo(
            formatId: 'storyboard',
            height: 90,
            hasVideo: false,
            hasAudio: false,
          ),
        ]),
      );
      addTearDown(provider.dispose);
      await provider.fetchVideoInfo('https://example.com/video');
      expect(provider.availableResolutions.map((r) => r.height), [
        1080,
        720,
        360,
      ]);
      expect(provider.selectedAudioFormatId, 'audio');
      expect(provider.totalEstimatedDownloadSize, 1100000);
      provider.setSelectedHeight(360);
      expect(provider.selectedVideoFormatId, '18');
      expect(provider.selectedAudioFormatId, isNull);
      expect(provider.totalEstimatedDownloadSize, 1000000);
    },
  );

  test(
    'retains every codec and combined variant at the same resolution',
    () async {
      final provider = VideoProvider(
        _FormatService([
          _video('dash', 720),
          _video('combined', 720, audio: true),
          FormatInfo(
            formatId: 'vp9',
            height: 720,
            extension: 'webm',
            videoCodec: 'vp9',
            hasVideo: true,
            hasAudio: false,
            filesize: 800000,
          ),
        ]),
      );
      addTearDown(provider.dispose);
      await provider.fetchVideoInfo('https://example.com/video');
      final resolution = provider.availableResolutions.single;
      expect(
        resolution.formats.map((f) => f.formatId),
        unorderedEquals(['dash', 'combined', 'vp9']),
      );
      for (final format in resolution.formats) {
        provider.setSelectedVideoFormat(format);
        expect(provider.selectedVideoFormatId, format.formatId);
      }
    },
  );

  test(
    'progressive-only videos still expose their actual quality ladder',
    () async {
      final provider = VideoProvider(
        _FormatService([
          _video('720', 720, audio: true),
          _video('360', 360, audio: true),
        ]),
      );
      addTearDown(provider.dispose);
      await provider.fetchVideoInfo('https://example.com/video');
      expect(provider.availableResolutions.map((r) => r.height), [720, 360]);
      expect(provider.selectedAudioFormatId, isNull);
      expect(provider.canDownload, isTrue);
    },
  );
}
