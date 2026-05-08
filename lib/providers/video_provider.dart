import 'package:flutter/material.dart';
import '../models/video_info.dart';
import '../models/playlist_info.dart';
import '../services/ytdlp_service.dart';
import '../services/ytdlp_service_android.dart';
import '../services/logging_service.dart';

class VideoProvider extends ChangeNotifier {
  final dynamic
  _ytdlpService; // YtdlpService (Windows) or YtdlpServiceAndroid (Android)

  VideoInfo? _videoInfo;
  PlaylistInfo? _playlistInfo;
  bool _isLoading = false;
  String? _errorMessage;
  String _loadingStatus = '';
  String _currentUrl = '';
  final List<String> _fetchLogs = [];
  String? _technicalError;
  bool _requiresYtdlpUpdate = false;

  bool _audioOnly = false;

  // New selection logic
  List<ResolutionOption> _availableResolutions = [];
  ResolutionOption? _selectedResolution;
  // Override specific format selection (e.g. AV1 vs VP9)
  FormatInfo? _selectedVideoFormatOverride;

  // Cache for processed resolutions to avoid redundant computation
  List<ResolutionOption>? _cachedResolutions;
  String? _cachedVideoId;

  // We keep track of the specific audio format we want to merge with
  FormatInfo? _selectedAudioMergeStream;
  String? _bestAudioFormatId; // Kept for reference to "default" best

  AudioQuality _selectedAudioQuality = AudioQuality.high;
  bool _subtitlesEnabled = false;
  bool _embedSubtitles = false;
  final Set<SubtitleTrack> _selectedSubtitles = {};

  VideoProvider(this._ytdlpService) {
    if (!(_ytdlpService is YtdlpService ||
        _ytdlpService is YtdlpServiceAndroid)) {
      throw ArgumentError(
        'VideoProvider requires YtdlpService (Windows) or YtdlpServiceAndroid (Android).',
      );
    }
  }

  VideoInfo? get videoInfo => _videoInfo;
  PlaylistInfo? get playlistInfo => _playlistInfo;
  bool get hasVideo => _videoInfo != null;
  bool get hasPlaylist => _playlistInfo != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get loadingStatus => _loadingStatus;
  bool get hasError => _errorMessage != null;
  String get currentUrl => _currentUrl;
  List<String> get fetchLogs => List.unmodifiable(_fetchLogs);
  String? get technicalError => _technicalError;
  bool get requiresYtdlpUpdate => _requiresYtdlpUpdate;

  bool get audioOnly => _audioOnly;

  ResolutionOption? get selectedResolution => _selectedResolution;
  List<ResolutionOption> get availableResolutions => _availableResolutions;

  AudioQuality get selectedAudioQuality => _selectedAudioQuality;
  bool get subtitlesEnabled => _subtitlesEnabled;
  bool get embedSubtitles => _embedSubtitles;
  Set<SubtitleTrack> get selectedSubtitles => _selectedSubtitles;

  // Getters for YtDlpService consumption
  FormatInfo? get selectedVideoFormat =>
      _selectedVideoFormatOverride ?? _selectedResolution?.formatInfo;
  String? get selectedVideoFormatId => selectedVideoFormat?.formatId;
  String? get selectedAudioFormatId =>
      _audioOnly ? _bestAudioFormatId : _selectedAudioMergeStream?.formatId;
  int? get selectedHeight => _selectedResolution?.height;

  FormatInfo? get selectedAudioMergeStream => _selectedAudioMergeStream;

  int get totalEstimatedDownloadSize {
    if (_audioOnly) {
      // If audio only, we rely on the generic selected format logic for now,
      // but typically we'd look at the selected audio stream.
      // For now returning 0 or implementing if we track specific audio selection in audio-only mode.
      // Current implementation for audio-only relies on 'quality tier' finding a format at download time.
      // Better to estimate based on "best for quality".
      if (_videoInfo == null) return 0;
      final format = _videoInfo!.getBestAudioForQuality(_selectedAudioQuality);
      return format?.filesize ?? 0;
    }

    int size = 0;

    // Video part
    if (_selectedVideoFormatOverride != null) {
      size += _selectedVideoFormatOverride!.filesize ?? 0;
    } else if (_selectedResolution != null &&
        _selectedResolution!.formatInfo.filesize != null) {
      size += _selectedResolution!.formatInfo.filesize!;
    }

    // Audio part (if not already merged)
    final videoFormat =
        _selectedVideoFormatOverride ?? _selectedResolution?.formatInfo;
    bool videoHasAudio = videoFormat?.hasAudio ?? false;

    if (!videoHasAudio && _selectedAudioMergeStream != null) {
      size += _selectedAudioMergeStream!.filesize ?? 0;
    }

    return size;
  }

