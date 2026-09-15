import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/utils/version_utils.dart';
import 'certificate_pinning_service.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime publishedAt;
  final String? assetName;
  final int? assetSize;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
    this.assetName,
    this.assetSize,
  });
}

/// Thrown when Android "Install unknown apps" is not granted for this app.
/// Callers should route the user to system Settings instead of retrying.
class InstallPermissionDeniedException implements Exception {
  final String message;
  const InstallPermissionDeniedException([
    this.message =
        'Enable "Install unknown apps" for AeroTube in system settings, then retry.',
  ]);
  @override
  String toString() => 'InstallPermissionDeniedException: $message';
}

class UpdateService {
  static const String _releasesUrl = AppConstants.appLatestReleaseApiUrl;

  /// Channel used for FileProvider + APK install on Android.
  static const _fileProviderChannel =
      MethodChannel('com.aerotube.youtube_downloader/file_provider');

  final CertificatePinningService _certPinningService = CertificatePinningService();

  // ── Rate-limit friendly cache / throttle ──────────────────────────────────
  UpdateInfo? _cachedResult;
  String? _cachedForVersion;
  DateTime? _cacheTime;
  String? _cachedLatestTag;
  static DateTime? _lastFetchAttempt;
  static const Duration _cacheExpiry = Duration(minutes: 60);
  static const Duration _throttleWindow = Duration(seconds: 60);
  bool _hasCache = false;

  String? _getGithubToken() {
    try {
      final env = Platform.environment['GITHUB_TOKEN'];
      if (env != null && env.isNotEmpty) return env;
    } catch (_) {}
    const fromEnv = String.fromEnvironment('GITHUB_TOKEN');
    if (fromEnv.isNotEmpty) return fromEnv;
    return null;
  }

