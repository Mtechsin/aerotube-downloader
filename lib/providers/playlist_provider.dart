import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/playlist_info.dart';
import '../models/video_info.dart';
import '../services/ytdlp/ytdlp_service_windows.dart';
import '../services/ytdlp/ytdlp_service_android.dart';
import '../services/core/logging_service.dart';
import '../core/utils/error_helper.dart';
import 'download_provider.dart';
import '../models/download_mode.dart';

class PlaylistProvider extends ChangeNotifier {
  final dynamic
  _ytdlpService; // YtdlpService (Windows) or YtdlpServiceAndroid (Android)

  PlaylistProvider({required dynamic ytdlpService})
    : _ytdlpService = ytdlpService {
    if (!(_ytdlpService is YtdlpService ||
        _ytdlpService is YtdlpServiceAndroid)) {
      throw ArgumentError(
        'PlaylistProvider requires YtdlpService (Windows) or YtdlpServiceAndroid (Android).',
      );
    }
  }

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
  bool get isAllSelected =>
      _playlist != null && _selectedIds.length == _playlist!.videos.length;

  String get selectedFormatId => _selectedFormatId;
  bool get audioOnly => _audioOnly;
  AudioQuality get audioQuality => _audioQuality;

  // VPN/clunkiness guards
  int _fetchGen = 0;
  DateTime _lastStatus = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _throttle = Duration(milliseconds: 250);

  void _throttledStatus(String s) {
    _loadingStatus = s;
    final now = DateTime.now();
    if (now.difference(_lastStatus) >= _throttle) {
      _lastStatus = now;
      notifyListeners();
    }
  }

  bool _isVpnError(String m) {
    final l = m.toLowerCase();
    return l.contains('timed out') || l.contains('timeout') || l.contains('vpn') || l.contains('unable to download');
  }

  /// Cancel in-flight playlist fetch (Windows & Android).
  Future<void> cancelFetch() async {
    if (!_isLoading) return;
    _fetchGen++;
    _isLoading = false;
    _loadingStatus = null;
    try {
      // ignore: avoid_dynamic_calls
      await _ytdlpService.cancelFetch();
    } catch (_) {}
    LoggingService().info('Playlist fetch cancelled by user', component: 'PlaylistProvider');
    notifyListeners();
  }

  // Actions

  Future<void> fetchPlaylist(String url) async {
    if (url.isEmpty) return;
    if (_isLoading) _fetchGen++;
    final myGen = ++_fetchGen;

    _isLoading = true;
    _error = null;
    _playlist = null;
    _currentUrl = url;
    _selectedIds.clear();
    _loadingStatus = 'Initializing...';
    notifyListeners();
    _lastStatus = DateTime.now();

    try {
      final future = _ytdlpService.getPlaylistInfo(
        url,
        onProgress: (status) {
          if (myGen != _fetchGen) return;
          _throttledStatus(status);
        },
      ) as Future<PlaylistInfo>;
      final info = await future.timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw TimeoutException(
          'Fetch timed out - VPN may be slowing connection, try again or disable VPN',
          Duration(seconds: 90),
        ),
      );
      if (myGen != _fetchGen) return;

      _playlist = info;
      _selectedIds.addAll(info.videos.map((v) => v.id));
    } catch (e, stackTrace) {
      if (myGen != _fetchGen) return;
      LoggingService().error(
        'Playlist fetch failed for $url: $e',
        component: 'PlaylistProvider',
        error: e,
        stackTrace: stackTrace,
      );
      var cleaned = ErrorHelper.clean(e.toString());
      if (e is TimeoutException || _isVpnError(cleaned)) {
        if (!cleaned.toLowerCase().contains('vpn')) {
          cleaned = 'Fetch timed out - VPN may be slowing connection, try again or disable VPN. ($cleaned)';
        }
      }
      _error = cleaned;
    } finally {
      if (myGen == _fetchGen) {
        _isLoading = false;
        _loadingStatus = null;
        notifyListeners();
      }
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

  void updateBatchSettings({
    String? formatId,
    bool? audioOnly,
    AudioQuality? audioQuality,
  }) {
    if (formatId != null) _selectedFormatId = formatId;
    if (audioOnly != null) _audioOnly = audioOnly;
    if (audioQuality != null) _audioQuality = audioQuality;
    notifyListeners();
  }

  Future<void> downloadSelected(
    DownloadProvider downloadProvider,
    String outputPath,
  ) async {
    if (_playlist == null || _selectedIds.isEmpty) return;

    final videosToDownload = _playlist!.videos
        .where((v) => _selectedIds.contains(v.id))
        .toList();
    if (videosToDownload.isEmpty) return;

    // PF10 fix: single Hive write + single notify via batched API.
    final videoInfos = videosToDownload
        .map(_createMinimalVideoInfo)
        .toList(growable: false);

    await downloadProvider.startDownloadsBatch(
      videos: videoInfos,
      outputPath: outputPath,
      mode: _audioOnly ? DownloadMode.audioOnly : DownloadMode.videoWithAudio,
      targetHeight: _parseTargetHeight(_selectedFormatId),
      audioQuality: _audioQuality.ytdlpValue,
    );
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
    super.dispose();
  }
}
