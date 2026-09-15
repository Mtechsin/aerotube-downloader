import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../../core/utils/platform_utils.dart';
import 'logging_service.dart';

/// Path to Windows built-in curl.exe
const _curlExe = r'C:\Windows\System32\curl.exe';

/// Number of parallel connections.
const _numConnections = 8;

/// Shared HttpClient with keep-alive for pure-Dart fallback downloads.
final HttpClient _sharedHttpClient = HttpClient()
  ..connectionTimeout = const Duration(seconds: 30);

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
      '-sI', '-L', '--fail',
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

  if (!PlatformUtils.isWindows || !_curlExists()) {
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
  // Unique parts dir per download to avoid collisions when same dest is queued concurrently (B15)
  final rand = Random().nextInt(0xFFFFFF).toString().padLeft(6, '0');
  final partsDir = Directory('${destPath}_parts_${DateTime.now().microsecondsSinceEpoch}_$rand');
  await partsDir.create(recursive: true);

  final chunkFiles = <File>[];
  final procs = <Process>[];
  Timer? poller;

  try {
    // Launch all download processes
    for (int i = 0; i < _numConnections; i++) {
      final start = i * chunkSize;
      final end = (i == _numConnections - 1) ? fileSize - 1 : start + chunkSize - 1;
      final chunkFile = File('${partsDir.path}${Platform.pathSeparator}part_$i');
      chunkFiles.add(chunkFile);

      final proc = await Process.start(_curlExe, [
        '-L', '-s', '--fail',
        '--retry', '3',
        '--retry-delay', '1',
        '--connect-timeout', '30',
        '--max-time', '600',
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
    poller = Timer.periodic(const Duration(milliseconds: 200), (_) {
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
    poller = null;

    if (killed || isCancelled?.call() == true) {
      throw Exception('Cancelled');
    }

    for (int i = 0; i < codes.length; i++) {
      if (codes[i] != 0) {
        throw Exception('Chunk $i failed (exit ${codes[i]})');
      }
    }

    // Merge chunks - B6 fix: keep progress monotonic (>=0.99)
    onProgress?.call(0.99);
    final mergedFile = File(destPath);
    final sink = mergedFile.openWrite();
    for (final chunk in chunkFiles) {
      await sink.addStream(chunk.openRead());
    }
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
    // B3: await curl exit before deleting parts dir (Windows file lock)
    try { await Future.wait(procs.map((p) => p.exitCode)).timeout(const Duration(seconds: 5)); } catch (_) {}
    try { await File(destPath).delete(); } catch (e) { LoggingService().debug('Failed to delete incomplete file: $e', component: 'DownloadHelper'); }
    rethrow;
  } finally {
    poller?.cancel();
    // Ensure all curl processes are terminated before attempting dir delete
    for (final p in procs) { try { p.kill(); } catch (_) {} }
    try { await Future.wait(procs.map((p) => p.exitCode)).timeout(const Duration(seconds: 5)); } catch (_) {}
    // Retry with delay for Windows file-lock race (B3)
    for (int i = 0; i < 3; i++) {
      try {
        if (await partsDir.exists()) await partsDir.delete(recursive: true);
        break;
      } catch (e) {
        LoggingService().debug('Failed to delete temp parts directory (attempt ${i+1}): $e', component: 'DownloadHelper');
        if (i < 2) await Future.delayed(const Duration(milliseconds: 400));
      }
    }
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

  final useCurl = PlatformUtils.isWindows && _curlExists();

  if (useCurl) {
    final proc = await Process.start(_curlExe, [
      '-L', '--fail',
      '--retry', '3',
      '--connect-timeout', '30',
      '--max-time', '600',
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

  // Pure Dart fallback (non-Windows or no curl) - with timeout/watchdog (B4) and safe sink handling (B12)
  IOSink? sink;
  bool success = false;
  try {
    final req = await _sharedHttpClient.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 30));
    final resp = await req.close().timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }

    final total = resp.contentLength;
    int downloaded = 0;
    sink = File(destPath).openWrite();

    // Apply per-chunk timeout to avoid hanging forever on stalled transfer (B4)
    await for (final chunk in resp.timeout(const Duration(seconds: 60))) {
      sink.add(chunk);
      downloaded += chunk.length;
      if (total > 0) onProgress?.call((downloaded / total).clamp(0.0, 1.0));
      if (isCancelled?.call() == true) {
        throw Exception('Cancelled');
      }
    }

    await sink.flush();
    await sink.close();
    sink = null;
    success = true;
    onProgress?.call(1.0);
    return destPath;
  } catch (e) {
    // Ensure truncated file is not left behind (B12)
    if (e.toString().contains('Cancelled')) rethrow;
    rethrow;
  } finally {
    if (sink != null) {
      try { await sink.close(); } catch (_) {}
    }
    if (!success) {
      try { await File(destPath).delete(); } catch (e) { LoggingService().debug('Failed to delete truncated file: $e', component: 'DownloadHelper'); }
    }
  }
}
