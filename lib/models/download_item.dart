import 'package:hive/hive.dart';

part 'download_item.g.dart';

@HiveType(typeId: 0)
enum DownloadStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  downloadingVideo,
  @HiveField(2)
  downloadingAudio,
  @HiveField(3)
  merging,
  @HiveField(4)
  completed,
  @HiveField(5)
  failed,
  @HiveField(6)
  cancelled,
  @HiveField(7)
  queued
}

@HiveType(typeId: 1)
class DownloadItem {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String? thumbnailUrl;
  
  @HiveField(3)
  final String url;
  
  @HiveField(4)
  final String outputPath;
  
  // Progress tracking
  @HiveField(5)
  double progress;
  
  @HiveField(6)
  double speed; // bytes per second
  
  @HiveField(7)
  int eta; // seconds
  
  @HiveField(8)
  DownloadStatus status;
  
  @HiveField(9)
  String? error;
  
  // Format info
  @HiveField(10)
  final String? formatId;
  
  @HiveField(11)
  final String? audioFormatId;
  
  @HiveField(12)
  final bool audioOnly;

  // New fields for history/stats
  @HiveField(13)
  final DateTime? completedDate;
  
  @HiveField(14)
  final int? totalBytes;
  
  @HiveField(15)
  final String? videoQuality; // e.g., "1080p60"

  @HiveField(16)
  final String? thumbnailPath; // Local path if we save it

  @HiveField(17)
  final String? savePath; // Actual final file path

  DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    required this.outputPath,
    this.thumbnailUrl,
    this.progress = 0.0,
    this.speed = 0.0,
    this.eta = 0,
    this.status = DownloadStatus.pending,
    this.error,
    this.formatId,
    this.audioFormatId,
    this.audioOnly = false,
    this.completedDate,
    this.totalBytes,
    this.videoQuality,
    this.thumbnailPath,
    this.savePath,
  });

  String get formattedSpeed {
    if (speed < 1024) return '${speed.toStringAsFixed(1)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    if (speed < 1024 * 1024 * 1024) return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(speed / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
  }

  String get formattedEta {
    if (eta == 0) return '';
    final h = eta ~/ 3600;
    final m = (eta % 3600) ~/ 60;
    final s = eta % 60;
    
    if (h > 0) {
      return '${h}h ${m}m ${s}s';
    } else if (m > 0) {
      return '${m}m ${s}s';
    } else {
      return '${s}s';
    }
  }

  // Helper copyWith for updates
  DownloadItem copyWith({
    String? id,
    String? title,
    String? thumbnailUrl,
    String? url,
    String? outputPath,
    double? progress,
    double? speed,
    int? eta,
    DownloadStatus? status,
    String? error,
    String? formatId,
    String? audioFormatId,
    bool? audioOnly,
    DateTime? completedDate,
    int? totalBytes,
    String? videoQuality,
    String? thumbnailPath,
    String? savePath,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      url: url ?? this.url,
      outputPath: outputPath ?? this.outputPath,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      status: status ?? this.status,
      error: error ?? this.error,
      formatId: formatId ?? this.formatId,
      audioFormatId: audioFormatId ?? this.audioFormatId,
      audioOnly: audioOnly ?? this.audioOnly,
      completedDate: completedDate ?? this.completedDate,
      totalBytes: totalBytes ?? this.totalBytes,
      videoQuality: videoQuality ?? this.videoQuality,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      savePath: savePath ?? this.savePath,
    );
  }
}
