import 'package:material_symbols_icons/symbols.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/error_helper.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/download_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/tool_update_provider.dart';
import '../../providers/update_provider.dart';
import '../../services/core/android_storage_service.dart';
import '../../services/core/logging_service.dart';
import '../components/aero_button.dart';
import '../components/aero_chip.dart';
import '../components/aero_density.dart';
import '../components/aero_dialog.dart';
import '../components/aero_snack.dart';
import '../components/aero_text_field.dart';
import '../components/component_gallery_screen.dart';
import '../components/empty_state.dart';
import '../components/section_header.dart';
import '../components/settings_row.dart';
import '../components/status_pill.dart';
import '../widgets/app_logo.dart';
import '../widgets/bug_report_dialog.dart';
import '../widgets/error_details_dialog.dart';
import '../widgets/floating_progress_overlay.dart';
import '../widgets/logs_viewer.dart';
import '../widgets/update_dialog.dart';

/// Redesigned AeroTube Settings Screen following Section 7.5 of the Redesign Spec.
///
/// Features:
/// - Max width 720 px on Windows (centered)
/// - Search field at top of Settings for quick filtering across all settings
/// - Groups with [SectionHeader]:
///   1. Tools (yt-dlp and FFmpeg versions, updates, and advanced options)
///   2. Account
///   3. Downloads (folder, quality, concurrency, naming, subtitles, storage permission)
///   4. Appearance (theme, animations toggle, density)
///   5. Notifications & Background (notifications, SponsorBlock, unrestricted battery, OEM autostart, archive)
///   6. Advanced (logs viewer, export logs, bug report, Component Gallery entry, logging toggle)
///   7. About (App logo, app version, updater)
/// - Destructive actions (Log out, Clear history) styled as danger ghost buttons confirming via [AeroDialog]
/// - All tiles styled using [SettingsRow] and Aero design tokens
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  String _appVersion = '';
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

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
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    final updateProvider = context.watch<UpdateProvider>();
    final isDesktop = !PlatformUtils.isMobile;

    final contentList = _buildFilteredSections(
      context,
      settingsProvider,
      updateProvider,
    );

    Widget body = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AeroSpace.xxl : AeroSpace.lg,
            vertical: AeroSpace.lg,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeader(context),
              const SizedBox(height: AeroSpace.lg),
              _buildSearchField(context),
              ...contentList,
              const SizedBox(height: AeroSpace.xxl * 2),
            ]),
          ),
        ),
      ],
    );

    if (isDesktop) {
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: body,
        ),
      );
    }

    return SafeArea(
      child: Stack(
        children: [
          body,
          const RepaintBoundary(
            child: FloatingProgressOverlay(showDownloadProgress: false),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AeroSpace.xs, bottom: AeroSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: AeroText.headline.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.aero.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Personalize downloads, appearance, and tools',
                  style: AeroText.bodySm.copyWith(
                    color: context.aero.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          if (PlatformUtils.isAndroid)
            IconButton(
              icon: Icon(
                Symbols.home_rounded,
                size: 22,
                color: context.aero.onSurfaceMuted,
              ),
              tooltip: 'Home',
              onPressed: () =>
                  context.read<NavigationProvider>().switchToHome(),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        return AeroTextField(
          controller: _searchController,
          hintText: 'Search settings…',
          prefixIcon: const Icon(Symbols.search_rounded),
          suffixIcon: value.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Symbols.close_rounded, size: 18),
                  tooltip: 'Clear',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchFilter = '');
                  },
                )
              : null,
          onChanged: (text) => setState(() => _searchFilter = text.trim()),
        );
      },
    );
  }

  List<Widget> _buildFilteredSections(
    BuildContext context,
    PlatformSettingsProvider settingsProvider,
    UpdateProvider updateProvider,
  ) {
    final q = _searchFilter.toLowerCase();

    final accountItems = _getAccountItems(context, settingsProvider);
    final downloadsItems = _getDownloadsItems(context, settingsProvider);
    final appearanceItems = _getAppearanceItems(context, settingsProvider);
    final toolsItems = _getToolsItems(context, settingsProvider);
    final backgroundItems = _getBackgroundItems(context, settingsProvider);
    final advancedItems = _getAdvancedItems(context, settingsProvider);
    final aboutItems = _getAboutItems(
      context,
      settingsProvider,
      updateProvider,
    );

    final filteredAccount = accountItems.where((i) => i.matches(q)).toList();
    final filteredDownloads = downloadsItems
        .where((i) => i.matches(q))
        .toList();
    final filteredAppearance = appearanceItems
        .where((i) => i.matches(q))
        .toList();
    final filteredTools = toolsItems.where((i) => i.matches(q)).toList();
    final filteredBackground = backgroundItems
        .where((i) => i.matches(q))
        .toList();
    final filteredAdvanced = advancedItems.where((i) => i.matches(q)).toList();
    final filteredAbout = aboutItems.where((i) => i.matches(q)).toList();

    final hasAnyMatch =
        filteredAccount.isNotEmpty ||
        filteredDownloads.isNotEmpty ||
        filteredAppearance.isNotEmpty ||
        filteredTools.isNotEmpty ||
        filteredBackground.isNotEmpty ||
        filteredAdvanced.isNotEmpty ||
        filteredAbout.isNotEmpty;

    if (!hasAnyMatch && q.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: AeroSpace.xxl),
          child: EmptyState(
            icon: Symbols.search_off_rounded,
            title: 'No Settings Found',
            description: 'No settings match "$_searchFilter"',
            actionLabel: 'Clear Filter',
            onAction: () {
              _searchController.clear();
              setState(() => _searchFilter = '');
            },
          ),
        ),
      ];
    }

    final List<Widget> sections = [];

    if (filteredTools.isNotEmpty) {
      sections.add(const SectionHeader(title: 'Tools'));
      sections.add(
        _buildSettingsSection(
          context,
          filteredTools.map((i) => i.widget).toList(),
        ),
      );
    }

    if (filteredAccount.isNotEmpty) {
      sections.add(const SectionHeader(title: 'Account'));
      sections.add(
        _buildSettingsSection(
          context,
          filteredAccount.map((i) => i.widget).toList(),
        ),
      );
    }

    if (filteredDownloads.isNotEmpty) {
      sections.add(const SectionHeader(title: 'Downloads'));
      sections.add(
        _buildSettingsSection(
          context,
          filteredDownloads.map((i) => i.widget).toList(),
        ),
      );
    }

    if (filteredAppearance.isNotEmpty) {
      sections.add(const SectionHeader(title: 'Appearance'));
      sections.add(
        _buildSettingsSection(
          context,
          filteredAppearance.map((i) => i.widget).toList(),
        ),
      );
    }

    if (filteredBackground.isNotEmpty) {
      sections.add(const SectionHeader(title: 'Notifications & Background'));
      sections.add(
        _buildSettingsSection(
          context,
          filteredBackground.map((i) => i.widget).toList(),
        ),
      );
    }

    if (filteredAdvanced.isNotEmpty) {
      sections.add(const SectionHeader(title: 'Advanced'));
      sections.add(
        _buildSettingsSection(
          context,
          filteredAdvanced.map((i) => i.widget).toList(),
        ),
      );
    }

    if (filteredAbout.isNotEmpty) {
      sections.add(const SectionHeader(title: 'About'));
      sections.add(
        _buildSettingsSection(
          context,
          filteredAbout.map((i) => i.widget).toList(),
        ),
      );
      sections.add(const SizedBox(height: AeroSpace.xl));
      sections.add(_buildAboutFooter(context));
    }

    return sections;
  }

  Widget _buildSettingsSection(BuildContext context, List<Widget> children) {
    final colors = context.aero;
    final List<Widget> withDividers = [];

    for (int i = 0; i < children.length; i++) {
      withDividers.add(children[i]);
      if (i < children.length - 1) {
        withDividers.add(
          Divider(height: 1, thickness: 1, indent: 56, color: colors.outline),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: AeroRadius.lgBorderRadius,
        border: Border.all(color: colors.outline, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: withDividers,
      ),
    );
  }

  // =========================================================================
  // SECTION ITEMS
  // =========================================================================

  List<_SettingEntry> _getAccountItems(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    final isSignedIn = provider.isYouTubeLoggedIn;
    final cookiesReady = provider.isCookieActive;
    final statusLabel = isSignedIn
        ? 'Signed in'
        : cookiesReady
        ? 'Cookies ready'
        : 'Guest';
    final statusSubtitle = isSignedIn
        ? provider.enableCookies
              ? 'YouTube session ready'
              : 'Signed in · cookies are off'
        : cookiesReady
        ? 'Cookie source ready'
        : 'Optional for members-only videos';

    return [
      _SettingEntry(
        title: 'Account Status',
        subtitle: statusSubtitle,
        keywords: ['status', 'google', 'profile', 'auth', 'signed in', 'guest'],
        widget: SettingsRow(
          title: 'Account Status',
          subtitle: statusSubtitle,
          icon: isSignedIn || cookiesReady
              ? Symbols.lock_open_rounded
              : Symbols.lock_rounded,
          iconColor: isSignedIn || cookiesReady ? Colors.green : null,
          trailing: StatusPill(
            label: statusLabel,
            type: isSignedIn || cookiesReady
                ? StatusPillType.success
                : StatusPillType.neutral,
          ),
        ),
      ),
      _SettingEntry(
        title: 'Sign in with YouTube',
        subtitle: 'Access members-only videos',
        keywords: ['login', 'sign in', 'authenticate', 'webview', 'channel'],
        widget: SettingsRow(
          title: 'Sign in with YouTube',
          subtitle: 'Access members-only videos',
          icon: Symbols.login_rounded,
          onTap: () async {
            final result = await Navigator.pushNamed(context, '/youtube_login');
            if (result == true) {
              await provider.onYouTubeLoginComplete();
            }
          },
        ),
      ),
      if (!provider.isAndroid)
        _SettingEntry(
          title: 'Browser Cookies',
          subtitle: _getBrowserLabel(provider.settings.cookieBrowser),
          keywords: [
            'chrome',
            'firefox',
            'edge',
            'brave',
            'cookies',
            'browser',
          ],
          widget: SettingsRow(
            title: 'Browser Cookies',
            subtitle: _getBrowserLabel(provider.settings.cookieBrowser),
            icon: Symbols.cookie_rounded,
            onTap: () => _showBrowserSheet(context, provider),
          ),
        ),
      _SettingEntry(
        title: 'Enable Cookies File',
        subtitle: 'Import Netscape format cookies.txt',
        keywords: ['cookies.txt', 'netscape', 'cookie', 'file'],
        widget: SettingsRow(
          title: 'Enable Cookies File',
          subtitle: 'Import Netscape format cookies.txt',
          icon: Symbols.file_copy_rounded,
          trailing: Switch.adaptive(
            value: provider.enableCookies,
            activeThumbColor: context.aero.primary,
            activeTrackColor: context.aero.primarySoft,
            onChanged: provider.setEnableCookies,
          ),
          onTap: () => provider.setEnableCookies(!provider.enableCookies),
        ),
      ),
      if (provider.enableCookies)
        _SettingEntry(
          title: 'Import cookies.txt',
          subtitle: provider.cookieFileName ?? 'No file selected',
          keywords: ['upload', 'cookies.txt', 'netscape', 'import'],
          widget: SettingsRow(
            title: 'Import cookies.txt',
            subtitle: provider.cookieFileName ?? 'No file selected',
            icon: Symbols.upload_file_rounded,
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['txt'],
              );
              if (result != null && result.files.single.path != null) {
                provider.setCookiePath(result.files.single.path);
              }
            },
          ),
        ),
      if (isSignedIn)
        _SettingEntry(
          title: 'Log out of YouTube',
          subtitle: 'Disconnect YouTube account and remove active session',
          keywords: ['logout', 'sign out', 'disconnect', 'leave', 'remove'],
          widget: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AeroSpace.lg,
              vertical: AeroSpace.md,
            ),
            child: Row(
              children: [
                AeroButton.danger(
                  text: 'Log out of YouTube',
                  icon: const Icon(Symbols.logout_rounded, size: 16),
                  density: AeroDensity.compact,
                  onPressed: () => _confirmLogout(context, provider),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<_SettingEntry> _getDownloadsItems(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    return [
      _SettingEntry(
        title: 'Download Location',
        subtitle: provider.outputPath ?? 'Default folder',
        keywords: ['folder', 'directory', 'path', 'save', 'storage', 'output'],
        widget: SettingsRow(
          title: 'Download Location',
          subtitle: provider.outputPath ?? 'Default folder',
          icon: Symbols.folder_rounded,
          onTap: () async {
            final result = await FilePicker.platform.getDirectoryPath();
            if (result == null || !context.mounted) return;

            if (provider.isAndroid) {
              final validation = await AndroidStorageService()
                  .validateCustomDirectory(result);
              if (!context.mounted) return;
              if (!validation.ok) {
                AeroSnack.warning(
                  context,
                  message: validation.reason ?? 'Folder not usable.',
                );
                return;
              }
            }

            await provider.setOutputPath(result);
            if (context.mounted) {
              AeroSnack.success(context, message: 'Download folder updated');
            }
          },
        ),
      ),
      if (provider.isAndroid)
        _SettingEntry(
          title: 'Storage Access',
          subtitle: 'Manage public storage write permissions',
          keywords: ['permission', 'storage', 'sd card', 'android', 'access'],
          widget: _AndroidStoragePermissionTile(provider: provider),
        ),
      _SettingEntry(
        title: 'Default Quality',
        subtitle: provider.defaultQuality,
        keywords: [
          'resolution',
          '1080p',
          '4k',
          '720p',
          'audio',
          'format',
          'quality',
        ],
        widget: SettingsRow(
          title: 'Default Quality',
          subtitle: provider.defaultQuality,
          icon: Symbols.high_quality_rounded,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.defaultQuality,
                style: AeroText.bodySm.copyWith(
                  color: context.aero.onSurfaceMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Symbols.chevron_right_rounded,
                size: 20,
                color: context.aero.onSurfaceMuted,
              ),
            ],
          ),
          onTap: () => _showQualitySheet(context, provider),
        ),
      ),
      _SettingEntry(
        title: 'Default Subtitle Language',
        subtitle: _subtitleLanguageLabel(provider.defaultSubtitleLanguage),
        keywords: [
          'subtitles',
          'captions',
          'language',
          'english',
          'auto',
          'subs',
        ],
        widget: SettingsRow(
          title: 'Default Subtitle Language',
          subtitle: _subtitleLanguageLabel(provider.defaultSubtitleLanguage),
          icon: Symbols.subtitles_rounded,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _subtitleLanguageLabel(provider.defaultSubtitleLanguage),
                style: AeroText.bodySm.copyWith(
                  color: context.aero.onSurfaceMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Symbols.chevron_right_rounded,
                size: 20,
                color: context.aero.onSurfaceMuted,
              ),
            ],
          ),
          onTap: () => _showDefaultSubtitleLanguageSheet(context, provider),
        ),
      ),
      _SettingEntry(
        title: 'Concurrent Downloads',
        subtitle: 'Max parallel background downloads',
        keywords: [
          'concurrency',
          'parallel',
          'threads',
          'simultaneous',
          'speed',
          'limit',
        ],
        widget: const _ConcurrentDownloadsControl(),
      ),
      _SettingEntry(
        title: 'File Naming Pattern',
        subtitle: '%(title)s [%(resolution)s].%(ext)s',
        keywords: [
          'naming',
          'filename',
          'format',
          'template',
          'pattern',
          'title',
        ],
        widget: SettingsRow(
          title: 'File Naming Pattern',
          subtitle: '%(title)s [%(resolution)s].%(ext)s',
          icon: Symbols.badge_rounded,
          trailing: StatusPill(label: 'Standard', type: StatusPillType.neutral),
        ),
      ),
      _SettingEntry(
        title: 'Embed Thumbnail',
        subtitle: 'Add video thumbnail as cover artwork',
        keywords: ['cover', 'album art', 'image', 'picture', 'thumbnail'],
        widget: SettingsRow(
          title: 'Embed Thumbnail',
          subtitle: 'Add video thumbnail as cover artwork',
          icon: Symbols.image_rounded,
          trailing: Switch.adaptive(
            value: provider.embedThumbnail,
            activeThumbColor: context.aero.primary,
            activeTrackColor: context.aero.primarySoft,
            onChanged: provider.setEmbedThumbnail,
          ),
          onTap: () => provider.setEmbedThumbnail(!provider.embedThumbnail),
        ),
      ),
      _SettingEntry(
        title: 'Embed Metadata',
        subtitle: 'Include video details and tags in file metadata',
        keywords: ['tags', 'artist', 'description', 'info', 'metadata'],
        widget: SettingsRow(
          title: 'Embed Metadata',
          subtitle: 'Include video details and tags in file metadata',
          icon: Symbols.info_rounded,
          trailing: Switch.adaptive(
            value: provider.embedMetadata,
            activeThumbColor: context.aero.primary,
            activeTrackColor: context.aero.primarySoft,
            onChanged: provider.setEmbedMetadata,
          ),
          onTap: () => provider.setEmbedMetadata(!provider.embedMetadata),
        ),
      ),
      _SettingEntry(
        title: 'Clear Download History',
        subtitle: 'Remove completed history items without deleting files',
        keywords: ['delete', 'remove', 'history', 'clean', 'clear'],
        widget: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AeroSpace.lg,
            vertical: AeroSpace.md,
          ),
          child: Row(
            children: [
              AeroButton.danger(
                text: 'Clear download history',
                icon: const Icon(Symbols.delete_rounded, size: 16),
                density: AeroDensity.compact,
                onPressed: () => _confirmClearHistory(context),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<_SettingEntry> _getAppearanceItems(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    return [
      _SettingEntry(
        title: 'Theme Mode',
        subtitle: 'System, Light, Dark, or pure-black AMOLED theme',
        keywords: [
          'dark',
          'light',
          'oled',
          'amoled',
          'black',
          'battery',
          'system',
          'mode',
          'color',
          'theme',
        ],
        widget: _buildThemeSegmented(context, provider),
      ),
      _SettingEntry(
        title: 'Enable Animations',
        subtitle: 'Linear transitions and loading animations',
        keywords: [
          'motion',
          'motion',
          'transitions',
          'reduce motion',
          'animation',
        ],
        widget: SettingsRow(
          title: 'Enable Animations',
          subtitle: 'Linear transitions and loading animations',
          icon: Symbols.animation_rounded,
          trailing: Switch.adaptive(
            value: provider.enableAnimations,
            activeThumbColor: context.aero.primary,
            activeTrackColor: context.aero.primarySoft,
            onChanged: provider.setEnableAnimations,
          ),
          onTap: () => provider.setEnableAnimations(!provider.enableAnimations),
        ),
      ),
      _SettingEntry(
        title: 'Interface Density',
        subtitle: PlatformUtils.isMobile
            ? 'Comfortable (Optimized for touch)'
            : 'Compact (Optimized for pointer & keyboard)',
        keywords: [
          'density',
          'compact',
          'comfortable',
          'touch',
          'scale',
          'size',
        ],
        widget: SettingsRow(
          title: 'Interface Density',
          subtitle: PlatformUtils.isMobile
              ? 'Comfortable (Optimized for touch)'
              : 'Compact (Optimized for pointer & keyboard)',
          icon: Symbols.density_medium_rounded,
          trailing: StatusPill.info(
            label: PlatformUtils.isMobile ? 'Comfortable' : 'Compact',
          ),
        ),
      ),
    ];
  }

  Widget _buildThemeSegmented(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    final current = provider.themeMode;
    final amoledSelected = provider.amoledDark && current == ThemeMode.dark;

    final chips = <Widget>[
      AeroChip(
        text: 'Auto',
        icon: const Icon(Symbols.auto_mode_rounded),
        selected: current == ThemeMode.system,
        onTap: () {
          provider.setAmoledDark(false);
          provider.setThemeMode(ThemeMode.system);
        },
      ),
      AeroChip(
        text: 'Light',
        icon: const Icon(Symbols.light_mode_rounded),
        selected: current == ThemeMode.light,
        onTap: () {
          provider.setAmoledDark(false);
          provider.setThemeMode(ThemeMode.light);
        },
      ),
      AeroChip(
        text: 'Dark',
        icon: const Icon(Symbols.dark_mode_rounded),
        selected: current == ThemeMode.dark && !amoledSelected,
        onTap: () {
          provider.setAmoledDark(false);
          provider.setThemeMode(ThemeMode.dark);
        },
      ),
      AeroChip(
        text: 'AMOLED',
        icon: const Icon(Symbols.contrast_rounded),
        selected: amoledSelected,
        onTap: () {
          provider.setThemeMode(ThemeMode.dark);
          provider.setAmoledDark(true);
        },
      ),
    ];

    final String description;
    if (amoledSelected) {
      description =
          'Pure black background — saves battery on OLED/AMOLED screens.';
    } else if (current == ThemeMode.system) {
      description = 'Follows your device theme setting.';
    } else if (current == ThemeMode.light) {
      description = 'Always uses the light palette.';
    } else {
      description = 'Deep navy greys that are easier on the eyes at night.';
    }

    return Padding(
      padding: const EdgeInsets.all(AeroSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.aero.surface2,
                  borderRadius: AeroRadius.smBorderRadius,
                  border: Border.all(color: context.aero.outline, width: 1.0),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Symbols.palette_rounded,
                  size: 20,
                  color: context.aero.onSurface,
                ),
              ),
              const SizedBox(width: AeroSpace.md),
              Text(
                'Theme Mode',
                style: AeroText.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AeroSpace.md),
          // Narrow phones can't fit four chips side by side; wrap to two rows
          // instead of clipping.
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 440) {
                return Wrap(
                  spacing: AeroSpace.sm,
                  runSpacing: AeroSpace.sm,
                  children: chips,
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: AeroSpace.sm),
                    Expanded(child: chips[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AeroSpace.sm),
          Text(
            description,
            style: AeroText.caption.copyWith(
              color: context.aero.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }

  List<_SettingEntry> _getToolsItems(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    return [
      _SettingEntry(
        title: 'yt-dlp',
        subtitle: 'Core video download engine',
        keywords: [
          'ytdlp',
          'binary',
          'version',
          'update',
          'downloader',
          'core',
        ],
        widget: Consumer<ToolUpdateProvider>(
          builder: (context, toolProvider, _) {
            final state = toolProvider.ytdlpState;
            return _buildToolRow(
              context,
              toolName: 'yt-dlp',
              icon: Symbols.terminal_rounded,
              state: state,
              version: provider.ytdlpVersion,
              onCheckUpdate: () =>
                  toolProvider.checkYtdlpForUpdate(force: true),
              onUpdate: state.hasUpdate
                  ? () => toolProvider.updateYtdlp()
                  : null,
              onCancel: state.isBusy
                  ? () => toolProvider.cancelYtdlpUpdate()
                  : null,
              onInstall: () => toolProvider.installYtdlp(),
              onAdvanced: () => _showToolAdvancedSheet(
                context,
                provider,
                toolProvider,
                'yt-dlp',
              ),
            );
          },
        ),
      ),
      _SettingEntry(
        title: 'FFmpeg',
        subtitle: 'Media stream merge and format conversion engine',
        keywords: [
          'ffmpeg',
          'binary',
          'version',
          'update',
          'muxer',
          'audio',
          'convert',
        ],
        widget: Consumer<ToolUpdateProvider>(
          builder: (context, toolProvider, _) {
            final state = toolProvider.ffmpegState;
            return _buildToolRow(
              context,
              toolName: 'FFmpeg',
              icon: Symbols.video_settings_rounded,
              state: state,
              version: provider.ffmpegVersion,
              onCheckUpdate: () =>
                  toolProvider.checkFfmpegForUpdate(force: true),
              onUpdate: state.hasUpdate
                  ? () => toolProvider.updateFfmpeg()
                  : null,
              onCancel: state.isBusy
                  ? () => toolProvider.cancelFfmpegUpdate()
                  : null,
              onInstall: () => toolProvider.installFfmpeg(),
              onAdvanced: () => _showToolAdvancedSheet(
                context,
                provider,
                toolProvider,
                'FFmpeg',
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildToolRow(
    BuildContext context, {
    required String toolName,
    required IconData icon,
    required ToolUpdateState state,
    required String? version,
    required VoidCallback onCheckUpdate,
    VoidCallback? onUpdate,
    VoidCallback? onCancel,
    required VoidCallback onInstall,
    required VoidCallback onAdvanced,
  }) {
    String subtitle;
    StatusPill pill;

    if (state.isBusy) {
      subtitle = state.statusMessage ?? 'Operation in progress…';
      pill = const StatusPill(
        label: 'Updating…',
        type: StatusPillType.info,
        showSpinner: true,
      );
    } else if (state.status == ToolUpdateStatus.error) {
      subtitle = 'Error encountered. Tap to inspect.';
      pill = StatusPill.danger(
        label: 'Error',
        onTap: () {
          final parsed = ErrorHelper.parse(state.errorMessage ?? 'Tool error');
          ErrorDetailsDialog.show(
            context,
            error: parsed,
            customTitle: '$toolName Error',
            onRetry: onCheckUpdate,
          );
        },
      );
    } else if (state.hasUpdate) {
      subtitle = PlatformUtils.isMobile
          ? 'v${state.latestVersion} available'
          : 'New release available: v${state.latestVersion}';
      pill = StatusPill.warning(label: 'Update v${state.latestVersion}');
    } else if (state.currentVersion != null || version != null) {
      final v = state.currentVersion ?? version;
      subtitle = 'Installed: v$v';
      pill = StatusPill.success(label: 'v$v');
    } else {
      subtitle = 'Not installed or not detected';
      pill = const StatusPill.warning(label: 'Not installed');
    }

    Widget actionButton;
    if (state.isBusy) {
      actionButton = AeroButton.tonal(
        text: 'Cancel',
        height: 32,
        density: AeroDensity.compact,
        onPressed: onCancel,
      );
    } else if (state.hasUpdate) {
      actionButton = AeroButton.primary(
        text: 'Update',
        height: 32,
        density: AeroDensity.compact,
        onPressed: onUpdate,
      );
    } else if (!state.isAvailable) {
      actionButton = AeroButton.primary(
        text: 'Install',
        height: 32,
        density: AeroDensity.compact,
        onPressed: onInstall,
      );
    } else {
      actionButton = AeroButton.tonal(
        text: 'Check',
        height: 32,
        density: AeroDensity.compact,
        isLoading: state.status == ToolUpdateStatus.checking,
        onPressed: onCheckUpdate,
      );
    }

    return SettingsRow(
      title: toolName,
      subtitle: subtitle,
      icon: icon,
      padding: PlatformUtils.isMobile
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!PlatformUtils.isMobile) ...[
            pill,
            const SizedBox(width: AeroSpace.sm),
            actionButton,
          ] else
            IconButton.filledTonal(
              tooltip: state.isBusy
                  ? 'Cancel $toolName update'
                  : state.hasUpdate
                  ? 'Update $toolName'
                  : !state.isAvailable
                  ? 'Install $toolName'
                  : 'Check $toolName for updates',
              onPressed: state.isBusy
                  ? onCancel
                  : state.hasUpdate
                  ? onUpdate
                  : !state.isAvailable
                  ? onInstall
                  : onCheckUpdate,
              icon: Icon(
                state.isBusy
                    ? Symbols.close_rounded
                    : state.hasUpdate
                    ? Symbols.system_update_alt_rounded
                    : !state.isAvailable
                    ? Symbols.download_rounded
                    : Symbols.refresh_rounded,
                size: 20,
              ),
            ),
          const SizedBox(width: AeroSpace.xs),
          IconButton(
            icon: const Icon(Symbols.more_vert_rounded, size: 18),
            tooltip: 'Advanced Settings',
            onPressed: onAdvanced,
          ),
        ],
      ),
    );
  }

  List<_SettingEntry> _getBackgroundItems(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    return [
      _SettingEntry(
        title: 'Download Notifications',
        subtitle: 'Show system alerts on download progress and completion',
        keywords: ['alerts', 'push', 'notifications', 'tray', 'background'],
        widget: SettingsRow(
          title: 'Download Notifications',
          subtitle: 'Show system alerts on download progress and completion',
          icon: Symbols.notifications_rounded,
          trailing: Switch.adaptive(
            value: provider.enableNotifications,
            activeThumbColor: context.aero.primary,
            activeTrackColor: context.aero.primarySoft,
            onChanged: provider.setEnableNotifications,
          ),
          onTap: () =>
              provider.setEnableNotifications(!provider.enableNotifications),
        ),
      ),
      _SettingEntry(
        title: 'SponsorBlock',
        subtitle:
            'Automatically skip sponsored segments and non-music sections',
        keywords: [
          'skip',
          'sponsors',
          'segments',
          'intro',
          'outro',
          'sponsorblock',
        ],
        widget: SettingsRow(
          title: 'SponsorBlock',
          subtitle:
              'Automatically skip sponsored segments and non-music sections',
          icon: Symbols.skip_next_rounded,
          trailing: Switch.adaptive(
            value: provider.sponsorBlockEnabled,
            activeThumbColor: context.aero.primary,
            activeTrackColor: context.aero.primarySoft,
            onChanged: provider.setSponsorBlockEnabled,
          ),
          onTap: () =>
              provider.setSponsorBlockEnabled(!provider.sponsorBlockEnabled),
        ),
      ),
      if (provider.isAndroid)
        _SettingEntry(
          title: 'Unrestricted Battery',
          subtitle: provider.isBatteryOptimizationIgnored
              ? 'Allowed — downloads continue when the screen is locked'
              : 'Restricted — system may suspend downloads when screen turns off',
          keywords: ['battery', 'unrestricted', 'doze', 'pause', 'screen off'],
          widget: _buildBatteryOptimizationTile(provider),
        ),
      if (provider.isAndroid && provider.isAggressiveOem)
        _SettingEntry(
          title: 'OEM Autostart Settings',
          subtitle: 'Configure device-specific background whitelist',
          keywords: [
            'autostart',
            'xiaomi',
            'samsung',
            'oppo',
            'vivo',
            'huawei',
          ],
          widget: SettingsRow(
            title: '${provider.deviceManufacturer ?? "OEM"} Autostart Settings',
            subtitle: 'Configure device-specific background whitelist',
            icon: Symbols.power_settings_new_rounded,
            trailing: const Icon(Symbols.open_in_new_rounded, size: 18),
            onTap: () => provider.openOemAutostartSettings(),
          ),
        ),
      _SettingEntry(
        title: 'Download Archive',
        subtitle: 'Track downloaded video IDs to avoid duplicate downloads',
        keywords: [
          'archive',
          'duplicate',
          'history',
          're-download',
          'skip existing',
        ],
        widget: SettingsRow(
          title: 'Download Archive',
          subtitle: 'Track downloaded video IDs to avoid duplicate downloads',
          icon: Symbols.history_rounded,
          trailing: Switch.adaptive(
            value: provider.useDownloadArchive,
            activeThumbColor: context.aero.primary,
            activeTrackColor: context.aero.primarySoft,
            onChanged: provider.setUseDownloadArchive,
          ),
          onTap: () =>
              provider.setUseDownloadArchive(!provider.useDownloadArchive),
        ),
      ),
    ];
  }

  Widget _buildBatteryOptimizationTile(PlatformSettingsProvider provider) {
    final isExempt = provider.isBatteryOptimizationIgnored;
    final isChecking = provider.isCheckingBatteryOptimization;

    return SettingsRow(
      title: 'Unrestricted Battery',
      subtitle: isExempt
          ? 'Allowed — downloads continue when the screen is locked'
          : 'Restricted — system may suspend downloads when screen turns off. Tap to allow.',
      icon: isExempt
          ? Symbols.battery_charging_full_rounded
          : Symbols.battery_alert_rounded,
      iconColor: isExempt ? Colors.green : Colors.orange,
      trailing: isChecking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : StatusPill(
              label: isExempt ? 'Allowed' : 'Restricted',
              type: isExempt ? StatusPillType.success : StatusPillType.warning,
            ),
      onTap: isChecking
          ? null
          : () async {
              final granted = await provider
                  .requestBatteryOptimizationExemption();
              if (!mounted) return;
              if (granted) {
                AeroSnack.success(
                  context,
                  message: 'Unrestricted battery allowed',
                );
              } else {
                _showBatteryHelpDialog(provider);
              }
            },
    );
  }

  void _showBatteryHelpDialog(PlatformSettingsProvider provider) {
    showAeroDialog<void>(
      context: context,
      builder: (dialogContext) => AeroDialog(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: dialogContext.aero.danger.withValues(alpha: 0.15),
            borderRadius: AeroRadius.smBorderRadius,
          ),
          alignment: Alignment.center,
          child: Icon(
            Symbols.battery_alert_rounded,
            color: dialogContext.aero.danger,
            size: 20,
          ),
        ),
        titleText: 'Downloads May Pause',
        content: Text(
          'Your device did not grant unrestricted battery. To fix background paused downloads, locate AeroTube in your system battery optimization settings and choose "Unrestricted".',
          style: AeroText.bodySm.copyWith(
            color: dialogContext.aero.onSurfaceMuted,
          ),
        ),
        actions: [
          AeroButton.ghost(
            text: 'Later',
            density: AeroDensity.compact,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          AeroButton.primary(
            text: 'Open Battery Settings',
            density: AeroDensity.compact,
            onPressed: () {
              Navigator.pop(dialogContext);
              provider.openBatteryOptimizationSettings();
            },
          ),
        ],
      ),
    );
  }

  List<_SettingEntry> _getAdvancedItems(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    return [
      _SettingEntry(
        title: 'Component Gallery',
        subtitle: 'Interactive catalog of all Aero design system widgets',
        keywords: ['components', 'gallery', 'design', 'tokens', 'debug', 'ui'],
        widget: SettingsRow(
          title: 'Component Gallery',
          subtitle: 'Interactive catalog of all Aero design system widgets',
          icon: Symbols.widgets_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ComponentGalleryScreen()),
          ),
        ),
      ),
      _SettingEntry(
        title: 'View Logs',
        subtitle: 'Developer debugging logs and runtime events',
        keywords: ['logs', 'view', 'console', 'debug', 'errors', 'terminal'],
        widget: SettingsRow(
          title: 'View Logs',
          subtitle: 'Developer debugging logs and runtime events',
          icon: Symbols.receipt_long_rounded,
          onTap: () => _showLogsViewer(context),
        ),
      ),
      _SettingEntry(
        title: 'Export Logs',
        subtitle: 'Save or copy app.log for troubleshooting',
        keywords: ['export', 'save logs', 'copy', 'file', 'share'],
        widget: SettingsRow(
          title: 'Export Logs',
          subtitle: 'Save or copy app.log for troubleshooting',
          icon: Symbols.file_download_rounded,
          onTap: () => _exportLogs(context),
        ),
      ),
      _SettingEntry(
        title: 'Report a Bug',
        subtitle: 'Compile diagnostic report to file on GitHub',
        keywords: ['bug', 'report', 'issue', 'github', 'crash', 'problem'],
        widget: SettingsRow(
          title: 'Report a Bug',
          subtitle: 'Compile diagnostic report to file on GitHub',
          icon: Symbols.pest_control_rounded,
          onTap: () => BugReportDialog.show(context),
        ),
      ),
      _SettingEntry(
        title: 'Enable Logging',
        subtitle: 'Write debug information to file',
        keywords: ['logging', 'debug', 'trace', 'file'],
        widget: SettingsRow(
          title: 'Enable Logging',
          subtitle: 'Write debug information to file',
          icon: Symbols.bug_report_rounded,
          trailing: Switch.adaptive(
            value: provider.enableLogging,
            activeThumbColor: context.aero.primary,
            activeTrackColor: context.aero.primarySoft,
            onChanged: provider.setEnableLogging,
          ),
          onTap: () => provider.setEnableLogging(!provider.enableLogging),
        ),
      ),
    ];
  }

  List<_SettingEntry> _getAboutItems(
    BuildContext context,
    PlatformSettingsProvider provider,
    UpdateProvider updateProvider,
  ) {
    return [
      _SettingEntry(
        title: 'Check for Updates',
        subtitle: updateProvider.hasUpdate
            ? 'Version ${updateProvider.updateInfo?.version} available'
            : 'Check for new AeroTube releases',
        keywords: ['update', 'version', 'github', 'download', 'upgrade'],
        widget: SettingsRow(
          title: 'Check for Updates',
          subtitle: updateProvider.hasUpdate
              ? 'Version ${updateProvider.updateInfo?.version} available'
              : 'Check for new AeroTube releases',
          icon: Symbols.system_update_rounded,
          trailing: updateProvider.isChecking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : updateProvider.hasUpdate
              ? const StatusPill.warning(label: 'Update Available')
              : const Icon(Symbols.chevron_right_rounded, size: 20),
          onTap: updateProvider.isChecking
              ? null
              : () async {
                  await updateProvider.checkForUpdates(force: true);
                  if (!context.mounted) return;
                  if (updateProvider.status == UpdateStatus.available ||
                      updateProvider.status == UpdateStatus.upToDate ||
                      updateProvider.status == UpdateStatus.error) {
                    showAeroDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const UpdateDialog(),
                    );
                  }
                },
        ),
      ),
      _SettingEntry(
        title: 'Auto-check for Updates',
        subtitle: 'Check automatically at app launch',
        keywords: ['auto check', 'startup', 'updates', 'automatic'],
        widget: SettingsRow(
          title: 'Auto-check for Updates',
          subtitle: 'Check automatically at app launch',
          icon: Symbols.update_rounded,
          trailing: Switch.adaptive(
            value: updateProvider.autoCheckEnabled,
            activeThumbColor: context.aero.primary,
            activeTrackColor: context.aero.primarySoft,
            onChanged: (val) => updateProvider.setAutoCheckEnabled(val),
          ),
          onTap: () => updateProvider.setAutoCheckEnabled(
            !updateProvider.autoCheckEnabled,
          ),
        ),
      ),
    ];
  }

  Widget _buildAboutFooter(BuildContext context) {
    final colors = context.aero;

    return Center(
      child: Column(
        children: [
          const AppLogo(size: 72, showGlow: true),
          const SizedBox(height: AeroSpace.md),
          Text(
            'AeroTube v$_appVersion',
            style: AeroText.bodySm.copyWith(
              color: colors.onSurfaceMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AeroSpace.xs),
          Text(
            'Clean, focused media downloader',
            style: AeroText.caption.copyWith(color: colors.onSurfaceFaint),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  // =========================================================================
  // MODAL SHEETS & ACTIONS
  // =========================================================================

  Future<void> _confirmLogout(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) async {
    final confirmed = await showAeroDialog<bool>(
      context: context,
      builder: (dialogContext) => AeroDialog(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: dialogContext.aero.danger.withValues(alpha: 0.15),
            borderRadius: AeroRadius.smBorderRadius,
          ),
          alignment: Alignment.center,
          child: Icon(
            Symbols.logout_rounded,
            color: dialogContext.aero.danger,
            size: 20,
          ),
        ),
        titleText: 'Log out of YouTube?',
        content: Text(
          'You will need to sign in again to download members-only or age-restricted videos.',
          style: AeroText.bodySm.copyWith(
            color: dialogContext.aero.onSurfaceMuted,
          ),
        ),
        actions: [
          AeroButton.ghost(
            text: 'Cancel',
            density: AeroDensity.compact,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AeroButton.danger(
            text: 'Log out',
            density: AeroDensity.compact,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.logoutFromYouTube();
      await provider.setCookieBrowser(null);
      if (context.mounted) {
        AeroSnack.info(context, message: 'Logged out of YouTube');
      }
    }
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showAeroDialog<bool>(
      context: context,
      builder: (dialogContext) => AeroDialog(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: dialogContext.aero.danger.withValues(alpha: 0.15),
            borderRadius: AeroRadius.smBorderRadius,
          ),
          alignment: Alignment.center,
          child: Icon(
            Symbols.delete_rounded,
            color: dialogContext.aero.danger,
            size: 20,
          ),
        ),
        titleText: 'Clear Download History?',
        content: Text(
          'This will remove all downloaded entries from your history list. Files on disk will remain untouched.',
          style: AeroText.bodySm.copyWith(
            color: dialogContext.aero.onSurfaceMuted,
          ),
        ),
        actions: [
          AeroButton.ghost(
            text: 'Cancel',
            density: AeroDensity.compact,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AeroButton.danger(
            text: 'Clear history',
            density: AeroDensity.compact,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      if (PlatformUtils.isMobile) {
        context.read<MobileDownloadProvider>().clearCompleted();
        context.read<MobileDownloadProvider>().clearFailed();
        context.read<MobileDownloadProvider>().clearCancelled();
      } else {
        await context.read<DownloadProvider>().clearHistory();
      }
      if (context.mounted) {
        AeroSnack.success(context, message: 'Download history cleared');
      }
    }
  }

  void _showQualitySheet(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    const qualities = ['Best', '4K', '1080p', '720p', '480p', 'Audio Only'];

    showAeroSheet(
      context: context,
      titleText: 'Default Download Quality',
      builder: (sheetContext) {
        final colors = sheetContext.aero;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: qualities.map((q) {
            final isSelected = provider.defaultQuality == q;
            return SettingsRow(
              title: q,
              icon: _getQualityIcon(q),
              trailing: isSelected
                  ? Icon(Symbols.check_rounded, color: colors.primary, size: 20)
                  : null,
              onTap: () {
                provider.setDefaultQuality(q);
                Navigator.pop(sheetContext);
              },
            );
          }).toList(),
        );
      },
    );
  }

  IconData _getQualityIcon(String quality) {
    switch (quality) {
      case 'Best':
        return Symbols.auto_awesome_rounded;
      case '4K':
        return Symbols.four_k_rounded;
      case '1080p':
        return Symbols.hd_rounded;
      case '720p':
      case '480p':
        return Symbols.sd_rounded;
      case 'Audio Only':
        return Symbols.audiotrack_rounded;
      default:
        return Symbols.high_quality_rounded;
    }
  }

  void _showDefaultSubtitleLanguageSheet(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    const subtitleLanguages = <Map<String, String>>[
      {'code': 'auto', 'label': 'Auto (Video Default)'},
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

    showAeroSheet(
      context: context,
      titleText: 'Default Subtitle Language',
      builder: (sheetContext) {
        final colors = sheetContext.aero;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: subtitleLanguages.map((lang) {
            final isSelected = provider.defaultSubtitleLanguage == lang['code'];
            return SettingsRow(
              title: lang['label']!,
              subtitle: lang['code'] == 'auto'
                  ? 'Pick first available subtitle stream automatically'
                  : 'Language code: ${lang['code']}',
              icon: _getSubtitleLanguageIcon(lang['code']!),
              trailing: isSelected
                  ? Icon(Symbols.check_rounded, color: colors.primary, size: 20)
                  : null,
              onTap: () {
                provider.setDefaultSubtitleLanguage(lang['code']!);
                Navigator.pop(sheetContext);
              },
            );
          }).toList(),
        );
      },
    );
  }

  String _subtitleLanguageLabel(String code) {
    const labels = <String, String>{
      'auto': 'Auto (Video Default)',
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
    if (code == 'auto') return Symbols.auto_awesome_rounded;
    if (code == 'ar') return Symbols.language_rounded;
    return Symbols.translate_rounded;
  }

  void _showBrowserSheet(
    BuildContext context,
    PlatformSettingsProvider provider,
  ) {
    const browsers = ['chrome', 'firefox', 'edge', 'opera', 'brave', 'vivaldi'];

    showAeroSheet(
      context: context,
      titleText: 'Select Browser for Cookies',
      builder: (sheetContext) {
        final colors = sheetContext.aero;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: browsers.map((b) {
            final isSelected = provider.settings.cookieBrowser == b;
            return SettingsRow(
              title: b[0].toUpperCase() + b.substring(1),
              icon: _getBrowserIcon(b),
              trailing: isSelected
                  ? Icon(Symbols.check_rounded, color: colors.primary, size: 20)
                  : null,
              onTap: () {
                provider.setCookieBrowser(b);
                Navigator.pop(sheetContext);
              },
            );
          }).toList(),
        );
      },
    );
  }

  String _getBrowserLabel(String? browser) {
    if (browser == null || browser.isEmpty) return 'Not selected';
    return browser[0].toUpperCase() + browser.substring(1);
  }

  IconData _getBrowserIcon(String browser) {
    switch (browser.toLowerCase()) {
      case 'chrome':
        return Symbols.public_rounded;
      case 'firefox':
        return Symbols.local_fire_department_rounded;
      case 'edge':
        return Symbols.open_in_browser_rounded;
      case 'opera':
        return Symbols.circle_rounded;
      case 'brave':
        return Symbols.shield_rounded;
      case 'vivaldi':
        return Symbols.apps_rounded;
      default:
        return Symbols.web_rounded;
    }
  }

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

    final toolState = isYtdlp
        ? toolProvider.ytdlpState
        : toolProvider.ffmpegState;
    final currentVersion = toolState.currentVersion;
    final latestVersion = toolState.latestVersion;

    showAeroSheet(
      context: context,
      titleText: '$toolName Configuration',
      builder: (sheetContext) {
        final colors = sheetContext.aero;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AeroSpace.md),
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: AeroRadius.mdBorderRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Installed Path:',
                    style: AeroText.caption.copyWith(
                      color: colors.onSurfaceMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentPath,
                    style: AeroText.bodySm.copyWith(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version: ${currentVersion ?? "Unknown"} (Latest: ${latestVersion ?? "Unknown"})',
                    style: AeroText.caption.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AeroSpace.md),
            SettingsRow(
              title: 'Download / Reinstall',
              subtitle: 'Download latest official release binary',
              icon: Symbols.download_for_offline_rounded,
              onTap: () {
                Navigator.pop(sheetContext);
                if (isYtdlp) {
                  toolProvider.installYtdlp();
                } else {
                  toolProvider.installFfmpeg();
                }
              },
            ),
            if (PlatformUtils.isWindows)
              SettingsRow(
                title: 'Select Custom Binary',
                subtitle: 'Choose custom executable path (.exe)',
                icon: Symbols.file_open_rounded,
                onTap: () async {
                  Navigator.pop(sheetContext);
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
            SettingsRow(
              title: 'Reset to Managed',
              subtitle: 'Restore application default managed binary',
              icon: Symbols.restart_alt_rounded,
              onTap: () async {
                Navigator.pop(sheetContext);
                if (isYtdlp) {
                  await provider.setYtdlpPath(null);
                } else {
                  await provider.setFfmpegPath(null);
                }
                await toolProvider.refreshAvailability();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportLogs(BuildContext context) async {
    final service = LoggingService();

    try {
      final pickedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder to export logs',
      );

      if (pickedPath == null || !context.mounted) return;

      if (PlatformUtils.isAndroid) {
        final validation = await AndroidStorageService()
            .validateCustomDirectory(pickedPath);
        if (!context.mounted) return;
        if (!validation.ok) {
          AeroSnack.warning(
            context,
            message: validation.reason ?? 'Folder not usable.',
          );
          return;
        }
      }

      final exportedPath = await service.exportLogsToFile(pickedPath);
      if (context.mounted) {
        AeroSnack.success(context, message: 'Logs saved to $exportedPath');
      }
    } catch (e) {
      if (PlatformUtils.isMobile) {
        try {
          final copiedText = service.exportLogs();
          if (copiedText.trim().isNotEmpty) {
            await Clipboard.setData(ClipboardData(text: copiedText));
            if (context.mounted) {
              AeroSnack.info(context, message: 'Logs copied to clipboard');
            }
            return;
          }
        } catch (_) {}
      }
      if (context.mounted) {
        AeroSnack.error(context, message: 'Failed to export logs: $e');
      }
    }
  }

  void _showLogsViewer(BuildContext context) {
    final windowHeight = MediaQuery.sizeOf(context).height;
    final desktopPanelHeight = (windowHeight - 180)
        .clamp(220.0, 640.0)
        .toDouble();

    if (PlatformUtils.isDesktop) {
      showAeroDialog<void>(
        context: context,
        builder: (_) => AeroDialog(
          maxWidth: 920,
          titleText: 'Runtime Logs',
          showCloseButton: true,
          content: SizedBox(
            height: desktopPanelHeight,
            child: const LogsViewer(showTitle: false),
          ),
        ),
      );
      return;
    }

    showAeroSheet<void>(
      context: context,
      titleText: 'Runtime Logs',
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.72,
        child: const LogsViewer(showTitle: false),
      ),
    );
  }
}

class _SettingEntry {
  final String title;
  final String? subtitle;
  final List<String> keywords;
  final Widget widget;

  _SettingEntry({
    required this.title,
    this.subtitle,
    this.keywords = const [],
    required this.widget,
  });

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (title.toLowerCase().contains(q)) return true;
    if (subtitle != null && subtitle!.toLowerCase().contains(q)) return true;
    for (final kw in keywords) {
      if (kw.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

/// Storage permission tile for Android
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
      if (!granted) {
        await storage.openManageStorageSettings();
      }
      await _refresh();
      if (mounted && _granted) {
        try {
          final preferred = await storage.getPreferredDownloadDirectory();
          if (preferred != widget.provider.outputPath) {
            await widget.provider.setOutputPath(preferred);
          }
        } catch (_) {}
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _granted ? 'Storage Access' : 'Grant Storage Access';
    final subtitle = _checking
        ? 'Checking permission…'
        : _granted
        ? 'Public Downloads folder is writable'
        : 'Allow All files access so downloads save to Downloads/AeroTube';

    return SettingsRow(
      title: title,
      subtitle: subtitle,
      icon: _granted
          ? Symbols.sd_storage_rounded
          : Symbols.warning_amber_rounded,
      iconColor: _granted ? context.aero.primary : Colors.amber.shade700,
      trailing: (_requesting || _checking)
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : StatusPill(
              label: _granted ? 'Granted' : 'Action Required',
              type: _granted ? StatusPillType.success : StatusPillType.warning,
            ),
      onTap: _requesting ? null : _request,
    );
  }
}

/// Debounced concurrency control with Aero slider styling
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
    final persisted = context.select<PlatformSettingsProvider, int>(
      (p) => p.maxConcurrentDownloads,
    );
    final displayed = (_dragValue ?? persisted.toDouble()).clamp(1.0, 6.0);
    final colors = context.aero;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AeroSpace.lg,
        vertical: AeroSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: AeroRadius.smBorderRadius,
                  border: Border.all(color: colors.outline, width: 1.0),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Symbols.downloading_rounded,
                  size: 20,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(width: AeroSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Concurrent Downloads',
                      style: AeroText.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${displayed.toInt()} simultaneous active downloads',
                      style: AeroText.bodySm.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AeroSpace.sm),
          Padding(
            padding: const EdgeInsets.only(left: 48, right: 8),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: colors.primary,
                inactiveTrackColor: colors.surface3,
                thumbColor: colors.primary,
                overlayColor: colors.primaryGlow,
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
      ),
    );
  }
}
