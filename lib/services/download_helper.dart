import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'logging_service.dart';

/// Path to Windows built-in curl.exe
const _curlExe = r'C:\Windows\System32\curl.exe';

/// Number of parallel connections.
const _numConnections = 8;

/// Check if curl.exe exists (fast filesystem check, no process spawn).
bool _curlExists() {
  try {
    return File(_curlExe).existsSync();
  } catch (e) {
    LoggingService().debug('curl.exe check failed: $e', component: 'DownloadHelper');
    return false;
  }
}

/// Get file size and check range support in a single HEAD request.
/// Returns file size if ranges are supported, -1 otherwise.
Future<int> _getFileSizeIfRangesOk(String url) async {
  try {
    final r = await Process.run(_curlExe, [
      '-sI', '-L',
      '--max-time', '10',
      '--max-redirs', '10',
      url,
    ]).timeout(const Duration(seconds: 15));

    if (r.exitCode != 0) return -1;

    final output = (r.stdout as String).toLowerCase();
    if (!output.contains('accept-ranges: bytes')) return -1;

    // Find the LAST content-length (after all redirects)
    int size = -1;
    for (final line in (r.stdout as String).split('\n')) {
      if (line.toLowerCase().startsWith('content-length:')) {
        final val = int.tryParse(line.split(':').last.trim());
        if (val != null && val > 0) size = val;
      }
    }
    return size;
  } catch (e) {
    LoggingService().debug('Failed to get file size/range support: $e', component: 'DownloadHelper');
    return -1;
  }
}

/// Download [url] → [destPath] at maximum speed.
///
/// Uses 8 parallel curl.exe connections with HTTP Range headers for files
/// that support it. Falls back to a single connection otherwise.
Future<String> downloadInBackground({
  required String url,
  required String destPath,
  void Function(double progress)? onProgress,
  bool Function()? isCancelled,
}) async {
  await File(destPath).parent.create(recursive: true);

  if (!Platform.isWindows || !_curlExists()) {
    return _singleDownload(url: url, destPath: destPath,
      onProgress: onProgress, isCancelled: isCancelled);
  }

  final fileSize = await _getFileSizeIfRangesOk(url);

  if (fileSize > 512 * 1024) {
    // File > 512 KB and supports ranges → multi-connection
    return _multiDownload(
      url: url, destPath: destPath, fileSize: fileSize,
      onProgress: onProgress, isCancelled: isCancelled,
    );
  }

  return _singleDownload(url: url, destPath: destPath,
    onProgress: onProgress, isCancelled: isCancelled);
}

// ── Multi-connection download ───────────────────────────────────────────────

