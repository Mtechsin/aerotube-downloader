import 'package:flutter/foundation.dart';
import '../models/playlist_info.dart';
import '../models/video_info.dart';
import '../services/ytdlp_service.dart';
import 'download_provider.dart';
import '../models/download_mode.dart';

class PlaylistProvider extends ChangeNotifier {
  final YtdlpService _ytdlpService;

  PlaylistProvider({required YtdlpService ytdlpService}) : _ytdlpService = ytdlpService;

  bool _isLoading = false;
  String? _error;
  PlaylistInfo? _playlist;
  String? _loadingStatus; 

  // Selection state
  final Set<String> _selectedIds = {};

  // Batch settings (Video)
  String _selectedFormatId = 'best'; 
  bool _audioOnly = false;
  AudioQuality _audioQuality = AudioQuality.high; // Default to High
  
  String? _currentUrl; // Track current URL

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  PlaylistInfo? get playlist => _playlist;
  String? get loadingStatus => _loadingStatus;
  String? get currentUrl => _currentUrl;
  Set<String> get selectedIds => _selectedIds;
  int get selectedCount => _selectedIds.length;
  bool get isAllSelected => _playlist != null && _selectedIds.length == _playlist!.videos.length;
  
  String get selectedFormatId => _selectedFormatId;
  bool get audioOnly => _audioOnly;
  AudioQuality get audioQuality => _audioQuality;

  // Actions

  Future<void> fetchPlaylist(String url) async {
    if (url.isEmpty) return;
    
    _isLoading = true;
    _error = null;
    _playlist = null;
    _currentUrl = url;
    _selectedIds.clear();
    _loadingStatus = 'Initializing...';
    notifyListeners();

    try {
      final info = await _ytdlpService.getPlaylistInfo(url, onProgress: (status) {
        _loadingStatus = status;
        notifyListeners();
      });

      _playlist = info;
      _selectedIds.addAll(info.videos.map((v) => v.id));
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _loadingStatus = null;
      notifyListeners();
    }
  }

  void toggleSelection(String videoId) {
    if (_selectedIds.contains(videoId)) {
      _selectedIds.remove(videoId);
    } else {
      _selectedIds.add(videoId);
    }
    notifyListeners();
  }

  void setSelection(String videoId, bool selected) {
    if (selected) {
      _selectedIds.add(videoId);
    } else {
      _selectedIds.remove(videoId);
    }
    notifyListeners();
  }

  void selectAll() {
    if (_playlist == null) return;
    _selectedIds.addAll(_playlist!.videos.map((v) => v.id));
    notifyListeners();
  }

  void deselectAll() {
    _selectedIds.clear();
    notifyListeners();
  }

  void toggleSelectAll() {
    if (_playlist == null) return;
    
    if (isAllSelected) {
      deselectAll();
    } else {
      selectAll();
    }
  }

  /// Release all playlist data from memory
  void clear() {
    _playlist = null;
    _selectedIds.clear();
    _error = null;
    _currentUrl = null;
    _loadingStatus = null;
    notifyListeners();
  }

  void updateBatchSettings({String? formatId, bool? audioOnly, AudioQuality? audioQuality}) {
    if (formatId != null) _selectedFormatId = formatId;
    if (audioOnly != null) _audioOnly = audioOnly;
    if (audioQuality != null) _audioQuality = audioQuality;
    notifyListeners();
  }

  void downloadSelected(DownloadProvider downloadProvider, String outputPath) {
    if (_playlist == null || _selectedIds.isEmpty) return;

    final videosToDownload = _playlist!.videos.where((v) => _selectedIds.contains(v.id)).toList();

    for (final video in videosToDownload) {
      downloadProvider.startDownload(
        video: _createMinimalVideoInfo(video),
        outputPath: outputPath, 
        mode: _audioOnly ? DownloadMode.audioOnly : DownloadMode.videoWithAudio,
        targetHeight: _parseTargetHeight(_selectedFormatId),
        audioQuality: _audioQuality.ytdlpValue,
      );
    }
    // Optionally deselect or notify user via callback
  }

  VideoInfo _createMinimalVideoInfo(PlaylistVideoItem item) {
    return VideoInfo(
      id: item.id,
      title: item.title,
      channel: item.channel,
      channelUrl: '', // Not available in flat playlist
      thumbnailUrl: item.thumbnailUrl ?? '',
      duration: item.duration,
      description: '', // Not available
      viewCount: item.viewCount ?? 0,
      uploadDate: item.uploadDate ?? '',
      formats: [], // Not available
      url: item.url,
      subtitles: [],
    );
  }

  int? _parseTargetHeight(String formatId) {
    if (formatId == 'best') return null;
    return int.tryParse(formatId);
  }
}
