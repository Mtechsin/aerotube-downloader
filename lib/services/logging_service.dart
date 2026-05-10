import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/url_sanitizer.dart';

/// Log level enumeration
enum LogLevel { debug, info, warning, error }

/// Log entry model
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? component;
  final dynamic error;
  final StackTrace? stackTrace;
  final bool sanitizeUrls;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.component,
    this.error,
    this.stackTrace,
    this.sanitizeUrls = true,
  });

  String get formattedTimestamp {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  String get compactTimestamp {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  String get levelEmoji {
    switch (level) {
      case LogLevel.debug:
        return '🐛';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[$formattedTimestamp] $levelEmoji ');
    if (component != null) buffer.write('[$component] ');
    buffer.write(sanitizeUrls ? UrlSanitizer.sanitize(message) : message);
    if (error != null) {
      final errorStr = error.toString();
      buffer.write('\n  Error: ${sanitizeUrls ? UrlSanitizer.sanitize(errorStr) : errorStr}');
    }
    if (stackTrace != null) buffer.write('\n  Stack: $stackTrace');
    return buffer.toString();
  }
}

/// User-facing log entry (simplified)
class UserLogEntry {
  final String id;
  final DateTime timestamp;
  final String message;
  final bool isError;
  final bool isWarning;
  final Duration? autoDismissDuration;

  UserLogEntry({
    required this.id,
    required this.timestamp,
    required this.message,
    this.isError = false,
    this.isWarning = false,
    this.autoDismissDuration,
  });

  bool get shouldAutoDismiss => autoDismissDuration != null;
}

/// Comprehensive logging service for both developer and user logs
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  // Dev logs
  final List<LogEntry> _devLogs = [];
  final _devLogsController = StreamController<List<LogEntry>>.broadcast();
  Stream<List<LogEntry>> get devLogsStream => _devLogsController.stream;
  List<LogEntry> get devLogs => List.unmodifiable(_devLogs);

  // User logs (temporary, auto-dismiss)
  final List<UserLogEntry> _userLogs = [];
  final _userLogsController = StreamController<List<UserLogEntry>>.broadcast();
  Stream<List<UserLogEntry>> get userLogsStream => _userLogsController.stream;
  List<UserLogEntry> get userLogs => List.unmodifiable(_userLogs);

  // Configuration
  static const int _maxDevLogs = 1000;
  static const int _maxUserLogs = 5;
  static const Duration _userLogDefaultDuration = Duration(seconds: 5);
  static const Duration _userLogErrorDuration = Duration(seconds: 8);
  static const int _maxLogFileSize = 5 * 1024 * 1024; // 5MB
  static const int _maxRotatedFiles = 3;

  bool _isInitialized = false;
  bool _loggingEnabled = true;
  bool _sanitizeUrls = true;
  late File _logFile;

  bool get isEnabled => _loggingEnabled;
  bool get isSanitizeUrlsEnabled => _sanitizeUrls;

  Future<void> setEnabled(bool enabled) async {
    _loggingEnabled = enabled;
    if (enabled) {
      info('Logging enabled', component: 'LoggingService');
    } else {
      debugPrint('Logging disabled');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('logging_enabled', enabled);
  }

  Future<void> setSanitizeUrlsEnabled(bool enabled) async {
    _sanitizeUrls = enabled;
    if (enabled) {
      info('URL sanitization enabled', component: 'LoggingService');
    } else {
      info('URL sanitization disabled', component: 'LoggingService');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sanitize_urls', enabled);
  }

  // Progress tracking for downloads
  final Map<String, double> _downloadProgress = {};
  final _progressController = StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get progressStream => _progressController.stream;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final appDir = await getApplicationSupportDirectory();
      final logDir = Directory(p.join(appDir.path, 'logs'));
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      _logFile = File(p.join(logDir.path, 'app.log'));
      _isInitialized = true;

    final prefs = await SharedPreferences.getInstance();
    _loggingEnabled = prefs.getBool('logging_enabled') ?? true;
    _sanitizeUrls = prefs.getBool('sanitize_urls') ?? true;

    await cleanupOldLogs(maxAgeDays: 7);

    info('LoggingService initialized', component: 'LoggingService');
    } catch (e) {
      debugPrint('Failed to initialize LoggingService: $e');
    }
  }

  void setLoggingEnabled(bool enabled) {
    _loggingEnabled = enabled;
    if (enabled) {
      info('Logging enabled', component: 'LoggingService');
    } else {
      debugPrint('Logging disabled');
    }
  }

  /// Log a debug message (dev only)
  void debug(
    String message, {
    String? component,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.debug,
      message,
      component: component,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an info message
  void info(
    String message, {
    String? component,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.info,
      message,
      component: component,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a warning
  void warning(
    String message, {
    String? component,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.warning,
      message,
      component: component,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an error
  void error(
    String message, {
    String? component,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      message,
      component: component,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(
    LogLevel level,
    String message, {
    String? component,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      component: component,
      error: error,
      stackTrace: stackTrace,
      sanitizeUrls: _sanitizeUrls,
    );

    // Always show in console for debug builds (not gated by _loggingEnabled)
    if (kDebugMode) {
      debugPrint(entry.toString());
    }

    // In-memory store and file write respect the user toggle
    if (!_loggingEnabled) return;

    _devLogs.add(entry);
    if (_devLogs.length > _maxDevLogs) {
      _devLogs.removeAt(0);
    }
    _devLogsController.add(List.unmodifiable(_devLogs));

    _writeToFile(entry);
  }

  Future<void> _writeToFile(LogEntry entry) async {
    if (!_isInitialized || !_loggingEnabled) return;

    try {
      // Check and rotate log file if needed
      await _rotateLogFileIfNeeded();

      final line = '${entry.toString()}\n';
      await _logFile.writeAsString(line, mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }

  Future<void> _rotateLogFileIfNeeded() async {
    try {
      if (!await _logFile.exists()) return;

      final fileSize = await _logFile.length();
      if (fileSize < _maxLogFileSize) return;

      // Rotate files: app.log.2 → app.log.3, app.log.1 → app.log.2, app.log → app.log.1
      for (int i = _maxRotatedFiles - 1; i >= 1; i--) {
        final sourceFile = File('${_logFile.path}.$i');
        if (await sourceFile.exists()) {
          if (i == _maxRotatedFiles - 1) {
            // Delete oldest file
            await sourceFile.delete();
          } else {
            // Move to next number
            await sourceFile.rename('${_logFile.path}.${i + 1}');
          }
        }
      }

      // Rename current log to app.log.1
      await _logFile.rename('${_logFile.path}.1');

      // Create new log file
      _logFile = File(p.join(_logFile.parent.path, 'app.log'));
      await _logFile.create();

      info('Log file rotated', component: 'LoggingService');
    } catch (e) {
      debugPrint('Failed to rotate log file: $e');
    }
  }

  Future<void> cleanupOldLogs({int maxAgeDays = 30}) async {
    try {
      final logDir = _logFile.parent;
      if (!await logDir.exists()) return;

      final logFiles = <File>[];
      await for (final entity in logDir.list()) {
        if (entity is File &&
            (entity.path.endsWith('.log') || entity.path.contains('.log.'))) {
          logFiles.add(entity);
        }
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeDays));

      for (final file in logFiles) {
        final stat = await file.stat();
        if (stat.modified.isBefore(cutoffDate)) {
          await file.delete();
          debugPrint('Deleted old log file: ${file.path}');
        }
      }
    } catch (e) {
      debugPrint('Failed to cleanup old logs: $e');
    }
  }

  /// Show a user-facing log message (appears in UI, auto-dismisses)
  void showUserLog(
    String message, {
    bool isError = false,
    bool isWarning = false,
    Duration? autoDismissDuration,
  }) {
    final entry = UserLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      message: message,
      isError: isError,
      isWarning: isWarning,
      autoDismissDuration:
          autoDismissDuration ??
          (isError ? _userLogErrorDuration : _userLogDefaultDuration),
    );

    _userLogs.add(entry);
    if (_userLogs.length > _maxUserLogs) {
      _userLogs.removeAt(0);
    }
    _userLogsController.add(List.unmodifiable(_userLogs));

    // Auto-dismiss after duration
    if (entry.shouldAutoDismiss) {
      Timer(entry.autoDismissDuration!, () {
        dismissUserLog(entry.id);
      });
    }

    // Also log to dev logs
    if (isError) {
      error(message, component: 'UserLog');
    } else if (isWarning) {
      warning(message, component: 'UserLog');
    } else {
      info(message, component: 'UserLog');
    }
  }

  /// Dismiss a specific user log
  void dismissUserLog(String id) {
    _userLogs.removeWhere((log) => log.id == id);
    _userLogsController.add(List.unmodifiable(_userLogs));
  }

  /// Clear all user logs
  void clearUserLogs() {
    _userLogs.clear();
    _userLogsController.add([]);
  }

  /// Update download progress
  void updateDownloadProgress(String downloadId, double progress) {
    _downloadProgress[downloadId] = progress.clamp(0.0, 1.0);
    _progressController.add(Map.unmodifiable(_downloadProgress));
  }

  /// Remove download progress
  void removeDownloadProgress(String downloadId) {
    _downloadProgress.remove(downloadId);
    _progressController.add(Map.unmodifiable(_downloadProgress));
  }

  /// Get current progress for a download
  double getDownloadProgress(String downloadId) {
    return _downloadProgress[downloadId] ?? 0.0;
  }

  /// Get overall progress (average of all active downloads)
  double get overallProgress {
    if (_downloadProgress.isEmpty) return 0.0;
    final total = _downloadProgress.values.reduce((a, b) => a + b);
    return total / _downloadProgress.length;
  }

  /// Check if any downloads are in progress
  bool get hasActiveDownloads => _downloadProgress.isNotEmpty;

  /// Get count of active downloads
  int get activeDownloadCount => _downloadProgress.length;

  /// Clear all dev logs
  void clearDevLogs() {
    _devLogs.clear();
    _devLogsController.add([]);
  }

  /// Export logs to a string
  String exportLogs({bool? sanitizeUrls}) {
    final shouldSanitize = sanitizeUrls ?? _sanitizeUrls;
    if (shouldSanitize) {
      return _devLogs.map((e) => e.toString()).join('\n');
    } else {
      return _devLogs.map((e) {
        final buffer = StringBuffer();
        buffer.write('[${e.formattedTimestamp}] ${e.levelEmoji} ');
        if (e.component != null) buffer.write('[${e.component}] ');
        buffer.write(e.message);
        if (e.error != null) buffer.write('\n  Error: ${e.error}');
        if (e.stackTrace != null) buffer.write('\n  Stack: ${e.stackTrace}');
        return buffer.toString();
      }).join('\n');
    }
  }

  /// Export logs to a file in the selected output directory.
  ///
  /// The exported file is written to `outputPath/app.log`.
  Future<String> exportLogsToFile(String outputPath) async {
    if (!_isInitialized) {
      throw StateError('Logging service is not initialized yet.');
    }

    if (outputPath.trim().isEmpty) {
      throw ArgumentError.value(
        outputPath,
        'outputPath',
        'A valid directory is required.',
      );
    }

    final outputDir = Directory(outputPath);
    await outputDir.create(recursive: true);

    final exportFile = File(p.join(outputDir.path, 'app.log'));
    final sourceFileExists = await _logFile.exists();
    final hasInMemoryLogs = _devLogs.isNotEmpty;

    if (!sourceFileExists && !hasInMemoryLogs) {
      throw StateError(
        'No log file exists and there are no in-memory log entries to export.',
      );
    }

    if (sourceFileExists) {
      await _logFile.copy(exportFile.path);
      final sourceStat = await _logFile.stat();
      final pendingLogs = _devLogs
          .where((entry) => entry.timestamp.isAfter(sourceStat.modified))
          .toList();

      if (pendingLogs.isNotEmpty) {
        final pendingText = pendingLogs
            .map((entry) => entry.toString())
            .join('\n');
        await exportFile.writeAsString('$pendingText\n', mode: FileMode.append);
      }
    } else {
      final logsText = exportLogs();
      await exportFile.writeAsString('$logsText\n', mode: FileMode.write);
    }

    return exportFile.path;
  }

  /// Dispose resources
  void dispose() {
    _devLogsController.close();
    _userLogsController.close();
    _progressController.close();
  }
}

// Global extension for easy logging
extension LoggingExtension on Object {
  LoggingService get logger => LoggingService();
}
