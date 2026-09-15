class UrlValidator {
  /// YouTube hosts — used for YouTube-specific features (login, cookies,
  /// search, player-client fallbacks). yt-dlp itself supports far more.
  static const Set<String> youtubeHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'www.youtu.be',
  };

  /// Legacy alias kept for any external callers.
  static const Set<String> allowedHosts = youtubeHosts;

  /// Validates that [url] is a well-formed http(s) URL yt-dlp can attempt.
  /// Any host is accepted — yt-dlp supports hundreds of extractors.
  static String validate(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) throw UrlValidationException('URL must not be empty');
    if (trimmed.startsWith('-')) {
      throw UrlValidationException('URL must not start with a dash');
    }

    // Allow scheme-less input by prepending https:// so users can paste
    // "vimeo.com/123" or "youtube.com/watch?v=…" without typing the scheme.
    final candidate = _looksLikeSchemelessHost(trimmed) ? 'https://$trimmed' : trimmed;

    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority || uri.host.isEmpty) {
      throw UrlValidationException('Invalid URL: $trimmed');
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw UrlValidationException('URL must use http or https scheme');
    }
    // Basic host sanity: at least one dot, no spaces.
    final host = uri.host.toLowerCase();
    if (!host.contains('.') || host.contains(' ')) {
      throw UrlValidationException('Invalid URL host: $host');
    }
    // Return the normalized form (with scheme) so yt-dlp always gets a full URL.
    return candidate;
  }

  static bool _looksLikeSchemelessHost(String input) {
    if (input.contains('://')) return false;
    // e.g. "youtube.com/watch?v=x", "vimeo.com/123", "youtu.be/abc"
    final first = input.split('/').first;
    return first.contains('.') && !first.contains(' ');
  }

  /// Checks whether a given string is a valid YouTube URL (with or without scheme).
  static bool isYouTubeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasAuthority && youtubeHosts.contains(uri.host.toLowerCase())) {
      return true;
    }
    // Also try with a scheme prepended for scheme-less input.
    final withScheme = Uri.tryParse('https://$trimmed');
    if (withScheme != null && youtubeHosts.contains(withScheme.host.toLowerCase())) {
      return true;
    }
    final lower = trimmed.toLowerCase();
    return lower.contains('youtube.com/') ||
        lower.contains('youtu.be/') ||
        lower.contains('music.youtube.com/');
  }

  /// True when [url] looks like a playlist (YouTube `list=` param or a
  /// `/playlist` path segment used by several sites).
  static bool looksLikePlaylist(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.isEmpty) return false;
    return lower.contains('list=') || lower.contains('/playlist');
  }
}

class UrlValidationException implements Exception {
  final String message;
  UrlValidationException(this.message);
  @override
  String toString() => 'UrlValidationException: $message';
}
