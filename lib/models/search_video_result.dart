import 'video_display_item.dart';

class SearchVideoResult with VideoDisplayItem {
  @override
  final String id;
  @override
  final String title;
  @override
  final String author;
  @override
  final String thumbnailUrl;
  final Duration? duration;
  @override
  final int? viewCount;
  @override
  final String? uploadDate;

  SearchVideoResult({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.duration,
    this.viewCount,
    this.uploadDate,
  });

  String get videoUrl => 'https://www.youtube.com/watch?v=$id';

  @override
  String get url => videoUrl;

  @override
  String get channel => author;

  @override
  int? get durationSeconds => duration?.inSeconds;

  @override
  String? get formattedDuration =>
      duration != null ? VideoDisplayItem.formatDuration(duration!) : null;
}
