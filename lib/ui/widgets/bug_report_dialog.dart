import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/tool_update_provider.dart';
import '../../services/core/bug_report_service.dart';
import '../../services/core/logging_service.dart';

/// User-facing "Report a Bug" form.
///
/// Collects a short description + steps, attaches sanitized diagnostics and a
/// log tail, then lets the user copy / save / open GitHub with a prefilled
/// issue body. Safe to open from Settings or from an ErrorDetailsDialog.
class BugReportDialog extends StatefulWidget {
  final String? initialSummary;
  final String? initialErrorDetail;
  final String? initialCategory;

  const BugReportDialog({
    super.key,
    this.initialSummary,
    this.initialErrorDetail,
    this.initialCategory,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialSummary,
    String? initialErrorDetail,
    String? initialCategory,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => BugReportDialog(
        initialSummary: initialSummary,
        initialErrorDetail: initialErrorDetail,
        initialCategory: initialCategory,
      ),
    );
  }

  @override
  State<BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<BugReportDialog> {
  final _summaryController = TextEditingController();
  final _stepsController = TextEditingController();
  final _expectedController = TextEditingController();
  final _actualController = TextEditingController();
  final _service = BugReportService();

  BugDiagnostics? _diagnostics;
  bool _loadingDiagnostics = true;
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;
  String? _selectedCategory;

  static const List<String> _categories = [
    'Download failed',
    'Search / metadata',
    'Playlist',
    'Login / cookies',
    'Crash / freeze',
    'UI / layout',
    'Update',
    'Performance',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSummary != null) {
      _summaryController.text = widget.initialSummary!;
    }
    if (widget.initialErrorDetail != null) {
      _actualController.text = widget.initialErrorDetail!;
    }
    _selectedCategory = widget.initialCategory;
    _loadDiagnostics();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _stepsController.dispose();
    _expectedController.dispose();
    _actualController.dispose();
    super.dispose();
  }

  Future<void> _loadDiagnostics() async {
    String? ytdlpVersion;
    String? ffmpegVersion;
    String? outputPath;
    bool? cookiesEnabled;

    try {
      final tools = context.read<ToolUpdateProvider>();
      ytdlpVersion = tools.ytdlpState.currentVersion;
      ffmpegVersion = tools.ffmpegState.currentVersion;
    } catch (_) {}

    try {
      final settings = context.read<PlatformSettingsProvider>();
      outputPath = settings.outputPath;
      cookiesEnabled = settings.enableCookies;
    } catch (_) {}

    final diagnostics = await _service.collectDiagnostics(
      ytdlpVersion: ytdlpVersion,
      ffmpegVersion: ffmpegVersion,
      outputPath: outputPath,
      cookiesEnabled: cookiesEnabled,
    );

    if (!mounted) return;
    setState(() {
      _diagnostics = diagnostics;
      _loadingDiagnostics = false;
    });
  }

