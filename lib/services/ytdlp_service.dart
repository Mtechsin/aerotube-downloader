import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/download_item.dart';
import '../models/video_info.dart';
import '../models/playlist_info.dart';
import 'notification_service.dart';
import 'logging_service.dart';

class YtdlpService {
  String _ytdlpPath;
  String? _cookiePath;
  String? _cookieBrowser;
  String? _webViewPath;
  String? _ffmpegPath;
  String? _userAgent;
  bool _enableCookies = false;
  bool _isInitialized = false;
  final NotificationService? _notificationService;

  static const String _windowsDownloadUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';
  // Fallback or other OS support can be added here, currently focusing on Windows per context.

  YtdlpService({
    String? ytdlpPath,
    String? cookiePath,
    String? cookieBrowser,
    String? webViewPath,
    String? ffmpegPath,
    NotificationService? notificationService,
  }) : _ytdlpPath = ytdlpPath ?? 'yt-dlp',
       _cookiePath = cookiePath,
       _cookieBrowser = cookieBrowser,
       _webViewPath = webViewPath,
       _ffmpegPath = ffmpegPath,
       _notificationService = notificationService;

  set ytdlpPath(String path) => _ytdlpPath = path;
  String get ytdlpPath => _ytdlpPath;
  set cookiePath(String? path) => _cookiePath = path;
  String? get cookiePath => _cookiePath;
  set cookieBrowser(String? browser) => _cookieBrowser = browser;
  String? get cookieBrowser => _cookieBrowser;
  set webViewPath(String? path) => _webViewPath = path;
  String? get webViewPath => _webViewPath;
  set ffmpegPath(String? path) => _ffmpegPath = path;
  String? get ffmpegPath => _ffmpegPath;
  set userAgent(String? ua) => _userAgent = ua;
  String? get userAgent => _userAgent;
  set enableCookies(bool value) => _enableCookies = value;

  bool get isUsingCookies =>
      _enableCookies &&
      ((_cookiePath != null && File(_cookiePath!).existsSync()) ||
          (_cookieBrowser != null && _cookieBrowser != 'none') ||
          (_webViewPath != null));

  String? get activeCookieSource => _cookiePath != null
      ? 'file'
      : (_cookieBrowser != 'none'
            ? 'browser'
            : (_webViewPath != null ? 'webview' : null));

  /// Initialize the service: locate or download yt-dlp
  Future<void> initialize({bool force = false}) async {
    if (_isInitialized && !force) return;
    if (force) _isInitialized = false;

    try {
      final dir = await getApplicationSupportDirectory();
      final executableName = Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
      final localPath = p.join(dir.path, 'bin', executableName);
      final localFile = File(localPath);

      // If the current path is NOT the default 'yt-dlp' AND not our managed local path,
      // it means the user (or settings) provided a custom path. We should respect it.
      if (_ytdlpPath != 'yt-dlp' && _ytdlpPath != localPath) {
        // Verify if it exists, if not, try adding .exe on Windows
        if (!await File(_ytdlpPath).exists()) {
           if (Platform.isWindows && !_ytdlpPath.toLowerCase().endsWith('.exe')) {
             final withExe = '$_ytdlpPath.exe';
             if (await File(withExe).exists()) {
               _ytdlpPath = withExe;
             }
           }
        }
        _isInitialized = true;
        return;
      }

      if (await localFile.exists()) {
        _ytdlpPath = localPath;
      } else {
        // If not in managed local path, check if it's already available in system PATH
        if (await isAvailable()) {
          // Already available in system, we can use it as is
          _isInitialized = true;
          return;
        }
        
        // Not in local path and not in system PATH, download it
        await _downloadYtdlp(localFile);
        _ytdlpPath = localPath;
      }

      _isInitialized = true;
    } catch (e) {
      // Fallback to system PATH if initialization fails, or rethrow if critical
      // If we haven't set a path yet (and didn't crash), we rely on default 'yt-dlp' from constructor
    }
  }

