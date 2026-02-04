import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../providers/tool_update_provider.dart';
import '../widgets/update_dialog.dart';
import '../widgets/logs_viewer.dart';
import '../widgets/floating_progress_overlay.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return Stack(
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
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        // Floating progress overlay
        const FloatingProgressOverlay(),
      ],
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
                            maxLines: 1,
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
  Widget _buildToolsSection(BuildContext context, SettingsProvider provider) {
    final theme = Theme.of(context);
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
              onCheckUpdate: () => toolProvider.checkYtdlpForUpdate(),
              onUpdate: ytdlpState.hasUpdate
                  ? () => toolProvider.updateYtdlp()
                  : null,
              onInstall: () => toolProvider.installYtdlp(),
              onAdvanced: () =>
                  _showToolAdvancedSheet(context, provider, toolProvider, 'yt-dlp'),
            ),
            _buildToolTile(
              context,
              title: 'FFmpeg',
              icon: Icons.video_settings_rounded,
              state: ffmpegState,
              onCheckUpdate: () => toolProvider.checkFfmpegForUpdate(),
              onUpdate: ffmpegState.hasUpdate
                  ? () => toolProvider.updateFfmpeg()
                  : null,
              onInstall: () => toolProvider.installFfmpeg(),
              onAdvanced: () =>
                  _showToolAdvancedSheet(context, provider, toolProvider, 'FFmpeg'),
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
    bool isOptional = false,
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);

    String subtitle;
    Color iconColor;
    Widget? trailing;

    if (state.isBusy) {
      subtitle = state.statusMessage ?? 'Working...';
      iconColor = theme.colorScheme.primary;
      trailing = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: state.progress > 0 ? state.progress : null,
          color: theme.colorScheme.primary,
        ),
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
              color: Colors.orange.withOpacity(0.2),
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
          _buildAdvancedButton(onAdvanced),
        ],
      );
    } else if (state.isAvailable) {
      subtitle = state.status == ToolUpdateStatus.upToDate
          ? 'Up to date (v${state.currentVersion})'
          : 'Installed (v${state.currentVersion})';
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
      showDivider: showDivider,
    );
  }

  // --- Logs Section ---
  Widget _buildLogsSection(BuildContext context) {
    return _buildSettingsSection(
      children: [
        _buildSettingsTile(
          title: 'View Logs',
          subtitle: 'Developer logs and debugging info',
          icon: Icons.bug_report_rounded,
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

  void _showFFmpegUpdateInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FFmpeg Update'),
        content: const Text(
          'FFmpeg updates require manual download from the official website. Would you like to open the download page?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              launchUrl(Uri.parse('https://www.gyan.dev/ffmpeg/builds/'));
              Navigator.pop(context);
            },
            child: const Text('Open Download Page'),
          ),
        ],
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

  Future<void> _updateTool(
    BuildContext context,
    SettingsProvider provider,
    String toolName,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Checking for $toolName updates...')),
    );

    bool result = false;
    if (toolName == 'yt-dlp') {
      result = await provider.updateYtdlp();
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result ? '$toolName is up to date!' : 'Failed to update $toolName',
        ),
      ),
    );
  }



  // --- Download Preferences Section ---
  Widget _buildDownloadSection(
    BuildContext context,
    SettingsProvider provider,
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
          title: 'Download Location',
          subtitle: provider.outputPath ?? 'Not set',
          icon: Icons.folder_rounded,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () async {
            final result = await FilePicker.platform.getDirectoryPath();
            if (result != null) {
              provider.setOutputPath(result);
            }
          },
        ),
        _buildSettingsTile(
          title: 'Concurrent Downloads',
          subtitle: '${provider.maxConcurrentDownloads} active downloads',
          icon: Icons.downloading_rounded,
          showDivider: false,
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
              value: provider.maxConcurrentDownloads.toDouble(),
              min: 1,
              max: 6,
              divisions: 5,
              label: '${provider.maxConcurrentDownloads}',
              onChanged: (v) => provider.setMaxConcurrentDownloads(v.toInt()),
            ),
          ),
        ),
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

  void _showQualitySheet(BuildContext context, SettingsProvider provider) {
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

  // --- Appearance Section ---
  Widget _buildAppearanceSection(
    BuildContext context,
    SettingsProvider provider,
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
      ],
    );
  }

  Widget _buildThemeChips(SettingsProvider provider) {
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
  Widget _buildAuthSection(BuildContext context, SettingsProvider provider) {
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
    SettingsProvider provider,
    ToolUpdateProvider toolProvider,
    String toolName,
  ) {
    final isYtdlp = toolName == 'yt-dlp';
    final currentPath = isYtdlp
        ? provider.activeYtdlpPath
        : (provider.activeFfmpegPath ?? 'System PATH');
    final version = isYtdlp ? provider.ytdlpVersion : provider.ffmpegVersion;

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
                _buildInfoRow('Version', version ?? 'Unknown'),
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

  void _showFFmpegDownloadNotice(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download FFmpeg'),
        content: const Text(
          'FFmpeg is a complex tool. We recommend downloading the "release-essentials" zip from Gyan.dev, extracting it, and selecting the ffmpeg.exe using "Select Custom Binary".\n\nWould you like to open the download page?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              launchUrl(Uri.parse('https://www.gyan.dev/ffmpeg/builds/'));
              Navigator.pop(context);
            },
            child: const Text('Open Page'),
          ),
        ],
      ),
    );
  }

  void _showBrowserSheet(BuildContext context, SettingsProvider provider) {
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
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.white70,
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
                            : Colors.white,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
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
    SettingsProvider provider,
  ) {
    return _buildSettingsSection(
      children: [
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
        _buildToggleTile(
          title: 'Download Archive',
          subtitle: 'Avoid re-downloading videos',
          icon: Icons.history_rounded,
          value: provider.useDownloadArchive,
          onChanged: provider.setUseDownloadArchive,
          showDivider: false,
        ),
      ],
    );
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
                      showUpdateDialogWrapper(context);
                      await updateProvider.checkForUpdates();
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

  Widget _buildAboutSection(BuildContext context, SettingsProvider provider) {
    return Center(
      child: Column(
        children: [
          Text(
            'YouTube Downloader v1.0.0',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
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
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
              const Text('❤️', style: TextStyle(fontSize: 12)),
              Text(
                ' by Agent',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
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