  Future<void> fetchVideoInfo(String url) async {
    LoggingService().debug(
      'Starting for url: $url',
      component: 'VideoProvider',
    );
    _isLoading = true;
    _errorMessage = null;
    _technicalError = null;
    _requiresYtdlpUpdate = false;
    _currentUrl = url;
    _availableResolutions = []; // Clear previous
    _selectedVideoFormatOverride = null;
    _subtitlesEnabled = false;
    _embedSubtitles = false;
    _selectedSubtitles.clear();
    _loadingStatus = 'Initializing...';
    _resetFetchLogs();
    _appendFetchLog('Starting fetch request');
    _appendFetchLog('URL accepted');
    notifyListeners();

    try {
      LoggingService().debug(
        'Calling _ytdlpService.getVideoInfo',
        component: 'VideoProvider',
      );
      _videoInfo = await _ytdlpService.getVideoInfo(
        url,
        onProgress: (status) {
          _loadingStatus = status;
          _appendFetchLog(status);
          notifyListeners();
        },
      );
      LoggingService().debug(
        'Got video info: ${_videoInfo?.title}',
        component: 'VideoProvider',
      );
      _appendFetchLog('Video metadata received');
      _playlistInfo = null;

      if (_videoInfo != null) {
        _loadingStatus = 'Processing formats...';
        _appendFetchLog('Processing formats...');
        notifyListeners();
        _processFormats();
        _appendFetchLog(
          'Found ${_videoInfo!.formats.length} available stream formats',
        );
      }
    } catch (e) {
      LoggingService().error(
        'Error: $e',
        component: 'VideoProvider',
        error: e,
      );
      final rawError = e.toString();
      final cleanedError = _cleanErrorMessage(rawError);
      _technicalError = cleanedError;
      _requiresYtdlpUpdate = _shouldSuggestYtdlpUpdate(cleanedError);

      if (_requiresYtdlpUpdate) {
        _errorMessage =
            'yt-dlp seems outdated for this video. Please update yt-dlp from Settings and try again.';
      } else {
        _errorMessage = cleanedError;
      }
      _appendFetchLog('Fetch failed: $cleanedError');
      _videoInfo = null;
    } finally {
      _isLoading = false;
      _loadingStatus = '';
      notifyListeners();
    }
  }

  /// The Core Logic: Separate streams, group by resolution, find best bitrate
  void _processFormats() {
    if (_videoInfo == null) return;

    // Return cached if same video
    if (_cachedResolutions != null && _cachedVideoId == _videoInfo!.id) {
      _availableResolutions = _cachedResolutions!;
      if (_availableResolutions.isNotEmpty) {
        _selectedResolution = _availableResolutions.firstWhere(
          (r) => r.height == 1080,
          orElse: () => _availableResolutions.first,
        );
      }
      return;
    }

    final video = _videoInfo!;

    // 1. Find Best Audio Stream
    // Usually the one with highest bitrate/sampling rate.
    // We'll use this single audio stream to calculate total size for all video resolutions.
    final bestAudio = video.audioOnlyFormats.isNotEmpty
        ? video
              .audioOnlyFormats
              .first // audioOnlyFormats is already sorted by quality in model
        : null;

    _bestAudioFormatId = bestAudio?.formatId;
    _selectedAudioMergeStream = bestAudio; // Default to best audio
    final int audioSize = bestAudio?.filesize ?? 0;

    // 2. Group Video Streams by Resolution
    final Map<int, List<FormatInfo>> formatsByRes = {};

    // Check separate video streams first
    if (video.videoOnlyFormats.isNotEmpty) {
      for (var f in video.videoOnlyFormats) {
        if (f.height == null) continue;
        formatsByRes.putIfAbsent(f.height!, () => []).add(f);
      }
    } else {
      // Fallback to combined formats if no separate streams
      for (var f in video.combinedFormats) {
        if (f.height == null) continue;
        formatsByRes.putIfAbsent(f.height!, () => []).add(f);
      }
    }

    // 3. Create Resolution Options
    final List<ResolutionOption> options = [];

    formatsByRes.forEach((height, formats) {
      // Sort formats by bitrate (descending) to find the "Default" best one
      formats.sort(
        (a, b) => (b.videoBitrate ?? 0).compareTo(a.videoBitrate ?? 0),
      );

      final bestFormat = formats.first;

      int estimatedSize = (bestFormat.filesize ?? 0);
      bool isEstimate = bestFormat.filesize == null;
      bool isMerged = bestFormat.hasAudio && bestFormat.hasVideo;

      // Add audio size if we are going to merge (and it's not already merged)
      if (!isMerged && bestAudio != null) {
        estimatedSize += audioSize;
        if (bestAudio.filesize == null) isEstimate = true;
      }

      options.add(
        ResolutionOption(
          height: height,
          label: _getQualityLabel(height),
          videoFormatId: bestFormat.formatId,
          totalSize: estimatedSize,
          isApproximateSize: isEstimate,
          formatInfo: bestFormat,
          formats: formats, // Store all variants
          isMerged: isMerged,
        ),
      );
    });

    // Sort: 4K -> 1080p -> 720p
    options.sort((a, b) => b.height.compareTo(a.height));

    _availableResolutions = options;
    _cachedResolutions = options;
    _cachedVideoId = video.id;

    // Default Selection: 1080p or highest available
    if (options.isNotEmpty) {
      _selectedResolution = options.firstWhere(
        (r) => r.height == 1080,
        orElse: () => options.first,
      );
      _selectedVideoFormatOverride = null; // Reset specific override
    }
  }

