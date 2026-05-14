import 'package:flutter/material.dart';
import '../models/search_video_result.dart';
import '../services/search_service.dart';

class SearchProvider extends ChangeNotifier {
  final SearchService _searchService = SearchService();

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

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;

    _isLoading = true;
    _error = null;
    _lastQuery = query;
    notifyListeners();

    try {
      _searchResults = await _searchService.searchVideos(query);
      _hasMoreResults = _searchResults.isNotEmpty;
    } catch (e) {
      _error = e.toString();
      _hasMoreResults = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMoreResults) return;

    _isLoadingMore = true;
    _error = null;
    notifyListeners();

    try {
      final nextResults = await _searchService.loadMoreVideos();
      if (nextResults.isEmpty) {
        _hasMoreResults = false;
      } else {
        final existingIds = _searchResults.map((video) => video.id).toSet();
        _searchResults.addAll(
          nextResults.where((video) => existingIds.add(video.id)),
        );
      }
    } catch (e) {
      _error = e.toString();
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
      _trendingVideos = await _searchService.getTrendingVideos();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    _lastQuery = '';
    _error = null;
    _hasMoreResults = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchService.dispose();
    super.dispose();
  }
}
