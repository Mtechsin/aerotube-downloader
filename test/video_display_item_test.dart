import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/models/video_display_item.dart';
import 'package:youtube_downloader/models/video_info.dart';
import 'package:youtube_downloader/models/playlist_info.dart';
import 'package:youtube_downloader/models/search_video_result.dart';
import 'package:youtube_downloader/core/utils/url_validator.dart';
import 'package:youtube_downloader/ui/widgets/url_input_helper.dart';

void main() {
  group('VideoDisplayItem', () {
    test('formats duration in seconds correctly', () {
      expect(VideoDisplayItem.formatDurationSeconds(45), '00:45');
      expect(VideoDisplayItem.formatDurationSeconds(125), '02:05');
      expect(VideoDisplayItem.formatDurationSeconds(3665), '01:01:05');
    });

    test('formats view count correctly', () {
      expect(VideoDisplayItem.formatViewCount(500), '500 views');
      expect(VideoDisplayItem.formatViewCount(1500), '1.5K views');
      expect(VideoDisplayItem.formatViewCount(2500000), '2.5M views');
      expect(VideoDisplayItem.formatViewCount(3000000000), '3.0B views');
    });

    test('VideoInfo implements VideoDisplayItem', () {
      final info = VideoInfo(
        id: 'abc12345',
        title: 'Test Title',
        channel: 'Test Channel',
        channelUrl: 'https://youtube.com/channel/test',
        thumbnailUrl: 'https://img.youtube.com/vi/abc12345/0.jpg',
        duration: 200,
        description: 'Test Description',
        viewCount: 1000,
        uploadDate: '2026-01-01',
        formats: [],
        url: 'https://youtube.com/watch?v=abc12345',
        subtitles: [],
      );

      expect(info, isA<VideoDisplayItem>());
      expect(info.author, 'Test Channel');
      expect(info.durationSeconds, 200);
      expect(info.formattedDuration, '03:20');
    });

    test('PlaylistVideoItem implements VideoDisplayItem', () {
      final item = PlaylistVideoItem(
        id: 'play123',
        title: 'Playlist Video',
        channel: 'Creator',
        duration: 90,
        url: 'https://youtube.com/watch?v=play123',
      );

      expect(item, isA<VideoDisplayItem>());
      expect(item.author, 'Creator');
      expect(item.durationSeconds, 90);
      expect(item.formattedDuration, '01:30');
    });

    test('SearchVideoResult implements VideoDisplayItem', () {
      final item = SearchVideoResult(
        id: 'search123',
        title: 'Search Title',
        author: 'Artist',
        thumbnailUrl: 'https://img.youtube.com/vi/search123/0.jpg',
        duration: const Duration(seconds: 150),
      );

      expect(item, isA<VideoDisplayItem>());
      expect(item.channel, 'Artist');
      expect(item.url, 'https://www.youtube.com/watch?v=search123');
      expect(item.durationSeconds, 150);
      expect(item.formattedDuration, '02:30');
    });
  });

  group('UrlValidator.isYouTubeUrl', () {
    test('identifies YouTube URLs accurately', () {
      expect(UrlValidator.isYouTubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(UrlValidator.isYouTubeUrl('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(UrlValidator.isYouTubeUrl('https://music.youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(UrlValidator.isYouTubeUrl('https://m.youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(UrlValidator.isYouTubeUrl('youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(UrlValidator.isYouTubeUrl('https://vimeo.com/12345'), isFalse);
      expect(UrlValidator.isYouTubeUrl('https://google.com'), isFalse);
      expect(UrlValidator.isYouTubeUrl(''), isFalse);
    });
  });

  group('UrlValidator.validate', () {
    test('accepts YouTube URLs', () {
      expect(
        UrlValidator.validate('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(
        UrlValidator.validate('https://youtu.be/dQw4w9WgXcQ'),
        'https://youtu.be/dQw4w9WgXcQ',
      );
    });

    test('accepts non-YouTube yt-dlp supported URLs', () {
      expect(
        UrlValidator.validate('https://vimeo.com/12345'),
        'https://vimeo.com/12345',
      );
      expect(
        UrlValidator.validate('https://www.twitch.tv/videos/12345'),
        'https://www.twitch.tv/videos/12345',
      );
      expect(
        UrlValidator.validate('https://twitter.com/user/status/123'),
        'https://twitter.com/user/status/123',
      );
      expect(
        UrlValidator.validate('https://www.tiktok.com/@user/video/123'),
        'https://www.tiktok.com/@user/video/123',
      );
      expect(
        UrlValidator.validate('https://soundcloud.com/artist/track'),
        'https://soundcloud.com/artist/track',
      );
    });

    test('normalizes scheme-less URLs', () {
      expect(
        UrlValidator.validate('youtube.com/watch?v=dQw4w9WgXcQ'),
        'https://youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(
        UrlValidator.validate('vimeo.com/12345'),
        'https://vimeo.com/12345',
      );
    });

    test('rejects invalid input', () {
      expect(() => UrlValidator.validate(''), throwsA(isA<UrlValidationException>()));
      expect(() => UrlValidator.validate('-rm_rf'), throwsA(isA<UrlValidationException>()));
      expect(() => UrlValidator.validate('ftp://example.com/file'), throwsA(isA<UrlValidationException>()));
      expect(() => UrlValidator.validate('not a url'), throwsA(isA<UrlValidationException>()));
    });
  });

  group('UrlValidator.looksLikePlaylist', () {
    test('detects YouTube playlist URLs', () {
      expect(UrlValidator.looksLikePlaylist('https://youtube.com/playlist?list=PL123'), isTrue);
      expect(UrlValidator.looksLikePlaylist('https://youtube.com/watch?v=abc&list=PL123'), isTrue);
      expect(UrlValidator.looksLikePlaylist('https://youtube.com/watch?v=abc'), isFalse);
    });

    test('detects generic playlist paths', () {
      expect(UrlValidator.looksLikePlaylist('https://vimeo.com/album/123/playlist'), isTrue);
    });
  });

  group('UrlInputHelper.getStatusIcon', () {
    test('returns expected icons based on status message content', () {
      expect(UrlInputHelper.getStatusIcon('Connecting to server...'), Icons.wifi_rounded);
      expect(UrlInputHelper.getStatusIcon('Fetching video metadata...'), Icons.cloud_download_rounded);
      expect(UrlInputHelper.getStatusIcon('Processing video...'), Icons.settings_rounded);
      expect(UrlInputHelper.getStatusIcon('Found playlist with 10 videos'), Icons.playlist_play_rounded);
      expect(UrlInputHelper.getStatusIcon('Retrying connection...'), Icons.refresh_rounded);
      expect(UrlInputHelper.getStatusIcon('Unknown status'), Icons.hourglass_empty_rounded);
    });
  });
}
