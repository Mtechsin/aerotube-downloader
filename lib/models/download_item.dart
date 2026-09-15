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
  queued,
  @HiveField(8)
  paused,
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
  final String? videoQuality; // e.g. "1080p60"

  @HiveField(16)
  final String? thumbnailPath; // Local path if we save it

  @HiveField(17)
  final String? savePath; // Actual final file path

  // Per-download options (for execution, not necessarily persisted)
  @HiveField(18)
  final String? audioQuality;

  @HiveField(19)
  final List<String>? subtitleLanguages;

  @HiveField(20)
  final bool embedSubtitles;

  @HiveField(21)
  final bool sponsorBlock;

  @HiveField(22)
  final bool useDownloadArchive;

  bool thumbnailExists;

  String? statusText;

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
    this.audioQuality,
    this.subtitleLanguages,
    this.embedSubtitles = false,
    this.sponsorBlock = false,
    this.useDownloadArchive = false,
    this.thumbnailExists = false,
    this.statusText,
  });

  String get formattedSpeed {
    if (speed < 1024) return '${speed.toStringAsFixed(1)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    if (speed < 1024 * 1024 * 1024) {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
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

  static const Object _sentinel = Object();

  // Helper copyWith for updates (supports clearing nullable fields by passing null)
  DownloadItem copyWith({
    String? id,
    String? title,
    Object? thumbnailUrl = _sentinel,
    String? url,
    String? outputPath,
    double? progress,
    double? speed,
    int? eta,
    DownloadStatus? status,
    Object? error = _sentinel,
    Object? formatId = _sentinel,
    Object? audioFormatId = _sentinel,
    bool? audioOnly,
    Object? completedDate = _sentinel,
    Object? totalBytes = _sentinel,
    Object? videoQuality = _sentinel,
    Object? thumbnailPath = _sentinel,
    Object? savePath = _sentinel,
    Object? audioQuality = _sentinel,
    Object? subtitleLanguages = _sentinel,
    bool? embedSubtitles,
    bool? sponsorBlock,
    bool? useDownloadArchive,
    bool? thumbnailExists,
    Object? statusText = _sentinel,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      title: title ?? this.title,
      thumbnailUrl: identical(thumbnailUrl, _sentinel)
          ? this.thumbnailUrl
          : (thumbnailUrl as String?),
      url: url ?? this.url,
      outputPath: outputPath ?? this.outputPath,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      status: status ?? this.status,
      error: identical(error, _sentinel) ? this.error : (error as String?),
      formatId: identical(formatId, _sentinel)
          ? this.formatId
          : (formatId as String?),
      audioFormatId: identical(audioFormatId, _sentinel)
          ? this.audioFormatId
          : (audioFormatId as String?),
      audioOnly: audioOnly ?? this.audioOnly,
      completedDate: identical(completedDate, _sentinel)
          ? this.completedDate
          : (completedDate as DateTime?),
      totalBytes: identical(totalBytes, _sentinel)
          ? this.totalBytes
          : (totalBytes as int?),
      videoQuality: identical(videoQuality, _sentinel)
          ? this.videoQuality
          : (videoQuality as String?),
      thumbnailPath: identical(thumbnailPath, _sentinel)
          ? this.thumbnailPath
          : (thumbnailPath as String?),
      savePath: identical(savePath, _sentinel)
          ? this.savePath
          : (savePath as String?),
      audioQuality: identical(audioQuality, _sentinel)
          ? this.audioQuality
          : (audioQuality as String?),
      subtitleLanguages: identical(subtitleLanguages, _sentinel)
          ? this.subtitleLanguages
          : (subtitleLanguages as List<String>?),
      embedSubtitles: embedSubtitles ?? this.embedSubtitles,
      sponsorBlock: sponsorBlock ?? this.sponsorBlock,
      useDownloadArchive: useDownloadArchive ?? this.useDownloadArchive,
      thumbnailExists: thumbnailExists ?? this.thumbnailExists,
      statusText: identical(statusText, _sentinel)
          ? this.statusText
          : (statusText as String?),
    );
  }
}
