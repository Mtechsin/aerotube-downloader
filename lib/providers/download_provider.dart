import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/ytdlp_service.dart';
import '../models/video_info.dart';
import '../models/download_item.dart';
import '../models/download_mode.dart';

class DownloadProvider extends ChangeNotifier {
  final YtdlpService _ytdlpService;
  
  // Active downloads (in memory only while active)
  final List<DownloadItem> _activeDownloads = [];
  
  // History downloads (persisted)
  List<DownloadItem> _historyDownloads = [];
  
  final Map<String, Process> _activeProcesses = {};
  
  late Box<DownloadItem> _downloadsBox;
  bool _isInit = false;

  DownloadProvider(this._ytdlpService) {
    _initHive();
  }

  Future<void> _initHive() async {
    _downloadsBox = await Hive.openBox<DownloadItem>('downloads_history');
    _loadHistory();
    _isInit = true;
    notifyListeners();
  }
  
  void _loadHistory() {
    _historyDownloads = _downloadsBox.values.toList()
      ..sort((a, b) => (b.completedDate ?? DateTime.now()).compareTo(a.completedDate ?? DateTime.now()));
    notifyListeners();
  }

  List<DownloadItem> get activeDownloads => List.unmodifiable(_activeDownloads);
  List<DownloadItem> get historyDownloads => List.unmodifiable(_historyDownloads);
  
  // Backwards compatibility getter if needed, or migration getter
  List<DownloadItem> get downloads => [..._activeDownloads, ..._historyDownloads];
  
  int get activeCount => _activeDownloads.length;
  int get activeRunningCount => _activeDownloads.where((i) => 
      i.status == DownloadStatus.downloadingVideo || 
      i.status == DownloadStatus.downloadingAudio || 
      i.status == DownloadStatus.merging).length;
  
  int get pendingCount => _activeDownloads.where((i) => 
      i.status == DownloadStatus.pending || 
      i.status == DownloadStatus.queued).length;

  int get pausedCount => 0; // Placeholder until pause is implemented

  int get completedCount => _historyDownloads.length; // Approximate, assuming history is completed/failed