  String _getQualityLabel(int height) {
    if (height >= 2160) return '4K';
    if (height >= 1440) return '2K';
    if (height >= 1080) return '1080p';
    if (height >= 720) return '720p';
    if (height >= 480) return '480p';
    return '${height}p';
  }

  Future<void> fetchPlaylistInfo(String url) async {
    _isLoading = true;
    _errorMessage = null;
    _technicalError = null;
    _requiresYtdlpUpdate = false;
    _currentUrl = url;
    _resetFetchLogs();
    _appendFetchLog('Starting playlist fetch');
    _subtitlesEnabled = false;
    _embedSubtitles = false;
    _selectedSubtitles.clear();
    notifyListeners();

    try {
      _playlistInfo = await _ytdlpService.getPlaylistInfo(
        url,
        onProgress: (status) {
          _loadingStatus = status;
          _appendFetchLog(status);
          notifyListeners();
        },
      );
      _videoInfo = null;
      _appendFetchLog(
        'Playlist loaded (${_playlistInfo?.videoCount ?? 0} videos)',
      );
    } catch (e) {
      final rawError = e.toString();
      final cleanedError = _cleanErrorMessage(rawError);
      _technicalError = cleanedError;
      _requiresYtdlpUpdate = _shouldSuggestYtdlpUpdate(cleanedError);
      _errorMessage = _requiresYtdlpUpdate
          ? 'yt-dlp may be outdated. Please update it from Settings and try again.'
          : cleanedError;
      _appendFetchLog('Playlist fetch failed: $cleanedError');
      _playlistInfo = null;
    } finally {
      _isLoading = false;
      _loadingStatus = '';
      notifyListeners();
    }
  }

  void clear() {
    _videoInfo = null;
    _playlistInfo = null;
    _currentUrl = '';
    _loadingStatus = '';
    _errorMessage = null;
    _technicalError = null;
    _requiresYtdlpUpdate = false;
    _fetchLogs.clear();
    _subtitlesEnabled = false;
    _embedSubtitles = false;
    _selectedSubtitles.clear();
    _availableResolutions = [];
    _selectedResolution = null;
    _selectedVideoFormatOverride = null;
    _cachedResolutions = null;
    _cachedVideoId = null;
    notifyListeners();
  }

  void _resetFetchLogs() {
    _fetchLogs.clear();
  }

  void _appendFetchLog(String message) {
    final normalized = message.trim();
    if (normalized.isEmpty) return;

    final timestamp = DateTime.now();
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    final entry = '[$hh:$mm:$ss] $normalized';

    if (_fetchLogs.isNotEmpty && _fetchLogs.last == entry) return;
    _fetchLogs.add(entry);
    if (_fetchLogs.length > 30) {
      _fetchLogs.removeRange(0, _fetchLogs.length - 30);
    }
  }

  String _cleanErrorMessage(String raw) {
    return raw
        .replaceFirst('YtdlpException:', '')
        .replaceFirst('YtdlpAndroidException:', '')
        .trim();
  }

  bool _shouldSuggestYtdlpUpdate(String errorMessage) {
    final lower = errorMessage.toLowerCase();
    final hintByText =
        lower.contains('outdated') ||
        lower.contains('update yt-dlp') ||
        lower.contains('signature') ||
        lower.contains('unable to extract') ||
        lower.contains('decipher') ||
        lower.contains('extraction failed');

    if (hintByText) return true;

    try {
      final service = _ytdlpService;
      if (service is YtdlpService) {
        return service.isBrokenError(errorMessage);
      }
      if (service is YtdlpServiceAndroid) {
        return service.isBrokenError(errorMessage);
      }
    } catch (_) {
      // no-op: safe fallback to text matching above
    }
    return false;
  }

  void setAudioOnly(bool value) {
    _audioOnly = value;
    notifyListeners();
  }

