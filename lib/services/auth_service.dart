import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logging_service.dart';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

/// Service for securely storing and retrieving authentication tokens
class AuthService {
  static const String _authTokenKey = 'youtube_auth_token';
  static const String _refreshTokenKey = 'youtube_refresh_token';
  static const String _tokenExpiryKey = 'youtube_token_expiry';
  static const String _isLoggedInKey = 'youtube_is_logged_in';
  static const String _userIdKey = 'youtube_user_id';
  static const String _userNameKey = 'youtube_user_name';

  static const String _clientId =
      'YOUR_CLIENT_ID.apps.googleusercontent.com'; // TODO: Replace with your actual Google OAuth client ID
  static const String _redirectUri =
      'myapp://oauth2callback'; // TODO: Configure custom scheme in AndroidManifest.xml
  static const List<String> _scopes = [
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/youtube.readonly',
  ];

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final LoggingService _logger = LoggingService();

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

  /// Store authentication token
  Future<void> storeAuthToken({
    required String accessToken,
    String? refreshToken,
    required DateTime expiry,
    String? userId,
    String? userName,
  }) async {
    try {
      await _secureStorage.write(key: _authTokenKey, value: accessToken);

      if (refreshToken != null) {
        await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
      }

      if (userId != null) {
        await _secureStorage.write(key: _userIdKey, value: userId);
      }

      if (userName != null) {
        await _secureStorage.write(key: _userNameKey, value: userName);
      }

      // Store expiry in shared preferences (not sensitive)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenExpiryKey, expiry.toIso8601String());
      await prefs.setBool(_isLoggedInKey, true);

      _logger.info('Auth token stored successfully', component: 'AuthService');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to store auth token',
        component: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get authentication token
  Future<String?> getAuthToken() async {
    try {
      return await _secureStorage.read(key: _authTokenKey);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to read auth token',
        component: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _refreshTokenKey);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to read refresh token',
        component: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Check if token is expired
  Future<bool> isTokenExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryStr = prefs.getString(_tokenExpiryKey);

      if (expiryStr == null) return true;

      final expiry = DateTime.parse(expiryStr);
      return DateTime.now().isAfter(expiry);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check token expiry',
        component: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return true;
    }
  }

  /// Get user ID
  Future<String?> getUserId() async {
    try {
      return await _secureStorage.read(key: _userIdKey);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to read user ID',
        component: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get user name
  Future<String?> getUserName() async {
    try {
      return await _secureStorage.read(key: _userNameKey);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to read user name',
        component: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check login status',
        component: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Clear all authentication data
  Future<void> clearAuth() async {
    try {
      await _secureStorage.delete(key: _authTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _userIdKey);
      await _secureStorage.delete(key: _userNameKey);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenExpiryKey);
      await prefs.remove(_isLoggedInKey);

      _logger.info('Auth data cleared', component: 'AuthService');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to clear auth data',
        component: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all stored auth data (for debugging)
  Future<Map<String, dynamic>> getAuthData() async {
    final data = <String, dynamic>{};

    try {
      data['authToken'] = await getAuthToken();
      data['refreshToken'] = await getRefreshToken();
      data['userId'] = await getUserId();
      data['userName'] = await getUserName();
      data['isLoggedIn'] = await isLoggedIn();
      data['tokenExpired'] = await isTokenExpired();

      final prefs = await SharedPreferences.getInstance();
      data['tokenExpiry'] = prefs.getString(_tokenExpiryKey);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get auth data',
        component: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return data;
  }

  /// Performs the YouTube OAuth 2.0 login flow using PKCE
  Future<bool> login() async {
    final isLoggedInFlag = await isLoggedIn();
    final isExpired = await isTokenExpired();
    if (isLoggedInFlag && !isExpired) {
      return true;
    }

    final token = await _performAuth();
    return token != null;
  }

  Future<String?> _performAuth() async {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    final stateBytes = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    );
    final state = base64Url
        .encode(stateBytes)
        .replaceAll('=', '')
        .substring(0, 32);

    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': _scopes.join(' '),
      'response_type': 'code',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      'access_type': 'offline',
      'prompt': 'select_account',
    }).toString();

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: _redirectUri.split('://')[0],
      );

      final uri = Uri.parse(result ?? '');
      if (uri.queryParameters['state'] != state) {
        throw const FormatException('State parameter mismatch');
      }

      final code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const FormatException('No authorization code received');
      }

      // Exchange code for tokens
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'code': code,
          'code_verifier': verifier,
          'grant_type': 'authorization_code',
          'redirect_uri': _redirectUri,
        },
      );

      if (response.statusCode != 200) {
        throw http.ClientException(
          'Token exchange failed: ${response.statusCode} ${response.body}',
        );
      }

      final Map<String, dynamic> tokenData = json.decode(response.body);
      final String accessToken = tokenData['access_token'];
      final String? refreshToken = tokenData['refresh_token'];
      final int expiresIn = tokenData['expires_in'] ?? 3600;

      final DateTime expiry = DateTime.now().add(Duration(seconds: expiresIn));

      // Fetch user info
      final userResponse = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (userResponse.statusCode != 200) {
        throw http.ClientException(
          'User info fetch failed: ${userResponse.statusCode} ${userResponse.body}',
        );
      }

      final Map<String, dynamic> userData = json.decode(userResponse.body);
      final String? userId = userData['id'];
      final String? userName = userData['name'] ?? userData['email'];

      await storeAuthToken(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiry: expiry,
        userId: userId,
        userName: userName,
      );

      _logger.info(
        'YouTube authentication successful',
        component: 'AuthService',
      );
      return accessToken;
    } on FormatException catch (e) {
      _logger.error('Auth flow format error: $e', component: 'AuthService');
      return null;
    } catch (e, stackTrace) {
      _logger.error(
        'YouTube auth flow failed',
        component: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Refreshes the access token using the refresh token
  Future<String?> refreshAccessToken() async {
    final String? currentRefreshToken = await getRefreshToken();
    if (currentRefreshToken == null) {
      await clearAuth();
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'refresh_token': currentRefreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode != 200) {
        throw http.ClientException(
          'Refresh failed: ${response.statusCode} ${response.body}',
        );
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final String accessToken = data['access_token'];
      final String? newRefreshToken = data['refresh_token'];
      final int expiresIn = data['expires_in'] ?? 3600;

      final DateTime expiry = DateTime.now().add(Duration(seconds: expiresIn));

      await storeAuthToken(
        accessToken: accessToken,
        refreshToken: newRefreshToken ?? currentRefreshToken,
        expiry: expiry,
        userId: null,
        userName: null,
      );

      _logger.info(
        'Access token refreshed successfully',
        component: 'AuthService',
      );
      return accessToken;
    } catch (e, stackTrace) {
      _logger.error(
        'Token refresh failed',
        component: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      await clearAuth();
      return null;
    }
  }

  /// Returns a valid access token, refreshing if necessary
  Future<String?> getValidAccessToken() async {
    if (!(await isLoggedIn())) {
      return null;
    }

    final bool expired = await isTokenExpired();
    if (expired) {
      return await refreshAccessToken();
    }

    return await getAuthToken();
  }
}
