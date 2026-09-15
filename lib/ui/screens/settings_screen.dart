import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../providers/tool_update_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../core/utils/platform_utils.dart';
import '../../services/core/android_storage_service.dart';
import '../../services/core/logging_service.dart';
import '../../core/utils/error_helper.dart';
import '../widgets/error_details_dialog.dart';
import '../widgets/update_dialog.dart';
import '../widgets/logs_viewer.dart';
import '../widgets/bug_report_dialog.dart';
import '../widgets/floating_progress_overlay.dart';
import '../widgets/app_logo.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAppVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<PlatformSettingsProvider>();
      if (provider.isAndroid) {
        provider.refreshBatteryOptimizationStatus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check battery optimization when the user returns from the system dialog.
    if (state == AppLifecycleState.resumed && mounted) {
      final provider = context.read<PlatformSettingsProvider>();
      if (provider.isAndroid) {
        provider.refreshBatteryOptimizationStatus();
      }
    }
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<PlatformSettingsProvider>();

    return SafeArea(
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                title: const Text('Settings'),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                actions: [
                  if (PlatformUtils.isAndroid)
                    IconButton(
                      icon: const Icon(Icons.home_outlined),
                      tooltip: 'Home',
                      onPressed: () =>
                          context.read<NavigationProvider>().switchToHome(),
                    ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader('TOOLS MANAGEMENT'),
                    const SizedBox(height: 16),
                    _buildToolsSection(context, settingsProvider),

                    const SizedBox(height: 32),
                    _buildSectionHeader('DOWNLOAD PREFERENCES'),
                    const SizedBox(height: 16),
                    _buildDownloadSection(context, settingsProvider),

                    const SizedBox(height: 32),
                    _buildSectionHeader('APPEARANCE'),
                    const SizedBox(height: 16),
                    _buildAppearanceSection(context, settingsProvider),

                    const SizedBox(height: 32),
                    _buildSectionHeader('AUTHENTICATION & COOKIES'),
                    const SizedBox(height: 16),
                    _buildAuthSection(context, settingsProvider),

                    const SizedBox(height: 32),
                    _buildSectionHeader('ADVANCED'),
                    const SizedBox(height: 16),
                    _buildAdvancedSection(context, settingsProvider),

                    const SizedBox(height: 32),
                    _buildSectionHeader('LOGS & DEBUGGING'),
                    const SizedBox(height: 16),
                    _buildLogsSection(context),

                    const SizedBox(height: 32),
                    _buildSectionHeader('APP UPDATES'),
                    const SizedBox(height: 16),
                    _buildUpdateSection(context),

                    const SizedBox(height: 48),
                    _buildAboutSection(context, settingsProvider),
                    const SizedBox(height: 48),
                  ]),
                ),
              ),
            ],
          ),
          // Floating progress overlay — PF8: RepaintBoundary to isolate repaints
          const RepaintBoundary(child: FloatingProgressOverlay()),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // --- Section Container ---
  Widget _buildSettingsSection({required List<Widget> children}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Column(children: children),
    );
  }

  // --- Modern Tile ---
  Widget _buildSettingsTile({
    required String title,
    String? subtitle,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.transparent,
            highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (iconColor ?? theme.colorScheme.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: iconColor ?? theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing,
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          ),
      ],
    );
  }

  // --- Modern Toggle Tile ---
  Widget _buildToggleTile({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);

    return _buildSettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      showDivider: showDivider,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: theme.colorScheme.primary,
      ),
    );
  }

  // --- Tools Section ---
  Widget _buildToolsSection(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    return Consumer<ToolUpdateProvider>(
      builder: (context, toolProvider, child) {
        final ytdlpState = toolProvider.ytdlpState;
        final ffmpegState = toolProvider.ffmpegState;

        return _buildSettingsSection(
          children: [
            _buildToolTile(
              context,
              title: 'yt-dlp',
              icon: Icons.terminal_rounded,
              state: ytdlpState,
              onCheckUpdate: () => toolProvider.checkYtdlpForUpdate(force: true),
              onUpdate: ytdlpState.hasUpdate
                  ? () => toolProvider.updateYtdlp()
                  : null,
              onCancel: ytdlpState.isBusy
                  ? () => toolProvider.cancelYtdlpUpdate()
                  : null,
              onInstall: () => toolProvider.installYtdlp(),
              onAdvanced: () => _showToolAdvancedSheet(
                context,
                provider,
                toolProvider,
                'yt-dlp',
              ),
            ),
            _buildToolTile(
              context,
              title: 'FFmpeg',
              icon: Icons.video_settings_rounded,
              state: ffmpegState,
              onCheckUpdate: () => toolProvider.checkFfmpegForUpdate(force: true),
              onUpdate: ffmpegState.hasUpdate
                  ? () => toolProvider.updateFfmpeg()
                  : null,
              onCancel: ffmpegState.isBusy
                  ? () => toolProvider.cancelFfmpegUpdate()
                  : null,
              onInstall: () => toolProvider.installFfmpeg(),
              onAdvanced: () => _showToolAdvancedSheet(
                context,
                provider,
                toolProvider,
                'FFmpeg',
              ),
              isOptional: true,
              showDivider: false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required ToolUpdateState state,
    required VoidCallback onCheckUpdate,
    VoidCallback? onUpdate,
    required VoidCallback onInstall,
    required VoidCallback onAdvanced,
    VoidCallback? onCancel,
    bool isOptional = false,
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);

    String subtitle;
    Color iconColor;
    Widget? trailing;

    VoidCallback? tileTap;
    if (state.status == ToolUpdateStatus.error) {
      final rawError =
          state.errorMessage ??
          state.statusMessage ??
          'Operation failed. Tap to inspect.';
      final parsed = ErrorHelper.parse(rawError);
      subtitle = '${parsed.friendlyMessage} (Tap for info)';
      iconColor = Colors.red;
      tileTap = () => ErrorDetailsDialog.show(
        context,
        error: parsed,
        customTitle: '$title Error',
        onRetry: onCheckUpdate,
      );
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: theme.colorScheme.error,
            ),
            tooltip: 'View Error Details',
            onPressed: tileTap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          _buildSmallButton('Retry', onCheckUpdate),
          const SizedBox(width: 8),
          _buildAdvancedButton(onAdvanced),
        ],
      );
    } else if (state.isBusy) {
      subtitle = state.statusMessage ?? 'Working...';
      iconColor = theme.colorScheme.primary;
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: state.progress > 0 ? state.progress : null,
              color: theme.colorScheme.primary,
            ),
          ),
          if (onCancel != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onCancel,
              icon: Icon(Icons.close_rounded, size: 20, color: Colors.red),
              visualDensity: VisualDensity.compact,
              tooltip: 'Cancel',
            ),
          ],
        ],
      );
    } else if (state.hasUpdate) {
      subtitle = 'Update available: ${state.latestVersion}';
      iconColor = Colors.orange;
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'Update',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildSmallButton('Update', onUpdate!),
          const SizedBox(width: 8),
          _buildAdvancedButton(onAdvanced),
        ],
      );
    } else if (state.isAvailable) {
      // Tool is available - show version and status
      if (state.status == ToolUpdateStatus.upToDate) {
        subtitle = 'Up to date (v${state.currentVersion})';
      } else if (state.currentVersion != null) {
        // Tool is installed but update status not checked yet
        subtitle = 'Installed (v${state.currentVersion})';
      } else {
        // Fallback if version is somehow null
        subtitle = 'Installed';
      }
      iconColor = Colors.green;
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSmallButton('Check', onCheckUpdate),
          const SizedBox(width: 8),
          _buildAdvancedButton(onAdvanced),
        ],
      );
    } else {
      subtitle = isOptional ? 'Not found (Optional)' : 'Not found';
      iconColor = isOptional ? Colors.grey : Colors.red;
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOptional)
            Text(
              'Optional',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          const SizedBox(width: 8),
          _buildSmallButton('Install', onInstall, filled: !isOptional),
          const SizedBox(width: 8),
          _buildAdvancedButton(onAdvanced),
        ],
      );
    }

    return _buildSettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      trailing: trailing,
      onTap: tileTap,
      showDivider: showDivider,
    );
  }

  // --- Logs Section ---
  Widget _buildLogsSection(BuildContext context) {
    return _buildSettingsSection(
      children: [
        _buildSettingsTile(
          title: 'Report a Bug',
          subtitle: 'Build a report (copy / save / file on GitHub)',
          icon: Icons.pest_control_rounded,
          iconColor: Theme.of(context).colorScheme.primary,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => BugReportDialog.show(context),
        ),
        _buildSettingsTile(
          title: 'Export Logs',
          subtitle: 'Save app.log to a folder you choose',
          icon: Icons.file_download_rounded,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => _exportLogs(context),
        ),
        RecentLogsPreview(onViewAll: () => _showLogsViewer(context)),
        _buildSettingsTile(
          title: 'View Logs',
          subtitle: 'Developer logs and debugging info',
          icon: Icons.receipt_long_rounded,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => _showLogsViewer(context),
        ),
        _buildSettingsTile(
          title: 'Download Progress',
          subtitle: 'Show floating progress indicator',
          icon: Icons.download_rounded,
          showDivider: false,
          trailing: const CompactDownloadProgress(showWhenEmpty: true),
        ),
      ],
    );
  }

  Future<void> _exportLogs(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = LoggingService();
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.fuchsia;

    try {
      final pickedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select a folder to export logs',
      );

      if (pickedPath == null) return;

      // Fail fast on SD-card / unwritable picks: FilePicker returns a raw
      // path with no persistable SAF grant, so yt-dlp-style raw writes would
      // fail later. Validate before attempting the export.
      if (PlatformUtils.isAndroid) {
        final validation =
            await AndroidStorageService().validateCustomDirectory(pickedPath);
        if (!validation.ok) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(content: Text(validation.reason ?? 'Folder not usable.')),
          );
          return;
        }
      }

      final exportedPath = await service.exportLogsToFile(pickedPath);
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text('Logs exported to $exportedPath')),
      );
    } catch (e) {
      if (!isMobile) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to export logs: $e')),
        );
        return;
      }

      try {
        final copiedText = service.exportLogs();
        if (copiedText.trim().isEmpty) {
          throw StateError('No log entries are available to copy.');
        }

        await Clipboard.setData(ClipboardData(text: copiedText));
        if (!mounted) return;

        messenger.showSnackBar(
          const SnackBar(content: Text('Logs copied to clipboard')),
        );
      } catch (clipboardError) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to export logs: $clipboardError')),
        );
      }
    }
  }

  void _showLogsViewer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const LogsViewer(),
      ),
    );
  }

  Widget _buildAdvancedButton(VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        Icons.tune_rounded,
        size: 20,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
      ),
      tooltip: 'Advanced Settings',
    );
  }

  Widget _buildSmallButton(
    String label,
    VoidCallback onPressed, {
    bool filled = false,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        splashColor: Colors.transparent,
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: filled
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? Colors.black : theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildBatteryOptimizationTile(PlatformSettingsProvider provider) {
    final theme = Theme.of(context);
    final isExempt = provider.isBatteryOptimizationIgnored;
    final isChecking = provider.isCheckingBatteryOptimization;
    final color = isExempt ? Colors.green : Colors.orange;

    return _buildSettingsTile(
      title: 'Unrestricted Battery',
      subtitle: isExempt
          ? 'Allowed — downloads keep running when the screen is off'
          : 'Restricted — Android may pause downloads when the screen is off. Tap to allow.',
      icon: isExempt
          ? Icons.battery_charging_full_rounded
          : Icons.battery_alert_rounded,
      iconColor: color,
      trailing: isChecking
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          : _buildStatusChip(isExempt ? 'ALLOWED' : 'RESTRICTED', color: color),
      onTap: isChecking
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              // Blocks until the user responds to the system dialog (or
              // returns from the fallback battery settings page).
              final granted =
                  await provider.requestBatteryOptimizationExemption();
              if (!mounted) return;

              if (granted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Unrestricted battery allowed — downloads will keep running in the background.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                _showBatteryHelpDialog(provider);
              }
            },
      showDivider: true,
    );
  }

  Widget _buildOemAutostartTile(PlatformSettingsProvider provider) {
    final rawManufacturer = provider.deviceManufacturer ?? 'Device';
    final manufacturer = rawManufacturer.isNotEmpty
        ? '${rawManufacturer[0].toUpperCase()}${rawManufacturer.substring(1)}'
        : 'OEM';

    return _buildSettingsTile(
      title: '$manufacturer Autostart Settings',
      subtitle:
          'Open $manufacturer settings to permit autostart and unrestricted background execution',
      icon: Icons.power_settings_new_rounded,
      iconColor: Colors.blueAccent,
      trailing: const Icon(Icons.open_in_new_rounded, size: 20),
      onTap: () async {
        await provider.openOemAutostartSettings();
      },
      showDivider: true,
    );
  }

  /// Shown when the exemption request came back without a grant — either the
  /// user denied the prompt, or their device (Samsung/Xiaomi/...) skipped the
  /// prompt and sent them to the settings list instead. Offers a one-tap jump
  /// to the battery-optimization list page.
  void _showBatteryHelpDialog(PlatformSettingsProvider provider) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.battery_alert_rounded,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: const Text('Downloads may pause'),
        content: const Text(
          'Your device didn\'t grant unrestricted battery. Some phones '
          '(Samsung, Xiaomi, etc.) hide the usual prompt.\n\n'
          'To fix it, find this app in the battery optimization list and '
          'set it to "Don\'t optimize" / "Unrestricted".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: const Text('Open battery settings'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              provider.openBatteryOptimizationSettings();
            },
          ),
        ],
      ),
    );
  }

  // --- Download Preferences Section ---
  Widget _buildDownloadSection(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    final theme = Theme.of(context);
    return _buildSettingsSection(
      children: [
        _buildSettingsTile(
          title: 'Default Quality',
          subtitle: provider.defaultQuality,
          icon: Icons.high_quality_rounded,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => _showQualitySheet(context, provider),
        ),
        _buildSettingsTile(
          title: 'Default Subtitle Language',
          subtitle: _subtitleLanguageLabel(provider.defaultSubtitleLanguage),
          icon: Icons.subtitles_rounded,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => _showDefaultSubtitleLanguageSheet(context, provider),
        ),
        _buildSettingsTile(
          title: 'Download Location',
          subtitle: provider.outputPath ?? 'Not set',
          icon: Icons.folder_rounded,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () async {
            final result = await FilePicker.platform.getDirectoryPath();
            if (result == null) return;
            if (!context.mounted) return;
            // FilePicker gives a raw path with no persistable SAF grant.
            // Validate writability now (blocks SD-card trap) instead of
            // saving a folder that will fail writes later.
            if (provider.isAndroid) {
              final validation = await AndroidStorageService()
                  .validateCustomDirectory(result);
              if (!context.mounted) return;
              if (!validation.ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(validation.reason ?? 'Folder not usable.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
            }
            await provider.setOutputPath(result);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download location set to $result'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        if (provider.isAndroid)
          _AndroidStoragePermissionTile(provider: provider),
        const _ConcurrentDownloadsControl(),
        _buildToggleTile(
          title: 'Embed Thumbnail',
          subtitle: 'Add thumbnail to downloaded files',
          icon: Icons.image_rounded,
          value: provider.embedThumbnail,
          onChanged: provider.setEmbedThumbnail,
        ),
        _buildToggleTile(
          title: 'Embed Metadata',
          subtitle: 'Include video info in file metadata',
          icon: Icons.info_outline_rounded,
          value: provider.embedMetadata,
          onChanged: provider.setEmbedMetadata,
          showDivider: false,
        ),
      ],
    );
  }

  void _showQualitySheet(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    final qualities = ['Best', '4K', '1080p', '720p', '480p', 'Audio Only'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBottomSheet(
        title: 'Select Quality',
        children: qualities
            .map(
              (q) => _buildSheetOption(
                label: q,
                isSelected: provider.defaultQuality == q,
                icon: _getQualityIcon(q),
                onTap: () {
                  provider.setDefaultQuality(q);
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  IconData _getQualityIcon(String quality) {
    switch (quality) {
      case 'Best':
        return Icons.auto_awesome_rounded;
      case '4K':
        return Icons.four_k_rounded;
      case '1080p':
        return Icons.hd_rounded;
      case '720p':
        return Icons.sd_rounded;
      case '480p':
        return Icons.sd_rounded;
      case 'Audio Only':
        return Icons.audiotrack_rounded;
      default:
        return Icons.high_quality_rounded;
    }
  }

  void _showDefaultSubtitleLanguageSheet(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    const subtitleLanguages = <Map<String, String>>[
      {'code': 'auto', 'label': 'Auto (video default)'},
      {'code': 'en', 'label': 'English'},
      {'code': 'ar', 'label': 'Arabic'},
      {'code': 'es', 'label': 'Spanish'},
      {'code': 'fr', 'label': 'French'},
      {'code': 'de', 'label': 'German'},
      {'code': 'it', 'label': 'Italian'},
      {'code': 'pt', 'label': 'Portuguese'},
      {'code': 'ru', 'label': 'Russian'},
      {'code': 'hi', 'label': 'Hindi'},
      {'code': 'tr', 'label': 'Turkish'},
      {'code': 'ja', 'label': 'Japanese'},
      {'code': 'ko', 'label': 'Korean'},
      {'code': 'zh', 'label': 'Chinese'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBottomSheet(
        title: 'Default Subtitle Language',
        children: subtitleLanguages
            .map(
              (lang) => _buildSheetOption(
                label: lang['label']!,
                subtitle: lang['code'] == 'auto'
                    ? 'Pick first available subtitle automatically'
                    : 'Code: ${lang['code']}',
                isSelected: provider.defaultSubtitleLanguage == lang['code'],
                icon: _getSubtitleLanguageIcon(lang['code']!),
                onTap: () {
                  provider.setDefaultSubtitleLanguage(lang['code']!);
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  String _subtitleLanguageLabel(String code) {
    const labels = <String, String>{
      'auto': 'Auto (video default)',
      'en': 'English',
      'ar': 'Arabic',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'hi': 'Hindi',
      'tr': 'Turkish',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
    };
    return labels[code] ?? code.toUpperCase();
  }

  IconData _getSubtitleLanguageIcon(String code) {
    if (code == 'auto') return Icons.auto_awesome_rounded;
    if (code == 'ar') return Icons.language_rounded;
    return Icons.translate_rounded;
  }

  // --- Appearance Section ---
  Widget _buildAppearanceSection(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    return _buildSettingsSection(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Theme Mode',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildThemeChips(provider),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        _buildToggleTile(
          title: 'Enable Animations',
          subtitle: 'Show UI animations and page transitions',
          icon: Icons.animation_rounded,
          value: provider.enableAnimations,
          onChanged: provider.setEnableAnimations,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildThemeChips(PlatformSettingsProvider provider) {
    return Row(
      children: [
        _buildThemeChip(
          label: 'Auto',
          icon: Icons.auto_mode_rounded,
          isSelected: provider.themeMode == ThemeMode.system,
          onTap: () => provider.setThemeMode(ThemeMode.system),
        ),
        const SizedBox(width: 8),
        _buildThemeChip(
          label: 'Light',
          icon: Icons.light_mode_rounded,
          isSelected: provider.themeMode == ThemeMode.light,
          onTap: () => provider.setThemeMode(ThemeMode.light),
        ),
        const SizedBox(width: 8),
        _buildThemeChip(
          label: 'Dark',
          icon: Icons.dark_mode_rounded,
          isSelected: provider.themeMode == ThemeMode.dark,
          onTap: () => provider.setThemeMode(ThemeMode.dark),
        ),
      ],
    );
  }

  Widget _buildThemeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Auth Section ---
  Widget _buildAuthSection(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    final isAuthData = provider.isCookieActive;
    final theme = Theme.of(context);

    return _buildSettingsSection(
      children: [
        _buildSettingsTile(
          title: 'Current Status',
          subtitle: provider.cookieStatus,
          icon: isAuthData
              ? Icons.lock_open_rounded
              : Icons.lock_outline_rounded,
          iconColor: isAuthData ? Colors.green : Colors.grey,
          trailing: isAuthData
              ? _buildSmallButton('Logout', () async {
                  await provider.logoutFromYouTube();
                  await provider.setCookieBrowser(null);
                })
              : null,
        ),
        _buildSettingsTile(
          title: 'Login to YouTube',
          subtitle: 'Open secure browser to sign in',
          icon: Icons.login_rounded,
          iconColor: Colors.blueAccent,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () async {
            final result = await Navigator.pushNamed(context, '/youtube_login');
            if (result == true) {
              await provider.onYouTubeLoginComplete();
            }
          },
        ),
        // Browser cookie extraction (--cookies-from-browser) is a desktop-only
        // yt-dlp feature; on Android it silently fails. Hide the tile there.
        if (!provider.isAndroid)
          _buildSettingsTile(
            title: 'Use Browser Cookies',
            subtitle: _getBrowserLabel(provider.settings.cookieBrowser),
            icon: Icons.cookie_rounded,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            onTap: () => _showBrowserSheet(context, provider),
          ),
        _buildToggleTile(
          title: 'Enable Cookies File',
          subtitle: 'Import Netscape format cookies.txt',
          icon: Icons.file_copy_outlined,
          value: provider.enableCookies,
          onChanged: provider.setEnableCookies,
          showDivider: provider.enableCookies,
        ),
        if (provider.enableCookies)
          _buildSettingsTile(
            title: 'Import cookies.txt',
            subtitle: provider.cookieFileName ?? 'No file selected',
            icon: Icons.upload_file_rounded,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            showDivider: false,
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['txt'],
              );

              if (result != null) {
                provider.setCookiePath(result.files.single.path);
              }
            },
          ),
      ],
    );
  }

  String _getBrowserLabel(String? browser) {
    if (browser == null || browser.isEmpty) return 'Not selected';
    return browser[0].toUpperCase() + browser.substring(1);
  }

  // --- Tool Advanced Sheet ---
  void _showToolAdvancedSheet(
    BuildContext context,
    PlatformSettingsProvider provider,
    ToolUpdateProvider toolProvider,
    String toolName,
  ) {
    final isYtdlp = toolName == 'yt-dlp';
    final currentPath = isYtdlp
        ? provider.activeYtdlpPath
        : (provider.activeFfmpegPath ?? 'System PATH');

    // Use version from ToolUpdateProvider state (updated during check)
    final toolState = isYtdlp
        ? toolProvider.ytdlpState
        : toolProvider.ffmpegState;
    final currentVersion = toolState.currentVersion;
    final latestVersion = toolState.latestVersion;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBottomSheet(
        title: '$toolName Advanced Settings',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Current Path', currentPath),
                const SizedBox(height: 12),
                _buildInfoRow('Installed Version', currentVersion ?? 'Unknown'),
                if (latestVersion != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow('Latest Version', latestVersion),
                ],
              ],
            ),
          ),
          const Divider(height: 1, indent: 24, endIndent: 24),
          _buildSheetOption(
            label: 'Download / Re-install',
            subtitle: isYtdlp
                ? 'Download latest binary to app folder'
                : 'Download FFmpeg (Windows Only)',
            isSelected: false,
            icon: Icons.download_for_offline_rounded,
            onTap: () {
              Navigator.pop(context);
              if (isYtdlp) {
                toolProvider.installYtdlp();
              } else {
                toolProvider.installFfmpeg();
              }
            },
          ),
          if (PlatformUtils.isWindows)
            _buildSheetOption(
              label: 'Select Custom Binary',
              subtitle: 'Choose an existing .exe file',
              isSelected: false,
              icon: Icons.file_open_rounded,
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['exe'],
                );
                if (result != null && result.files.single.path != null) {
                  if (isYtdlp) {
                    await provider.setYtdlpPath(result.files.single.path);
                  } else {
                    await provider.setFfmpegPath(result.files.single.path);
                  }
                  await toolProvider.refreshAvailability();
                }
              },
            ),
          _buildSheetOption(
            label: 'Reset to Managed',
            subtitle: 'Use app-managed or system version',
            isSelected: false,
            icon: Icons.restart_alt_rounded,
            onTap: () async {
              Navigator.pop(context);
              if (isYtdlp) {
                await provider.setYtdlpPath(null);
              } else {
                await provider.setFfmpegPath(null);
              }
              await toolProvider.refreshAvailability();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            color: Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showBrowserSheet(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    final browsers = ['chrome', 'firefox', 'edge', 'opera', 'brave', 'vivaldi'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBottomSheet(
        title: 'Select Browser',
        children: browsers
            .map(
              (b) => _buildSheetOption(
                label: b[0].toUpperCase() + b.substring(1),
                isSelected: provider.settings.cookieBrowser == b,
                icon: _getBrowserIcon(b),
                onTap: () {
                  provider.setCookieBrowser(b);
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  IconData _getBrowserIcon(String browser) {
    switch (browser.toLowerCase()) {
      case 'chrome':
        return Icons.public_rounded;
      case 'firefox':
        return Icons.local_fire_department_rounded;
      case 'edge':
        return Icons.open_in_browser_rounded;
      case 'opera':
        return Icons.circle_outlined;
      case 'brave':
        return Icons.shield_rounded;
      case 'vivaldi':
        return Icons.apps_rounded;
      default:
        return Icons.web_rounded;
    }
  }

  // --- Bottom Sheet Builder ---
  Widget _buildBottomSheet({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          left: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          right: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          // Options
          Flexible(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSheetOption({
    required String label,
    String? subtitle,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Advanced Section ---
  Widget _buildAdvancedSection(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    final children = <Widget>[
      _buildToggleTile(
        title: 'Notifications',
        subtitle: 'Show download notifications',
        icon: Icons.notifications_rounded,
        value: provider.enableNotifications,
        onChanged: provider.setEnableNotifications,
      ),
      _buildToggleTile(
        title: 'SponsorBlock',
        subtitle: 'Skip sponsored segments automatically',
        icon: Icons.skip_next_rounded,
        value: provider.sponsorBlockEnabled,
        onChanged: provider.setSponsorBlockEnabled,
      ),
      if (provider.isAndroid) _buildBatteryOptimizationTile(provider),
      if (provider.isAndroid && provider.isAggressiveOem)
        _buildOemAutostartTile(provider),
      _buildToggleTile(
        title: 'Download Archive',
        subtitle: 'Avoid re-downloading videos',
        icon: Icons.history_rounded,
        value: provider.useDownloadArchive,
        onChanged: provider.setUseDownloadArchive,
      ),
      _buildToggleTile(
        title: 'Enable Logging',
        subtitle: 'Record debug information to log file',
        icon: Icons.bug_report_rounded,
        value: provider.enableLogging,
        onChanged: provider.setEnableLogging,
        showDivider: false,
      ),
    ];

    return _buildSettingsSection(children: children);
  }

  Widget _buildUpdateSection(BuildContext context) {
    return Consumer<UpdateProvider>(
      builder: (context, updateProvider, child) {
        return _buildSettingsSection(
          children: [
            _buildSettingsTile(
              title: 'Check for Updates',
              subtitle: updateProvider.hasUpdate
                  ? 'Version ${updateProvider.updateInfo?.version} available'
                  : 'Check for the latest version',
              icon: Icons.system_update_rounded,
              iconColor: updateProvider.hasUpdate ? Colors.orange : null,
              trailing: updateProvider.isChecking
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : updateProvider.hasUpdate
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            'New',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Icon(
                      Icons.chevron_right_rounded,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
              onTap: updateProvider.isChecking
                  ? null
                  : () async {
                      // Manual check always hits GitHub (force = true).
                      await updateProvider.checkForUpdates(force: true);
                      if (!context.mounted) return;
                      // Show the dialog for both update-available and
                      // up-to-date so the user always gets feedback.
                      if (updateProvider.status == UpdateStatus.available ||
                          updateProvider.status == UpdateStatus.upToDate ||
                          updateProvider.status == UpdateStatus.error) {
                        showUpdateDialogWrapper(context);
                      }
                    },
            ),
            _buildToggleTile(
              title: 'Auto-check for Updates',
              subtitle: 'Check automatically on startup',
              icon: Icons.update_rounded,
              value: updateProvider.autoCheckEnabled,
              onChanged: (value) => updateProvider.setAutoCheckEnabled(value),
              showDivider: false,
            ),
          ],
        );
      },
    );
  }

  void showUpdateDialogWrapper(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const UpdateDialog(),
    );
  }

  Widget _buildAboutSection(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          const AppLogo(size: 80, showGlow: true),
          const SizedBox(height: 16),
          Text(
            'AeroTube v$_appVersion',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Made with ',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
              const Text('❤️', style: TextStyle(fontSize: 12)),
              Text(
                ' by Agent',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ).animate().fadeIn(delay: 200.ms),
    );
  }
}

/// Shows current public-Downloads access and lets the user grant it
/// (system dialog or All-files-access settings, depending on Android version).
class _AndroidStoragePermissionTile extends StatefulWidget {
  const _AndroidStoragePermissionTile({required this.provider});

  final PlatformSettingsProvider provider;

  @override
  State<_AndroidStoragePermissionTile> createState() =>
      _AndroidStoragePermissionTileState();
}

class _AndroidStoragePermissionTileState
    extends State<_AndroidStoragePermissionTile>
    with WidgetsBindingObserver {
  bool _granted = true;
  bool _checking = true;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _checking = true);
    try {
      final storage = AndroidStorageService();
      final granted = await storage.hasStoragePermission();
      if (!mounted) return;
      setState(() {
        _granted = granted;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  Future<void> _request() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final storage = AndroidStorageService();
      await storage.requestStoragePermission();
      if (!mounted) return;
      final granted = await storage.hasStoragePermission();
      // If still blocked, open All-files-access settings as a fallback.
      if (!granted) {
        await storage.openManageStorageSettings();
      }
      await _refresh();
      // After a successful grant, switch downloads back to public Downloads.
      if (mounted && _granted) {
        try {
          final preferred = await storage.getPreferredDownloadDirectory();
          if (preferred != widget.provider.outputPath) {
            await widget.provider.setOutputPath(preferred);
          }
        } catch (_) {}
      }
    } catch (_) {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _granted ? 'Storage Access' : 'Grant Storage Access';
    final subtitle = _checking
        ? 'Checking…'
        : _granted
            ? 'Public Downloads folder is writable'
            : 'Allow All files access so downloads save to Downloads/AeroTube';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _requesting ? null : _request,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                _granted
                    ? Icons.sd_storage_rounded
                    : Icons.warning_amber_rounded,
                color: _granted
                    ? theme.colorScheme.primary
                    : Colors.amber.shade700,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              if (_requesting || _checking)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Debounced concurrency control — local drag value, persist only on changeEnd
/// so dragging does NOT trigger per-tick disk write + notifyListeners + SliverList rebuild.
class _ConcurrentDownloadsControl extends StatefulWidget {
  const _ConcurrentDownloadsControl();

  @override
  State<_ConcurrentDownloadsControl> createState() =>
      _ConcurrentDownloadsControlState();
}

class _ConcurrentDownloadsControlState
    extends State<_ConcurrentDownloadsControl> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final persisted =
        context.select<PlatformSettingsProvider, int>((p) => p.maxConcurrentDownloads);
    final displayed = (_dragValue ?? persisted.toDouble()).clamp(1.0, 6.0);

    return Column(
      children: [
        // Title row — mirrors _buildSettingsTile styling without divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.downloading_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Concurrent Downloads',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${displayed.toInt()} active downloads',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(64, 0, 16, 16),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: displayed,
              min: 1,
              max: 6,
              divisions: 5,
              label: '${displayed.toInt()}',
              onChanged: (v) => setState(() => _dragValue = v),
              onChangeEnd: (v) {
                setState(() => _dragValue = null);
                context
                    .read<PlatformSettingsProvider>()
                    .setMaxConcurrentDownloads(v.toInt());
              },
            ),
          ),
        ),
      ],
    );
  }
}