  /// Download yt-dlp binary
  Future<void> _downloadYtdlp(File targetFile) async {
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    // Determine URL based on platform (assuming Windows for this specific request context, but making it slightly generic)
    final url = Platform.isWindows
        ? _windowsDownloadUrl
        : _windowsDownloadUrl; // TODO: Add Linux/Mac URLs

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await targetFile.writeAsBytes(response.bodyBytes);

        if (!Platform.isWindows) {
          // Make executable on Unix-like systems
          await Process.run('chmod', ['+x', targetFile.path]);
        }
      } else {
        throw YtdlpException(
          'Failed to download yt-dlp: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      throw YtdlpException('Failed to download yt-dlp: $e');
    }
  }

  /// Update yt-dlp using its self-update feature
  Future<bool> update() async {
    try {
      // If we are using the managed version, we can try deleting and re-downloading
      // OR use the built-in -U command. -U is easier usually.
      final result = await Process.run(_ytdlpPath, ['-U']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Check if yt-dlp is available
  Future<bool> isAvailable() async {
    try {
      // First try with current path
      var result = await Process.run(_ytdlpPath, ['--version']);
      if (result.exitCode == 0) return true;

      // If on Windows and it failed, try with .exe if not already there
      if (Platform.isWindows && !_ytdlpPath.toLowerCase().endsWith('.exe')) {
        result = await Process.run('$_ytdlpPath.exe', ['--version']);
        if (result.exitCode == 0) {
          _ytdlpPath = '$_ytdlpPath.exe';
          return true;
        }
      }

      // If it's still just 'yt-dlp', maybe it's in a different spot than PATH
      // But we handled local managed version in initialize()
      
      return false;
    } catch (e) {
      // If error is "file not found" and we are on Windows, try with .exe
      if (Platform.isWindows && !_ytdlpPath.toLowerCase().endsWith('.exe')) {
        try {
          final result = await Process.run('$_ytdlpPath.exe', ['--version']);
          if (result.exitCode == 0) {
             _ytdlpPath = '$_ytdlpPath.exe';
             return true;
          }
        } catch (_) {}
      }
      return false;
    }
  }

  /// Get yt-dlp version
  Future<String?> getVersion() async {
    try {
      final result = await Process.run(_ytdlpPath, ['--version']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if a newer version of yt-dlp is available on GitHub
  Future<String?> getLatestVersion() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String tagName = data['tag_name'] as String;
        // yt-dlp tags are usually the version itself (e.g. 2024.12.23)
        return tagName;
      }
    } catch (e) {
      // Error checking for update - will return null
    }
    return null;
  }

  /// Compare two yt-dlp versions (format: YYYY.MM.DD)
  /// Returns true if latest > current
  bool isNewerVersion(String current, String latest) {
    // Basic string comparison works for YYYY.MM.DD format
    // tag_name might have a 'v' prefix, let's normalize
    final normCurrent = current.startsWith('v')
        ? current.substring(1)
        : current;
    final normLatest = latest.startsWith('v') ? latest.substring(1) : latest;

    // Sometimes versions are like 2024.12.23.1
    // We can split and compare parts
    final currentParts = normCurrent.split('.');
    final latestParts = normLatest.split('.');

    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length)
        return true; // latest has more parts (e.g. .1)
      final c = int.tryParse(currentParts[i]) ?? 0;
      final l = int.tryParse(latestParts[i]) ?? 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Detect if an error suggests yt-dlp is broken or outdated
  bool isBrokenError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('outdated') ||
        lowerError.contains('update') ||
        lowerError.contains('signature') ||
        lowerError.contains('decipher') ||
        lowerError.contains('extraction failed');
  }

  /// Fetch video information from URL with retry logic for authentication
  Future<VideoInfo> getVideoInfo(
    String url, {
    Function(String status)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    onProgress?.call('Connecting to YouTube...');

    // First attempt with current configuration
    final args = _buildCommonArgs();
    args.addAll(['--dump-json', url]);

    onProgress?.call('Fetching video metadata...');
    var result = await Process.run(_ytdlpPath, args);

    if (result.exitCode != 0) {
      final error = (result.stderr as String).trim();
      final stdout = (result.stdout as String).trim();

      final authError = checkAuthenticationErrors(error);

      if (authError != null) {

        // Try with additional extractor arguments for YouTube
        if (error.contains('Sign in to confirm you') || error.contains('bot')) {
          onProgress?.call('Retrying with alternative method...');

          final retryArgs = <String>[
            '--newline',
            '--no-playlist',
            if (_ffmpegPath != null) ...['--ffmpeg-location', _ffmpegPath!],
            if (_userAgent != null) ...['--user-agent', _userAgent!],
            if (_cookiePath != null && File(_cookiePath!).existsSync()) ...[
              '--cookies',
              _cookiePath!,
            ],
            '--extractor-args',
            'youtube:player-client=web,mweb,android,ios;player-skip=webpage,configs',
            '--dump-json',
            url,
          ];

          result = await Process.run(_ytdlpPath, retryArgs);

          if (result.exitCode == 0) {
            onProgress?.call('Processing video formats...');
            final jsonStr = (result.stdout as String).trim();
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            return VideoInfo.fromJson(json);
          }
        }

        throw YtdlpException(authError);
      }

      // Fallback for DPAPI decryption error if browser cookies were used
      if ((error.contains('DPAPI') || error.contains('Failed to decrypt')) &&
          _cookieBrowser != null) {
        onProgress?.call('Retrying without browser cookies...');

        final argsWithoutBrowser = <String>[
          '--newline',
          '--no-playlist',
          if (_ffmpegPath != null) ...['--ffmpeg-location', _ffmpegPath!],
          if (_cookiePath != null && File(_cookiePath!).existsSync()) ...[
            '--cookies',
            _cookiePath!,
          ],
          '--dump-json',
          url,
        ];

        result = await Process.run(_ytdlpPath, argsWithoutBrowser);

        if (result.exitCode != 0) {
          final retryError = (result.stderr as String).trim();
          throw YtdlpException(
            'Failed to fetch video info: $retryError\n\nNote: Browser cookie extraction failed due to DPAPI. Try exporting cookies to a file or closing your browser.',
          );
        }
      } else {
        throw YtdlpException('Failed to fetch video info: $error');
      }
    }

    onProgress?.call('Processing video formats...');
    final stdout = (result.stdout as String).trim();
    if (stdout.isEmpty) {
      throw YtdlpException(
        'Failed to fetch video info: Empty output from yt-dlp',
      );
    }

    // Handle multi-line JSON output (yt-dlp can return multiple JSON objects)
    final lines = stdout.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      throw YtdlpException(
        'Failed to fetch video info: No valid JSON lines in output',
      );
    }

    try {
      final json = jsonDecode(lines.first) as Map<String, dynamic>;
      final info = VideoInfo.fromJson(json);
      _notificationService?.show(title: 'Fetch Complete', body: info.title);
      return info;
    } catch (e) {
      throw YtdlpException('Failed to parse video info: $e');
    }
  }

  /// Fetch playlist information from URL
  Future<PlaylistInfo> getPlaylistInfo(
    String url, {
    Function(String status)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    onProgress?.call('Connecting to YouTube...');

    final args = _buildCommonArgs();
    // Remove --no-playlist for playlist fetching
    args.remove('--no-playlist');

    // Use --flat-playlist for fast metadata fetching
    args.addAll([
      '--flat-playlist',
      '--extractor-args',
      'youtubetab:skip=authcheck',
      '--dump-json',
      url,
    ]);

    onProgress?.call('Fetching playlist metadata...');
    final process = await Process.start(_ytdlpPath, args);
    final videos = <PlaylistVideoItem>[];
    Map<String, dynamic>? playlistMetadata;
    final stderrBuffer = StringBuffer();
    String? playlistTitle;
    int? expectedCount;

    // Listen to stdout for line-by-line JSON
    final stdoutFuture = process.stdout
        .transform(const SystemEncoding().decoder)
        .listen((data) {
          final lines = data.split('\n').where((l) => l.trim().isNotEmpty);
          for (final line in lines) {
            try {
              final json = jsonDecode(line) as Map<String, dynamic>;

              if (json['_type'] == 'playlist') {
                playlistMetadata = json;
                playlistTitle = json['title'] as String?;
                expectedCount =
                    (json['playlist_count'] as int?) ??
                    (json['n_entries'] as int?);
                if (playlistTitle != null) {
                  onProgress?.call('Found playlist: $playlistTitle');
                }
              } else {
                final video = PlaylistVideoItem.fromJson(json);
                videos.add(video);

                // Build detailed status message
                final videoTitle = video.title.length > 40
                    ? '${video.title.substring(0, 40)}...'
                    : video.title;
                final countStr = expectedCount != null
                    ? '${videos.length}/$expectedCount'
                    : '${videos.length}';
                onProgress?.call('Loading video $countStr: $videoTitle');
              }
            } catch (e) {
              // Ignore parsing errors for individual lines
            }
          }
        })
        .asFuture();

    // Capture stderr
    final stderrFuture = process.stderr
        .transform(const SystemEncoding().decoder)
        .listen((data) {
          stderrBuffer.write(data);
        })
        .asFuture();

    final exitCode = await process.exitCode;
    await stdoutFuture;
    await stderrFuture;

    if (exitCode != 0) {
      final error = stderrBuffer.toString().trim();

      final authError = checkAuthenticationErrors(error);
      if (authError != null) throw YtdlpException(authError);

      throw YtdlpException('Failed to fetch playlist info: $error');
    }

    if (videos.isEmpty) {
      throw YtdlpException('No videos found in playlist');
    }

    onProgress?.call('Processing ${videos.length} videos...');

    final info = PlaylistInfo(
      id: playlistMetadata?['id'] ?? '',
      title: playlistMetadata?['title'] ?? 'Playlist',
      uploader:
          playlistMetadata?['uploader'] ??
          playlistMetadata?['uploader_id'] ??
          'Unknown',
      description: playlistMetadata?['description'],
      videoCount: videos.length,
      videos: videos,
    );
    _notificationService?.show(
      title: 'Playlist Fetched',
      body: '${info.title} (${info.videoCount} videos)',
    );
    return info;
  }

  /// Download video with specified format
  Future<Process> downloadVideo({
    required String url,
    required String outputPath,
    String? formatId,
    String? audioFormatId,
    bool audioOnly = false,
    String? audioQuality, // '0' (best) to '9' (worst)
    int? targetHeight,
    bool embedThumbnail = true,
    bool embedMetadata = true,
    Function(double progress, double speed, int eta)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    final args = _buildCommonArgs();
    args.addAll(['-o', outputPath]);

    // Embed thumbnail and metadata (requires FFmpeg)
    if (_ffmpegPath != null) {
      if (embedThumbnail) args.add('--embed-thumbnail');
      if (embedMetadata) args.add('--embed-metadata');
    }

    // Always write thumbnail to disk for History UI optimization
    args.add('--write-thumbnail');

    if (audioOnly) {
      // Audio only mode
      args.addAll([
        '-x', // Extract audio
        '--audio-format', 'mp3',
        '--audio-quality', audioQuality ?? '0', // Default to 0 (Best)
      ]);
    } else if (formatId != null && audioFormatId != null) {
      // Separate video and audio streams - strictly use selected formats
      args.addAll(['-f', '$formatId+$audioFormatId']);
    } else if (formatId != null) {
      // Single format with fallback - skip if it's a live stream format (9x range)
      final isLikelyLiveFormat =
          int.tryParse(formatId) != null &&
          int.parse(formatId) >= 90 &&
          int.parse(formatId) <= 99;
      if (isLikelyLiveFormat) {
        // Use best quality instead of live stream format
        args.addAll([
          '-f',
          'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best',
        ]);
      } else {
        // Strictly use the specified single format
        args.addAll(['-f', formatId]);
      }
    } else if (targetHeight != null) {
      // User specified max resolution - apply height filter
      args.addAll([
        '-f',
        'bestvideo[height<=$targetHeight][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$targetHeight]+bestaudio/best[height<=$targetHeight][ext=mp4]/best[height<=$targetHeight]',
      ]);
    } else {
      // Best quality default with comprehensive fallback chain
      args.addAll([
        '-f',
        'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best',
      ]);
    }

    args.add(url);

    final process = await Process.start(_ytdlpPath, args);
    return process;
  }

  /// Build common arguments for yt-dlp including cookies and ffmpeg location
  List<String> _buildCommonArgs() {
    final args = <String>[
      '--newline',
      '--no-playlist',
      '--retries',
      '2',
      '--fragment-retries',
      '2',
      '--extractor-retries',
      '1',
      '--socket-timeout',
      '10',
      '--no-warnings',
    ];

    if (_ffmpegPath != null && _ffmpegPath != 'ffmpeg') {
      args.addAll(['--ffmpeg-location', _ffmpegPath!]);
    }

    if (_userAgent != null) {
      args.addAll(['--user-agent', _userAgent!]);
    }

    // Authentication logic: WebView profile > cookies file > browser cookies
    if (_enableCookies) {
      if (_webViewPath != null) {
        args.addAll(['--cookies-from-browser', 'edge:$_webViewPath']);
      } else if (_cookiePath != null) {
        final cookieFile = File(_cookiePath!);

        if (cookieFile.existsSync()) {
          try {
            final content = cookieFile.readAsStringSync();

            // Check for critical YouTube auth cookies
            final criticalCookies = [
              'SAPISID',
              'HSID',
              'SSID',
              'SID',
              'LOGIN_INFO',
              '__Secure-1PSID',
              '__Secure-3PSID',
            ];
            final missingCookies = <String>[];

            for (final cookie in criticalCookies) {
              if (!content.contains(cookie)) {
                missingCookies.add(cookie);
              }
            }

            if (missingCookies.isNotEmpty) {
              // Add additional flags to help with authentication issues
              args.addAll([
                '--extractor-args',
                'youtube:player-client=web;webpage=no_cookie',
              ]);
            }
          } catch (e) {
            // Failed to read cookie file - continue without extra args
          }

          args.addAll(['--cookies', _cookiePath!]);
        }
      } else if (_cookieBrowser != null && _cookieBrowser != 'none') {
        args.addAll(['--cookies-from-browser', _cookieBrowser!.toLowerCase()]);
      }
    }

    return args;
  }

  /// Check for authentication or permission errors in yt-dlp output
  static String? checkAuthenticationErrors(String output) {
    if (output.contains('Sign in to confirm you’re not a bot') ||
        output.contains('Sign in to confirm your age') ||
        output.contains('This video is age-restricted') ||
        output.contains('Please sign in to view this video') ||
        output.contains('requires authentication')) {
      return 'Authentication required. Please provide a cookies.txt file or use browser cookies in Settings.';
    }

    if (output.contains('Permission denied') && output.contains('cookie')) {
      return 'Access to browser cookies denied. Please close all windows of specified browser and try again, or use a cookies.txt file.';
    }

    if (output.contains('Incomplete cookies file')) {
      return 'The selected cookies.txt file is incomplete or invalid. Please re-export it using the Netscape format.';
    }

    // Check for specific YouTube authentication errors
    if (output.toLowerCase().contains('authentication') &&
        (output.toLowerCase().contains('failed') ||
            output.toLowerCase().contains('required'))) {
      return 'Authentication failed. Please verify your cookies are valid and up-to-date.';
    }

    if (output.contains('HTTP Error 429') ||
        output.contains('Too Many Requests')) {
      return 'Rate limit exceeded (HTTP 429). Please wait a while before downloading more videos.';
    }

    return null;
  }

  /// Parse progress from yt-dlp output line
  static DownloadProgress? parseProgress(String line) {
    // Check for destination to determine phase
    if (line.contains('[download] Destination:')) {
      if (line.toLowerCase().contains('.mp4') ||
          line.toLowerCase().contains('.mkv') ||
          line.toLowerCase().contains('.webm')) {
        return DownloadProgress(
          progress: 0,
          speed: 0,
          eta: 0,
          status: DownloadStatus.downloadingVideo,
        );
      } else if (line.toLowerCase().contains('.m4a') ||
          line.toLowerCase().contains('.audio') ||
          line.toLowerCase().contains('.mp3') ||
          line.toLowerCase().contains('.opus')) {
        return DownloadProgress(
          progress: 0,
          speed: 0,
          eta: 0,
          status: DownloadStatus.downloadingAudio,
        );
      }
    }

    // Example: [download]  45.2% of 125.50MiB at 5.25MiB/s ETA 00:15
    // Example: [download]  10.0% of  1.20GiB at 10.00MiB/s ETA 01:20:30
    final progressMatch = RegExp(
      r'\[download\]\s+(\d+\.?\d*)%\s+of\s+~?(\d+\.?\d*)(Ki|Mi|Gi)?B?\s+at\s+(\d+\.?\d*)(Ki|Mi|Gi)?B/s\s+ETA\s+(?:(\d+):)?(\d+):(\d+)',
    ).firstMatch(line);

    if (progressMatch != null) {
      final percent = double.parse(progressMatch.group(1)!) / 100;

      // Parse speed
      double speed = double.parse(progressMatch.group(4)!);
      final speedUnit = progressMatch.group(5);
      if (speedUnit == 'Ki') {
        speed *= 1024;
      } else if (speedUnit == 'Mi') {
        speed *= 1024 * 1024;
      } else if (speedUnit == 'Gi') {
        speed *= 1024 * 1024 * 1024;
      }

      // Parse ETA
      final etaHoursStr = progressMatch.group(6);
      final etaHours = etaHoursStr != null ? int.parse(etaHoursStr) : 0;
      final etaMin = int.parse(progressMatch.group(7)!);
      final etaSec = int.parse(progressMatch.group(8)!);
      final eta = etaHours * 3600 + etaMin * 60 + etaSec;

      return DownloadProgress(progress: percent, speed: speed, eta: eta);
    }

    // Check for completion of a part (not the whole thing)
    if (line.contains('[download] 100%') ||
        line.contains('has already been downloaded')) {
      return DownloadProgress(progress: 1.0, speed: 0, eta: 0);
    }

    // Check for merging
    if (line.contains('[Merger]') ||
        line.contains('[ffmpeg]') ||
        line.contains('Merging formats into')) {
      return DownloadProgress(
        progress: 1.0,
        speed: 0,
        eta: 0,
        status: DownloadStatus.merging,
      );
    }

    return null;
  }

  /// Get best format for a specific resolution
  static String? getBestFormatForResolution(
    VideoInfo video,
    int targetHeight, {
    bool videoOnly = false,
  }) {
    final formats = videoOnly ? video.videoOnlyFormats : video.formats;

    // Find formats matching or closest to target height
    final matchingFormats = formats
        .where((f) => f.hasVideo && f.height != null)
        .toList();

    if (matchingFormats.isEmpty) return null;

    // Sort by how close they are to target, preferring higher quality
    matchingFormats.sort((a, b) {
      final diffA = (a.height! - targetHeight).abs();
      final diffB = (b.height! - targetHeight).abs();
      if (diffA != diffB) return diffA.compareTo(diffB);
      return (b.height ?? 0).compareTo(a.height ?? 0);
    });

    return matchingFormats.first.formatId;
  }

  /// Get best audio format
  static String? getBestAudioFormat(VideoInfo video) {
    final audioFormats = video.audioOnlyFormats;
    if (audioFormats.isEmpty) return null;
    return audioFormats.first.formatId;
  }

  /// Test authentication with a simple YouTube video to verify cookies are working
  Future<bool> testAuthentication() async {
    try {
      // Use a simple, non-age-restricted video for testing
      final testVideoUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

      // Try to fetch video info - this will fail if authentication is not working
      await getVideoInfo(testVideoUrl);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check for updates and return update info with download URL
  /// Returns null ONLY if yt-dlp is not available or version check failed
  /// Returns YtdlpUpdateInfo with same current/latest version when up to date
  Future<YtdlpUpdateInfo?> checkForUpdateWithProgress() async {
    final logger = LoggingService();
    logger.info('Checking for yt-dlp updates...', component: 'YtdlpService');

    try {
      final currentVersion = await getVersion();
      if (currentVersion == null) {
        logger.warning(
          'Cannot check for updates: yt-dlp not available',
          component: 'YtdlpService',
        );
        return null;
      }

      final latestVersion = await getLatestVersion();
      if (latestVersion == null) {
        logger.warning(
          'Cannot check for updates: failed to fetch latest version',
          component: 'YtdlpService',
        );
        // Still return info with current version so UI knows yt-dlp is installed
        return YtdlpUpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion, // Same as current means up to date
          downloadUrl: _windowsDownloadUrl,
          publishedAt: DateTime.now(),
          releaseNotes: 'Up to date',
        );
      }

      final hasUpdate = isNewerVersion(currentVersion, latestVersion);

      logger.info(
        'Update check complete: current=$currentVersion, latest=$latestVersion, updateAvailable=$hasUpdate',
        component: 'YtdlpService',
      );

      // Always return info - this lets the caller know yt-dlp is available
      return YtdlpUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl: _windowsDownloadUrl,
        publishedAt: DateTime.now(),
        releaseNotes: hasUpdate ? 'New version available: $latestVersion' : 'Up to date',
      );
    } catch (e, stackTrace) {
      logger.error(
        'Failed to check for yt-dlp updates',
        component: 'YtdlpService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Download and install update with progress callback
  Future<bool> downloadAndInstallUpdate(
    String downloadUrl, {
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
  }) async {
    final logger = LoggingService();

    try {
      onStatus('Downloading latest yt-dlp...');
      logger.info('Starting yt-dlp update download', component: 'YtdlpService');

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (contentLength > 0) {
          onProgress(bytes.length / contentLength);
        }
      }

      onStatus('Installing update...');
      logger.info(
        'Download complete, installing update',
        component: 'YtdlpService',
      );

      // Backup current binary
      final currentFile = File(_ytdlpPath);
      final backupPath = '$_ytdlpPath.backup';

      if (await currentFile.exists()) {
        await currentFile.copy(backupPath);
        logger.info('Created backup at $backupPath', component: 'YtdlpService');
      }

      try {
        // Write new binary
        await currentFile.writeAsBytes(bytes);
        logger.info('Update installed successfully', component: 'YtdlpService');

        // Clean up backup
        final backupFile = File(backupPath);
        if (await backupFile.exists()) {
          await backupFile.delete();
        }

        onStatus('Update complete!');
        return true;
      } catch (e) {
        // Restore backup on failure
        logger.error(
          'Failed to install update, restoring backup',
          component: 'YtdlpService',
          error: e,
        );
        final backupFile = File(backupPath);
        if (await backupFile.exists()) {
          await backupFile.copy(_ytdlpPath);
          await backupFile.delete();
        }
        throw Exception('Failed to install update: $e');
      }
    } catch (e, stackTrace) {
      logger.error(
        'Update download/install failed',
        component: 'YtdlpService',
        error: e,
        stackTrace: stackTrace,
      );
      onStatus('Update failed: $e');
      return false;
    }
  }
}

class DownloadProgress {
  final double progress;
  final double speed;
  final int eta;
  final DownloadStatus? status;

  DownloadProgress({
    required this.progress,
    required this.speed,
    required this.eta,
    this.status,
  });
}

class YtdlpException implements Exception {
  final String message;
  YtdlpException(this.message);

  @override
  String toString() => 'YtdlpException: $message';
}

/// Update information for yt-dlp
class YtdlpUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final DateTime publishedAt;
  final String releaseNotes;

  YtdlpUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.publishedAt,
    required this.releaseNotes,
  });
}
