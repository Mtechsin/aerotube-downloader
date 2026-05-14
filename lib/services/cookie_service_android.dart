import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'logging_service.dart';

import 'cookie_service.dart';

/// Android-specific CookieService using flutter_web_auth_2
class CookieServiceAndroid extends CookieService {
  static const String _authTokenKey = 'youtube_auth_token';
  static const String _refreshTokenKey = 'youtube_refresh_token';
  static const String _tokenExpiryKey = 'youtube_token_expiry';
  static const String _isLoggedInKey = 'youtube_is_logged_in';
  static const String _codeVerifierKey = 'youtube_oauth_code_verifier';

  static const String _clientId =
      'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
  static const String _redirectUri =
      'com.youtube.downloader:/oauth2callback';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LoggingService _logger = LoggingService();

  bool _isLoggedIn = false;
  DateTime? _tokenExpiry;
  String? _cachedAuthToken;

  /// Initialize the service
  @override
  Future<void> init() async {
    try {
      // Load login status from shared preferences
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      final expiryTimestamp = prefs.getString(_tokenExpiryKey);
      if (expiryTimestamp != null) {
        _tokenExpiry = DateTime.parse(expiryTimestamp);
      }

      // Load cached auth token
      _cachedAuthToken = await _secureStorage.read(key: _authTokenKey);

      _logger.info(
        'CookieServiceAndroid initialized',
        component: 'CookieServiceAndroid',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize CookieServiceAndroid',
        component: 'CookieServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Check if user is logged in
  @override
  Future<bool> get isLoggedIn async {
    // Check token expiry
    if (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!)) {
      _isLoggedIn = false;
      await _updateLoginStatus(false);
    }
    return _isLoggedIn;
  }

  /// Get last login time (from token expiry)
  @override
  Future<DateTime?> get lastLoginTime async => _tokenExpiry;

  /// Get cached auth token
  Future<String?> get authToken async => _cachedAuthToken;

  /// Perform YouTube login using flutter_web_auth_2
  Future<bool> login({Function(String status)? onStatus}) async {
    try {
      onStatus?.call('Opening YouTube login page...');

      // Generate PKCE code verifier and challenge
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      // Persist the verifier so _exchangeCodeForTokens can retrieve it
      await _secureStorage.write(key: _codeVerifierKey, value: codeVerifier);

      // YouTube OAuth URL
      const authUrl = 'https://accounts.google.com/o/oauth2/v2/auth';

      // Build authorization URL with PKCE
      final authorizationUrl = Uri.parse(authUrl).replace(
        queryParameters: {
          'client_id': _clientId,
          'redirect_uri': _redirectUri,
          'response_type': 'code',
          'scope':
              'openid email profile https://www.googleapis.com/auth/youtube.readonly',
          'access_type': 'offline',
          'prompt': 'consent',
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      );

      onStatus?.call('Waiting for authentication...');

      // Perform authentication
      final result = await FlutterWebAuth2.authenticate(
        url: authorizationUrl.toString(),
        callbackUrlScheme: _redirectUri.split('://')[0],
        options: const FlutterWebAuth2Options(preferEphemeral: false),
      );

      // Extract authorization code from callback URL
      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code == null) {
        throw CookieAndroidException('Authorization code not received');
      }

      onStatus?.call('Exchanging code for tokens...');

      // Exchange code for tokens (this should be done on a backend server for security)
      // For now, we'll simulate receiving tokens
      // In production, call your backend API to exchange the code
      final tokens = await _exchangeCodeForTokens(code);

      if (tokens == null) {
        throw CookieAndroidException('Failed to get tokens');
      }

      // Store tokens securely
      await _storeTokens(
        accessToken: tokens['access_token']!,
        refreshToken: tokens['refresh_token']!,
        expiresIn: int.parse(tokens['expires_in']!),
      );

      _isLoggedIn = true;
      await _updateLoginStatus(true);

      _logger.info(
        'YouTube login successful',
        component: 'CookieServiceAndroid',
      );

      onStatus?.call('Login successful!');
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Login failed',
        component: 'CookieServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      onStatus?.call('Login failed: $e');
      return false;
    }
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Exchange authorization code for tokens
  Future<Map<String, String>?> _exchangeCodeForTokens(String code) async {
    try {
      final codeVerifier = await _secureStorage.read(key: _codeVerifierKey);
      await _secureStorage.delete(key: _codeVerifierKey);

      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'code': code,
          'code_verifier': codeVerifier,
          'grant_type': 'authorization_code',
          'redirect_uri': _redirectUri,
        },
      );

      if (response.statusCode != 200) {
        _logger.error(
          'Token exchange failed: ${response.statusCode} ${response.body}',
          component: 'CookieServiceAndroid',
        );
        return null;
      }

      final Map<String, dynamic> data = json.decode(response.body);
      return {
        'access_token': data['access_token'] as String,
        'refresh_token': data['refresh_token'] as String? ?? '',
        'expires_in': (data['expires_in'] ?? 3600).toString(),
      };
    } catch (e) {
      _logger.error(
        'Failed to exchange code for tokens',
        component: 'CookieServiceAndroid',
        error: e,
      );
      return null;
    }
  }

  /// Store tokens securely
  Future<void> _storeTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    try {
      // Store access token
      await _secureStorage.write(key: _authTokenKey, value: accessToken);
      _cachedAuthToken = accessToken;

      // Store refresh token
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);

      // Store token expiry
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenExpiryKey, _tokenExpiry!.toIso8601String());
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to store tokens',
        component: 'CookieServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      throw CookieAndroidException('Failed to store tokens: $e');
    }
  }

  /// Refresh access token using refresh token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);

      if (refreshToken == null) {
        _logger.warning(
          'No refresh token available',
          component: 'CookieServiceAndroid',
        );
        return false;
      }

      // In production, call your backend API to refresh the token
      // For now, simulate token refresh
      final newTokens = await _refreshTokenWithBackend(refreshToken);

      if (newTokens == null) {
        return false;
      }

      // Store new tokens
      await _storeTokens(
        accessToken: newTokens['access_token']!,
        refreshToken: newTokens['refresh_token'] ?? refreshToken,
        expiresIn: int.parse(newTokens['expires_in']!),
      );

      _logger.info(
        'Token refreshed successfully',
        component: 'CookieServiceAndroid',
      );
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to refresh token',
        component: 'CookieServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Refresh token with Google's token endpoint
  Future<Map<String, String>?> _refreshTokenWithBackend(
    String refreshToken,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode != 200) {
        _logger.error(
          'Token refresh failed: ${response.statusCode} ${response.body}',
          component: 'CookieServiceAndroid',
        );
        return null;
      }

      final Map<String, dynamic> data = json.decode(response.body);
      return {
        'access_token': data['access_token'] as String,
        'refresh_token': data['refresh_token'] as String? ?? refreshToken,
        'expires_in': (data['expires_in'] ?? 3600).toString(),
      };
    } catch (e) {
      _logger.error(
        'Failed to refresh token',
        component: 'CookieServiceAndroid',
        error: e,
      );
      return null;
    }
  }

  /// Logout and clear tokens
  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: _authTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenExpiryKey);
      await prefs.remove(_isLoggedInKey);

      _cachedAuthToken = null;
      _tokenExpiry = null;
      _isLoggedIn = false;

      _logger.info('User logged out', component: 'CookieServiceAndroid');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to logout',
        component: 'CookieServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Update login status in shared preferences
  Future<void> _updateLoginStatus(bool loggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, loggedIn);
  }

  /// Get cookie file path for yt-dlp (Android uses tokens instead)
  @override
  Future<String?> get cookieFilePath async {
    if (!_isLoggedIn || _cachedAuthToken == null) {
      return null;
    }

    // On Android, we don't use cookie files
    // Instead, we pass the auth token directly to yt-dlp or use youtube_explode_dart
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'youtube_auth.json');
  }

  /// Get user agent string
  @override
  Future<String?> get userAgent async {
    return 'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
  }

  /// Get WebView path (not used on Android, but required for interface)
  @override
  Future<String?> get webViewPath async => null;

  /// Clear all cookies/tokens
  @override
  Future<void> clearCookies() async {
    await logout();
  }

  /// Export cookies to file (for compatibility with yt-dlp if needed)
  Future<void> exportCookiesToFile(String filePath) async {
    if (!_isLoggedIn) {
      throw CookieAndroidException('Not logged in');
    }

    try {
      final file = File(filePath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }

      // Export auth token as JSON
      final cookieData = {
        'auth_token': _cachedAuthToken,
        'token_expiry': _tokenExpiry?.toIso8601String(),
        'user_agent': await userAgent,
      };

      await file.writeAsString(jsonEncode(cookieData));

      _logger.info(
        'Cookies exported to $filePath',
        component: 'CookieServiceAndroid',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to export cookies',
        component: 'CookieServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      throw CookieAndroidException('Failed to export cookies: $e');
    }
  }

  /// Import cookies from file
  Future<void> importCookiesFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw CookieAndroidException('Cookie file not found');
      }

      final content = await file.readAsString();
      final cookieData = jsonDecode(content) as Map<String, dynamic>;

      _cachedAuthToken = cookieData['auth_token'] as String?;

      if (cookieData['token_expiry'] != null) {
        _tokenExpiry = DateTime.parse(cookieData['token_expiry'] as String);
      }

      if (_cachedAuthToken != null) {
        await _secureStorage.write(key: _authTokenKey, value: _cachedAuthToken);
        _isLoggedIn = true;
        await _updateLoginStatus(true);
      }

      _logger.info(
        'Cookies imported from $filePath',
        component: 'CookieServiceAndroid',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to import cookies',
        component: 'CookieServiceAndroid',
        error: e,
        stackTrace: stackTrace,
      );
      throw CookieAndroidException('Failed to import cookies: $e');
    }
  }
}

/// Exception for Android-specific cookie errors
class CookieAndroidException implements Exception {
  final String message;
  CookieAndroidException(this.message);

  @override
  String toString() => 'CookieAndroidException: $message';
}
