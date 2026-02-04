import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.component,
    this.error,
    this.stackTrace,
  });

  String get formattedTimestamp {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
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
    buffer.write(message);
    if (error != null) buffer.write('\n  Error: $error');
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

  bool _isInitialized = false;
  late File _logFile;

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

      info('LoggingService initialized', component: 'LoggingService');
    } catch (e) {
      debugPrint('Failed to initialize LoggingService: $e');
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
    );

    // Add to dev logs
    _devLogs.add(entry);
    if (_devLogs.length > _maxDevLogs) {
      _devLogs.removeAt(0);
    }
    _devLogsController.add(List.unmodifiable(_devLogs));

    // Write to file
    _writeToFile(entry);

    // Also show in console for debug builds
    if (kDebugMode) {
      debugPrint(entry.toString());
    }
  }

  Future<void> _writeToFile(LogEntry entry) async {
    if (!_isInitialized) return;

    try {
      final line = '${entry.toString()}\n';
      await _logFile.writeAsString(line, mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
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
  String exportLogs() {
    return _devLogs.map((e) => e.toString()).join('\n');
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
