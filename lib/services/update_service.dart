import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

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

  /// Check for available updates from GitHub
  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final response = await http
          .get(
            Uri.parse(_releasesUrl),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'AeroTube-Updater',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to check for updates: HTTP ${response.statusCode}',
        );
      }

      final data = json.decode(response.body);
      final latestVersion = data['tag_name'] as String?;

      if (latestVersion == null) {
        return null;
      }

      // Remove 'v' prefix if present for comparison
      final cleanLatestVersion = latestVersion.startsWith('v')
          ? latestVersion.substring(1)
          : latestVersion;
      final cleanCurrentVersion = currentVersion.startsWith('v')
          ? currentVersion.substring(1)
          : currentVersion;

      // Compare versions
      if (!_isNewerVersion(cleanLatestVersion, cleanCurrentVersion)) {
        return null; // No update available
      }

      // Find Windows asset
      final assets = data['assets'] as List<dynamic>?;
      String? downloadUrl;
      String? assetName;
      int? assetSize;

      if (assets != null) {
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          // Look for Windows executable or zip
          if (name.contains('windows') ||
              name.contains('.exe') ||
              name.contains('.zip') ||
              name.contains('.msix')) {
            downloadUrl = asset['browser_download_url'] as String?;
            assetName = name;
            assetSize = asset['size'] as int?;
            break;
          }
        }
      }

      // Fallback to source zip if no Windows asset found
      downloadUrl ??= data['zipball_url'] as String?;

      if (downloadUrl == null) {
        return null;
      }

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

  /// Compare two version strings (e.g., "1.0.0" vs "1.0.1")
  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      // Pad with zeros to make lengths equal
      while (latestParts.length < currentParts.length) {
        latestParts.add(0);
      }
      while (currentParts.length < latestParts.length) {
        currentParts.add(0);
      }

      for (int i = 0; i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }

      return false; // Versions are equal
    } catch (e) {
      // If parsing fails, do string comparison
      return latest != current;
    }
  }

  /// Download the update file
  Future<String> downloadUpdate(String url, Function(double) onProgress) async {
    try {
      final response = await http.Client().send(
        http.Request('GET', Uri.parse(url)),
      );

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (contentLength > 0) {
          onProgress(bytes.length / contentLength);
        }
      }

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(Uri.parse(url).path);
      final filePath = path.join(
        tempDir.path,
        fileName.isEmpty ? 'update.zip' : fileName,
      );

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      throw Exception('Failed to download update: $e');
    }
  }

  /// Launch the installer
  Future<void> launchInstaller(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Installer file not found');
      }

      // On Windows, launch the installer
      if (Platform.isWindows) {
        if (filePath.endsWith('.exe')) {
          // Launch executable directly
          await Process.start(filePath, [], mode: ProcessStartMode.detached);
        } else if (filePath.endsWith('.zip')) {
          // Open containing folder for zip files
          await Process.start('explorer.exe', [file.parent.path]);
        } else if (filePath.endsWith('.msix')) {
          // Install MSIX package
          await Process.start('powershell.exe', [
            '-Command',
            'Add-AppxPackage -Path "$filePath"',
          ], mode: ProcessStartMode.detached);
        }
      }
    } catch (e) {
      throw Exception('Failed to launch installer: $e');
    }
  }

  /// Get current app version from pubspec
  Future<String> getCurrentVersion() async {
    // This should match your pubspec.yaml version
    return '1.0.0';
  }
}
