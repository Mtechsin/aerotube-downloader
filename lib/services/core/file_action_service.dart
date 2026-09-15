import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/utils/platform_utils.dart';
import 'logging_service.dart';

/// Cross-platform service for handling file operations:
/// - Opening downloaded media files with the default player or chooser (Open with)
/// - Sharing downloaded files via system share sheet (Android) or file selection (Desktop)
/// - Opening the containing folder in system file manager / Downloads UI
class FileActionService {
  static const String channelName = 'com.aerotube.youtube_downloader/file_provider';

  static FileActionService _instance = FileActionService._internal();
  factory FileActionService() => _instance;

  FileActionService._internal();

  @visibleForTesting
  static void setMockInstance(FileActionService mock) {
    _instance = mock;
  }

  @visibleForTesting
  static void resetInstance() {
    _instance = FileActionService._internal();
  }

  MethodChannel _channel = const MethodChannel(channelName);

  @visibleForTesting
  void setChannel(MethodChannel channel) {
    _channel = channel;
  }

  final LoggingService _logger = LoggingService();
  String? _lastError;

  /// Returns the most recent error message, if any.
  String? get lastError => _lastError;

  /// Opens a downloaded file using the default media application or chooser.
  ///
  /// On Android, uses FileProvider and Intent.ACTION_VIEW with MIME resolution.
  /// On Windows, executes default shell command via cmd /c start.
  Future<bool> openFile(String filePath, {bool useChooser = false}) async {
    _lastError = null;

    if (filePath.trim().isEmpty) {
      _lastError = 'File path cannot be empty.';
      return false;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      _lastError = 'File not found on device.';
      _logger.warning('Cannot open file, not found: $filePath', component: 'FileActionService');
      return false;
    }

    if (PlatformUtils.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('openFile', {
          'filePath': filePath,
          'useChooser': useChooser,
        });
        if (result == true) {
          return true;
        } else {
          _lastError = 'Failed to open file.';
          return false;
        }
      } on PlatformException catch (e, st) {
        _logger.warning('openFile PlatformException: ${e.code} - ${e.message}', component: 'FileActionService', error: e, stackTrace: st);
        if (e.code == 'NO_APP_FOUND') {
          _lastError = 'No application found to open this file.';
        } else if (e.code == 'FILE_NOT_FOUND') {
          _lastError = 'File not found on device.';
        } else {
          _lastError = e.message ?? 'Failed to open file.';
        }
        return false;
      } catch (e, st) {
        _logger.error('openFile unexpected error: $e', component: 'FileActionService', error: e, stackTrace: st);
        _lastError = 'Unexpected error opening file.';
        return false;
      }
    } else if (PlatformUtils.isWindows) {
      try {
        final res = await Process.run('cmd', ['/c', 'start', '""', filePath]);
        if (res.exitCode == 0) {
          return true;
        } else {
          _lastError = 'Could not open file (exit code: ${res.exitCode}).';
          _logger.warning('Windows openFile returned ${res.exitCode}: ${res.stderr}', component: 'FileActionService');
          return false;
        }
      } catch (e, st) {
        _logger.error('Windows openFile error: $e', component: 'FileActionService', error: e, stackTrace: st);
        _lastError = 'Error launching file player.';
        return false;
      }
    } else if (PlatformUtils.isMacOS) {
      try {
        final res = await Process.run('open', [filePath]);
        return res.exitCode == 0;
      } catch (e) {
        _lastError = 'Could not open file: $e';
        return false;
      }
    } else if (PlatformUtils.isLinux) {
      try {
        final res = await Process.run('xdg-open', [filePath]);
        return res.exitCode == 0;
      } catch (e) {
        _lastError = 'Could not open file: $e';
        return false;
      }
    }

