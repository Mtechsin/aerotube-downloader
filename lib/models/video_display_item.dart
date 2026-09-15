/// Common interface for models representing a video or playable item
/// with display properties (title, duration, thumbnail, author/channel, url).
abstract mixin class VideoDisplayItem {
  String get id;
  String get title;
  String? get thumbnailUrl;
  String get author;
  String get channel;
  String get url;
  int? get durationSeconds;
  String? get formattedDuration;
  int? get viewCount;
  String? get uploadDate;

  /// Helper to format duration in seconds into HH:MM:SS or MM:SS format.
  static String formatDurationSeconds(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSecs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
  }

  /// Helper to format a [Duration] object into HH:MM:SS or MM:SS format.
  static String formatDuration(Duration duration) {
    return formatDurationSeconds(duration.inSeconds);
  }

  /// Helper to format view count into compact notation (e.g. 1.2M views).
  static String formatViewCount(int count) {
    if (count >= 1000000000) {
      return '${(count / 1000000000).toStringAsFixed(1)}B views';
    }
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M views';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K views';
    }
    return '$count views';
  }
}
