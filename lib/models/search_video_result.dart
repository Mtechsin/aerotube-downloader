class SearchVideoResult {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration? duration;
  final int? viewCount;
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
}
