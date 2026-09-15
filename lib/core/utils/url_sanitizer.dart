class UrlSanitizer {
  static const List<String> _sensitiveParams = [
    'cookie',
    'cookies',
    'token',
    'key',
    'auth',
    'session',
    'sid',
    'ssid',
    'access_token',
    'refresh_token',
    'api_key',
    'apikey',
    'secret',
    'password',
    'pwd',
    'pass',
    'credentials',
    'oauth',
    'bearer',
    'jwt',
    'signature',
    'sig',
    'nonce',
    'timestamp',
    'hash',
  ];

  static const List<String> _sensitiveHeaders = [
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'x-auth-token',
    'x-access-token',
    'x-csrf-token',
    // YouTube / Google-specific headers that carry identifying tokens (M4).
    'x-youtube-identity-token',
    'x-goog-api-key',
    'x-goog-authuser',
    'x-goog-visitor-id',
  ];

  /// Header-name prefixes whose values should always be redacted even if the
  /// exact name isn't in [_sensitiveHeaders] (covers rotating variants like
  /// `x-youtube-*`, `x-goog-*`).
  static const List<String> _sensitiveHeaderPrefixes = [
    'x-youtube-',
    'x-goog-',
  ];

  static String sanitize(String input) {
    if (input.isEmpty) return input;

    try {
      final urlPattern = RegExp(
        r'https?://[^\s<>"{}|\\^`\[\]]+',
        caseSensitive: false,
      );

      return input.replaceAllMapped(urlPattern, (match) {
        return _sanitizeUrl(match.group(0)!);
      });
    } catch (e) {
      return _sanitizeSensitiveData(input);
    }
  }

  static String _sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // Detect a sensitive query parameter anywhere in the URL.
      final hasSensitiveParam = uri.queryParameters.keys.any(
        (key) => _isSensitiveKey(key),
      );

      // Also detect a sensitive token in the URL fragment. Tokens are
      // frequently delivered in the fragment (e.g. OAuth implicit grants put
      // `#access_token=...` there), so the fragment must be inspected too (M4).
      final hasSensitiveFragment = _fragmentContainsSensitiveData(
        uri.fragment,
      );

      if (!hasSensitiveParam && !hasSensitiveFragment) return url;

      final sanitizedParams = Map<String, String>.fromEntries(
        uri.queryParameters.entries.where(
          (entry) => !_isSensitiveKey(entry.key),
        ),
      );

      // Drop the fragment entirely if it carried anything sensitive; otherwise
      // preserve it.
      final sanitizedFragment = hasSensitiveFragment ? '' : uri.fragment;

      final sanitizedUri = uri.replace(
        queryParameters: sanitizedParams,
        fragment: sanitizedFragment,
      );
      return sanitizedUri.toString();
    } catch (e) {
      return _sanitizeSensitiveData(url);
    }
  }

  /// True when [key] (case-insensitive) matches any sensitive substring.
  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return _sensitiveParams.any((sensitive) => lower.contains(sensitive));
  }

  /// Inspects a URL fragment for `key=value` style tokens with sensitive keys.
  /// Fragments use both `&` and `;` as separators across OAuth providers.
  static bool _fragmentContainsSensitiveData(String fragment) {
    if (fragment.isEmpty) return false;
    final lower = fragment.toLowerCase();
    // Match `access_token=`, `token:`, etc. anywhere in the fragment.
    for (final sensitive in _sensitiveParams) {
      if (lower.contains('$sensitive=') ||
          lower.contains('$sensitive:')) {
        return true;
      }
    }
    return false;
  }

  static String _sanitizeSensitiveData(String input) {
    String result = input;

    for (final param in _sensitiveParams) {
      final patterns = [
        RegExp('$param=[^&\\s]*', caseSensitive: false),
        RegExp('$param\\s*[:=]\\s*[^\\s,;]*', caseSensitive: false),
      ];

      for (final pattern in patterns) {
        result = result.replaceAllMapped(pattern, (match) {
          final matchStr = match.group(0)!;
          final separatorIndex = matchStr.indexOf(RegExp(r'[=:]'));
          if (separatorIndex == -1) return matchStr;
          
          final key = matchStr.substring(0, separatorIndex + 1);
          return '$key[REDACTED]';
        });
      }
    }

    return result;
  }

  static String sanitizeHeaders(Map<String, String> headers) {
    final sanitized = <String, String>{};

    for (final entry in headers.entries) {
      final lower = entry.key.toLowerCase();
      final isSensitive = _sensitiveHeaders.contains(lower) ||
          _sensitiveHeaderPrefixes.any((prefix) => lower.startsWith(prefix));
      sanitized[entry.key] = isSensitive ? '[REDACTED]' : entry.value;
    }

    return sanitized.toString();
  }

  static String sanitizeJson(Map<String, dynamic> json) {
    final sanitized = <String, dynamic>{};

    for (final entry in json.entries) {
      final isSensitive = _sensitiveParams.any(
        (sensitive) => entry.key.toLowerCase().contains(sensitive),
      );

      if (isSensitive) {
        sanitized[entry.key] = '[REDACTED]';
      } else if (entry.value is String) {
        sanitized[entry.key] = sanitize(entry.value as String);
      } else if (entry.value is Map) {
        sanitized[entry.key] = sanitizeJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      } else {
        sanitized[entry.key] = entry.value;
      }
    }

    return sanitized.toString();
  }

  static bool containsSensitiveData(String input) {
    final lowerInput = input.toLowerCase();
    return _sensitiveParams.any(
      (param) => lowerInput.contains('$param=') || lowerInput.contains('$param:'),
    );
  }
}