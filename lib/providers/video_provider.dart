import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/video_info.dart';
import '../models/playlist_info.dart';
import '../services/ytdlp/ytdlp_service_windows.dart';
import '../services/ytdlp/ytdlp_service_android.dart';
import '../services/ytdlp/ytdlp_tool_service.dart';
import '../services/core/logging_service.dart';
import '../core/utils/error_helper.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/platform_utils.dart';

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

  // VPN / clunkiness fixes: cancellation + throttling
  int _fetchGen = 0;
  DateTime _lastStatusNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _statusThrottle = Duration(milliseconds: 250);

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

  /// Preferred quality from settings ("Best", "4K", "1080p", "720p", "480p", "Audio Only").
  /// Applied when a new video's formats are processed.
  String _preferredQuality = 'Best';

  void setPreferredQuality(String quality) {
    _preferredQuality = quality;
  }

  int? _heightForQualityLabel(String label) {
    switch (label) {
      case '4K':
        return 2160;
      case '1080p':
        return 1080;
      case '720p':
        return 720;
      case '480p':
        return 480;
      default:
        return null;
    }
  }

  VideoProvider(this._ytdlpService) {
    if (_ytdlpService is! YtdlpToolService &&
        _ytdlpService is! YtdlpService &&
        _ytdlpService is! YtdlpServiceAndroid) {
      throw ArgumentError(
        'VideoProvider requires YtdlpToolService.',
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
  String? get selectedAudioFormatId {
    final videoFormat = selectedVideoFormat;
    // Don't return an audio format if the video format already has audio
    if (videoFormat != null && videoFormat.hasAudio) {
      return null;
    }
    return _selectedAudioMergeStream?.formatId ?? _bestAudioFormatId;
  }
  int? get selectedHeight => _selectedResolution?.height;

  FormatInfo? get selectedAudioMergeStream => _selectedAudioMergeStream;

  int get totalEstimatedDownloadSize {
    final dur = _videoInfo?.duration;
    if (_audioOnly) {
      if (_videoInfo == null) return 0;
      final format =
          _selectedAudioMergeStream ??
          _videoInfo!.getBestAudioForQuality(_selectedAudioQuality);
      return format?.estimatedFilesize(dur) ?? 0;
    }

    int size = 0;

    // Video part
    if (_selectedVideoFormatOverride != null) {
      size += _selectedVideoFormatOverride!.estimatedFilesize(dur) ?? 0;
    } else if (_selectedResolution != null) {
      size += _selectedResolution!.formatInfo.estimatedFilesize(dur) ?? 0;
    }

    // Audio part (if not already merged)
    final videoFormat =
        _selectedVideoFormatOverride ?? _selectedResolution?.formatInfo;
    bool videoHasAudio = videoFormat?.hasAudio ?? false;

    if (!videoHasAudio && _selectedAudioMergeStream != null) {
      size += _selectedAudioMergeStream!.estimatedFilesize(dur) ?? 0;
    }

    return size;
  }

  /// Total merged size for a specific video format (video + best audio if video-only).
  int estimatedTotalSizeForFormat(FormatInfo format) {
    final dur = _videoInfo?.duration;
    final videoSize = format.estimatedFilesize(dur) ?? 0;
    if (format.hasAudio) return videoSize;
    final audioSize = _selectedAudioMergeStream?.estimatedFilesize(dur) ??
        _videoInfo?.audioOnlyFormats.firstOrNull?.estimatedFilesize(dur) ??
        0;
    return videoSize + audioSize;
  }

  String formattedTotalSizeForFormat(FormatInfo format) {
    final dur = _videoInfo?.duration;
    final total = estimatedTotalSizeForFormat(format);
    if (total == 0) return format.formattedEstimatedFilesize(dur);
    final isEst = format.isEstimated(dur) ||
        (_selectedAudioMergeStream?.isEstimated(dur) ?? false) ||
        (_videoInfo?.audioOnlyFormats.firstOrNull?.isEstimated(dur) ?? false);
    final str = total < 1024
        ? '$total B'
        : total < 1024 * 1024
            ? '${(total / 1024).toStringAsFixed(1)} KB'
            : total < 1024 * 1024 * 1024
                ? '${(total / (1024 * 1024)).toStringAsFixed(1)} MB'
                : '${(total / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    return isEst ? '~$str' : str;
  }

  bool _isVpnError(String msg) {
    final l = msg.toLowerCase();
    return l.contains('timed out') ||
        l.contains('timeout') ||
        l.contains('vpn') ||
        l.contains('temporary failure in name resolution') ||
        l.contains('unable to download webpage') ||
        l.contains('connection timed out') ||
        l.contains('network is unreachable') ||
        l.contains('failed host lookup');
  }

  /// Cancel an in-flight fetch (Windows & Android). Kills yt-dlp process via service.
  Future<void> cancelFetch() async {
    if (!_isLoading) return;
    _fetchGen++; // invalidate any in-flight future
    _isLoading = false;
    _loadingStatus = '';
    _appendFetchLog('Cancelled by user');
    try {
      // ignore: avoid_dynamic_calls
      await _ytdlpService.cancelFetch();
    } catch (_) {}
    try {
      // Also attempt to cancel via service-specific channel if available
      LoggingService().info('Video fetch cancelled by user', component: 'VideoProvider');
    } catch (_) {}
    notifyListeners();
  }

  void _throttledStatusUpdate(String status) {
    _loadingStatus = status;
    _appendFetchLog(status);
    final now = DateTime.now();
    if (now.difference(_lastStatusNotify) >= _statusThrottle) {
      _lastStatusNotify = now;
      notifyListeners();
    }
  }

  /// Seamless auto-update of yt-dlp with live progress reporting.
  Future<bool> _autoUpdateYtdlp() async {
    try {
      _loadingStatus = 'Updating yt-dlp to latest version...';
      _appendFetchLog('Auto-updating yt-dlp to latest release...');
      notifyListeners();

      final downloadUrl = PlatformUtils.isAndroid
          ? AppConstants.ytdlpAndroidDownloadUrl
          : AppConstants.ytdlpWindowsDownloadUrl;

      final success = await _ytdlpService.downloadAndInstallUpdate(
        downloadUrl,
        onProgress: (p) {
          final percent = (p * 100).clamp(0, 100).toInt();
          _loadingStatus = 'Updating yt-dlp $percent%...';
          notifyListeners();
        },
        onStatus: (status) {
          _loadingStatus = status;
          _appendFetchLog(status);
          notifyListeners();
        },
      );

      if (success) {
        _appendFetchLog('yt-dlp update completed successfully');
        _requiresYtdlpUpdate = false;
        return true;
      }
      return false;
    } catch (e) {
      _appendFetchLog('Auto-update error: $e');
      LoggingService().warning(
        'VideoProvider autoUpdateYtdlp failed: $e',
        component: 'VideoProvider',
      );
      return false;
    }
  }

  /// Public method allowing UI to trigger an update and immediately retry the current URL.
  Future<void> updateYtdlpAndRetry() async {
    if (_currentUrl.isEmpty) return;
    final url = _currentUrl;
    _isLoading = true;
    _errorMessage = null;
    _loadingStatus = 'Updating yt-dlp...';
    notifyListeners();

    final updated = await _autoUpdateYtdlp();
    if (updated) {
      await fetchVideoInfo(url, isRetryAfterUpdate: true);
    } else {
      _isLoading = false;
      _errorMessage = 'Could not update yt-dlp automatically. Please check your internet connection.';
      notifyListeners();
    }
  }

  Future<void> fetchVideoInfo(String url, {bool isRetryAfterUpdate = false}) async {
    // Guard: if already loading, cancel previous via generation bump
    if (_isLoading && !isRetryAfterUpdate) {
      _fetchGen++; // cancel previous
      LoggingService().debug('fetchVideoInfo: cancelling previous fetch (isLoading guard)', component: 'VideoProvider');
    }
    final myGen = ++_fetchGen;
    LoggingService().debug(
      'Starting for url: $url (gen $myGen)',
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
    if (!isRetryAfterUpdate) {
      _resetFetchLogs();
    }
    _appendFetchLog('Starting fetch request');
    _appendFetchLog('URL accepted');
    notifyListeners();
    _lastStatusNotify = DateTime.now();

    // Pre-flight check: ensure yt-dlp is available before attempting fetch
    try {
      final isAvailable = await _ytdlpService.isAvailable();
      if (!isAvailable) {
        _loadingStatus = 'Setting up yt-dlp automatically...';
        _appendFetchLog('yt-dlp missing locally. Auto-installing...');
        notifyListeners();
        final installed = await _autoUpdateYtdlp();
        if (!installed) {
          _errorMessage = 'Could not set up yt-dlp automatically. Please check your internet connection.';
          _requiresYtdlpUpdate = true;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}

    try {
      LoggingService().debug(
        'Calling _ytdlpService.getVideoInfo',
        component: 'VideoProvider',
      );
      // Provider-level timeout guard: 90s overall, VPN-friendly message
      final future = _ytdlpService.getVideoInfo(
        url,
        onProgress: (status) {
          if (myGen != _fetchGen) return; // cancelled
          _throttledStatusUpdate(status);
        },
      ) as Future<VideoInfo>;
      _videoInfo = await future.timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw TimeoutException(
          'Fetch timed out - VPN may be slowing connection, try again or disable VPN',
          Duration(seconds: 90),
        ),
      );
      if (myGen != _fetchGen) {
        LoggingService().debug('fetchVideoInfo gen $myGen stale after await, discarding', component: 'VideoProvider');
        return;
      }
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
    } catch (e, stackTrace) {
      if (myGen != _fetchGen) {
        LoggingService().debug('fetchVideoInfo gen $myGen cancelled, ignoring error $e', component: 'VideoProvider');
        return;
      }
      LoggingService().error('Error fetching video info: $e', component: 'VideoProvider', error: e, stackTrace: stackTrace);
      final rawError = e.toString();
      String cleanedError = _cleanErrorMessage(rawError);
      // Enrich timeout/VPN errors with user-friendly hint if not already present
      if (e is TimeoutException || _isVpnError(rawError)) {
        if (!cleanedError.toLowerCase().contains('vpn')) {
          cleanedError = 'Fetch timed out - VPN may be slowing connection, try again or disable VPN. ($cleanedError)';
        }
      }
      _technicalError = cleanedError;
      _requiresYtdlpUpdate = _shouldSuggestYtdlpUpdate(cleanedError);

      // Self-healing auto-update retry
      if (_requiresYtdlpUpdate && !isRetryAfterUpdate) {
        _appendFetchLog('Detected outdated extractor. Automatically updating yt-dlp...');
        _loadingStatus = 'Updating yt-dlp to latest version...';
        notifyListeners();

        final updateSuccess = await _autoUpdateYtdlp();
        if (updateSuccess && myGen == _fetchGen) {
          _appendFetchLog('yt-dlp updated successfully! Retrying video fetch...');
          _loadingStatus = 'Retrying video fetch...';
          notifyListeners();
          return fetchVideoInfo(url, isRetryAfterUpdate: true);
        }
      }

      if (_requiresYtdlpUpdate) {
        _errorMessage =
            'YouTube updated its player format. Tap "Update & Retry" to refresh yt-dlp.';
      } else {
        _errorMessage = cleanedError;
      }
      _appendFetchLog('Fetch failed: $cleanedError');
      _videoInfo = null;
    } finally {
      if (myGen == _fetchGen) {
        _isLoading = false;
        _loadingStatus = '';
        notifyListeners();
      }
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
      // Reset audio state to avoid stale selection from cache — single lookup
      final video = _videoInfo!;
      final cachedAudio = video.audioOnlyFormats;
      final bestAudio = cachedAudio.isNotEmpty ? cachedAudio.first : null;
      _bestAudioFormatId = bestAudio?.formatId;
      _selectedAudioMergeStream = bestAudio;
      return;
    }

    final video = _videoInfo!;
    final dur = video.duration;

    // 1. Find Best Audio Stream — single lookup of cached getter
    final audioOnly = video.audioOnlyFormats;
    final bestAudio = audioOnly.isNotEmpty ? audioOnly.first : null;

    _bestAudioFormatId = bestAudio?.formatId;
    _selectedAudioMergeStream = bestAudio; // Default to best audio
    final int audioSize = bestAudio?.estimatedFilesize(dur) ?? 0;
    final bool audioIsEstimated = bestAudio?.isEstimated(dur) ?? false;

    // 2. Group Video Streams by Resolution — single lookup per list
    final Map<int, List<FormatInfo>> formatsByRes = {};
    final videoOnly = video.videoOnlyFormats;
    if (videoOnly.isNotEmpty) {
      for (var f in videoOnly) {
        if (f.height == null) continue;
        formatsByRes.putIfAbsent(f.height!, () => []).add(f);
      }
    } else {
      final combined = video.combinedFormats;
      for (var f in combined) {
        if (f.height == null) continue;
        formatsByRes.putIfAbsent(f.height!, () => []).add(f);
      }
    }

    // 3. Create Resolution Options
    final List<ResolutionOption> options = [];

    formatsByRes.forEach((height, formats) {
      // Sort by estimated size / effective bitrate (heuristic when vbr/tbr null) to ensure meaningful order
      formats.sort((a, b) {
        final aSize = a.estimatedFilesize(dur) ?? 0;
        final bSize = b.estimatedFilesize(dur) ?? 0;
        if (aSize != bSize) return bSize.compareTo(aSize);
        final aKbps = a.effectiveBitrateKbps ?? 0;
        final bKbps = b.effectiveBitrateKbps ?? 0;
        if (aKbps != bKbps) return bKbps.compareTo(aKbps);
        return (b.height ?? 0).compareTo(a.height ?? 0);
      });

      final bestFormat = formats.first;

      int estimatedSize = bestFormat.estimatedFilesize(dur) ?? 0;
      bool isEstimate = bestFormat.isEstimated(dur);
      bool isMerged = bestFormat.hasAudio && bestFormat.hasVideo;

      // Add audio size if we are going to merge (and it's not already merged)
      if (!isMerged && bestAudio != null) {
        estimatedSize += audioSize;
        if (audioIsEstimated) isEstimate = true;
      }
      // If still 0 (e.g. live or missing duration), keep as estimated so UI shows ~ rather than Unknown
      if (estimatedSize == 0 && (bestFormat.tbr != null || bestFormat.videoBitrate != null)) {
        isEstimate = true;
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

    // Default Selection: preferred quality from settings, fallback to 1080p, then highest
    if (options.isNotEmpty) {
      final preferredHeight = _heightForQualityLabel(_preferredQuality);
      if (_preferredQuality == 'Audio Only') {
        _audioOnly = true;
        _selectedResolution = options.first;
      } else if (preferredHeight != null) {
        _selectedResolution = options.firstWhere(
          (r) => r.height == preferredHeight,
          orElse: () => options.firstWhere(
            (r) => r.height <= preferredHeight,
            orElse: () => options.first,
          ),
        );
        _audioOnly = false;
      } else {
        // "Best" or unknown → 1080p if available, else highest
        _selectedResolution = options.firstWhere(
          (r) => r.height == 1080,
          orElse: () => options.first,
        );
        _audioOnly = false;
      }
      _selectedVideoFormatOverride = null; // Reset specific override
    }
    // Background: probe HEAD for first videos' real sizes to correct heuristic estimate
    // Fire-and-forget, throttled to 8 formats to avoid hammering
    unawaited(_probeHeadSizes());
  }

  Future<void> _probeHeadSizes() async {
    if (_videoInfo == null) return;
    // Collect formats that are currently estimated via heuristic (no exact, no approx, tbr/vbr missing)
    final toProbe = <FormatInfo>[];
    final seen = <String>{};
    for (final res in _availableResolutions) {
      for (final f in res.formats) {
        if (f.filesize != null) continue; // exact exists
        if (f.filesizeApprox != null) continue; // approx exists (already ~)
        if (f.url == null || f.url!.isEmpty || !f.url!.startsWith('http')) continue;
        if (seen.contains(f.formatId)) continue;
        // Limit to 2 per resolution to be efficient
        final perResCount = toProbe.where((x) => x.height == f.height).length;
        if (perResCount >= 2) continue;
        seen.add(f.formatId);
        toProbe.add(f);
        if (toProbe.length >= 8) break;
      }
      if (toProbe.length >= 8) break;
    }
    if (toProbe.isEmpty) return;
    // Also probe best audio if heuristic
    final bestAudio = _selectedAudioMergeStream;
    if (bestAudio != null &&
        bestAudio.filesize == null &&
        bestAudio.filesizeApprox == null &&
        bestAudio.url != null &&
        bestAudio.url!.startsWith('http') &&
        !seen.contains(bestAudio.formatId)) {
      toProbe.add(bestAudio);
    }
    if (toProbe.isEmpty) return;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      for (final fmt in toProbe) {
        if (_cachedVideoId != _videoInfo?.id) break;
        if (fmt.url == null) continue;
        try {
          final uri = Uri.parse(fmt.url!);
          final req = await client.openUrl('HEAD', uri).timeout(const Duration(seconds: 4));
          req.headers.set('User-Agent', 'AeroTube/1.0');
          final resp = await req.close().timeout(const Duration(seconds: 4));
          final lenStr = resp.headers.value(HttpHeaders.contentLengthHeader) ??
              resp.headers.value('content-length');
          final len = int.tryParse(lenStr ?? '');
          await resp.drain();
          if (len != null && len > 1024) {
            _videoInfo!.applyProbedSize(fmt.formatId, len);
            _cachedResolutions = null;
            _processFormats();
            // Keep selection stable if same height
            notifyListeners();
            LoggingService().debug('HEAD probed ${fmt.formatId}: $len bytes', component: 'VideoProvider');
          }
        } catch (_) {
          // per-format failure ignored
        }
        await Future.delayed(const Duration(milliseconds: 120));
      }
    } finally {
      client.close(force: true);
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

  Future<void> fetchPlaylistInfo(String url, {bool isRetryAfterUpdate = false}) async {
    if (_isLoading && !isRetryAfterUpdate) _fetchGen++;
    final myGen = ++_fetchGen;
    _isLoading = true;
    _errorMessage = null;
    _technicalError = null;
    _requiresYtdlpUpdate = false;
    _currentUrl = url;
    if (!isRetryAfterUpdate) {
      _resetFetchLogs();
    }
    _appendFetchLog('Starting playlist fetch');
    _subtitlesEnabled = false;
    _embedSubtitles = false;
    _selectedSubtitles.clear();
    notifyListeners();
    _lastStatusNotify = DateTime.now();

    // Pre-flight check: ensure yt-dlp is available before attempting playlist fetch
    try {
      final isAvailable = await _ytdlpService.isAvailable();
      if (!isAvailable) {
        _loadingStatus = 'Setting up yt-dlp automatically...';
        _appendFetchLog('yt-dlp missing locally. Auto-installing...');
        notifyListeners();
        final installed = await _autoUpdateYtdlp();
        if (!installed) {
          _errorMessage = 'Could not set up yt-dlp automatically. Please check your internet connection.';
          _requiresYtdlpUpdate = true;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}

    try {
      final future = _ytdlpService.getPlaylistInfo(
        url,
        onProgress: (status) {
          if (myGen != _fetchGen) return;
          _throttledStatusUpdate(status);
        },
      ) as Future<PlaylistInfo>;
      _playlistInfo = await future.timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw TimeoutException(
          'Fetch timed out - VPN may be slowing connection, try again or disable VPN',
          Duration(seconds: 90),
        ),
      );
      if (myGen != _fetchGen) return;
      _videoInfo = null;
      _appendFetchLog(
        'Playlist loaded (${_playlistInfo?.videoCount ?? 0} videos)',
      );
    } catch (e, stackTrace) {
      if (myGen != _fetchGen) return;
      LoggingService().error('Error fetching playlist info: $e', component: 'VideoProvider', error: e, stackTrace: stackTrace);
      final rawError = e.toString();
      String cleanedError = _cleanErrorMessage(rawError);
      if (e is TimeoutException || _isVpnError(rawError)) {
        if (!cleanedError.toLowerCase().contains('vpn')) {
          cleanedError = 'Fetch timed out - VPN may be slowing connection, try again or disable VPN. ($cleanedError)';
        }
      }
      _technicalError = cleanedError;
      _requiresYtdlpUpdate = _shouldSuggestYtdlpUpdate(cleanedError);

      // Self-healing auto-update retry
      if (_requiresYtdlpUpdate && !isRetryAfterUpdate) {
        _appendFetchLog('Detected outdated extractor. Automatically updating yt-dlp...');
        _loadingStatus = 'Updating yt-dlp to latest version...';
        notifyListeners();

        final updateSuccess = await _autoUpdateYtdlp();
        if (updateSuccess && myGen == _fetchGen) {
          _appendFetchLog('yt-dlp updated successfully! Retrying playlist fetch...');
          _loadingStatus = 'Retrying playlist fetch...';
          notifyListeners();
          return fetchPlaylistInfo(url, isRetryAfterUpdate: true);
        }
      }

      _errorMessage = _requiresYtdlpUpdate
          ? 'YouTube updated its playlist format. Tap "Update & Retry" to refresh yt-dlp.'
          : cleanedError;
      _appendFetchLog('Playlist fetch failed: $cleanedError');
      _playlistInfo = null;
    } finally {
      if (myGen == _fetchGen) {
        _isLoading = false;
        _loadingStatus = '';
        notifyListeners();
      }
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
    _selectedAudioMergeStream = null;
    _bestAudioFormatId = null;
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
    return ErrorHelper.clean(raw);
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
    if (_availableResolutions.isEmpty) return;
    final option = _availableResolutions.firstWhere(
      (r) => r.height == height,
      orElse: () => _availableResolutions.first,
    );
    selectResolution(option);
  }

  void setSelectedAudioMergeStream(FormatInfo format) {
    _selectedAudioMergeStream = format;
    if (format.hasAudio && !format.hasVideo) {
      _selectedAudioQuality = format.audioQualityTier;
    }
    notifyListeners();
  }

  void setAudioQuality(AudioQuality quality) {
    _selectedAudioQuality = quality;
    if (_videoInfo != null) {
      final bestForQuality = _videoInfo!.getBestAudioForQuality(quality);
      if (bestForQuality != null) {
        _selectedAudioMergeStream = bestForQuality;
      }
    }
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
