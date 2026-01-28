import 'package:flutter/material.dart';
import '../models/video_info.dart';
import '../models/playlist_info.dart';
import '../services/ytdlp_service.dart';

class VideoProvider extends ChangeNotifier {
  final YtdlpService _ytdlpService;
  
  VideoInfo? _videoInfo;
  PlaylistInfo? _playlistInfo;
  bool _isLoading = false;
  String? _errorMessage;
  String _loadingStatus = '';
  
  bool _audioOnly = false;
  
  // New selection logic
  List<ResolutionOption> _availableResolutions = [];
  ResolutionOption? _selectedResolution;
  // Override specific format selection (e.g. AV1 vs VP9)
  FormatInfo? _selectedVideoFormatOverride;
  
  // We keep track of the specific audio format we want to merge with
  FormatInfo? _selectedAudioMergeStream;
  String? _bestAudioFormatId; // Kept for reference to "default" best
  
  AudioQuality _selectedAudioQuality = AudioQuality.high;
  bool _embedSubtitles = false;
  final Set<SubtitleTrack> _selectedSubtitles = {};

  VideoProvider(this._ytdlpService);

  VideoInfo? get videoInfo => _videoInfo;
  PlaylistInfo? get playlistInfo => _playlistInfo;
  bool get hasVideo => _videoInfo != null;
  bool get hasPlaylist => _playlistInfo != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get loadingStatus => _loadingStatus;
  bool get hasError => _errorMessage != null;

  bool get audioOnly => _audioOnly;
  
  ResolutionOption? get selectedResolution => _selectedResolution;
  List<ResolutionOption> get availableResolutions => _availableResolutions;

  AudioQuality get selectedAudioQuality => _selectedAudioQuality;
  bool get embedSubtitles => _embedSubtitles;
  Set<SubtitleTrack> get selectedSubtitles => _selectedSubtitles;
  
  // Getters for YtDlpService consumption
  FormatInfo? get selectedVideoFormat => _selectedVideoFormatOverride ?? _selectedResolution?.formatInfo;
  String? get selectedVideoFormatId => selectedVideoFormat?.formatId;
  String? get selectedAudioFormatId => _audioOnly ? _bestAudioFormatId : _selectedAudioMergeStream?.formatId;
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
    } else if (_selectedResolution != null && _selectedResolution!.formatInfo.filesize != null) {
      size += _selectedResolution!.formatInfo.filesize!;
    }

    // Audio part (if not already merged)
    final videoFormat = _selectedVideoFormatOverride ?? _selectedResolution?.formatInfo;
    bool videoHasAudio = videoFormat?.hasAudio ?? false;

    if (!videoHasAudio && _selectedAudioMergeStream != null) {
      size += _selectedAudioMergeStream!.filesize ?? 0;
    }

    return size;
  }

  Future<void> fetchVideoInfo(String url) async {
    _isLoading = true;
    _errorMessage = null;
    _availableResolutions = []; // Clear previous
    _selectedVideoFormatOverride = null;
    _loadingStatus = 'Initializing...';
    notifyListeners();
    
    try {
      _videoInfo = await _ytdlpService.getVideoInfo(url, onProgress: (status) {
        _loadingStatus = status;
        notifyListeners();
      });
      _playlistInfo = null;
      
      if (_videoInfo != null) {
        _loadingStatus = 'Processing formats...';
        notifyListeners();
        _processFormats();
      }
      
    } catch (e) {
      _errorMessage = e.toString();
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
    
    final video = _videoInfo!;
    
    // 1. Find Best Audio Stream
    // Usually the one with highest bitrate/sampling rate. 
    // We'll use this single audio stream to calculate total size for all video resolutions.
    final bestAudio = video.audioOnlyFormats.isNotEmpty 
        ? video.audioOnlyFormats.first // audioOnlyFormats is already sorted by quality in model
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
      formats.sort((a, b) => (b.videoBitrate ?? 0).compareTo(a.videoBitrate ?? 0));
      
      final bestFormat = formats.first;
      
      int estimatedSize = (bestFormat.filesize ?? 0);
      bool isEstimate = bestFormat.filesize == null;
      bool isMerged = bestFormat.hasAudio && bestFormat.hasVideo;
      
      // Add audio size if we are going to merge (and it's not already merged)
      if (!isMerged && bestAudio != null) {
        estimatedSize += audioSize;
        if (bestAudio.filesize == null) isEstimate = true;
      }
      
      options.add(ResolutionOption(
        height: height,
        label: _getQualityLabel(height),
        videoFormatId: bestFormat.formatId,
        totalSize: estimatedSize,
        isApproximateSize: isEstimate,
        formatInfo: bestFormat,
        formats: formats, // Store all variants
        isMerged: isMerged,
      ));
    });
    

    // Sort: 4K -> 1080p -> 720p
    options.sort((a, b) => b.height.compareTo(a.height));
    
    _availableResolutions = options;
    
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
    notifyListeners();

    try {
      _playlistInfo = await _ytdlpService.getPlaylistInfo(url);
      _videoInfo = null;
    } catch (e) {
      _errorMessage = e.toString();
      _playlistInfo = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _videoInfo = null;
    _playlistInfo = null;
    _availableResolutions = [];
    _selectedResolution = null;
    _selectedVideoFormatOverride = null;
    notifyListeners();
  }

  void setAudioOnly(bool value) {
    _audioOnly = value;
    notifyListeners();
  }

  void selectResolution(ResolutionOption resolution) {
    _selectedResolution = resolution;
    _selectedVideoFormatOverride = null; // Reset specific override when changing resolution
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
      orElse: () => _availableResolutions.first
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

  void setEmbedSubtitles(bool value) {
    _embedSubtitles = value;
    notifyListeners();
  }

  void toggleSubtitle(SubtitleTrack subtitle) {
    if (_selectedSubtitles.contains(subtitle)) {
      _selectedSubtitles.remove(subtitle);
    } else {
      _selectedSubtitles.add(subtitle);
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