  void selectResolution(ResolutionOption resolution) {
    _selectedResolution = resolution;
    _selectedVideoFormatOverride =
        null; // Reset specific override when changing resolution
    notifyListeners();
  }

  void setSelectedVideoFormat(FormatInfo format) {
    _selectedVideoFormatOverride = format;
    // We should also theoretically update selectedResolution if the height mismatch?
    // But UI usually only shows formats for current resolution.
    // However, if we did, we would find the matching ResolutionOption.
    // For now, assume format belongs to current resolution.

    notifyListeners();
  }

  void setSelectedHeight(int height) {
    final option = _availableResolutions.firstWhere(
      (r) => r.height == height,
      orElse: () => _availableResolutions.first,
    );
    selectResolution(option);
  }

  void setSelectedAudioMergeStream(FormatInfo format) {
    _selectedAudioMergeStream = format;
    notifyListeners();
  }

  void setAudioQuality(AudioQuality quality) {
    _selectedAudioQuality = quality;
    notifyListeners();
  }

  void setSubtitlesEnabled(
    bool value, {
    String preferredLanguageCode = 'auto',
  }) {
    _subtitlesEnabled = value;

    if (!value) {
      _selectedSubtitles.clear();
      _embedSubtitles = false;
      notifyListeners();
      return;
    }

    if (_videoInfo == null || _videoInfo!.subtitles.isEmpty) {
      _selectedSubtitles.clear();
      _embedSubtitles = false;
      notifyListeners();
      return;
    }

    if (_selectedSubtitles.isEmpty) {
      final defaultTrack = _findPreferredSubtitleTrack(
        _videoInfo!.subtitles,
        preferredLanguageCode,
      );
      if (defaultTrack != null) {
        _selectedSubtitles.add(defaultTrack);
      }
    }

    notifyListeners();
  }

  SubtitleTrack? _findPreferredSubtitleTrack(
    List<SubtitleTrack> tracks,
    String preferredLanguageCode,
  ) {
    if (tracks.isEmpty) return null;
    if (preferredLanguageCode.isEmpty || preferredLanguageCode == 'auto') {
      return tracks.first;
    }

    final normalized = preferredLanguageCode.toLowerCase();

    for (final track in tracks) {
      if (track.languageCode.toLowerCase() == normalized) {
        return track;
      }
    }

    for (final track in tracks) {
      final trackCode = track.languageCode.toLowerCase();
      if (trackCode == normalized ||
          trackCode.startsWith('$normalized-') ||
          trackCode.startsWith('${normalized}_') ||
          trackCode.startsWith(normalized)) {
        return track;
      }
    }

    return tracks.first;
  }

  void setEmbedSubtitles(bool value) {
    if (value && _selectedSubtitles.isEmpty) {
      _embedSubtitles = false;
    } else {
      _embedSubtitles = value;
      if (value) {
        _subtitlesEnabled = true;
      }
    }
    notifyListeners();
  }

  void toggleSubtitle(SubtitleTrack subtitle) {
    if (_selectedSubtitles.contains(subtitle)) {
      _selectedSubtitles.remove(subtitle);
    } else {
      _selectedSubtitles.add(subtitle);
      _subtitlesEnabled = true;
    }

    if (_selectedSubtitles.isEmpty) {
      _embedSubtitles = false;
    }

    notifyListeners();
  }

  void selectAllVideos(bool select) {
    if (_playlistInfo == null) return;
    for (var video in _playlistInfo!.videos) {
      video.isSelected = select;
    }
    notifyListeners();
  }

  void toggleVideoSelection(int index) {
    if (_playlistInfo == null) return;
    if (index >= 0 && index < _playlistInfo!.videos.length) {
      final video = _playlistInfo!.videos[index];
      video.isSelected = !video.isSelected;
      notifyListeners();
    }
  }
}

class ResolutionOption {
  final int height;
  final String label;
  final String videoFormatId;
  final int totalSize;
  final bool isApproximateSize;
  final FormatInfo formatInfo; // The default/best format for this resolution
  final List<FormatInfo> formats; // All formats for this resolution
  final bool isMerged;

  ResolutionOption({
    required this.height,
    required this.label,
    required this.videoFormatId,
    required this.totalSize,
    required this.isApproximateSize,
    required this.formatInfo,
    required this.formats,
    this.isMerged = false,
  });

  String get formattedSize {
    if (totalSize == 0) return 'Unknown';

    String sizeStr;
    if (totalSize < 1024) {
      sizeStr = '$totalSize B';
    } else if (totalSize < 1024 * 1024) {
      sizeStr = '${(totalSize / 1024).toStringAsFixed(1)} KB';
    } else if (totalSize < 1024 * 1024 * 1024) {
      sizeStr = '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      sizeStr = '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }

    return isApproximateSize ? '~$sizeStr' : sizeStr;
  }
}