  Future<void> startDownload({
    required VideoInfo video,
    required String outputPath,
    required DownloadMode mode,
    String? formatId,
    String? audioFormatId,
    int? targetHeight,
    String? audioQuality,
    bool embedThumbnail = true,
    bool embedMetadata = true,
  }) async {
    final item = DownloadItem(
      id: video.id,
      title: video.title,
      thumbnailUrl: video.thumbnailUrl,
      url: video.url,
      outputPath: outputPath, 
      status: DownloadStatus.pending,
      audioOnly: mode == DownloadMode.audioOnly,
      formatId: formatId,
      audioFormatId: audioFormatId,
      videoQuality: targetHeight != null ? '${targetHeight}p' : null,
    );

    _activeDownloads.add(item);
    notifyListeners();

    try {
      final templatePath = '$outputPath\\%(title)s.%(ext)s';

      final process = await _ytdlpService.downloadVideo(
        url: video.url,
        outputPath: templatePath,
        formatId: formatId,
        audioFormatId: audioFormatId,
        targetHeight: targetHeight,
        audioOnly: mode == DownloadMode.audioOnly,
        audioQuality: audioQuality,
        embedThumbnail: embedThumbnail,
        embedMetadata: embedMetadata,
      );

      _activeProcesses[item.id] = process;
      
      // Update status
      final index = _activeDownloads.indexOf(item);
      if (index != -1) {
        _activeDownloads[index] = item.copyWith(status: DownloadStatus.downloadingVideo);
        notifyListeners();
      }

      // Handle Output
      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        final lines = data.split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          
          final progress = YtdlpService.parseProgress(line);
          if (progress != null) {
            final idx = _activeDownloads.indexWhere((d) => d.id == item.id);
            if (idx != -1) {
              _activeDownloads[idx] = _activeDownloads[idx].copyWith(
                progress: progress.progress,
                speed: progress.speed,
                eta: progress.eta,
                status: progress.status ?? _activeDownloads[idx].status,
              );
              notifyListeners();
            }
          }
        }
      });

      final stderrBuffer = StringBuffer();
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        stderrBuffer.write(data);
        // Print stderr in real-time for debugging
        if (data.trim().isNotEmpty) {
          print('[yt-dlp stderr] ${data.trim()}');
        }
      });

      final exitCode = await process.exitCode;
      _activeProcesses.remove(item.id);

      final idx = _activeDownloads.indexWhere((d) => d.id == item.id);
      if (idx != -1) {
        DownloadItem finalItem = _activeDownloads[idx];
        
        if (exitCode == 0) {
          finalItem = finalItem.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
            eta: 0,
            completedDate: DateTime.now(),
            // We could parse file size from logs but for now let's leave it null or try to find file
          );
          
          // Move to history
          _activeDownloads.removeAt(idx);
          _addToHistory(finalItem);
          
        } else {
           if (finalItem.status != DownloadStatus.cancelled) {
             final errorMsg = stderrBuffer.toString().trim();
             finalItem = finalItem.copyWith(
               status: DownloadStatus.failed, 
               error: errorMsg.isNotEmpty ? errorMsg : 'Process exited with code $exitCode'
             );
             // Move to history even if failed? Or keep in active to retry? 
             // User requested separate tabs. Failed usually implies functionality stops.
             // Let's keep in active if failed to allow retry? Or move to history as failed.
             // Prompt says: "History/Finished Tab ... ListView of persisted Hive items (completed, failed, cancelled)"
             _activeDownloads.removeAt(idx);
             _addToHistory(finalItem);
           } else {
             _activeDownloads.removeAt(idx);
              finalItem = finalItem.copyWith(completedDate: DateTime.now());
             _addToHistory(finalItem);
           }
        }
        notifyListeners();
      }

    } catch (e) {
      print('Download error: $e');
      final idx = _activeDownloads.indexWhere((d) => d.id == item.id);
      if (idx != -1) {
         final finalItem = _activeDownloads[idx].copyWith(
           status: DownloadStatus.failed, 
           error: e.toString(),
           completedDate: DateTime.now()
         );
         _activeDownloads.removeAt(idx);
         _addToHistory(finalItem);
      }
      _activeProcesses.remove(item.id);
      notifyListeners();
    }
  }

  void cancelDownload(String id) {
    if (_activeProcesses.containsKey(id)) {
      _activeProcesses[id]?.kill();
      _activeProcesses.remove(id);
    }
    
    final index = _activeDownloads.indexWhere((d) => d.id == id);
    if (index != -1) {
        // Optimistic update
      _activeDownloads[index] = _activeDownloads[index].copyWith(status: DownloadStatus.cancelled);
      notifyListeners();
    }
  }
  
  Future<void> _addToHistory(DownloadItem item) async {
    if (!_isInit) await _initHive();
    await _downloadsBox.put(item.id, item);
    _loadHistory();
  }

  Future<void> deleteFromHistory(String id) async {
    if (!_isInit) return;
    await _downloadsBox.delete(id);
    _loadHistory();
  }

  Future<void> clearHistory() async {
     if (!_isInit) return;
     await _downloadsBox.clear();
     _loadHistory();
  }

  Future<void> clearCompleted() async {
    if (!_isInit) return;
    
    final keysToDelete = _historyDownloads
        .where((item) => item.status == DownloadStatus.completed)
        .map((item) => item.id)
        .toList();

    await _downloadsBox.deleteAll(keysToDelete);
    _loadHistory();
  }

  void retryDownload(String id) {
     // TODO: Implement retry logic by retrieving video info again
     // For now, we accept we can't fully retry without VideoInfo, 
     // unless we store VideoInfo json in DownloadItem.
  }
}
