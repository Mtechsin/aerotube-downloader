import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/download_item.dart';
import '../../models/video_info.dart';
import '../../models/playlist_info.dart';
import '../notification/notification_service.dart';
import '../core/logging_service.dart';
import '../core/download_helper.dart';
import 'ytdlp_tool_service.dart';
import '../core/certificate_pinning_service.dart';
import '../../core/utils/url_validator.dart';
import '../../core/utils/version_utils.dart' as version_utils show isNewerVersion;

export 'ytdlp_tool_service.dart' show YtdlpUpdateInfo;

class YtdlpService implements YtdlpToolService {
  String _ytdlpPath;
  String? _cookiePath;
  String? _cookieBrowser;
  String? _webViewPath;
  String? _ffmpegPath;
  String? _userAgent;
  bool _enableCookies = false;
  bool _isInitialized = false;
  final NotificationService? _notificationService;
  final CertificatePinningService _certPinningService = CertificatePinningService();
  String? _cachedLatestVersion;
  final _videoInfoCache = LinkedHashMap<String, VideoInfo>();
  static const int _maxCacheSize = 30;
  String? _cachedVersion;
  HttpClient? _pinnedClient;

  static const String _windowsDownloadUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';
  static const String _linuxDownloadUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp';
  static const String _macosDownloadUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos';

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

