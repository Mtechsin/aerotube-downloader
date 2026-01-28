class ErrorHelper {
  final String friendlyMessage;
  final String? suggestion;

  ErrorHelper({required this.friendlyMessage, this.suggestion});

  static ErrorHelper parse(String error) {
    if (error.contains('Sign in to confirm you')) {
      return ErrorHelper(
        friendlyMessage: 'Authentication required',
        suggestion: 'Please login to YouTube in Settings or provide a cookies file.',
      );
    }
    if (error.contains('Incomplete cookies file')) {
      return ErrorHelper(
        friendlyMessage: 'Invalid cookies file',
        suggestion: 'The cookies file is missing critical authentication data.',
      );
    }
    if (error.contains('HTTP Error 429')) {
      return ErrorHelper(
        friendlyMessage: 'Too many requests',
        suggestion: 'YouTube is rate-limiting you. Please wait before trying again.',
      );
    }
    if (error.contains('Video unavailable')) {
      return ErrorHelper(
        friendlyMessage: 'Video unavailable',
        suggestion: 'The video might be private, deleted, or region-locked.',
      );
    }
    
    // Default fallback
    return ErrorHelper(
      friendlyMessage: 'An error occurred',
      suggestion: error.length > 100 ? '${error.substring(0, 100)}...' : error,
    );
  }
}
