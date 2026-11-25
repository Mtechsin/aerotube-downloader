import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/utils/downloaded_file_finder.dart';
import 'package:youtube_downloader/models/download_item.dart';

/// Unit tests for the pure-ish filesystem helper used when a download
/// completes and the provider must locate the output file.
///
/// Scope note: MobileDownloadProvider itself is heavy (Hive, method channels,
/// foreground service). These tests isolate [findDownloadedFile] against a
/// real temp directory instead.
///
/// Contract under test:
/// - returns null when the output directory does not exist
/// - only considers media extensions
/// - prefers a filename that contains the download id (no mtime race)
/// - falls back to title-word matching when no id match
/// - picks the newest file when multiple candidates remain
void main() {
  late Directory tempDir;

  DownloadItem item({
    String id = 'dl-123',
    String title = 'Sample Video Title',
    String? outputPath,
  }) {
    return DownloadItem(
      id: id,
      title: title,
      url: 'https://example.com/v',
      outputPath: outputPath ?? tempDir.path,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finder_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> writeMedia(
    String name, {
    DateTime? modified,
    int bytes = 16,
  }) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(List<int>.filled(bytes, 1));
    if (modified != null) {
      await file.setLastModified(modified);
    }
    return file;
  }

  test('returns null when output directory does not exist', () async {
    final missing = item(outputPath: '${tempDir.path}${Platform.pathSeparator}nope');
    expect(await findDownloadedFile(missing), isNull);
  });

  test('returns null when directory has no media files', () async {
    await File('${tempDir.path}${Platform.pathSeparator}readme.txt')
        .writeAsString('not media');
    expect(await findDownloadedFile(item()), isNull);
  });

  test('does not attach the only media file when its name does not match', () async {
    await writeMedia('clip.mp4');
    expect(await findDownloadedFile(item()), isNull);
  });

  test('prefers filename containing the download id over newer unrelated file',
      () async {
    // id match is older
    final idMatch = await writeMedia(
      'video_dl-123.mp4',
      modified: DateTime.now().subtract(const Duration(hours: 2)),
    );
    // unrelated media is newer
    await writeMedia(
      'other.mp4',
      modified: DateTime.now(),
    );

    final found = await findDownloadedFile(item(id: 'dl-123'));
    expect(found, isNotNull);
    expect(found!.path, idMatch.path);
  });

  test('falls back to title words when no filename contains the id', () async {
    final titleMatch = await writeMedia(
      'sample video title.webm',
      modified: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    await writeMedia(
      'unrelated clip.mkv',
      modified: DateTime.now(),
    );

    final found = await findDownloadedFile(
      item(id: 'no-such-id', title: 'Sample Video Title'),
    );
    expect(found, isNotNull);
    expect(found!.path, titleMatch.path);
  });

  test('does not guess among several files when id and title both miss', () async {
    await writeMedia(
      'aaa.mp4',
      modified: DateTime.now().subtract(const Duration(hours: 3)),
    );
    await writeMedia(
      'zzz.mp4',
      modified: DateTime.now(),
    );

    final found = await findDownloadedFile(
      item(id: 'zzz-not-in-name', title: 'Completely Different Words'),
    );
    expect(found, isNull);
  });

  test('matches [videoId] when the download id has a timestamp suffix', () async {
    final match = await writeMedia('Talk [dQw4w9wgxcq].mp4');
    await writeMedia('Other [abcdefghijk].mp4');

    final found = await findDownloadedFile(
      item(
        id: 'dQw4w9wgxcq_1710000000000000_3',
        title: 'Something Else',
        outputPath: tempDir.path,
      ),
    );
    expect(found, isNotNull);
    expect(found!.path, match.path);
  });

  test('title match survives windows-sanitized characters', () async {
    final match = await writeMedia('axiom _ module_7.mp4');
    await writeMedia('unrelated.mp4');

    final found = await findDownloadedFile(
      item(id: 'no-id-here', title: 'Axiom | Module_7'),
    );
    expect(found, isNotNull);
    expect(found!.path, match.path);
  });

  test('ignores non-media extensions even if newer', () async {
    final media = await writeMedia(
      'song.mp3',
      modified: DateTime.now().subtract(const Duration(hours: 1)),
    );
    await File('${tempDir.path}${Platform.pathSeparator}thumb.jpg')
        .writeAsBytes(List<int>.filled(8, 2));
    await File('${tempDir.path}${Platform.pathSeparator}info.json')
        .writeAsString('{}');

    final found = await findDownloadedFile(item(id: 'nomatch', title: 'song'));
    expect(found, isNotNull);
    expect(found!.path, media.path);
    expect(found.path.endsWith('.mp3'), isTrue);
  });

  test('extension match is case-insensitive', () async {
    final upper = await writeMedia('Movie.MP4');
    final found = await findDownloadedFile(item(id: 'nope', title: 'Movie'));
    expect(found, isNotNull);
    expect(found!.path, upper.path);
  });

  test('supports common audio and video containers', () async {
    const names = [
      'a.mkv',
      'b.webm',
      'c.m4a',
      'd.opus',
      'e.aac',
      'f.ogg',
      'g.wav',
      'h.flac',
    ];
    for (final n in names) {
      await writeMedia('qqq$n');
      final found = await findDownloadedFile(item(id: 'x', title: 'qqq'));
      expect(found, isNotNull, reason: 'should find media for $n');
      // Clean up so only one candidate exists per iteration
      await found!.delete();
    }
  });
}
