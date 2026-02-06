import 'package:flutter/material.dart';
import '../models/search_video_result.dart';
import '../services/search_service.dart';

class SearchProvider extends ChangeNotifier {
  final SearchService _searchService = SearchService();
  
  List<SearchVideoResult> _searchResults = [];
  List<SearchVideoResult> _trendingVideos = [];
  bool _isLoading = false;
  String? _error;
  String _lastQuery = '';

  List<SearchVideoResult> get searchResults => _searchResults;
  List<SearchVideoResult> get trendingVideos => _trendingVideos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get lastQuery => _lastQuery;

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    
    _isLoading = true;
    _error = null;
    _lastQuery = query;
    notifyListeners();

    try {
      _searchResults = await _searchService.searchVideos(query);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
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
    notifyListeners();
  }

  @override
  void dispose() {
    _searchService.dispose();
    super.dispose();
  }
}
