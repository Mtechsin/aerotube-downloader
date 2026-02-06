import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide SearchResult;
import '../models/search_video_result.dart';
import 'logging_service.dart';

class SearchService {
  final YoutubeExplode _yt = YoutubeExplode();
  final LoggingService _logger = LoggingService();

  Future<List<SearchVideoResult>> searchVideos(String query) async {
    try {
      _logger.info('Searching videos for: $query', component: 'SearchService');
      final searchList = await _yt.search.search(query);
      
      if (searchList.isEmpty) {
        _logger.warning('No results found for query: $query', component: 'SearchService');
        return [];
      }

      return searchList.map((video) => SearchVideoResult(
        id: video.id.value,
        title: video.title,
        author: video.author,
        thumbnailUrl: video.thumbnails.mediumResUrl,
        duration: video.duration,
        viewCount: video.engagement.viewCount,
        uploadDate: video.uploadDate?.toString(),
      )).toList();
    } catch (e, stack) {
      _logger.error('Error searching videos for "$query"', component: 'SearchService', error: e, stackTrace: stack);
      // Return empty list instead of crashing, provider will handle empty state
      return [];
    }
  }

  Future<List<SearchVideoResult>> getTrendingVideos() async {
    try {
      _logger.info('Fetching trending videos', component: 'SearchService');
      
      // Fallback logic for trending
      final searchTerms = ['trending', 'popular videos', 'music', 'gaming'];
      
      for (final term in searchTerms) {
        try {
          final searchList = await _yt.search.search(term, filter: TypeFilters.video);
          if (searchList.isNotEmpty) {
            return searchList.map((video) => SearchVideoResult(
              id: video.id.value,
              title: video.title,
              author: video.author,
              thumbnailUrl: video.thumbnails.mediumResUrl,
              duration: video.duration,
              viewCount: video.engagement.viewCount,
              uploadDate: video.uploadDate?.toString(),
            )).toList();
          }
        } catch (e) {
          _logger.warning('Failed to fetch trending with term "$term": $e', component: 'SearchService');
          continue; // Try next term
        }
      }
      
      return [];
    } catch (e, stack) {
      _logger.error('Critical error in getTrendingVideos', component: 'SearchService', error: e, stackTrace: stack);
      return [];
    }
  }

  void dispose() {
    _yt.close();
  }
}
