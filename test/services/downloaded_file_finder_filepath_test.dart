import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/utils/downloaded_file_finder.dart';
import 'package:youtube_downloader/models/download_item.dart';

/// Contract tests for download completion file resolution.
///
/// MobileDownloadProvider._completeDownload prefers the exact `filepath`
/// reported by the native completed event (after_move) and only falls back
/// to [findDownloadedFile] when that path is missing or the file is gone.
/// The provider itself is too heavy to construct in a pure unit test (Hive,
/// method channels, storage service), so this file covers:
/// 1. the public finder fallback, and
/// 2. the exact-path-wins preference contract via a local mirror of the
///    provider's resolution order.
///
/// See mobile_download_provider.dart around the completed-event handler.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('filepath_finder_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  DownloadItem makeItem({
    required String id,
    required String title,
    String? outputPath,
  }) {
    return DownloadItem(
      id: id,
      title: title,
      url: 'https://youtube.com/watch?v=$id',
      outputPath: outputPath ?? tempDir.path,
    );
  }

  Future<File> writeMedia(String name, {Duration? age}) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsString('fake-media');
    if (age != null) {
      final when = DateTime.now().subtract(age);
      await file.setLastModified(when);
    }
    return file;
  }

  group('findDownloadedFile (mtime-scan fallback)', () {
    test('returns null when the output directory does not exist', () async {
      final item = makeItem(
        id: 'abc123',
        title: 'Missing Dir',
        outputPath: '${tempDir.path}${Platform.pathSeparator}does_not_exist',
      );
      expect(await findDownloadedFile(item), isNull);
    });

    test('returns null when the directory has no media files', () async {
      await File('${tempDir.path}${Platform.pathSeparator}readme.txt')
          .writeAsString('not media');
      final item = makeItem(id: 'abc123', title: 'No Media');
      expect(await findDownloadedFile(item), isNull);
    });

    test('matches by download id embedded in the filename', () async {
      await writeMedia('other-video.mp4', age: const Duration(hours: 2));
      final target = await writeMedia(
        'clip-abc123-final.mp4',
        age: const Duration(hours: 1),
      );
      final item = makeItem(id: 'abc123', title: 'Some Title');

      final found = await findDownloadedFile(item);
      expect(found, isNotNull);
      expect(found!.path, target.path);
    });

    test('falls back to title words when no id match exists', () async {
      await writeMedia('unrelated.mp4', age: const Duration(hours: 1));
      final target = await writeMedia(
        'My Cool Video 1080p.mp4',
        age: const Duration(hours: 2),
      );
      final item = makeItem(id: 'xyz999', title: 'My Cool Video');

      final found = await findDownloadedFile(item);
      expect(found, isNotNull);
      expect(found!.path, target.path);
    });

    test('prefers the newest mtime among id matches', () async {
      await writeMedia('abc123-old.mkv', age: const Duration(hours: 3));
      final newer = await writeMedia(
        'abc123-new.mkv',
        age: const Duration(minutes: 1),
      );
      final item = makeItem(id: 'abc123', title: 'Race');

      final found = await findDownloadedFile(item);
      expect(found, isNotNull);
      expect(found!.path, newer.path);
    });

    test('ignores non-media extensions even if they match the id', () async {
      final media = await writeMedia(
        'abc123-video.mp4',
        age: const Duration(hours: 1),
      );
      await File('${tempDir.path}${Platform.pathSeparator}abc123-info.json')
          .writeAsString('{"id":"abc123"}');
      final item = makeItem(id: 'abc123', title: 'Media Only');

      final found = await findDownloadedFile(item);
      expect(found, isNotNull);
      expect(found!.path, media.path);
      expect(found.path.endsWith('.json'), isFalse);
    });
  });

  group('completed-event filepath preference contract', () {
    // Mirrors MobileDownloadProvider._completeDownload resolution order:
    // exact native filepath wins when the file exists; otherwise fall back
    // to the mtime-scan finder. Kept local so the provider stays free of
    // test-only extraction.
    Future<File?> resolveCompletedFile({
      required String? filepath,
      required DownloadItem item,
    }) async {
      if (filepath != null && filepath.isNotEmpty) {
        final exact = File(filepath);
        if (await exact.exists()) {
          return exact;
        }
      }
      return findDownloadedFile(item);
    }

    test('known exact path wins over the mtime-scanned candidate', () async {
      final scannedNewest = await writeMedia(
        'abc123-newest.mp4',
        age: const Duration(minutes: 1),
      );
      final exactAfterMove = await writeMedia(
        'exact-after-move.mp4',
        age: const Duration(hours: 5),
      );
      final item = makeItem(id: 'abc123', title: 'Exact Wins');

      final resolved = await resolveCompletedFile(
        filepath: exactAfterMove.path,
        item: item,
      );

      expect(resolved, isNotNull);
      expect(resolved!.path, exactAfterMove.path);
      expect(resolved.path, isNot(scannedNewest.path));
    });

    test('missing exact path falls back to the finder', () async {
      final scanned = await writeMedia(
        'abc123-fallback.mp4',
        age: const Duration(minutes: 2),
      );
      final item = makeItem(id: 'abc123', title: 'Fallback');

      final resolved = await resolveCompletedFile(
        filepath: '${tempDir.path}${Platform.pathSeparator}ghost.mp4',
        item: item,
      );

      expect(resolved, isNotNull);
      expect(resolved!.path, scanned.path);
    });

    test('null filepath falls back to the finder', () async {
      final scanned = await writeMedia(
        'abc123-null-path.mp4',
        age: const Duration(minutes: 3),
      );
      final item = makeItem(id: 'abc123', title: 'Null Path');

      final resolved = await resolveCompletedFile(
        filepath: null,
        item: item,
      );

      expect(resolved, isNotNull);
      expect(resolved!.path, scanned.path);
    });

    test('empty filepath falls back to the finder', () async {
      final scanned = await writeMedia(
        'abc123-empty-path.webm',
        age: const Duration(minutes: 4),
      );
      final item = makeItem(id: 'abc123', title: 'Empty Path');

      final resolved = await resolveCompletedFile(
        filepath: '',
        item: item,
      );

      expect(resolved, isNotNull);
      expect(resolved!.path, scanned.path);
    });

    test('exact path missing and finder finds nothing → null (fail path)',
        () async {
      final emptyDir = await Directory.systemTemp.createTemp('empty_out_');
      addTearDown(() async {
        if (await emptyDir.exists()) {
          await emptyDir.delete(recursive: true);
        }
      });
      final item = DownloadItem(
        id: 'nope',
        title: 'Nothing',
        url: 'https://youtube.com/watch?v=nope',
        outputPath: emptyDir.path,
      );

      final resolved = await resolveCompletedFile(
        filepath: '${emptyDir.path}${Platform.pathSeparator}gone.mp4',
        item: item,
      );
      expect(resolved, isNull);
    });
  });
}