  void _setStatus(String message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<String?> _buildReport() async {
    final summary = _summaryController.text.trim();
    if (summary.isEmpty) {
      _setStatus('Please describe the problem first.', isError: true);
      return null;
    }
    return _service.buildFullReport(
      summary: summary,
      stepsToReproduce: _stepsController.text,
      expectedBehavior: _expectedController.text,
      actualBehavior: _actualController.text,
      category: _selectedCategory,
      errorDetail: widget.initialErrorDetail,
      ytdlpVersion: _diagnostics?.ytdlpVersion,
      ffmpegVersion: _diagnostics?.ffmpegVersion,
      outputPath: _diagnostics?.outputPathLabel,
      cookiesEnabled: _diagnostics?.cookiesEnabled,
    );
  }

  Future<void> _copyReport() async {
    setState(() => _busy = true);
    try {
      final report = await _buildReport();
      if (report == null) return;
      await Clipboard.setData(ClipboardData(text: report));
      if (!mounted) return;
      _setStatus('Report copied — paste it into a GitHub issue or chat.');
    } catch (e) {
      _setStatus('Could not build report: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveReport() async {
    setState(() => _busy = true);
    try {
      final report = await _buildReport();
      if (report == null) return;

      final picked = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose a folder for the bug report',
      );
      if (picked == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final path = await _service.saveReport(picked, report);
      if (!mounted) return;
      _setStatus('Saved to $path');
    } catch (e) {
      _setStatus('Could not save report: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openGitHub() async {
    setState(() => _busy = true);
    try {
      final summary = _summaryController.text.trim();
      final report = await _buildReport();
      if (report == null) return;

      // Always copy first so the user can paste if the URL body is clipped
      // or they close the browser by accident.
      await Clipboard.setData(ClipboardData(text: report));

      final diagnostics = _diagnostics;
      final title = diagnostics != null
          ? _service.issueTitleWithMeta(summary, diagnostics)
          : '[Bug] $summary';

      final uri = _service.buildGitHubIssueUrl(title: title, body: report);

      if (!mounted) return;
      // Keep the dialog open so the user sees "you still need to Submit".
      // Only pop if launch clearly cannot happen.
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;

      if (launched) {
        _setStatus(
          'GitHub issue form opened. Press “Submit new issue” there — '
          'the report is also on your clipboard.',
        );
        setState(() => _busy = false);
      } else {
        _setStatus(
          'Could not open the browser. Full report is on your clipboard — '
          'paste it into github.com/Amadoson3001/aerotube-downloader/issues/new',
          isError: true,
        );
        setState(() => _busy = false);
      }
    } catch (e) {
      if (mounted) {
        _setStatus(
          'Could not open GitHub (report is on clipboard): $e',
          isError: true,
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bug_report_rounded,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Report a Bug',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Builds a report with sanitized logs. Nothing is sent until you file it.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DiagnosticsBanner(loading: _loadingDiagnostics),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _summaryController,
                        decoration: const InputDecoration(
                          labelText: 'What went wrong? *',
                          hintText: 'Download stops at 99% for every video',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        maxLength: 160,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category (optional)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Not sure'),
                          ),
                          ..._categories.map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCategory = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _stepsController,
                        decoration: const InputDecoration(
                          labelText: 'Steps to reproduce',
                          hintText:
                              '1. Paste a video link\n2. Choose 1080p\n3. Start download',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 3,
                        maxLines: 5,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _expectedController,
                        decoration: const InputDecoration(
                          labelText: 'What did you expect?',
                          hintText: 'File appears in Downloads/AeroTube',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _actualController,
                        decoration: const InputDecoration(
                          labelText: 'What actually happened?',
                          hintText: 'Error dialog: network connection error',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      if (widget.initialErrorDetail != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Attached error details',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.initialErrorDetail!,
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _statusIsError
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Where does this go?',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• Copy — stays on your clipboard\n'
                              '• Save — writes a local .md file you choose\n'
                              '• File on GitHub — opens the issue form; you still press Submit\n\n'
                              'AeroTube does not upload reports in the background. '
                              'Cookies and tokens are redacted before sharing.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.4,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _copyReport,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _saveReport,
                      icon: const Icon(Icons.save_alt_rounded, size: 16),
                      label: const Text('Save'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _openGitHub,
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('File on GitHub'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsBanner extends StatelessWidget {
  final bool loading;

  const _DiagnosticsBanner({required this.loading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logging = LoggingService();

    if (loading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('Collecting diagnostics…', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    final chips = <Widget>[
      _chip(context, PlatformUtils.platformName),
      _chip(context, 'session ${logging.sessionId}'),
      _chip(context, logging.isEnabled ? 'logs on' : 'logs off',
          warn: !logging.isEnabled),
      if (logging.errorCount > 0)
        _chip(
          context,
          '${logging.errorCount} error${logging.errorCount == 1 ? '' : 's'}',
          warn: true,
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diagnostics attached',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
          if (!logging.isEnabled) ...[
            const SizedBox(height: 8),
            Text(
              'Logging is off — turn it on in Settings → Logs for a richer report.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade800,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, {bool warn = false}) {
    final theme = Theme.of(context);
    final color = warn ? Colors.orange.shade800 : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
