import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/utils/version_utils.dart';

void main() {
  group('VersionUtils.isNewerVersion', () {
    test('standard semver comparison', () {
      expect(VersionUtils.isNewerVersion('1.0.0', '1.0.1'), isTrue);
      expect(VersionUtils.isNewerVersion('1.0.0', '1.1.0'), isTrue);
      expect(VersionUtils.isNewerVersion('1.0.0', '2.0.0'), isTrue);
      expect(VersionUtils.isNewerVersion('1.0.1', '1.0.0'), isFalse);
      expect(VersionUtils.isNewerVersion('1.0.0', '1.0.0'), isFalse);
    });

    test('semver with v prefix', () {
      expect(VersionUtils.isNewerVersion('v1.0.0', 'v1.0.1'), isTrue);
      expect(VersionUtils.isNewerVersion('1.0.0', 'v1.0.1'), isTrue);
      expect(VersionUtils.isNewerVersion('v1.0.1', '1.0.0'), isFalse);
    });

    test('calver / date-based versions (yt-dlp)', () {
      expect(VersionUtils.isNewerVersion('2024.12.23', '2025.01.15'), isTrue);
      expect(VersionUtils.isNewerVersion('2025.01.15', '2024.12.23'), isFalse);
      expect(VersionUtils.isNewerVersion('2025.01.15', '2025.01.15'), isFalse);
      expect(VersionUtils.isNewerVersion('2025.01.15', '2025.01.15.1'), isTrue);
      expect(VersionUtils.isNewerVersion('2025.01.15.1', '2025.01.15'), isFalse);
    });

    test('ffmpeg tag differences should not falsely trigger update', () {
      // Current is build tag, latest is base version
      expect(VersionUtils.isNewerVersion('6.0-full_build', '6.0'), isFalse);
      expect(VersionUtils.isNewerVersion('6.0-full_build-www.gyan.dev', '6.0'), isFalse);
      // Latest is strictly higher major/minor version
      expect(VersionUtils.isNewerVersion('6.0-full_build', '7.0'), isTrue);
      expect(VersionUtils.isNewerVersion('6.0-full_build', '6.1'), isTrue);
      expect(VersionUtils.isNewerVersion('7.0', '6.0-full_build'), isFalse);
    });

    test('null, empty, and unknown version handling', () {
      expect(VersionUtils.isNewerVersion(null, '1.0.0'), isTrue);
      expect(VersionUtils.isNewerVersion('', '1.0.0'), isTrue);
      expect(VersionUtils.isNewerVersion('Unknown', '1.0.0'), isTrue);
      expect(VersionUtils.isNewerVersion('unknown', '1.0.0'), isTrue);
      expect(VersionUtils.isNewerVersion('1.0.0', null), isFalse);
      expect(VersionUtils.isNewerVersion('1.0.0', ''), isFalse);
    });

    test('different component lengths', () {
      expect(VersionUtils.isNewerVersion('1.0', '1.0.1'), isTrue);
      expect(VersionUtils.isNewerVersion('1.0.1', '1.0'), isFalse);
      expect(VersionUtils.isNewerVersion('1.0', '1.0.0'), isFalse);
    });
  });
}