    _lastError = 'Platform not supported for openFile.';
    return false;
  }

  /// Shares a downloaded file via the system share sheet (Android) or
  /// reveals the file in the file explorer (Desktop).
  Future<bool> shareFile(String filePath, {String? title}) async {
    _lastError = null;

    if (filePath.trim().isEmpty) {
      _lastError = 'File path cannot be empty.';
      return false;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      _lastError = 'File not found on device.';
      _logger.warning('Cannot share file, not found: $filePath', component: 'FileActionService');
      return false;
    }

    if (PlatformUtils.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('shareFile', {
          'filePath': filePath,
          'title': title,
        });
        if (result == true) {
          return true;
        } else {
          _lastError = 'Failed to share file.';
          return false;
        }
      } on PlatformException catch (e, st) {
        _logger.warning('shareFile PlatformException: ${e.code} - ${e.message}', component: 'FileActionService', error: e, stackTrace: st);
        if (e.code == 'NO_APP_FOUND') {
          _lastError = 'No application found to share this file.';
        } else if (e.code == 'FILE_NOT_FOUND') {
          _lastError = 'File not found on device.';
        } else {
          _lastError = e.message ?? 'Failed to share file.';
        }
        return false;
      } catch (e, st) {
        _logger.error('shareFile unexpected error: $e', component: 'FileActionService', error: e, stackTrace: st);
        _lastError = 'Unexpected error sharing file.';
        return false;
      }
    } else if (PlatformUtils.isWindows) {
      try {
        final res = await Process.run('explorer.exe', ['/select,', filePath]);
        return res.exitCode == 0;
      } catch (e, st) {
        _logger.error('Windows shareFile explorer select error: $e', component: 'FileActionService', error: e, stackTrace: st);
        _lastError = 'Error revealing file in explorer.';
        return false;
      }
    } else if (PlatformUtils.isMacOS) {
      try {
        final res = await Process.run('open', ['-R', filePath]);
        return res.exitCode == 0;
      } catch (e) {
        _lastError = 'Could not reveal file: $e';
        return false;
      }
    } else if (PlatformUtils.isLinux) {
      try {
        final res = await Process.run('xdg-open', [file.parent.path]);
        return res.exitCode == 0;
      } catch (e) {
        _lastError = 'Could not open directory: $e';
        return false;
      }
    }

    _lastError = 'Platform not supported for shareFile.';
    return false;
  }

  /// Opens the folder containing the downloaded file or target directory.
  Future<bool> openFolder(String folderPath) async {
    _lastError = null;

    if (folderPath.trim().isEmpty) {
      _lastError = 'Folder path cannot be empty.';
      return false;
    }

    String targetDir = folderPath;
    try {
      final type = FileSystemEntity.typeSync(folderPath);
      if (type == FileSystemEntityType.file) {
        targetDir = File(folderPath).parent.path;
      } else if (type == FileSystemEntityType.notFound) {
        final dir = Directory(folderPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }
    } catch (_) {
      // Best-effort check; continue with given folderPath
    }

    if (PlatformUtils.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('openFolder', {
          'folderPath': targetDir,
        });
        if (result == true) {
          return true;
        } else {
          _lastError = 'Could not open folder in file manager.';
          return false;
        }
      } on PlatformException catch (e, st) {
        _logger.warning('openFolder PlatformException: ${e.code} - ${e.message}', component: 'FileActionService', error: e, stackTrace: st);
        if (e.code == 'NO_APP_FOUND') {
          _lastError = 'No file manager found on device.';
        } else {
          _lastError = e.message ?? 'Failed to open folder.';
        }
        return false;
      } catch (e, st) {
        _logger.error('openFolder unexpected error: $e', component: 'FileActionService', error: e, stackTrace: st);
        _lastError = 'Unexpected error opening folder.';
        return false;
      }
    } else if (PlatformUtils.isWindows) {
      try {
        final res = await Process.run('explorer', [targetDir]);
        return res.exitCode == 0;
      } catch (e, st) {
        _logger.error('Windows openFolder explorer error: $e', component: 'FileActionService', error: e, stackTrace: st);
        _lastError = 'Could not open folder in explorer.';
        return false;
      }
    } else if (PlatformUtils.isMacOS) {
      try {
        final res = await Process.run('open', [targetDir]);
        return res.exitCode == 0;
      } catch (e) {
        _lastError = 'Could not open folder: $e';
        return false;
      }
    } else if (PlatformUtils.isLinux) {
      try {
        final res = await Process.run('xdg-open', [targetDir]);
        return res.exitCode == 0;
      } catch (e) {
        _lastError = 'Could not open folder: $e';
        return false;
      }
    }

    _lastError = 'Platform not supported for openFolder.';
    return false;
  }
}
