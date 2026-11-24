import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Contract test for pause/resume partial-file detection.
///
/// yt-dlp writes .part/.ytdl under `--paths temp:<cache>/aerotube_temp`.
/// Legacy partials may still sit in the public output dir.
/// `_hasPartialFiles` must treat EITHER location as resumable so resume
/// never falsely reports "Partial file was cleaned — restarts from 0%".
///
/// Mirrors `MobileDownloadProvider._directoryHasPartialFiles` matching rules.
bool directoryHasPartialFiles(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return false;
  for (final entity in dir.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = p.basename(entity.path).toLowerCase();
    if (name.endsWith('.part') ||
        name.endsWith('.ytdl') ||
        name.endsWith('.temp') ||
        name.contains('.part-') ||
        name.contains('frag')) {
      return true;
    }
  }
  return false;
}

bool hasPartialFiles(String outputDir, String? tempDir) {
  if (directoryHasPartialFiles(outputDir)) return true;
  if (tempDir != null && tempDir != outputDir) {
    if (directoryHasPartialFiles(tempDir)) return true;
  }
  return false;
}

void main() {
  late Directory root;
  late Directory outputDir;
  late Directory tempDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('resume_partial_test_');
    outputDir = Directory(p.join(root.path, 'Download', 'AeroTube'));
    tempDir = Directory(p.join(root.path, 'cache', 'aerotube_temp'));
    await outputDir.create(recursive: true);
    await tempDir.create(recursive: true);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('output-dir only partial counts as resumable', () async {
    await File(p.join(outputDir.path, 'video.mp4.part')).writeAsString('x');
    expect(hasPartialFiles(outputDir.path, tempDir.path), isTrue);
  });

  test('temp-dir only partial counts as resumable (current --paths temp path)',
      () async {
    // This is the regression the review flagged: partials live in cache,
    // not the public Downloads folder.
    await File(p.join(tempDir.path, 'video.mp4.part')).writeAsString('x');
    expect(hasPartialFiles(outputDir.path, tempDir.path), isTrue);
  });

  test('ytdl / frag / temp extensions in temp dir count', () async {
    await File(p.join(tempDir.path, 'video.mp4.ytdl')).writeAsString('x');
    expect(hasPartialFiles(outputDir.path, tempDir.path), isTrue);

    await File(p.join(tempDir.path, 'video.frag1')).writeAsString('x');
    expect(hasPartialFiles(outputDir.path, tempDir.path), isTrue);
  });

  test('both empty → not resumable (true wipe)', () async {
    expect(hasPartialFiles(outputDir.path, tempDir.path), isFalse);
  });

  test('missing temp dir does not throw and falls back to output scan', () async {
    await File(p.join(outputDir.path, 'a.part')).writeAsString('x');
    expect(
      hasPartialFiles(outputDir.path, p.join(root.path, 'missing_temp')),
      isTrue,
    );
    expect(
      hasPartialFiles(p.join(root.path, 'missing_out'), p.join(root.path, 'missing_temp')),
      isFalse,
    );
  });

  test('completed media without partials is not resumable', () async {
    await File(p.join(outputDir.path, 'done.mp4')).writeAsString('x');
    await File(p.join(tempDir.path, 'done.mp4')).writeAsString('x');
    expect(hasPartialFiles(outputDir.path, tempDir.path), isFalse);
  });
}