  bool _isRateLimitError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('rate limit') ||
        msg.contains('403') ||
        msg.contains('429');
  }

  // ── ABI detection ─────────────────────────────────────────────────────────

  /// Returns the primary ABI of the device, e.g. "arm64-v8a".
  /// Falls back to empty string on non-Android or on error.
  Future<String> getDeviceAbi() async {
    if (!PlatformUtils.isAndroid) return '';
    try {
      final String? abi =
          await _fileProviderChannel.invokeMethod<String>('getDeviceAbi');
      return abi ?? '';
    } catch (_) {
      // Channel doesn't have the method yet → graceful fallback
      return '';
    }
  }

  // ── Update check ──────────────────────────────────────────────────────────

  /// Check for available updates from GitHub.
  /// Set [force] to true to bypass cache/throttle (manual "Check" button).
  Future<UpdateInfo?> checkForUpdate(
    String currentVersion, {
    bool force = false,
  }) async {
    final now = DateTime.now();

    if (force) {
      // Manual check: clear throttle so we always hit the network.
      _lastFetchAttempt = null;
    } else {
      // ── Throttle: at most once per 60s
      if (_lastFetchAttempt != null &&
          now.difference(_lastFetchAttempt!) < _throttleWindow) {
        if (_hasCache &&
            _cacheTime != null &&
            now.difference(_cacheTime!) < _cacheExpiry &&
            _cachedForVersion == currentVersion) {
          // Return cached result (null means up-to-date, still avoids hammering)
          return _cachedResult;
        }
        // If we have a cached latest tag, we can answer without network
        if (_cachedLatestTag != null &&
            _cacheTime != null &&
            now.difference(_cacheTime!) < _cacheExpiry) {
          if (!VersionUtils.isNewerVersion(currentVersion, _cachedLatestTag!)) {
            return null;
          }
          if (_cachedResult != null &&
              _cachedForVersion == currentVersion) {
            return _cachedResult;
          }
        }
        // No fresh cache but throttled -> return cached if any to avoid hammer
        if (_cachedLatestTag != null && _hasCache) {
          if (_cachedResult != null &&
              _cachedForVersion == currentVersion) {
            return _cachedResult;
          }
          if (_cachedLatestTag != null &&
              !VersionUtils.isNewerVersion(currentVersion, _cachedLatestTag!)) {
            return null;
          }
        }
      }

      // ── Cache: if last check <60min and for same version, reuse
      if (_hasCache &&
          _cacheTime != null &&
          now.difference(_cacheTime!) < _cacheExpiry &&
          _cachedForVersion == currentVersion) {
        return _cachedResult;
      }
      if (_cachedLatestTag != null &&
          _cacheTime != null &&
          now.difference(_cacheTime!) < _cacheExpiry &&
          _cachedForVersion == currentVersion) {
        // We have latest tag cached, decide without network
        if (!VersionUtils.isNewerVersion(currentVersion, _cachedLatestTag!)) {
          return null;
        }
        if (_cachedResult != null) return _cachedResult;
      }
    }

    _lastFetchAttempt = now;

    Future<UpdateInfo?> tryFetch(HttpClient client) async {
      final uri = Uri.parse(_releasesUrl);
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      request.headers.set('User-Agent', 'AeroTube-Updater');
      final token = _getGithubToken();
      if (token != null && token.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $token');
      }

      final httpResponse =
          await request.close().timeout(const Duration(seconds: 15));
      final responseBody = await httpResponse.transform(utf8.decoder).join();

      if (httpResponse.statusCode == 403 ||
          httpResponse.statusCode == 429) {
        final snippet = responseBody.length > 300
            ? '${responseBody.substring(0, 300)}...'
            : responseBody;
        throw Exception(
          'GitHub API rate limit (${httpResponse.statusCode}). $snippet '
          'GitHub API rate limited (shared VPN IP 104.28.x.x?). '
          'Try again in a few minutes or set GITHUB_TOKEN env var for higher limits.',
        );
      }
      if (httpResponse.statusCode != 200) {
        final snippet = responseBody.length > 300
            ? '${responseBody.substring(0, 300)}...'
            : responseBody;
        throw Exception(
          'Failed to check for updates: HTTP ${httpResponse.statusCode}. $snippet',
        );
      }

      final data = json.decode(responseBody);
      final latestVersion = data['tag_name'] as String?;

      if (latestVersion == null) return null;

      // Cache latest tag for throttle fallback
      _cachedLatestTag = latestVersion;

      if (!VersionUtils.isNewerVersion(currentVersion, latestVersion)) {
        return null; // No update available
      }

      final assets = data['assets'] as List<dynamic>?;
      String? downloadUrl;
      String? assetName;
      int? assetSize;

      if (assets != null) {
        if (PlatformUtils.isAndroid) {
          // ── Android: prefer ABI-specific APK, fall back to universal ──────
          final deviceAbi = await getDeviceAbi();

          // Try ABI-specific match first
          if (deviceAbi.isNotEmpty) {
            for (final asset in assets) {
              final name = asset['name'] as String? ?? '';
              if (name.contains(deviceAbi) && name.endsWith('.apk')) {
                downloadUrl = asset['browser_download_url'] as String?;
                assetName = name;
                assetSize = asset['size'] as int?;
                break;
              }
            }
          }

          // Fall back to universal APK
          if (downloadUrl == null) {
            for (final asset in assets) {
              final name = asset['name'] as String? ?? '';
              if (name.contains('universal') && name.endsWith('.apk')) {
                downloadUrl = asset['browser_download_url'] as String?;
                assetName = name;
                assetSize = asset['size'] as int?;
                break;
              }
            }
          }

          // Last resort: any APK
          if (downloadUrl == null) {
            for (final asset in assets) {
              final name = asset['name'] as String? ?? '';
              if (name.endsWith('.apk')) {
                downloadUrl = asset['browser_download_url'] as String?;
                assetName = name;
                assetSize = asset['size'] as int?;
                break;
              }
            }
          }
        } else {
          // ── Windows: keep existing .exe / .zip / .msix logic ──────────────
          for (final asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name.contains('windows') ||
                name.endsWith('.exe') ||
                name.endsWith('.zip') ||
                name.endsWith('.msix')) {
              downloadUrl = asset['browser_download_url'] as String?;
              assetName = name;
              assetSize = asset['size'] as int?;
              break;
            }
          }
        }
      }

      // Fallback to source zip if nothing matched
      downloadUrl ??= data['zipball_url'] as String?;

      if (downloadUrl == null) return null;

      return UpdateInfo(
        version: VersionUtils.cleanVersion(latestVersion),
        downloadUrl: downloadUrl,
        releaseNotes: data['body'] as String? ?? 'No release notes available',
        publishedAt: DateTime.parse(data['published_at'] as String),
        assetName: assetName,
        assetSize: assetSize,
      );
    }

    try {
      final client = _certPinningService.createPinnedHttpClient();
      final result = await tryFetch(client);
      // Cache result
      _cachedResult = result;
      _cachedForVersion = currentVersion;
      _cacheTime = DateTime.now();
      _hasCache = true;
      try {
        client.close(force: true);
      } catch (_) {}
      return result;
    } catch (e) {
      // Rate limit -> return cached if available, don't fallback with same request
      if (_isRateLimitError(e)) {
        if (_hasCache &&
            _cachedForVersion == currentVersion &&
            _cachedResult != null) {
          return _cachedResult;
        }
        if (_cachedLatestTag != null &&
            !VersionUtils.isNewerVersion(currentVersion, _cachedLatestTag!)) {
          // Cached says up-to-date
          return null;
        }
        // Propagate with richer context, but keep snippet already included
        throw Exception('Failed to check for updates (rate limited): $e');
      }
      // Non-rate-limit error -> try plain fallback once
      HttpClient? fallback;
      try {
        fallback = HttpClient();
        final result = await tryFetch(fallback);
        _cachedResult = result;
        _cachedForVersion = currentVersion;
        _cacheTime = DateTime.now();
        _hasCache = true;
        fallback.close(force: true);
        return result;
      } catch (e2) {
        fallback?.close(force: true);
        if (_isRateLimitError(e2)) {
          if (_hasCache &&
              _cachedForVersion == currentVersion &&
              _cachedResult != null) {
            return _cachedResult;
          }
          if (_cachedLatestTag != null &&
              !VersionUtils.isNewerVersion(currentVersion, _cachedLatestTag!)) {
            return null;
          }
          throw Exception('Failed to check for updates (rate limited): $e2');
        }
        throw Exception('Failed to check for updates: $e2');
      }
    }
  }



  /// Downloads the update file and reports progress via [onProgress] (0.0–1.0).
  /// Streams to disk (no full-file memory buffer) so large APKs stay safe.
  /// Returns the local file path of the downloaded file.
  Future<String> downloadUpdate(
    String url,
    Function(double) onProgress, {
    String? expectedSha256,
    bool Function()? isCancelled,
  }) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' ||
        (!uri.host.endsWith('github.com') &&
            !uri.host.endsWith('githubusercontent.com'))) {
      throw Exception('Untrusted update download host: ${uri.host}');
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = path.basename(uri.path);
    final filePath = path.join(
      tempDir.path,
      fileName.isEmpty ? 'update.apk' : fileName,
    );
    final file = File(filePath);
    final sink = file.openWrite();

    try {
      final client = _certPinningService.createPinnedHttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      var received = 0;

      await for (final chunk in response) {
        if (isCancelled?.call() == true) {
          throw Exception('Download cancelled');
        }
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress((received / contentLength).clamp(0.0, 1.0));
        }
      }

      await sink.flush();
      await sink.close();

      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        final bytes = await file.readAsBytes();
        final computed = sha256.convert(bytes).toString();
        if (computed.toLowerCase() != expectedSha256.toLowerCase()) {
          await file.delete().catchError((_) => file);
          throw Exception(
            'SHA-256 verification failed for update. Expected $expectedSha256, got $computed',
          );
        }
      }

      onProgress(1.0);
      return filePath;
    } catch (e) {
      await sink.close().catchError((_) {});
      await file.delete().catchError((_) => file);
      rethrow;
    }
  }

  // ── Install (Windows) ─────────────────────────────────────────────────────

  /// Launches the installer on Windows.
  /// On Android, use [launchAndroidInstaller] instead.
  Future<void> launchInstaller(String filePath) async {
    if (!PlatformUtils.isWindows) return;
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Installer file not found');
      }

      if (filePath.endsWith('.exe')) {
        await Process.start(filePath, [], mode: ProcessStartMode.detached);
      } else if (filePath.endsWith('.zip')) {
        await Process.start('explorer.exe', [file.parent.path]);
      } else if (filePath.endsWith('.msix')) {
        await Process.start(
          'powershell.exe',
          ['-Command', 'Add-AppxPackage', '-Path', filePath],
          mode: ProcessStartMode.detached,
        );
      }
    } catch (e) {
      throw Exception('Failed to launch installer: $e');
    }
  }

  // ── Install (Android) ─────────────────────────────────────────────────────

  /// Whether the system allows this app to install APKs (Android 8+).
  /// Returns true on non-Android and on pre-O devices (no runtime toggle).
  Future<bool> canRequestPackageInstalls() async {
    if (!PlatformUtils.isAndroid) return true;
    try {
      final granted = await _fileProviderChannel.invokeMethod<bool>(
        'canRequestPackageInstalls',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system "Install unknown apps" page for this app.
  /// Completes after the user returns; re-check [canRequestPackageInstalls].
  Future<bool> requestInstallPermission() async {
    if (!PlatformUtils.isAndroid) return true;
    try {
      final granted = await _fileProviderChannel.invokeMethod<bool>(
        'requestInstallPermission',
      );
      return granted ?? false;
    } catch (_) {
      return canRequestPackageInstalls();
    }
  }

  /// Fire-and-forget open of the install-unknown-apps settings page.
  Future<bool> openInstallSettings() async {
    if (!PlatformUtils.isAndroid) return false;
    try {
      final ok = await _fileProviderChannel.invokeMethod<bool>(
        'openInstallSettings',
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static bool isInstallPermissionError(Object e) {
    final msg = e.toString();
    return e is InstallPermissionDeniedException ||
        msg.contains('INSTALL_PERMISSION_DENIED') ||
        msg.contains('Install unknown apps');
  }

  /// Triggers the system APK installer via FileProvider on Android.
  /// Throws [InstallPermissionDeniedException] when the system
  /// "Install unknown apps" toggle is off, so callers can route to Settings
  /// instead of failing silently. The user sees the standard Install prompt.
  Future<void> launchAndroidInstaller(String filePath) async {
    if (!PlatformUtils.isAndroid) return;
    try {
      final allowed = await canRequestPackageInstalls();
      if (!allowed) {
        throw const InstallPermissionDeniedException();
      }
      await _fileProviderChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
    } on InstallPermissionDeniedException {
      rethrow;
    } on PlatformException catch (e) {
      if (e.code == 'INSTALL_PERMISSION_DENIED') {
        throw InstallPermissionDeniedException(
          e.message ??
              'Enable "Install unknown apps" for AeroTube in system settings, then retry.',
        );
      }
      throw Exception('Failed to launch Android installer: ${e.message}');
    } catch (e) {
      if (isInstallPermissionError(e)) {
        throw InstallPermissionDeniedException(e.toString());
      }
      throw Exception('Failed to launch Android installer: $e');
    }
  }

  // ── Current version ───────────────────────────────────────────────────────

  /// Returns the current app version from package metadata.
  Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }
}
