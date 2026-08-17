class UrlValidator {
  static const Set<String> allowedHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'www.youtu.be',
  };

  static String validate(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) throw UrlValidationException('URL must not be empty');
    if (trimmed.startsWith('-')) {
      throw UrlValidationException('URL must not start with a dash');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw UrlValidationException('Invalid URL: $trimmed');
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw UrlValidationException('URL must use http or https scheme');
    }
    final host = uri.host.toLowerCase();
    if (!allowedHosts.contains(host)) {
      throw UrlValidationException('URL host "$host" is not a supported YouTube domain');
    }
    return trimmed;
  }
}

class UrlValidationException implements Exception {
  final String message;
  UrlValidationException(this.message);
  @override
  String toString() => 'UrlValidationException: $message';
}
