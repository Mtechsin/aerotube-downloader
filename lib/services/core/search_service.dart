import 'dart:async';

import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    hide SearchResult;
import '../../models/search_video_result.dart';
import 'logging_service.dart';

class SearchService {
  final YoutubeExplode _yt = YoutubeExplode();
  final LoggingService _logger = LoggingService();
  VideoSearchList? _currentSearchPage;

  // Simple in-memory cache for VPN / repeated queries
  final Map<String, List<SearchVideoResult>> _cache = {};
  final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const int _maxCacheEntries = 30;

  bool _isVpnError(Object e) {
    final m = e.toString().toLowerCase();
    return m.contains('timeout') ||
        m.contains('timed out') ||
        m.contains('socket') ||
        m.contains('connection') ||
        m.contains('network is unreachable') ||
        m.contains('failed host lookup');
  }

  Future<List<SearchVideoResult>> searchVideos(String query) async {
    final trimmed = query.trim();
    // Cache hit
    final cached = _cache[trimmed];
    if (cached != null) {
      final t = _cacheTime[trimmed];
      if (t != null && DateTime.now().difference(t) < _cacheExpiry) {
        _logger.debug('Search cache hit for "$trimmed"', component: 'SearchService');
        // still need to set _currentSearchPage? return cached copy; nextPage not valid
        return List<SearchVideoResult>.from(cached);
      } else {
        _cache.remove(trimmed);
        _cacheTime.remove(trimmed);
      }
    }

    // Retry with timeout (VPN often adds 100-300ms + packet loss)
    const timeout = Duration(seconds: 10);
    const maxAttempts = 3;
    Object? lastError;
    StackTrace? lastStack;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _logger.info('Searching videos for: $trimmed (attempt $attempt)', component: 'SearchService');
        final searchList = await _yt.search.search(trimmed).timeout(timeout);
        _currentSearchPage = searchList;

        if (searchList.isEmpty) {
          _logger.warning('No results found for query: $trimmed', component: 'SearchService');
          return [];
        }

        final mapped = _mapVideos(searchList);
        // cache
        if (_cache.length >= _maxCacheEntries) {
          final oldest = _cacheTime.entries.reduce((a, b) => a.value.isBefore(b.value) ? a : b).key;
          _cache.remove(oldest);
          _cacheTime.remove(oldest);
        }
        _cache[trimmed] = mapped;
        _cacheTime[trimmed] = DateTime.now();
        return mapped;
      } on TimeoutException catch (e, stack) {
        lastError = e;
        lastStack = stack;
        _logger.warning('Search timeout for "$trimmed" attempt $attempt/ $maxAttempts: $e', component: 'SearchService');
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 400 * attempt));
          continue;
        }
      } catch (e, stack) {
        lastError = e;
        lastStack = stack;
        if (_isVpnError(e) && attempt < maxAttempts) {
          _logger.warning('Search VPN/network error for "$trimmed" attempt $attempt: $e', component: 'SearchService');
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }
        _logger.error('Error searching videos for "$trimmed"', component: 'SearchService', error: e, stackTrace: stack);
        break;
      }
    }

    _logger.error('Search failed after $maxAttempts attempts for "$trimmed"', component: 'SearchService', error: lastError, stackTrace: lastStack);
    // Return cached stale if available, else empty
    if (cached != null) return List<SearchVideoResult>.from(cached);
    return [];
  }

  Future<List<SearchVideoResult>> loadMoreVideos() async {
    const timeout = Duration(seconds: 10);
    const maxAttempts = 2;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final nextPage = await _currentSearchPage?.nextPage().timeout(timeout);
        if (nextPage == null) return [];
        _currentSearchPage = nextPage;
        return _mapVideos(nextPage);
      } on TimeoutException catch (e) {
        _logger.warning('loadMore timeout attempt $attempt/$maxAttempts: $e', component: 'SearchService');
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
          continue;
        }
        return [];
      } catch (e, stack) {
        if (_isVpnError(e) && attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 400 * attempt));
          continue;
        }
        _logger.error('Error loading more search videos', component: 'SearchService', error: e, stackTrace: stack);
        return [];
      }
    }
    return [];
  }

  Future<List<SearchVideoResult>> getTrendingVideos() async {
    const perTermTimeout = Duration(seconds: 10);
    try {
      _logger.info('Fetching trending videos', component: 'SearchService');

      final searchTerms = ['trending', 'popular videos', 'music', 'gaming'];

      for (final term in searchTerms) {
        for (int attempt = 1; attempt <= 2; attempt++) {
          try {
            final searchList = await _yt.search.search(term, filter: TypeFilters.video).timeout(perTermTimeout);
            if (searchList.isNotEmpty) {
              return _mapVideos(searchList);
            }
            break; // empty, try next term
          } on TimeoutException catch (e) {
            _logger.warning('Trending timeout term "$term" attempt $attempt: $e', component: 'SearchService');
            if (attempt < 2) await Future.delayed(Duration(milliseconds: 300 * attempt));
            continue;
          } catch (e) {
            _logger.warning('Failed to fetch trending with term "$term" attempt $attempt: $e', component: 'SearchService');
            if (_isVpnError(e) && attempt < 2) {
              await Future.delayed(Duration(milliseconds: 400));
              continue;
            }
            break;
          }
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

  List<SearchVideoResult> _mapVideos(Iterable<Video> videos) {
    return videos
        .map(
          (video) => SearchVideoResult(
            id: video.id.value,
            title: video.title,
            author: video.author,
            thumbnailUrl: video.thumbnails.mediumResUrl,
            duration: video.duration,
            viewCount: video.engagement.viewCount,
            uploadDate: video.uploadDate?.toString(),
          ),
        )
        .toList();
  }
}
