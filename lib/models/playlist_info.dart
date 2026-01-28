class PlaylistInfo {
  final String id;
  final String title;
  final String uploader;
  final String? description;
  final int videoCount;
  final List<PlaylistVideoItem> videos;

  PlaylistInfo({
    this.id = '',
    required this.title,
    this.uploader = '',
    this.description,
    this.videoCount = 0,
    this.videos = const [],
  });
  
  int get selectedCount => videos.where((v) => v.isSelected).length;

  factory PlaylistInfo.fromJson(Map<String, dynamic> json) {
    return PlaylistInfo(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Playlist',
      uploader: json['uploader'] ?? json['uploader_id'] ?? '',
      description: json['description'],
      videoCount: json['entries'] != null ? (json['entries'] as List).length : 0,
      videos: [], // Populated separately normally
    );
  }
}

class PlaylistVideoItem {
  final String id;
  final String title;
  final String channel;
  final int duration;
  final String? thumbnailUrl;
  final String url;
  final int? viewCount;
  final String? uploadDate;
  
  bool isSelected = true; // Default to selected

  PlaylistVideoItem({
    required this.id,
    required this.title,
    this.channel = '',
    this.duration = 0,
    this.thumbnailUrl,
    required this.url,
    this.viewCount,
    this.uploadDate,
    this.isSelected = true,
  });
  
  String get uploader => channel;

  factory PlaylistVideoItem.fromJson(Map<String, dynamic> json) {
    return PlaylistVideoItem(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      channel: json['uploader'] ?? json['channel'] ?? '',
      duration: json['duration'] is num 
          ? (json['duration'] as num).toInt() 
          : (double.tryParse(json['duration']?.toString() ?? '0')?.toInt() ?? 0),
      thumbnailUrl: json['thumbnails'] != null && (json['thumbnails'] as List).isNotEmpty
          ? (json['thumbnails'] as List).last['url']
          : json['thumbnail'],
      url: json['url'] ?? json['webpage_url'] ?? 'https://youtube.com/watch?v=${json['id']}',
      viewCount: json['view_count'],
      uploadDate: json['upload_date'],
    );
  }

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
