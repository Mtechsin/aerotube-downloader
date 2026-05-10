import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
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

class UpdateService {
  static const String _repoOwner = 'Amadoson3001';
  static const String _repoName = 'aerotube-downloader';
  static const String _apiBaseUrl = 'https://api.github.com/repos';
  static const String _releasesUrl =
      '$_apiBaseUrl/$_repoOwner/$_repoName/releases/latest';

  /// Channel used for FileProvider + APK install on Android.
  static const _fileProviderChannel =
      MethodChannel('com.aerotube.youtube_downloader/file_provider');

  final CertificatePinningService _certPinningService = CertificatePinningService();

  // ── ABI detection ─────────────────────────────────────────────────────────

  /// Returns the primary ABI of the device, e.g. "arm64-v8a".
  /// Falls back to empty string on non-Android or on error.
  Future<String> getDeviceAbi() async {
    if (!Platform.isAndroid) return '';
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
  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final uri = Uri.parse(_releasesUrl);
      
      final client = _certPinningService.createPinnedHttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      request.headers.set('User-Agent', 'AeroTube-Updater');
      
      final httpResponse = await request.close().timeout(const Duration(seconds: 10));
      final responseBody = await httpResponse.transform(utf8.decoder).join();
      
      if (httpResponse.statusCode != 200) {
        throw Exception(
          'Failed to check for updates: HTTP ${httpResponse.statusCode}',
        );
      }

      final data = json.decode(responseBody);
      final latestVersion = data['tag_name'] as String?;

      if (latestVersion == null) return null;

      // Remove 'v' prefix if present for comparison
      final cleanLatestVersion = latestVersion.startsWith('v')
          ? latestVersion.substring(1)
          : latestVersion;
      final cleanCurrentVersion = currentVersion.startsWith('v')
          ? currentVersion.substring(1)
          : currentVersion;

      if (!_isNewerVersion(cleanLatestVersion, cleanCurrentVersion)) {
        return null; // No update available
      }

      final assets = data['assets'] as List<dynamic>?;
      String? downloadUrl;
      String? assetName;
      int? assetSize;

      if (assets != null) {
        if (Platform.isAndroid) {
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
        version: cleanLatestVersion,
        downloadUrl: downloadUrl,
        releaseNotes: data['body'] as String? ?? 'No release notes available',
        publishedAt: DateTime.parse(data['published_at'] as String),
        assetName: assetName,
        assetSize: assetSize,
      );
    } catch (e) {
      throw Exception('Failed to check for updates: $e');
    }
  }

  // ── Version comparison ────────────────────────────────────────────────────

  /// Returns true if [latest] is a higher semver than [current].
  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      // Pad with zeros to make lengths equal
      while (latestParts.length < currentParts.length) latestParts.add(0);
      while (currentParts.length < latestParts.length) currentParts.add(0);

      for (int i = 0; i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false; // Versions are equal
    } catch (_) {
      return latest != current;
    }
  }

  // ── Download ──────────────────────────────────────────────────────────────

  /// Downloads the update file and reports progress via [onProgress] (0.0–1.0).
  /// Returns the local file path of the downloaded file.
  Future<String> downloadUpdate(String url, Function(double) onProgress) async {
    try {
      final uri = Uri.parse(url);
      final client = _certPinningService.createPinnedHttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];

      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (contentLength > 0) {
          onProgress(bytes.length / contentLength);
        }
      }

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(uri.path);
      final filePath = path.join(
        tempDir.path,
        fileName.isEmpty ? 'update.apk' : fileName,
      );

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      throw Exception('Failed to download update: $e');
    }
  }

  // ── Install (Windows) ─────────────────────────────────────────────────────

  /// Launches the installer on Windows.
  /// On Android, use [launchAndroidInstaller] instead.
  Future<void> launchInstaller(String filePath) async {
    if (!Platform.isWindows) return;
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
          ['-Command', 'Add-AppxPackage -Path "$filePath"'],
          mode: ProcessStartMode.detached,
        );
      }
    } catch (e) {
      throw Exception('Failed to launch installer: $e');
    }
  }

  // ── Install (Android) ─────────────────────────────────────────────────────

  /// Triggers the system APK installer via FileProvider on Android.
  /// The user will see the standard Android "Install" prompt.
  Future<void> launchAndroidInstaller(String filePath) async {
    if (!Platform.isAndroid) return;
    try {
      await _fileProviderChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
    } catch (e) {
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
