import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';
import '../../core/utils/error_helper.dart';
import '../../core/utils/platform_utils.dart';
import 'logging_service.dart';

/// Snapshot of the environment at report time. Safe to share — paths are
/// redacted and URLs come from already-sanitized log entries.
class BugDiagnostics {
  final String appVersion;
  final String buildNumber;
  final String appName;
  final String platform;
  final String sessionId;
  final String timestamp;
  final bool loggingEnabled;
  final bool sanitizeUrls;
  final int logEntryCount;
  final int errorCount;
  final int warningCount;
  final String? ytdlpVersion;
  final String? ffmpegVersion;
  final String? outputPathLabel;
  final bool? cookiesEnabled;
  final String localeName;

  const BugDiagnostics({
    required this.appVersion,
    required this.buildNumber,
    required this.appName,
    required this.platform,
    required this.sessionId,
    required this.timestamp,
    required this.loggingEnabled,
    required this.sanitizeUrls,
    required this.logEntryCount,
    required this.errorCount,
    required this.warningCount,
    this.ytdlpVersion,
    this.ffmpegVersion,
    this.outputPathLabel,
    this.cookiesEnabled,
    required this.localeName,
  });

  String get versionLabel => '$appVersion+$buildNumber';
}

/// Builds a complete, copy-paste-ready bug report (markdown) that a user can
/// attach to a GitHub issue or paste into a chat. All log content is forced
/// through URL sanitization before leaving this service.
class BugReportService {
  BugReportService({LoggingService? logging})
      : _logging = logging ?? LoggingService();

  final LoggingService _logging;

  static const int _defaultLogTail = 60;
  static const int _maxErrorDetails = 5;
  static const int _githubBodyLimit = 7000;

  /// Collects a lightweight environment snapshot. Never throws — missing
  /// tools or failed PackageInfo lookups become "unknown".
  Future<BugDiagnostics> collectDiagnostics({
    String? ytdlpVersion,
    String? ffmpegVersion,
    String? outputPath,
    bool? cookiesEnabled,
  }) async {
    String appName = 'AeroTube';
    String appVersion = 'unknown';
    String buildNumber = '0';
    try {
      final info = await PackageInfo.fromPlatform();
      appName = info.appName.isNotEmpty ? info.appName : appName;
      appVersion = info.version;
      buildNumber = info.buildNumber;
    } catch (_) {
      // PackageInfo can fail in rare embedding cases; keep defaults.
    }

    return BugDiagnostics(
      appVersion: appVersion,
      buildNumber: buildNumber,
      appName: appName,
      platform: PlatformUtils.platformName,
      sessionId: _logging.sessionId,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      loggingEnabled: _logging.isEnabled,
      sanitizeUrls: _logging.isSanitizeUrlsEnabled,
      logEntryCount: _logging.devLogs.length,
      errorCount: _logging.errorCount,
      warningCount: _logging.warningCount,
      ytdlpVersion: ytdlpVersion,
      ffmpegVersion: ffmpegVersion,
      outputPathLabel: _redactPath(outputPath),
      cookiesEnabled: cookiesEnabled,
      localeName: Platform.localeName,
    );
  }

