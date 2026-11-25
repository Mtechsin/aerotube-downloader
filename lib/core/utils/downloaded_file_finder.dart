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

/// Download ids are `videoId_microseconds_counter`. The saved name only
/// contains `[videoId]`, so matching the full id never hits.
String? videoIdForFileMatch(DownloadItem item) {
  final parsed = Uri.tryParse(item.url);
  final queryId = parsed?.queryParameters['v'];
  if (queryId != null && queryId.isNotEmpty) return queryId;
  if (parsed != null && parsed.host.contains('youtu.be')) {
    final fromPath = parsed.pathSegments.isNotEmpty ? parsed.pathSegments.first : '';
    if (fromPath.isNotEmpty) return fromPath;
  }
  final match = RegExp(r'^(.*)_(\d+)_(\d+)$').firstMatch(item.id);
  final fromId = match?.group(1);
  if (fromId != null && fromId.isNotEmpty) return fromId;
  return item.id;
}

/// yt-dlp `--windows-filenames` replaces NTFS-forbidden characters with `_`.
String filenameToken(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
}

Future<File?> findDownloadedFile(DownloadItem item) async {
  final dir = Directory(item.outputPath);
  if (!await dir.exists()) return null;

  final videoId = videoIdForFileMatch(item);
  final idToken = videoId == null ? '' : filenameToken(videoId);
  final titleWords = item.title
      .split(' ')
      .where((word) => word.trim().isNotEmpty)
      .take(4)
      .map(filenameToken)
      .where((word) => word.isNotEmpty)
      .toList();

  final List<File> idMatches = [];
  final List<File> titleMatches = [];

  try {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path.toLowerCase();
      if (!_mediaExtensions.any(path.endsWith)) continue;

      final filename = entity.uri.pathSegments.isNotEmpty
          ? filenameToken(entity.uri.pathSegments.last)
          : filenameToken(entity.path);

      final idHit = idToken.isNotEmpty &&
          (filename.contains('[$idToken]') || filename.contains(idToken));
      if (idHit) {
        idMatches.add(entity);
        continue;
      }
      if (titleWords.isNotEmpty && titleWords.every(filename.contains)) {
        titleMatches.add(entity);
      }
    }
  } catch (e) {
    // ignore list errors
  }

  if (idMatches.isNotEmpty) return _newest(idMatches);
  if (titleMatches.isNotEmpty) return _newest(titleMatches);
  // An unmatched file is not this download, even when it is the only
  // media file in the folder.
  return null;
}

Future<File> _newest(List<File> files) async {
  if (files.length == 1) return files.first;
  final modTimes = <File, DateTime>{};
  await Future.wait(files.map((f) async {
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
  files.sort(
    (a, b) => modTimes[b]!.millisecondsSinceEpoch.compareTo(
      modTimes[a]!.millisecondsSinceEpoch,
    ),
  );
  return files.first;
}
