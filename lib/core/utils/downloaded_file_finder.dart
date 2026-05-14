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

  final candidates = await dir
      .list()
      .where((entity) => entity is File)
      .cast<File>()
      .where((file) => _mediaExtensions.any(file.path.toLowerCase().endsWith))
      .toList();

  if (candidates.isEmpty) return null;

  final titleWords = item.title
      .toLowerCase()
      .split(' ')
      .where((word) => word.trim().isNotEmpty)
      .take(4)
      .toList();

  final titleMatches = candidates.where((file) {
    final name = file.uri.pathSegments.last.toLowerCase();
    return titleWords.isEmpty || titleWords.every(name.contains);
  }).toList();

  final pool = titleMatches.isNotEmpty ? titleMatches : candidates;
  pool.sort(
    (a, b) =>
        b.lastModifiedSync().millisecondsSinceEpoch -
        a.lastModifiedSync().millisecondsSinceEpoch,
  );
  return pool.first;
}