  set ytdlpPath(String path) {
    if (_ytdlpPath != path) {
      _ytdlpPath = path;
      _cachedVersion = null;
    }
  }
  @override
  String get ytdlpPath => _ytdlpPath;
  @override
  set cookiePath(String? path) => _cookiePath = path;
  @override
  String? get cookiePath => _cookiePath;
  @override
  set cookieBrowser(String? browser) => _cookieBrowser = browser;
  @override
  String? get cookieBrowser => _cookieBrowser;
  @override
  set webViewPath(String? path) => _webViewPath = path;
  @override
  String? get webViewPath => _webViewPath;
  @override
  set ffmpegPath(String? path) => _ffmpegPath = path;
  @override
  String? get ffmpegPath => _ffmpegPath;
  @override
  set userAgent(String? ua) => _userAgent = ua;
  @override
  String? get userAgent => _userAgent;
  @override
  set enableCookies(bool value) => _enableCookies = value;
  @override
  bool get enableCookies => _enableCookies;

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
  @override
  Future<void> initialize({bool force = false}) async {
    if (_isInitialized && !force) return;
    if (force) {
      _isInitialized = false;
      _cachedVersion = null;
    }

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
          if (Platform.isWindows &&
              !_ytdlpPath.toLowerCase().endsWith('.exe')) {
            final withExe = '$_ytdlpPath.exe';
            if (await File(withExe).exists()) {
              // Use public setter so cache is invalidated on path change
              ytdlpPath = withExe;
            }
          }
        }
        _isInitialized = true;
        return;
      }

      if (await localFile.exists()) {
        // Use public setter so the availability cache is cleared when
        // the resolved local path differs from the current value.
        ytdlpPath = localPath;
      } else {
        // If not in local path and not in system PATH, download it
        if (await isAvailable()) {
          _isInitialized = true;
          return;
        }

        await _downloadYtdlp(localFile);
        // Use setter to ensure cache is cleared after download
        ytdlpPath = localPath;
      }

      _isInitialized = true;
    } catch (e) {
      // Fallback to system PATH if initialization fails
    }
  }

  /// Download yt-dlp binary (runs in a background isolate for full speed)
  Future<void> _downloadYtdlp(File targetFile) async {
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    final url = Platform.isWindows
        ? _windowsDownloadUrl
        : Platform.isMacOS
            ? _macosDownloadUrl
            : _linuxDownloadUrl;
    // Use a private temp directory with a random suffix (O_EXCL semantics)
    // instead of a guessable millisecond-timestamp name in the shared temp
    // dir, which was vulnerable to predicted-name symlink/hijack races (M11).
    final tempDir = await Directory.systemTemp.createTemp('yt-dlp-dl-');
    final tempFileName = Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
    final tempPath = p.join(tempDir.path, tempFileName);

    try {
      await downloadInBackground(url: url, destPath: tempPath);

      // Safe replace
      if (await targetFile.exists()) {
        final backupFile = File('${targetFile.path}.bak');
        await targetFile.rename(backupFile.path);
        try {
          await File(tempPath).copy(targetFile.path);
          await backupFile.delete();
        } catch (e) {
          await backupFile.rename(targetFile.path);
          throw YtdlpException('Failed to copy temp file: $e');
        }
      } else {
        await File(tempPath).copy(targetFile.path);
      }

      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', targetFile.path]);
      }
    } catch (e) {
      throw YtdlpException('Failed to download yt-dlp: $e');
    } finally {
      try {
        // Recursively delete the private temp directory (binary + anything
        // written alongside it).
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      } catch (e) {
        LoggingService().debug(
          'Failed to delete temp yt-dlp binary: $e',
          component: 'YtdlpService',
        );
      }
    }
  }

  @override
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

  /// Check if yt-dlp is available.
  ///
  /// NOTE: No result caching here on purpose — caching `false` before
  /// [initialize] resolves the managed binary path would produce a permanent
  /// false-negative that persists for the lifetime of the service.  The probe
  /// is a simple `--version` call (~5 ms) so the cost is negligible.
  @override
  Future<bool> isAvailable() async {
    try {
      // First try with current path
      var result = await Process.run(_ytdlpPath, ['--version']);
      if (result.exitCode == 0) {
        _cachedVersion = (result.stdout as String).trim();
        return true;
      }

      // On Windows, retry with .exe suffix if the bare name failed
      if (Platform.isWindows && !_ytdlpPath.toLowerCase().endsWith('.exe')) {
        result = await Process.run('$_ytdlpPath.exe', ['--version']);
        if (result.exitCode == 0) {
          ytdlpPath = '$_ytdlpPath.exe'; // setter clears version cache
          _cachedVersion = (result.stdout as String).trim();
          return true;
        }
      }

      return false;
    } catch (e) {
      // If process launch fails on Windows, retry with .exe
      if (Platform.isWindows && !_ytdlpPath.toLowerCase().endsWith('.exe')) {
        try {
          final result = await Process.run('$_ytdlpPath.exe', ['--version']);
          if (result.exitCode == 0) {
            ytdlpPath = '$_ytdlpPath.exe'; // setter clears version cache
            _cachedVersion = (result.stdout as String).trim();
            return true;
          }
        } catch (e) {
          LoggingService().warning(
            'yt-dlp .exe fallback check failed: $e',
            component: 'YtdlpService',
          );
        }
      }
      return false;
    }
  }

  /// Lightweight binary check for background isolate (compute).
  /// Returns version string if available, null otherwise.
  static Future<String?> checkBinaryAvailable(String path) async {
    try {
      var result = await Process.run(path, ['--version']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
      if (Platform.isWindows && !path.toLowerCase().endsWith('.exe')) {
        result = await Process.run('$path.exe', ['--version']);
        if (result.exitCode == 0) {
          return (result.stdout as String).trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Called after background isolate confirms binary works.
  /// Skips full initialize() I/O.
  @override
  void markReady(String version) {
    _cachedVersion = version;
    _isInitialized = true;
  }

  @override
  Future<String?> getVersion() async {
    if (_cachedVersion != null) return _cachedVersion;
    try {
      final result = await Process.run(_ytdlpPath, ['--version']);
      if (result.exitCode == 0) {
        _cachedVersion = (result.stdout as String).trim();
        return _cachedVersion;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if a newer version of yt-dlp is available on GitHub
  @override
  Future<String?> getLatestVersion({bool forceRefresh = false}) async {
    // Return cached version if available and not forcing refresh
    if (!forceRefresh && _cachedLatestVersion != null) {
      return _cachedLatestVersion;
    }

    try {
      // Route through the certificate-pinned client for consistency with
      // UpdateService (M3): the same api.github.com endpoint is pinned there,
      // so it must be pinned here too.
      _pinnedClient ??= _certPinningService.createPinnedHttpClient();
      final client = _pinnedClient!;
      final request = await client.getUrl(
        Uri.parse('https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest'),
      );
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      request.headers.set('User-Agent', 'AeroTube-Updater');
      final httpResponse = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final responseBody = await httpResponse.transform(utf8.decoder).join();
      if (httpResponse.statusCode == 200) {
        final data = jsonDecode(responseBody);
        String tagName = data['tag_name'] as String;
        _cachedLatestVersion = tagName; // Cache the version
        return tagName;
      }
    } catch (e) {
      // Error checking for update - will return null
    }
    return null;
  }

  bool isNewerVersion(String current, String latest) => version_utils.isNewerVersion(current, latest);

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

    final cacheKey = _buildVideoInfoCacheKey(url);
    final cachedInfo = _videoInfoCache[cacheKey];
    if (cachedInfo != null) {
      onProgress?.call('Using cached video metadata...');
      // Promote to most recently used
      _videoInfoCache.remove(cacheKey);
      _videoInfoCache[cacheKey] = cachedInfo;
      return cachedInfo;
    }

    onProgress?.call('Connecting to YouTube...');
    onProgress?.call('Fetching video metadata...');

    final args = _buildVideoInfoArgs(url);

    LoggingService().debug(
      'Executing info fetch: $_ytdlpPath ${args.join(' ')}',
      component: 'YtdlpService',
    );
    var result = await Process.run(_ytdlpPath, args).timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw YtdlpException(
        'yt-dlp timed out fetching video info (120 s). '
        'Check your network or try again.',
      ),
    );

    if (result.exitCode != 0) {
      final error = (result.stderr as String).trim();

      final authError = checkAuthenticationErrors(error);

      if (authError != null) {
        // Try with additional extractor arguments for YouTube
        if (error.contains('Sign in to confirm you') || error.contains('bot')) {
          onProgress?.call('Retrying with alternative method...');

          // Use extended player client for retry (from working baseline)
          final retryArgs = <String>[
            '--ignore-config',
            '--newline',
            '--no-playlist',
            '--skip-download',
            '--no-warnings',
            if (_ffmpegPath != null) ...['--ffmpeg-location', _ffmpegPath!],
            if (_userAgent != null) ...['--user-agent', _userAgent!],
            if (_cookiePath != null && File(_cookiePath!).existsSync()) ...[
              '--cookies',
              _cookiePath!,
            ],
            '--extractor-args',
            'youtube:player_client=web,mweb,android,ios;player-skip=webpage,configs',
            '--dump-single-json',
            url,
          ];

          result = await Process.run(_ytdlpPath, retryArgs).timeout(
            const Duration(seconds: 120),
            onTimeout: () => throw YtdlpException(
              'yt-dlp retry timed out (120 s).',
            ),
          );

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
          '--ignore-config',
          '--newline',
          '--no-playlist',
          '--skip-download',
          '--no-warnings',
          if (_ffmpegPath != null) ...['--ffmpeg-location', _ffmpegPath!],
          if (_cookiePath != null && File(_cookiePath!).existsSync()) ...[
            '--cookies',
            _cookiePath!,
          ],
          '--dump-single-json',
          url,
        ];

        result = await Process.run(_ytdlpPath, argsWithoutBrowser).timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw YtdlpException(
            'yt-dlp retry timed out (120 s).',
          ),
        );

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
      // Find the first line that starts with '{' (JSON object)
      String? jsonLine;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('{')) {
          jsonLine = trimmed;
          break;
        }
      }

      if (jsonLine == null) {
        throw YtdlpException(
          'Failed to fetch video info: No JSON object found in output',
        );
      }

      final json = jsonDecode(jsonLine) as Map<String, dynamic>;
      final info = VideoInfo.fromJson(json);
      if (_videoInfoCache.length >= _maxCacheSize) {
        _videoInfoCache.remove(_videoInfoCache.keys.first);
      }
      _videoInfoCache[cacheKey] = info;
      _notificationService?.show(title: 'Fetch Complete', body: info.title);
      return info;
    } catch (e) {
      throw YtdlpException('Failed to parse video info: $e');
    }
  }

  static String _validateUrl(String url) {
    try {
      return UrlValidator.validate(url);
    } on UrlValidationException catch (e) {
      throw YtdlpException(e.message);
    }
  }

  List<String> _buildVideoInfoArgs(String url) {
    final args = <String>[
      '--ignore-config',
      '--newline',
      '--no-playlist',
      '--skip-download',
      '--retries',
      '2',
      '--extractor-retries',
      '1',
      '--socket-timeout',
      '10',
      '--no-warnings',
      '--dump-single-json',
    ];

    if (_ffmpegPath != null && _ffmpegPath != 'ffmpeg') {
      args.addAll(['--ffmpeg-location', _ffmpegPath!]);
    }

    if (_userAgent != null) {
      args.addAll(['--user-agent', _userAgent!]);
    }

    if (_enableCookies) {
      if (_webViewPath != null) {
        args.addAll(['--cookies-from-browser', 'edge:$_webViewPath']);
      } else if (_cookiePath != null && File(_cookiePath!).existsSync()) {
        args.addAll(['--cookies', _cookiePath!]);
      } else if (_cookieBrowser != null && _cookieBrowser != 'none') {
        args.addAll(['--cookies-from-browser', _cookieBrowser!.toLowerCase()]);
      }
    }

    args.addAll(['--', _validateUrl(url)]);
    return args;
  }

  String _buildVideoInfoCacheKey(String url) {
    return [
      url.trim(),
      _enableCookies.toString(),
      _cookiePath ?? '',
      _cookieBrowser ?? '',
      _webViewPath ?? '',
      _userAgent ?? '',
    ].join('|');
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
      '--',
      _validateUrl(url),
    ]);

    onProgress?.call('Fetching playlist metadata...');
    final process = await Process.start(_ytdlpPath, args).timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw YtdlpException(
        'yt-dlp timed out starting playlist fetch (120 s).',
      ),
    );
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

    final exitCode = await process.exitCode.timeout(
      const Duration(minutes: 10),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        throw YtdlpException(
          'Playlist fetch timed out (10 min). The playlist may be too large.',
        );
      },
    );
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
    List<String>? subtitleLanguages,
    bool embedSubtitles = false,
    bool sponsorBlock = false,
    String? archivePath,
    Function(double progress, double speed, int eta)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    final args = _buildCommonArgs(
      sponsorBlock: sponsorBlock,
      archivePath: archivePath,
    );
    args.addAll(['-o', outputPath]);

    // Embed thumbnail and metadata (requires FFmpeg)
    if (_ffmpegPath != null) {
      if (embedThumbnail) args.add('--embed-thumbnail');
      if (embedMetadata) args.add('--embed-metadata');
    }

    // Subtitles
    if (subtitleLanguages != null && subtitleLanguages.isNotEmpty) {
      args.add('--write-subs');
      if (embedSubtitles && _ffmpegPath != null) {
        args.add('--embed-subs');
      }
      for (final lang in subtitleLanguages) {
        args.addAll(['--sub-lang', lang]);
      }
    }

    // Always write thumbnail to disk for History UI optimization
    args.add('--write-thumbnail');

    if (audioOnly) {
      // Audio only mode
      if (audioFormatId != null) {
        // Only force format if it's not a generic 'best' selection
        // to avoid redundant transcoding.
        if (audioFormatId != 'bestaudio' && audioFormatId != 'best') {
           args.addAll(['-f', audioFormatId]);
        }
      }
      args.addAll([
        '-x', // Extract audio
        '--audio-format', 'mp3',
        '--audio-quality', audioQuality ?? '0', // Default to 0 (Best)
      ]);
    } else if (formatId != null && audioFormatId != null) {
      // Separate video and audio streams - strictly use selected formats
      args.addAll(['-f', '$formatId+$audioFormatId']);

      // Ensure merge output format matches the destination extension if it's a standard container
      final ext = p.extension(outputPath).replaceAll('.', '').toLowerCase();
      if (ext.isNotEmpty &&
          ['mp4', 'mkv', 'ogg', 'webm', 'flv'].contains(ext)) {
        args.addAll(['--merge-output-format', ext]);
      }
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

    args.addAll(['--', _validateUrl(url)]);

    final process = await Process.start(_ytdlpPath, args);
    return process;
  }

  /// Build common arguments for yt-dlp including cookies and ffmpeg location
  List<String> _buildCommonArgs({
    bool sponsorBlock = false,
    String? archivePath,
  }) {
    final args = <String>[
      '--newline',
      '--no-playlist',
      '--no-continue-on-http-error',
      '--retries',
      '5',
      '--fragment-retries',
      '5',
      '--file-access-retries',
      '3',
      '--extractor-retries',
      '1',
      '--socket-timeout',
      '10',
      '--concurrent-fragments',
      '16',
      '--buffer-size',
      '16K',
      '--http-chunk-size',
      '10M',
      '--no-warnings',
    ];

    if (_ffmpegPath != null && _ffmpegPath != 'ffmpeg') {
      args.addAll(['--ffmpeg-location', _ffmpegPath!]);
    }

    if (_userAgent != null) {
      args.addAll(['--user-agent', _userAgent!]);
    }

    // SponsorBlock
    if (sponsorBlock) {
      args.add('--sponsorblock-remove');
    }

    // Download archive
    if (archivePath != null && archivePath.isNotEmpty) {
      args.addAll(['--download-archive', archivePath]);
    }

    // Authentication logic: WebView profile > cookies file > browser cookies
    if (_enableCookies) {
      if (_webViewPath != null) {
        args.addAll(['--cookies-from-browser', 'edge:$_webViewPath']);
      } else if (_cookiePath != null) {
        final cookieFile = File(_cookiePath!);

        if (cookieFile.existsSync()) {
          // Using 'web' client with cookies - no need for extra extractor args
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
    if (output.contains("Sign in to confirm you're not a bot") ||
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
    final lowerLine = line.toLowerCase();

    if (line.contains('[download] Destination:')) {
      if (lowerLine.contains('.mp4') ||
          lowerLine.contains('.mkv') ||
          lowerLine.contains('.webm')) {
        return DownloadProgress(
          progress: 0,
          speed: 0,
          eta: 0,
          status: DownloadStatus.downloadingVideo,
        );
      } else if (lowerLine.contains('.m4a') ||
          lowerLine.contains('.audio') ||
          lowerLine.contains('.mp3') ||
          lowerLine.contains('.opus')) {
        return DownloadProgress(
          progress: 0,
          speed: 0,
          eta: 0,
          status: DownloadStatus.downloadingAudio,
        );
      }
    }

    if (line.contains('[download] 100%') || line.contains('has already been downloaded')) {
      return DownloadProgress(progress: 1.0, eta: 0);
    }

    final progressMatch = RegExp(
      r'\[download\]\s+(\d+(?:\.\d+)?)%',
    ).firstMatch(line);

    if (progressMatch == null) {
      if (lowerLine.contains('[merger]') ||
          lowerLine.contains('[ffmpeg]') ||
          lowerLine.contains('merging formats into')) {
        return DownloadProgress(
          progress: 1.0,
          eta: 0,
          status: DownloadStatus.merging,
        );
      }

      return null;
    }

    final percent = double.parse(progressMatch.group(1)!) / 100;
    final speedMatch = RegExp(
      r'at\s+(\d+(?:\.\d+)?)\s*([KMG]?i?)B/s',
      caseSensitive: false,
    ).firstMatch(line);
    final etaMatch = RegExp(r'ETA\s+(?:(\d+):)?(\d+):(\d+)').firstMatch(line);

    double? speed;
    if (speedMatch != null) {
      final parsedSpeed = double.parse(speedMatch.group(1)!);
      final unit = (speedMatch.group(2) ?? '').toLowerCase();
      speed =
          parsedSpeed *
          switch (unit) {
            'ki' => 1024,
            'mi' => 1024 * 1024,
            'gi' => 1024 * 1024 * 1024,
            _ => 1,
          };
    }

    int? eta;
    if (etaMatch != null) {
      final hours = int.tryParse(etaMatch.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(etaMatch.group(2) ?? '0') ?? 0;
      final seconds = int.tryParse(etaMatch.group(3) ?? '0') ?? 0;
      eta = hours * 3600 + minutes * 60 + seconds;
    }

    return DownloadProgress(
      progress: percent.clamp(0.0, 1.0),
      speed: speed,
      eta: eta,
    );
  }

  static String formatDownloadError(String output, int exitCode) {
    final trimmed = output.trim();
    final lower = trimmed.toLowerCase();

    if (lower.contains('http error 416') ||
        lower.contains('requested range not satisfiable')) {
      return 'HTTP 416: the server rejected a resume request. yt-dlp will restart affected downloads without continuing partial files.';
    }

    if (trimmed.isEmpty) return 'Process exited with code $exitCode';
    return trimmed;
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
  @override
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
        releaseNotes: hasUpdate
            ? 'New version available: $latestVersion'
            : 'Up to date',
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

  /// Download and install update with progress callback.
  /// The download runs in a background isolate for full network throughput.
  @override
  Future<bool> downloadAndInstallUpdate(
    String downloadUrl, {
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
    bool Function()? isCancelled,
  }) async {
    final logger = LoggingService();
    File? tempFile;
    Directory? tempDir;

    try {
      onStatus('Downloading latest yt-dlp...');
      logger.info(
        'Starting yt-dlp update download (background isolate)',
        component: 'YtdlpService',
      );

      // Private temp directory with a random suffix (O_EXCL semantics) to
      // avoid predicted-name symlink/hijack races in the shared temp dir (M11).
      tempDir = await Directory.systemTemp.createTemp('yt-dlp-update-');
      tempFile = File(p.join(tempDir.path, 'yt-dlp.exe'));

      // Download via multi-connection curl (8 parallel connections)
      await downloadInBackground(
        url: downloadUrl,
        destPath: tempFile.path,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      logger.info('yt-dlp download complete', component: 'YtdlpService');
      final downloadedSize = await tempFile.length();
      if (downloadedSize < 1024 * 1024) {
        throw Exception('Downloaded file too small ($downloadedSize bytes), likely not a valid binary');
      }

      if (isCancelled?.call() == true) {
        onStatus('Update cancelled');
        return false;
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
      }

      try {
        if (await currentFile.exists()) await currentFile.delete();
        await tempFile.copy(_ytdlpPath);
        logger.info('Update installed successfully', component: 'YtdlpService');

        final backupFile = File(backupPath);
        if (await backupFile.exists()) await backupFile.delete();

        onStatus('Update complete!');
        return true;
      } catch (e) {
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
      if (e.toString().contains('Cancelled')) {
        onStatus('Update cancelled');
        return false;
      }
      logger.error(
        'Update download/install failed',
        component: 'YtdlpService',
        error: e,
        stackTrace: stackTrace,
      );
      onStatus('Update failed: $e');
      return false;
    } finally {
      if (tempDir != null && tempDir.existsSync()) {
        try {
          // Recursively delete the private temp directory (binary + anything
          // written alongside it).
          await tempDir.delete(recursive: true);
        } catch (e) {
          LoggingService().debug(
            'Failed to delete temp update file: $e',
            component: 'YtdlpService',
          );
        }
      }
    }
  }
}

class DownloadProgress {
  final double progress;
  final double? speed;
  final int? eta;
  final DownloadStatus? status;

  DownloadProgress({required this.progress, this.speed, this.eta, this.status});
}

class YtdlpException implements Exception {
  final String message;
  YtdlpException(this.message);

  @override
  String toString() => 'YtdlpException: $message';
}
