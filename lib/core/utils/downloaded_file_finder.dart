import 'dart:io';

import '../../models/download_item.dart';

const _mediaExtensions = {
  '.mp4',
  '.mkv',
  '.webm',
  '.m4a',
  '.mp3',
  '.opus',
  '.aac',
  '.ogg',
  '.wav',
  '.flac',
};

Future<File?> findDownloadedFile(DownloadItem item) async {
  final dir = Directory(item.outputPath);
  if (!await dir.exists()) return null;

  final List<File> candidates = [];
  try {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && _mediaExtensions.any(entity.path.toLowerCase().endsWith)) {
        candidates.add(entity);
        if (candidates.length >= 500) break;
      }
    }
  } catch (e) {
    // ignore list errors
  }

  if (candidates.isEmpty) return null;

  final idMatches = candidates.where((file) {
    final filename = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : '';
    return filename.contains(item.id);
  }).toList();

  final List<File> pool;
  if (idMatches.isNotEmpty) {
    pool = idMatches;
  } else {
    final titleWords = item.title
        .toLowerCase()
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .take(4)
        .toList();

    final titleMatches = candidates.where((file) {
      final name = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last.toLowerCase()
          : '';
      return titleWords.isEmpty || titleWords.every(name.contains);
    }).toList();

    pool = titleMatches.isNotEmpty ? titleMatches : candidates;
  }

  // PF4 fix: avoid lastModifiedSync O(n log n) sync I/O; cache async modified times once
  final modTimes = <File, DateTime>{};
  await Future.wait(pool.map((f) async {
    try {
      modTimes[f] = await f.lastModified();
    } catch (_) {
      try {
        modTimes[f] = (await f.stat()).modified;
      } catch (_) {
        modTimes[f] = DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
  }));
  pool.sort(
    (a, b) => modTimes[b]!.millisecondsSinceEpoch.compareTo(
      modTimes[a]!.millisecondsSinceEpoch,
    ),
  );
  return pool.first;
}
