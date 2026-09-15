import 'dart:async';
import 'package:flutter/material.dart';
import '../models/search_video_result.dart';
import '../services/core/search_service.dart';
import '../services/core/logging_service.dart';
import '../core/utils/error_helper.dart';

class SearchProvider extends ChangeNotifier {
  final SearchService _searchService = SearchService();
  Timer? _debounceTimer;

  List<SearchVideoResult> _searchResults = [];
  List<SearchVideoResult> _trendingVideos = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String _lastQuery = '';
  bool _hasMoreResults = false;

  List<SearchVideoResult> get searchResults => _searchResults;
  List<SearchVideoResult> get trendingVideos => _trendingVideos;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  String get lastQuery => _lastQuery;
  bool get hasMoreResults => _hasMoreResults;

  int _searchGen = 0;

  bool _isVpnError(String m) {
    final l = m.toLowerCase();
    return l.contains('timed out') || l.contains('timeout') || l.contains('vpn') || l.contains('socket') || l.contains('connection');
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;

    _debounceTimer?.cancel();
    final trimmed = query.trim();
    // debounce with cancellation support
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final myGen = ++_searchGen;
      _isLoading = true;
      _error = null;
      _lastQuery = trimmed;
      notifyListeners();

      try {
        // Wrap with 12s timeout to not hang indefinitely behind VPN
        final results = await _searchService.searchVideos(trimmed).timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw TimeoutException('Search timed out - VPN may be slowing connection, try again or disable VPN'),
        );
        if (myGen != _searchGen) return; // cancelled by newer search
        _searchResults = results;
        _hasMoreResults = results.isNotEmpty;
        if (results.isEmpty && _searchGen == myGen) {
          // keep empty but no error; service already logs
        }
      } catch (e, stackTrace) {
        if (myGen != _searchGen) return;
        LoggingService().error(
          'Search failed for query "$trimmed": $e',
          component: 'SearchProvider',
          error: e,
          stackTrace: stackTrace,
        );
        var cleaned = ErrorHelper.clean(e.toString());
        if (e is TimeoutException || _isVpnError(cleaned)) {
          if (!cleaned.toLowerCase().contains('vpn')) {
            cleaned = 'Search timed out - VPN may be slowing connection, try again or disable VPN. ($cleaned)';
          }
        }
        _error = cleaned;
        _hasMoreResults = false;
      } finally {
        if (myGen == _searchGen) {
          _isLoading = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMoreResults) return;

    _isLoadingMore = true;
    _error = null;
    notifyListeners();

    try {
      final nextResults = await _searchService.loadMoreVideos().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('Load more timed out - VPN may be slowing connection'),
      );
      if (nextResults.isEmpty) {
        _hasMoreResults = false;
      } else {
        final existingIds = _searchResults.map((video) => video.id).toSet();
        _searchResults.addAll(
          nextResults.where((video) => existingIds.add(video.id)),
        );
        const maxSearchResults = 200;
        if (_searchResults.length > maxSearchResults) {
          _searchResults = _searchResults.sublist(0, maxSearchResults);
          _hasMoreResults = false;
        }
      }
    } catch (e, stackTrace) {
      LoggingService().error(
        'Load more search results failed: $e',
        component: 'SearchProvider',
        error: e,
        stackTrace: stackTrace,
      );
      var cleaned = ErrorHelper.clean(e.toString());
      if (e is TimeoutException || _isVpnError(cleaned)) {
        cleaned = 'Load more timed out - VPN may be slowing connection. ($cleaned)';
      }
      _error = cleaned;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> fetchTrending() async {
    if (_trendingVideos.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _trendingVideos = await _searchService.getTrendingVideos().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Trending fetch timed out - VPN may be slowing connection'),
      );
    } catch (e, stackTrace) {
      LoggingService().error(
        'Fetch trending videos failed: $e',
        component: 'SearchProvider',
        error: e,
        stackTrace: stackTrace,
      );
      var cleaned = ErrorHelper.clean(e.toString());
      if (e is TimeoutException || _isVpnError(cleaned)) {
        cleaned = 'Trending fetch timed out - VPN may be slowing connection. ($cleaned)';
      }
      _error = cleaned;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    _searchResults = [];
    _lastQuery = '';
    _error = null;
    _hasMoreResults = false;
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _searchService.dispose();
    super.dispose();
  }
}