Future<String> _multiDownload({
  required String url,
  required String destPath,
  required int fileSize,
  void Function(double progress)? onProgress,
  bool Function()? isCancelled,
}) async {
  final chunkSize = fileSize ~/ _numConnections;
  final partsDir = Directory('${destPath}_parts');
  await partsDir.create(recursive: true);

  final chunkFiles = <File>[];
  final procs = <Process>[];

  try {
    // Launch all download processes
    for (int i = 0; i < _numConnections; i++) {
      final start = i * chunkSize;
      final end = (i == _numConnections - 1) ? fileSize - 1 : start + chunkSize - 1;
      final chunkFile = File('${partsDir.path}${Platform.pathSeparator}part_$i');
      chunkFiles.add(chunkFile);

      final proc = await Process.start(_curlExe, [
        '-L', '-s',
        '--retry', '3',
        '--retry-delay', '1',
        '--connect-timeout', '30',
        '-r', '$start-$end',
        '-o', chunkFile.path,
        url,
      ]);

      procs.add(proc);
      proc.stdout.drain<void>();
      proc.stderr.drain<void>();
    }

    // Poll for progress + cancellation
    bool killed = false;
    final poller = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (killed) return;
      if (isCancelled?.call() == true) {
        killed = true;
        for (final p in procs) { try { p.kill(); } catch (e) { LoggingService().debug('Failed to kill process: $e', component: 'DownloadHelper'); } }
        return;
      }
      if (onProgress != null) {
        int total = 0;
        for (final f in chunkFiles) {
          try { if (f.existsSync()) total += f.lengthSync(); } catch (e) { LoggingService().debug('Failed to read chunk file size: $e', component: 'DownloadHelper'); }
        }
        onProgress((total / fileSize).clamp(0.0, 0.99));
      }
    });

    // Wait for all chunks
    final codes = await Future.wait(procs.map((p) => p.exitCode));
    poller.cancel();

    if (killed || isCancelled?.call() == true) {
      throw Exception('Cancelled');
    }

    for (int i = 0; i < codes.length; i++) {
      if (codes[i] != 0) {
        throw Exception('Chunk $i failed (exit ${codes[i]})');
      }
    }

    // Merge chunks
    onProgress?.call(0.95);
    final sink = File(destPath).openWrite();
    for (final chunk in chunkFiles) {
      sink.add(await chunk.readAsBytes());
    }
    await sink.flush();
    await sink.close();

    // Verify
    final finalSize = await File(destPath).length();
    if (finalSize != fileSize) {
      throw Exception('Size mismatch: expected $fileSize, got $finalSize');
    }

    onProgress?.call(1.0);
    return destPath;

  } catch (e) {
    for (final p in procs) { try { p.kill(); } catch (e) { LoggingService().debug('Failed to kill process during cleanup: $e', component: 'DownloadHelper'); } }
    try { await File(destPath).delete(); } catch (e) { LoggingService().debug('Failed to delete incomplete file: $e', component: 'DownloadHelper'); }
    rethrow;
  } finally {
    try { await partsDir.delete(recursive: true); } catch (e) { LoggingService().debug('Failed to delete temp parts directory: $e', component: 'DownloadHelper'); }
  }
}

// ── Single-connection fallback ──────────────────────────────────────────────

Future<String> _singleDownload({
  required String url,
  required String destPath,
  void Function(double progress)? onProgress,
  bool Function()? isCancelled,
}) async {
  await File(destPath).parent.create(recursive: true);

  final useCurl = Platform.isWindows && _curlExists();

  if (useCurl) {
    final proc = await Process.start(_curlExe, [
      '-L',
      '--retry', '3',
      '--connect-timeout', '30',
      '-o', destPath,
      url,
    ]);

    proc.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('%') || t.startsWith('D')) return;
      final parts = t.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        final pct = double.tryParse(parts[0]);
        if (pct != null && pct >= 0 && pct <= 100) {
          onProgress?.call(pct / 100.0);
        }
      }
    });
    proc.stdout.drain<void>();

    bool killed = false;
    final cw = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!killed && isCancelled?.call() == true) { killed = true; proc.kill(); }
    });

    final code = await proc.exitCode;
    cw.cancel();

    if (killed || isCancelled?.call() == true) {
      try { await File(destPath).delete(); } catch (e) { LoggingService().debug('Failed to delete file on cancel: $e', component: 'DownloadHelper'); }
      throw Exception('Cancelled');
    }
    if (code != 0) {
      try { await File(destPath).delete(); } catch (e) { LoggingService().debug('Failed to delete failed download: $e', component: 'DownloadHelper'); }
      throw Exception('curl failed (exit $code)');
    }

    onProgress?.call(1.0);
    return destPath;
  }

  // Pure Dart fallback (non-Windows or no curl)
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);
  try {
    final req = await client.getUrl(Uri.parse(url));
    final resp = await req.close();
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }

    final total = resp.contentLength;
    int downloaded = 0;
    final sink = File(destPath).openWrite();

    await for (final chunk in resp) {
      sink.add(chunk);
      downloaded += chunk.length;
      if (total > 0) onProgress?.call((downloaded / total).clamp(0.0, 1.0));
      if (isCancelled?.call() == true) {
        await sink.close();
        try { await File(destPath).delete(); } catch (e) { LoggingService().debug('Failed to delete file on cancel: $e', component: 'DownloadHelper'); }
        throw Exception('Cancelled');
      }
    }

    await sink.flush();
    await sink.close();
    onProgress?.call(1.0);
    return destPath;
  } finally {
    client.close(force: true);
  }
}
