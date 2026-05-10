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

      final hasSensitiveParam = uri.queryParameters.keys.any(
        (key) => _sensitiveParams.any(
          (sensitive) => key.toLowerCase().contains(sensitive),
        ),
      );

      if (!hasSensitiveParam) return url;

      final sanitizedParams = Map<String, String>.fromEntries(
        uri.queryParameters.entries.where(
          (entry) => !_sensitiveParams.any(
            (sensitive) => entry.key.toLowerCase().contains(sensitive),
          ),
        ),
      );

      final sanitizedUri = uri.replace(queryParameters: sanitizedParams);
      return sanitizedUri.toString();
    } catch (e) {
      return _sanitizeSensitiveData(url);
    }
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
      final isSensitive = _sensitiveHeaders.contains(entry.key.toLowerCase());
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