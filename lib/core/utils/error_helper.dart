class ErrorHelper {
  final String friendlyMessage;
  final String? suggestion;
  final ErrorCategory category;

  ErrorHelper({
    required this.friendlyMessage,
    this.suggestion,
    this.category = ErrorCategory.unknown,
  });

  static ErrorHelper parse(String error) {
    if (error.contains('Sign in to confirm you')) {
      return ErrorHelper(
        friendlyMessage: 'Authentication required',
        suggestion: 'Please login to YouTube in Settings or provide a cookies file.',
        category: ErrorCategory.authentication,
      );
    }
    if (error.contains('Incomplete cookies file')) {
      return ErrorHelper(
        friendlyMessage: 'Invalid cookies file',
        suggestion: 'The cookies file is missing critical authentication data.',
        category: ErrorCategory.authentication,
      );
    }
    if (error.contains('HTTP Error 429') || error.contains('rate limit')) {
      return ErrorHelper(
        friendlyMessage: 'Too many requests',
        suggestion: 'YouTube is rate-limiting you. Please wait before trying again.',
        category: ErrorCategory.rateLimit,
      );
    }
    if (error.contains('Video unavailable')) {
      return ErrorHelper(
        friendlyMessage: 'Video unavailable',
        suggestion: 'The video might be private, deleted, or region-locked.',
        category: ErrorCategory.content,
      );
    }
    // Network errors
    if (error.contains('SocketException') ||
        error.contains('Network is unreachable') ||
        error.contains('Connection refused') ||
        error.contains('Connection timed out') ||
        error.contains('Network error') ||
        error.contains('Failed to connect')) {
      return ErrorHelper(
        friendlyMessage: 'Network connection error',
        suggestion: 'Check your internet connection and try again.',
        category: ErrorCategory.network,
      );
    }
    // Timeout errors
    if (error.contains('TimeoutException') ||
        error.contains('Request timeout') ||
        error.contains('operation timed out')) {
      return ErrorHelper(
        friendlyMessage: 'Request timed out',
        suggestion: 'The operation took too long. Please check your connection and try again.',
        category: ErrorCategory.network,
      );
    }
    // File system errors
    if (error.contains('File not found') ||
        error.contains('No such file') ||
        error.contains('ENOENT')) {
      return ErrorHelper(
        friendlyMessage: 'File not found',
        suggestion: 'The required file does not exist. Please check the file path.',
        category: ErrorCategory.fileSystem,
      );
    }
    if (error.contains('Permission denied') ||
        error.contains('EACCES') ||
        error.contains('access is denied')) {
      return ErrorHelper(
        friendlyMessage: 'Permission denied',
        suggestion: 'The app does not have permission to access this file or resource.',
        category: ErrorCategory.permission,
      );
    }
    if (error.contains('No space left') ||
        error.contains('ENOSPC') ||
        error.contains('disk full')) {
      return ErrorHelper(
        friendlyMessage: 'Disk space error',
        suggestion: 'Your device is out of storage space. Please free up some space and try again.',
        category: ErrorCategory.fileSystem,
      );
    }
    // SSL/TLS errors
    if (error.contains('SSL') ||
        error.contains('TLS') ||
        error.contains('certificate') ||
        error.contains('handshake')) {
      return ErrorHelper(
        friendlyMessage: 'Secure connection error',
        suggestion: 'Failed to establish a secure connection. Please check your network settings.',
        category: ErrorCategory.security,
      );
    }
    // Invalid URL
    if (error.contains('Invalid URL') ||
        error.contains('Malformed URL') ||
        error.contains('URI format')) {
      return ErrorHelper(
        friendlyMessage: 'Invalid URL format',
        suggestion: 'Please check the URL and try again.',
        category: ErrorCategory.validation,
      );
    }
    // Process errors
    if (error.contains('ProcessException') ||
        error.contains('Process exited') ||
        error.contains('command not found')) {
      return ErrorHelper(
        friendlyMessage: 'Process execution error',
        suggestion: 'Failed to execute the required process. Please check if all tools are properly installed.',
        category: ErrorCategory.process,
      );
    }
    // JSON parsing errors
    if (error.contains('FormatException') ||
        error.contains('JSON') ||
        error.contains('parsing')) {
      return ErrorHelper(
        friendlyMessage: 'Data format error',
        suggestion: 'Received unexpected data format. The service may have changed its response format.',
        category: ErrorCategory.data,
      );
    }
    // Cancellation/abort errors
    if (error.contains('cancelled') ||
        error.contains('aborted') ||
        error.contains('Canceled')) {
      return ErrorHelper(
        friendlyMessage: 'Operation cancelled',
        suggestion: 'The operation was cancelled.',
        category: ErrorCategory.user,
      );
    }

    // Default fallback - don't truncate, use full error with smart summary
    return ErrorHelper(
      friendlyMessage: 'An error occurred',
      suggestion: _generateSuggestion(error),
      category: ErrorCategory.unknown,
    );
  }

  static String _generateSuggestion(String error) {
    // Extract first meaningful line or summarize
    final lines = error.split('\\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return 'An unknown error occurred. Please try again.';
    }
    
    // Use first line if it's reasonably short, otherwise summarize
    final firstLine = lines.first;
    if (firstLine.length <= 200) {
      return firstLine;
    }
    
    // Extract key error type
    final errorMatch = RegExp(r'([A-Za-z]+(?:Exception|Error))').firstMatch(error);
    if (errorMatch != null) {
      return '${errorMatch.group(1)}: ${firstLine.substring(0, 150)}...';
    }
    
    return '${firstLine.substring(0, 150)}...';
  }
}

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
  unknown,
}