  /// Redacts the username segment of a filesystem path for safe sharing.
  /// `C:\Users\alice\Videos` → `C:\Users\•••\Videos`
  static String? _redactPath(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].toLowerCase() == 'users' && i + 1 < parts.length) {
        parts[i + 1] = '•••';
      }
      if (parts[i].toLowerCase() == 'home' && i + 1 < parts.length) {
        parts[i + 1] = '•••';
      }
      if (parts[i].toLowerCase() == 'data' &&
          i + 2 < parts.length &&
          parts[i + 1] == 'user') {
        parts[i + 1] = '•••';
      }
    }
    return parts.join('/');
  }

  /// Builds the full markdown bug report.
  String buildReport({
    required BugDiagnostics diagnostics,
    required String summary,
    String? stepsToReproduce,
    String? expectedBehavior,
    String? actualBehavior,
    String? category,
    String? errorDetail,
    int logTailLimit = _defaultLogTail,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('## Bug Report');
    buffer.writeln();
    buffer.writeln('**Summary:** ${_oneLine(summary)}');
    if (category != null && category.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('**Category:** ${category.trim()}');
    }

    buffer.writeln();
    buffer.writeln('### What happened');
    buffer.writeln(
      _oneLine(actualBehavior?.trim().isNotEmpty == true
          ? actualBehavior!
          : summary),
    );

    if (stepsToReproduce != null && stepsToReproduce.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### Steps to reproduce');
      for (final step in _numberedLines(stepsToReproduce)) {
        buffer.writeln(step);
      }
    }

    if (expectedBehavior != null && expectedBehavior.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### Expected');
      buffer.writeln(_oneLine(expectedBehavior));
    }

    buffer.writeln();
    buffer.writeln('### Environment');
    buffer.writeln();
    buffer.writeln('| Field | Value |');
    buffer.writeln('| --- | --- |');
    buffer.writeln('| App | ${diagnostics.appName} ${diagnostics.versionLabel} |');
    buffer.writeln('| Platform | ${diagnostics.platform} |');
    buffer.writeln('| Locale | ${diagnostics.localeName} |');
    buffer.writeln('| Session | `${diagnostics.sessionId}` |');
    buffer.writeln('| Report time (UTC) | ${diagnostics.timestamp} |');
    buffer.writeln('| yt-dlp | ${diagnostics.ytdlpVersion ?? 'unknown'} |');
    buffer.writeln('| ffmpeg | ${diagnostics.ffmpegVersion ?? 'unknown'} |');
    buffer.writeln(
      '| Cookies | ${_boolLabel(diagnostics.cookiesEnabled)} |',
    );
    buffer.writeln(
      '| Download folder | ${diagnostics.outputPathLabel ?? 'default'} |',
    );
    buffer.writeln(
      '| Logging | ${diagnostics.loggingEnabled ? 'on' : 'off'} |',
    );
    buffer.writeln(
      '| URL redaction | ${diagnostics.sanitizeUrls ? 'on' : 'off'} |',
    );
    buffer.writeln(
      '| Log buffer | ${diagnostics.logEntryCount} entries '
      '(${diagnostics.errorCount} errors, ${diagnostics.warningCount} warnings) |',
    );

    if (errorDetail != null && errorDetail.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### Error details');
      buffer.writeln();
      buffer.writeln('```');
      buffer.writeln(_clip(errorDetail.trim(), 2500));
      buffer.writeln('```');
    }

    final errors = _logging.recentErrors(limit: _maxErrorDetails);
    if (errors.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### Recent errors (this session)');
      buffer.writeln();
      buffer.writeln('```');
      for (final entry in errors) {
        buffer.writeln(entry.toStringWithSanitization(true));
      }
      buffer.writeln('```');
    }

    final tail = _logging.exportRecentLogTail(limit: logTailLimit);
    if (tail.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### Log tail (last $logTailLimit entries, sanitized)');
      buffer.writeln();
      buffer.writeln('```');
      buffer.writeln(_clip(tail, 12000));
      buffer.writeln('```');
    } else if (!diagnostics.loggingEnabled) {
      buffer.writeln();
      buffer.writeln(
        '_Logging is currently disabled. Enable it in Settings → Logs '
        'and reproduce the issue to capture a log tail._',
      );
    }

    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln(
      '_Generated by AeroTube Report a Bug. URLs and cookies are redacted._',
    );

    return buffer.toString();
  }

  /// Convenience: diagnostics + user text → markdown in one call.
  Future<String> buildFullReport({
    required String summary,
    String? stepsToReproduce,
    String? expectedBehavior,
    String? actualBehavior,
    String? category,
    String? errorDetail,
    String? ytdlpVersion,
    String? ffmpegVersion,
    String? outputPath,
    bool? cookiesEnabled,
    int logTailLimit = _defaultLogTail,
  }) async {
    final diagnostics = await collectDiagnostics(
      ytdlpVersion: ytdlpVersion,
      ffmpegVersion: ffmpegVersion,
      outputPath: outputPath,
      cookiesEnabled: cookiesEnabled,
    );
    return buildReport(
      diagnostics: diagnostics,
      summary: summary,
      stepsToReproduce: stepsToReproduce,
      expectedBehavior: expectedBehavior,
      actualBehavior: actualBehavior,
      category: category,
      errorDetail: errorDetail,
      logTailLimit: logTailLimit,
    );
  }

  /// Writes the report to `directory/bug-report-<session>-<stamp>.md`.
  Future<String> saveReport(
    String directoryPath,
    String reportMarkdown,
  ) async {
    final dir = Directory(directoryPath);
    await dir.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(
      p.join(dir.path, 'bug-report-${_logging.sessionId}-$stamp.md'),
    );
    await file.writeAsString(reportMarkdown);
    return file.path;
  }

  /// GitHub "new issue" URL. When [body] exceeds GitHub's practical query
  /// limit the body is omitted so the issue still opens; callers should also
  /// copy the full report to the clipboard in that case.
  Uri buildGitHubIssueUrl({
    required String title,
    required String body,
  }) {
    final repo =
        'https://github.com/${AppConstants.appRepoOwner}/${AppConstants.appRepoName}/issues/new';
    final clipped = body.length > _githubBodyLimit
        ? '${body.substring(0, _githubBodyLimit)}\n\n_(report truncated — paste full report from clipboard)_'
        : body;
    return Uri.parse(repo).replace(
      queryParameters: {
        'title': _issueTitle(title),
        'body': clipped,
      },
    );
  }

  /// Short, greppable issue title: `[Bug] summary (v1.1.0 · Windows · ABC123)`
  static String _issueTitle(String summary) {
    final short = _oneLine(summary);
    final trimmed = short.length > 80 ? '${short.substring(0, 77)}...' : short;
    return trimmed.isEmpty ? 'Bug report' : trimmed;
  }

  String issueTitleWithMeta(String summary, BugDiagnostics diagnostics) {
    final short = _oneLine(summary);
    final trimmed = short.length > 60 ? '${short.substring(0, 57)}...' : short;
    return '[Bug] ${trimmed.isEmpty ? 'Issue' : trimmed} '
        '(v${diagnostics.appVersion} · ${diagnostics.platform} · '
        '${diagnostics.sessionId})';
  }

  static String _boolLabel(bool? value) {
    if (value == null) return 'unknown';
    return value ? 'on' : 'off';
  }

  static String _oneLine(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _clip(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}\n… (truncated)';
  }

  static List<String> _numberedLines(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final result = <String>[];
    var auto = 1;
    for (final line in lines) {
      if (RegExp(r'^\d+[.)]\s').hasMatch(line)) {
        result.add(line);
      } else {
        result.add('$auto. $line');
        auto++;
      }
    }
    return result;
  }
}

/// Maps a [ErrorCategory] to a short label for the report form.
String bugCategoryLabel(ErrorCategory category) {
  switch (category) {
    case ErrorCategory.authentication:
      return 'Authentication';
    case ErrorCategory.network:
      return 'Network';
    case ErrorCategory.fileSystem:
      return 'File system';
    case ErrorCategory.permission:
      return 'Permission';
    case ErrorCategory.rateLimit:
      return 'Rate limit';
    case ErrorCategory.content:
      return 'Content unavailable';
    case ErrorCategory.security:
      return 'Security / SSL';
    case ErrorCategory.validation:
      return 'Invalid URL';
    case ErrorCategory.process:
      return 'yt-dlp / ffmpeg process';
    case ErrorCategory.data:
      return 'Data parsing';
    case ErrorCategory.user:
      return 'Cancelled';
    case ErrorCategory.outdatedTool:
      return 'Outdated yt-dlp';
    case ErrorCategory.toolUpdate:
      return 'Tool update';
    case ErrorCategory.unknown:
      return 'Unknown';
  }
}
