import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/core/utils/error_helper.dart';

void main() {
  group('ErrorHelper.clean', () {
    test('removes exception class prefixes', () {
      expect(
        ErrorHelper.clean('YtdlpException: Video unavailable'),
        'Video unavailable',
      );
      expect(
        ErrorHelper.clean('YtdlpAndroidException: Sign in to confirm you are not a bot'),
        'Sign in to confirm you are not a bot',
      );
      expect(
        ErrorHelper.clean('ProcessException: command not found'),
        'command not found',
      );
      expect(
        ErrorHelper.clean('Exception: Network error'),
        'Network error',
      );
    });
  });

  group('ErrorHelper.parse', () {
    test('parses authentication errors', () {
      final parsed = ErrorHelper.parse(
        'YtdlpException: Sign in to confirm you are not a bot',
      );
      expect(parsed.category, ErrorCategory.authentication);
      expect(parsed.friendlyMessage, 'Authentication required');
    });

    test('parses rate limit errors', () {
      final parsed = ErrorHelper.parse('HTTP Error 429: Too Many Requests');
      expect(parsed.category, ErrorCategory.rateLimit);
      expect(parsed.friendlyMessage, 'Too many requests');
    });

    test('parses content unavailable errors', () {
      final parsed = ErrorHelper.parse('ERROR: [youtube] Video unavailable');
      expect(parsed.category, ErrorCategory.content);
      expect(parsed.friendlyMessage, 'Video unavailable');
    });

    test('parses network errors', () {
      final parsed = ErrorHelper.parse('SocketException: Failed host lookup');
      expect(parsed.category, ErrorCategory.network);
      expect(parsed.friendlyMessage, 'Network connection error');
    });

    test('parses disk full errors', () {
      final parsed = ErrorHelper.parse('No space left on device');
      expect(parsed.category, ErrorCategory.fileSystem);
      expect(parsed.friendlyMessage, 'Disk space full');
    });

    test('parses outdated tool errors', () {
      final parsed = ErrorHelper.parse('nsig extraction failed: update yt-dlp');
      expect(parsed.category, ErrorCategory.outdatedTool);
      expect(parsed.friendlyMessage, 'Extractor update required');
    });

    test('parses Windows invalid-filename errors', () {
      final parsed = ErrorHelper.parse(
        "ERROR: unable to open for writing: [Errno 22] Invalid argument: 'Axiom | Module_7.mp4'",
      );
      expect(parsed.category, ErrorCategory.fileSystem);
      expect(parsed.title, 'Filename Not Allowed');
      expect(parsed.friendlyMessage, contains('Windows does not allow'));
    });

    test('parses Android platform/update errors including 14.f', () {
      final parsed = ErrorHelper.parse('Platform error: 14.f');
      expect(parsed.category, ErrorCategory.toolUpdate);
      expect(parsed.friendlyMessage, contains('yt-dlp update'));
    });

    test('parses unsupported player_client as outdated extractor', () {
      final parsed = ErrorHelper.parse(
        'ERROR: Unsupported player_client: media',
      );
      expect(parsed.category, ErrorCategory.outdatedTool);
    });

    test('correctly handles multiline errors with real newlines and escaped newlines', () {
      const multiline = 'First line\nERROR: Something broke in extractor\nTraceback info';
      final parsed = ErrorHelper.parse(multiline);
      expect(parsed.suggestion, contains('Something broke in extractor'));

      const escapedMultiline = r'First line\nERROR: Escaped newline error\nTraceback';
      final parsedEscaped = ErrorHelper.parse(escapedMultiline);
      expect(parsedEscaped.suggestion, contains('Escaped newline error'));
    });
  });

  group('ErrorHelper.formatDownloadError', () {
    test('formats HTTP 416 resume error', () {
      final formatted = ErrorHelper.formatDownloadError(
        'ERROR: HTTP Error 416: Requested Range Not Satisfiable',
      );
      expect(formatted, contains('HTTP 416'));
      expect(formatted, contains('rejected a resume request'));
    });

    test('extracts ERROR line from multiline stderr output', () {
      const output = 'Usage info...\n[debug] starting\nERROR: [youtube] abc: Private video\nExiting';
      final formatted = ErrorHelper.formatDownloadError(output, 1);
      expect(formatted, 'ERROR: [youtube] abc: Private video');
    });

    test('handles empty output with exitCode', () {
      final formatted = ErrorHelper.formatDownloadError('', 2);
      expect(formatted, 'Process exited with code 2');
    });
  });
}
