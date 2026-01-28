import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CookieService {
  String? _cachedWebViewPath;

  bool _isLoggedIn = false;
  DateTime? _lastLoginTime;

  Future<void> init() async {
    // Initial check
    await _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final userDataPath = await webViewPath;
    if (userDataPath != null) {
       // WebView2 on Windows stores cookies in Default/Network/Cookies or similar
       // But we just check if the directory has content which implies usage
       final dir = Directory(userDataPath);
       if (dir.existsSync() && dir.listSync().isNotEmpty) {
          _isLoggedIn = true;
          _lastLoginTime = dir.statSync().modified; // Approximation
       } else {
         _isLoggedIn = false;
         _lastLoginTime = null;
       }
    } else {
      _isLoggedIn = false;
      _lastLoginTime = null;
    }
  }

  Future<bool> get isLoggedIn async {
    await _checkLoginStatus();
    return _isLoggedIn;
  }

  Future<DateTime?> get lastLoginTime async {
    if (_lastLoginTime == null) await _checkLoginStatus();
    return _lastLoginTime;
  }

  Future<String?> get webViewPath async {
    if (_cachedWebViewPath != null) return _cachedWebViewPath;
    
    try {
      final dir = await getApplicationSupportDirectory();
      // Use a consistent path for the cookies file
      // We want a directory for the WebView user data, not just a file
      final userDataDir = Directory(p.join(dir.path, 'webview_cookies'));
      if (!userDataDir.existsSync()) {
        userDataDir.createSync(recursive: true);
      }
      _cachedWebViewPath = userDataDir.path;
      return _cachedWebViewPath;
    } catch (e) {
      print('Error getting WebView cookies path: $e');
      return null;
    }
  }

  Future<String?> get userAgent async {
    // Return a default user agent or one cached from webview
    // For now hardcode a modern one similar to what we'd want
    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  }

  Future<String?> get cookieFilePath async => webViewPath;

  Future<void> clearCookies() async {
    final path = await webViewPath;
    if (path != null) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (e) {
          print('Error clearing cookies: $e');
        }
      }
    }
    _isLoggedIn = false;
  }
}
