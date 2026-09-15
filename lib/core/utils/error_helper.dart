enum ErrorCategory {
  authentication,
  network,
  fileSystem,
  permission,
  rateLimit,
  content,
  security,
  validation,
  process,
  data,
  user,
  outdatedTool,
  toolUpdate,
  unknown,
}

class ErrorHelper {
  final String title;
  final String friendlyMessage;
  final String? suggestion;
  final ErrorCategory category;
  final String? originalError;
  final String? technicalDetails;

  ErrorHelper({
    String? title,
    required this.friendlyMessage,
    this.suggestion,
    this.category = ErrorCategory.unknown,
    this.originalError,
    this.technicalDetails,
  }) : title = title ?? _defaultTitleForCategory(category);

  static String _defaultTitleForCategory(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.authentication:
        return 'Authentication Required';
      case ErrorCategory.network:
        return 'Network Error';
      case ErrorCategory.fileSystem:
        return 'Storage / File Error';
      case ErrorCategory.permission:
        return 'Permission Denied';
      case ErrorCategory.rateLimit:
        return 'Rate Limit Exceeded';
      case ErrorCategory.content:
        return 'Content Unavailable';
      case ErrorCategory.security:
        return 'Security / SSL Error';
      case ErrorCategory.validation:
        return 'Validation Error';
      case ErrorCategory.process:
        return 'Tool Execution Error';
      case ErrorCategory.toolUpdate:
        return 'Tool Update Error';
      case ErrorCategory.data:
        return 'Data Parsing Error';
      case ErrorCategory.user:
        return 'Operation Cancelled';
      case ErrorCategory.outdatedTool:
        return 'Tool Update Required';
      case ErrorCategory.unknown:
        return 'Error Occurred';
    }
  }

  /// Strips out exception class name prefixes like "YtdlpException: ", "Exception: ", etc.
  static String clean(String raw) {
    var cleaned = raw.trim();
    const exceptionPrefixes = [
      'YtdlpAndroidException: ',
      'YtdlpAndroidException:',
      'YtdlpException: ',
      'YtdlpException:',
      'ProcessException: ',
      'ProcessException:',
      'FileSystemException: ',
      'FileSystemException:',
      'SocketException: ',
      'SocketException:',
      'FormatException: ',
      'FormatException:',
      'ClientException: ',
      'ClientException:',
      'HttpException: ',
      'HttpException:',
      'Exception: ',
      'Exception:',
    ];
    for (final prefix in exceptionPrefixes) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length).trim();
      }
    }
    return cleaned;
  }

  /// Parses an error string into a categorized ErrorHelper with a friendly message and actionable suggestion.
  static ErrorHelper parse(String rawError) {
    final error = clean(rawError);
    final lower = error.toLowerCase();

    // Rate limiting & GitHub API 403
    if (lower.contains('rate limit') ||
        (lower.contains('github') && lower.contains('403')) ||
        lower.contains('http error 429') ||
        lower.contains('429 too many requests') ||
        lower.contains('too many requests') ||
        lower.contains('automated queries')) {
      final isGithub = lower.contains('github') || (lower.contains('yt-dlp') && lower.contains('403'));
      return ErrorHelper(
        title: isGithub ? 'GitHub Rate Limit' : 'Too Many Requests',
        friendlyMessage: 'Too many requests',
        suggestion: isGithub
            ? 'GitHub temporarily limits unauthenticated update requests from your network. Please wait 10-15 minutes or switch internet networks. The app also uses direct mirror fallbacks.'
            : 'YouTube is temporarily rate-limiting requests. Please wait a few minutes before trying again.',
        category: ErrorCategory.rateLimit,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Permission errors
    if (lower.contains('permission denied') ||
        lower.contains('eacces') ||
        lower.contains('access is denied') ||
        lower.contains('permissionexception') ||
        lower.contains('all files access') ||
        lower.contains('storage permission')) {
      return ErrorHelper(
        title: 'Storage Permission Required',
        friendlyMessage: 'The app lacks permission to save files to external storage.',
        suggestion: 'Grant "All files access" in Android Settings, or use the default Downloads/AeroTube folder.',
        category: ErrorCategory.permission,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Filename / invalid-argument failures (Windows pipes, reserved chars)
    if (lower.contains('invalid argument') ||
        lower.contains('errno 22') ||
        lower.contains('einval') ||
        (lower.contains('filename') && lower.contains('invalid')) ||
        lower.contains('unable to open for writing')) {
      return ErrorHelper(
        title: 'Filename Not Allowed',
        friendlyMessage: 'Could not save the file because the title contains characters Windows does not allow.',
        suggestion: 'Retry the download — the app now sanitizes titles (| : * ? " < > \\ are replaced). If it keeps failing, rename the output folder in Settings.',
        category: ErrorCategory.fileSystem,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Native tool update failures
    if (lower.contains('native update failed') ||
        lower.contains('update failed') ||
        lower.contains('platform error') ||
        lower.contains('14.f') ||
        lower.contains('status: update_failed')) {
      return ErrorHelper(
        title: 'Tool Update Failed',
        friendlyMessage: 'Could not complete the yt-dlp update automatically.',
        suggestion: 'Check your internet connection. You can retry with the direct updater from Settings > Tools.',
        category: ErrorCategory.toolUpdate,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Authentication errors
    if (lower.contains('sign in to confirm you') ||
        lower.contains('sign in to confirm your age') ||
        lower.contains('please sign in') ||
        lower.contains('requires authentication') ||
        lower.contains('login required') ||
        lower.contains('bot detection') ||
        lower.contains('http error 403') ||
        lower.contains('403: forbidden') ||
        lower.contains('403 forbidden') ||
        lower.contains('account has been terminated') ||
        lower.contains('members-only') ||
        lower.contains('join this channel to get access')) {
      return ErrorHelper(
        title: 'Authentication Required',
        friendlyMessage: 'Authentication required',
        suggestion: 'Please login to YouTube in Settings or provide a cookies file.',
        category: ErrorCategory.authentication,
        originalError: rawError,
        technicalDetails: error,
      );
    }
    if (lower.contains('incomplete cookies file') ||
        lower.contains('could not parse cookies') ||
        lower.contains('cookie format error')) {
      return ErrorHelper(
        title: 'Invalid Cookies',
        friendlyMessage: 'Invalid cookies file',
        suggestion: 'The cookies file is invalid or missing critical authentication data. Try re-exporting your cookies.',
        category: ErrorCategory.authentication,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // HTTP 416 (Range Not Satisfiable / Resume failure)
    if (lower.contains('http error 416') ||
        lower.contains('requested range not satisfiable')) {
      return ErrorHelper(
        title: 'Resume Rejected',
        friendlyMessage: 'Download resume rejected',
        suggestion: 'The server rejected resuming the partial file. The download will restart from scratch.',
        category: ErrorCategory.network,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Outdated extractor / yt-dlp signature issues
    if (lower.contains('update yt-dlp') ||
        lower.contains('outdated') ||
        lower.contains('unable to extract') ||
        lower.contains('decipher') ||
        lower.contains('signature') ||
        lower.contains('unsupported player_client') ||
        lower.contains('requested format is not available') ||
        lower.contains('nsig extraction failed')) {
      return ErrorHelper(
        title: 'Extractor Update Required',
        friendlyMessage: 'Extractor update required',
        suggestion: 'YouTube updated its player format. yt-dlp updates automatically in the background, or you can tap Update & Retry. If the problem persists, update yt-dlp in Settings → Tools.',
        category: ErrorCategory.outdatedTool,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Content availability
    if (lower.contains('video unavailable') ||
        lower.contains('this video is unavailable') ||
        lower.contains('this video has been removed') ||
        lower.contains('video is not available') ||
        lower.contains('private video') ||
        lower.contains('copyright') ||
        lower.contains('blocked') ||
        lower.contains('geo-restricted') ||
        lower.contains('not available in your country') ||
        lower.contains('no videos found')) {
      return ErrorHelper(
        title: 'Video Unavailable',
        friendlyMessage: 'Video unavailable',
        suggestion: 'The video might be private, deleted, copyright-blocked, or region-restricted.',
        category: ErrorCategory.content,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Network errors (including GitHub server IP addresses like 140.82)
    if (lower.contains('140.82') ||
        lower.contains('socketexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection timed out') ||
        lower.contains('connectexception') ||
        lower.contains('network error') ||
        lower.contains('failed to connect') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('getaddrinfo failed') ||
        lower.contains('nodename nor servname provided') ||
        lower.contains('host not found') ||
        lower.contains('software caused connection abort')) {
      return ErrorHelper(
        title: 'Network Connection Error',
        friendlyMessage: 'Network connection error',
        suggestion: 'Check your internet connection and network settings, then try again.',
        category: ErrorCategory.network,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Timeout errors
    if (lower.contains('timeoutexception') ||
        lower.contains('request timeout') ||
        lower.contains('operation timed out') ||
        lower.contains('timed out')) {
      return ErrorHelper(
        title: 'Request Timed Out',
        friendlyMessage: 'Request timed out',
        suggestion: 'The operation took too long. Please check your internet speed and try again.',
        category: ErrorCategory.network,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Disk space full
    if (lower.contains('no space left') ||
        lower.contains('enospc') ||
        lower.contains('disk full')) {
      return ErrorHelper(
        title: 'Disk Space Full',
        friendlyMessage: 'Disk space full',
        suggestion: 'Your device is out of storage space. Please free up storage and try again.',
        category: ErrorCategory.fileSystem,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // File system errors
    if (lower.contains('file not found') ||
        lower.contains('no such file') ||
        lower.contains('enoent') ||
        lower.contains('pathnotfoundexception') ||
        lower.contains('directory not found')) {
      return ErrorHelper(
        title: 'File Not Found',
        friendlyMessage: 'File not found',
        suggestion: 'The required file or directory does not exist. Check the download path in Settings.',
        category: ErrorCategory.fileSystem,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Security / SSL / TLS
    if (lower.contains('ssl') ||
        lower.contains('tls') ||
        lower.contains('certificate') ||
        lower.contains('handshake') ||
        lower.contains('certificate_verify_failed')) {
      return ErrorHelper(
        title: 'Secure Connection Error',
        friendlyMessage: 'Secure connection error',
        suggestion: 'Failed to establish a secure SSL/TLS connection. Check your system time and network/VPN settings.',
        category: ErrorCategory.security,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // URL validation
    if (lower.contains('invalid url') ||
        lower.contains('malformed url') ||
        lower.contains('uri format') ||
        lower.contains('is not a valid url') ||
        lower.contains('unsupported url')) {
      return ErrorHelper(
        title: 'Invalid URL',
        friendlyMessage: 'Invalid URL format',
        suggestion: 'Please verify the YouTube link format and try again.',
        category: ErrorCategory.validation,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Process errors
    if (lower.contains('processexception') ||
        lower.contains('process exited') ||
        lower.contains('command not found') ||
        lower.contains('executable not found')) {
      return ErrorHelper(
        title: 'Process Execution Error',
        friendlyMessage: 'Process execution error',
        suggestion: 'Failed to run backend tools (yt-dlp/ffmpeg). Please check tool installation in Settings.',
        category: ErrorCategory.process,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Format / Data parsing errors
    if (lower.contains('formatexception') ||
        lower.contains('json') ||
        lower.contains('unexpected end of input')) {
      return ErrorHelper(
        title: 'Data Parsing Error',
        friendlyMessage: 'Data format error',
        suggestion: 'Received unexpected response data. The server response could not be parsed.',
        category: ErrorCategory.data,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // User cancellation
    if (lower.contains('cancelled') ||
        lower.contains('aborted') ||
        lower.contains('canceled')) {
      return ErrorHelper(
        title: 'Operation Cancelled',
        friendlyMessage: 'Operation cancelled',
        suggestion: 'The operation was cancelled by the user.',
        category: ErrorCategory.user,
        originalError: rawError,
        technicalDetails: error,
      );
    }

    // Default fallback
    return ErrorHelper(
      title: 'Error Occurred',
      friendlyMessage: 'An error occurred',
      suggestion: _generateSuggestion(error),
      category: ErrorCategory.unknown,
      originalError: rawError,
      technicalDetails: error,
    );
  }

  /// Unified download error formatter across Windows and Android
  static String formatDownloadError(String output, [int? exitCode]) {
    final cleaned = clean(output);
    final lower = cleaned.toLowerCase();

    if (lower.contains('http error 416') ||
        lower.contains('requested range not satisfiable')) {
      return 'HTTP 416: the server rejected a resume request. The download will restart without continuing partial files.';
    }

    if (cleaned.isEmpty) {
      return exitCode != null
          ? 'Process exited with code $exitCode'
          : 'Download failed';
    }

    // Extract the most descriptive line from yt-dlp stderr output
    // Normalize real CRLF first, then handle any literal "\\n" escapes from wrapped output
    final lines = cleaned
        .replaceAll('\r\n', '\n')
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return exitCode != null
          ? 'Process exited with code $exitCode'
          : 'Download failed';
    }

    final errorLine = lines.firstWhere(
      (l) => l.startsWith('ERROR:') || l.contains('Error:'),
      orElse: () => lines.first,
    );

    return errorLine;
  }

  static String _generateSuggestion(String error) {
    final lines = error
        .replaceAll('\r\n', '\n')
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return 'An unknown error occurred. Please try again.';
    }

    final errorLine = lines.firstWhere(
      (l) => l.startsWith('ERROR:') || l.contains('Error:') || l.contains('Exception:'),
      orElse: () => lines.first,
    );

    var displayLine = errorLine;
    if (displayLine.startsWith('ERROR:')) {
      displayLine = displayLine.replaceFirst('ERROR:', '').trim();
    }

    if (displayLine.length <= 200) {
      return displayLine;
    }

    final errorMatch = RegExp(r'([A-Za-z]+(?:Exception|Error))').firstMatch(error);
    if (errorMatch != null) {
      return '${errorMatch.group(1)}: ${displayLine.substring(0, 150)}...';
    }

    return '${displayLine.substring(0, 150)}...';
  }
}
