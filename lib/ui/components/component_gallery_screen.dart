import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import 'aero_button.dart';
import 'aero_card.dart';
import 'aero_chip.dart';
import 'aero_density.dart';
import 'aero_dialog.dart';
import 'aero_progress.dart';
import 'aero_snack.dart';
import 'aero_text_field.dart';
import 'empty_state.dart';
import 'section_header.dart';
import 'settings_row.dart';
import 'status_pill.dart';
import 'thumbnail_tile.dart';

/// Interactive debug screen displaying all Aero components in both Dark and Light themes.
///
/// Intended for quick visual inspection, contrast checks, and density previews.
class ComponentGalleryScreen extends StatefulWidget {
  final String? sampleImageUrl;

  const ComponentGalleryScreen({super.key, this.sampleImageUrl});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  bool _isDark = true;
  AeroDensity _density = AeroDensity.comfortable;
  double _testProgress = 0.65;
  bool _settingsSwitch1 = true;
  bool _settingsSwitch2 = false;
  String _selectedQuality = '1080p';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default to the ambient brightness initially
    _isDark = Theme.of(context).brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    final themeData = _isDark ? AppTheme.darkTheme : AppTheme.lightTheme;

    return Theme(
      data: themeData,
      child: Builder(
        builder: (themedContext) {
          final colors = themedContext.aero;

          return Scaffold(
            backgroundColor: colors.bg,
            appBar: AppBar(
              backgroundColor: colors.surface1,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: IconThemeData(color: colors.onSurface),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aero Component Gallery',
                    style: AeroText.titleSm.copyWith(color: colors.onSurface),
                  ),
                  Text(
                    'Design System v2 · Inspection Sandbox',
                    style: AeroText.caption.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
              actions: [
                // Density toggle
                IconButton(
                  tooltip: _density.isCompact
                      ? 'Density: Compact (Windows)'
                      : 'Density: Comfortable (Android)',
                  icon: Icon(
                    _density.isCompact
                        ? Symbols.desktop_windows_rounded
                        : Symbols.phone_android_rounded,
                    color: colors.onSurface,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _density = _density.isCompact
                          ? AeroDensity.comfortable
                          : AeroDensity.compact;
                    });
                  },
                ),
                // Theme toggle
                IconButton(
                  tooltip: _isDark ? 'Switch to Light' : 'Switch to Dark',
                  icon: Icon(
                    _isDark
                        ? Symbols.light_mode_rounded
                        : Symbols.dark_mode_rounded,
                    color: colors.onSurface,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isDark = !_isDark;
                    });
                  },
                ),
                const SizedBox(width: AeroSpace.sm),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AeroSpace.lg,
                    vertical: AeroSpace.lg,
                  ),
                  children: [
                    _buildThemeStatusCard(colors),
                    _buildSectionDivider('01. STATUS PILLS', colors),
                    _buildStatusPillSection(themedContext),
                    _buildSectionDivider('02. AERO PROGRESS', colors),
                    _buildProgressSection(themedContext, colors),
                    _buildSectionDivider('03. THUMBNAIL TILE', colors),
                    _buildThumbnailSection(themedContext, colors),
                    _buildSectionDivider('04. SECTION HEADERS', colors),
                    _buildSectionHeaderDemo(colors),
                    _buildSectionDivider('05. SETTINGS ROWS', colors),
                    _buildSettingsRowSection(themedContext, colors),
                    _buildSectionDivider('06. BUTTONS', colors),
                    _buildButtonSection(themedContext),
                    _buildSectionDivider('07. CHIPS & FILTERS', colors),
                    _buildChipsSection(themedContext),
                    _buildSectionDivider('08. TEXT FIELDS', colors),
                    _buildTextFieldSection(themedContext),
                    _buildSectionDivider('09. CARDS', colors),
                    _buildCardsSection(themedContext, colors),
                    _buildSectionDivider('10. DIALOGS & SHEETS', colors),
                    _buildDialogSection(themedContext),
                    _buildSectionDivider('11. SNACK BARS', colors),
                    _buildSnackSection(themedContext),
                    _buildSectionDivider('12. EMPTY STATE', colors),
                    _buildEmptyStateSection(themedContext, colors),
                    const SizedBox(height: AeroSpace.huge),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeStatusCard(AeroColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: AeroSpace.md),
      padding: const EdgeInsets.all(AeroSpace.md),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: AeroRadius.mdBorderRadius,
        border: Border.all(color: colors.outline, width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AeroSpace.sm),
          Expanded(
            child: Text(
              'Mode: ${_isDark ? "OLED Black (#000000)" : "Pure White (#FFFFFF)"}  ·  Density: ${_density.name.toUpperCase()}',
              style: AeroText.caption.copyWith(
                color: colors.onSurfaceMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          StatusPill(
            label: _isDark ? 'Dark Theme' : 'Light Theme',
            type: StatusPillType.info,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionDivider(String title, AeroColors colors) {
    return SectionHeader(
      title: title,
      margin: const EdgeInsets.only(top: AeroSpace.xxl, bottom: AeroSpace.md),
    );
  }

  Widget _buildStatusPillSection(BuildContext context) {
    return AeroCard(
      padding: const EdgeInsets.all(AeroSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AeroSpace.sm,
            runSpacing: AeroSpace.sm,
            children: [
              const StatusPill.success(label: 'Cookies on · Signed in'),
              const StatusPill.warning(label: 'Cookies on · Not signed in'),
              const StatusPill.danger(label: 'Error: Rate limited'),
              const StatusPill.info(label: 'Active download'),
              const StatusPill.neutral(label: 'Idle / Cookies off'),
            ],
          ),
          const SizedBox(height: AeroSpace.md),
          Text(
            'With Dot, Spinner, or Tappable Actions:',
            style: AeroText.caption.copyWith(
              color: context.aero.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: AeroSpace.sm),
          Wrap(
            spacing: AeroSpace.sm,
            runSpacing: AeroSpace.sm,
            children: [
              const StatusPill(
                label: 'Connecting...',
                type: StatusPillType.info,
                showSpinner: true,
              ),
              const StatusPill(
                label: 'Online',
                type: StatusPillType.success,
                showDot: true,
              ),
              StatusPill(
                label: 'Tap for Details',
                type: StatusPillType.warning,
                icon: Symbols.info_rounded,
                onTap: () {
                  AeroSnack.info(
                    context,
                    message: 'StatusPill tapped: Cookie details inspected',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context, AeroColors colors) {
    return AeroCard(
      padding: const EdgeInsets.all(AeroSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Determinate (4px track + head glow):',
                style: AeroText.caption.copyWith(color: colors.onSurfaceMuted),
              ),
              Text(
                '${(_testProgress * 100).toInt()}%',
                style: AeroText.tabularFigures(
                  AeroText.label.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AeroSpace.sm),
          AeroProgress(value: _testProgress),
          const SizedBox(height: AeroSpace.md),
          Row(
            children: [
              AeroButton(
                text: '25%',
                density: AeroDensity.compact,
                variant: AeroButtonVariant.tonal,
                onPressed: () => setState(() => _testProgress = 0.25),
              ),
              const SizedBox(width: AeroSpace.sm),
              AeroButton(
                text: '65%',
                density: AeroDensity.compact,
                variant: AeroButtonVariant.tonal,
                onPressed: () => setState(() => _testProgress = 0.65),
              ),
              const SizedBox(width: AeroSpace.sm),
              AeroButton(
                text: '100%',
                density: AeroDensity.compact,
                variant: AeroButtonVariant.tonal,
                onPressed: () => setState(() => _testProgress = 1.0),
              ),
            ],
          ),
          const SizedBox(height: AeroSpace.lg),
          Text(
            'Indeterminate (Smooth shimmer sweep):',
            style: AeroText.caption.copyWith(color: colors.onSurfaceMuted),
          ),
          const SizedBox(height: AeroSpace.sm),
          const AeroProgress(value: null),
        ],
      ),
    );
  }

  Widget _buildThumbnailSection(BuildContext context, AeroColors colors) {
    return AeroCard(
      padding: const EdgeInsets.all(AeroSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth > 500)
                  ? (constraints.maxWidth - AeroSpace.md) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: AeroSpace.md,
                runSpacing: AeroSpace.md,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ThumbnailTile(
                          imageUrl: widget.sampleImageUrl,
                          duration: '14:28',
                          onTap: () {
                            AeroSnack.info(
                              context,
                              message: 'ThumbnailTile clicked',
                            );
                          },
                        ),
                        const SizedBox(height: AeroSpace.xs),
                        Text(
                          '16:9 with Duration Chip & Image',
                          style: AeroText.caption.copyWith(
                            color: colors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ThumbnailTile(
                          imageUrl: null, // skeleton / fallback preview
                          duration: '03:45',
                        ),
                        const SizedBox(height: AeroSpace.xs),
                        Text(
                          'Fallback placeholder tile',
                          style: AeroText.caption.copyWith(
                            color: colors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeaderDemo(AeroColors colors) {
    return AeroCard(
      padding: const EdgeInsets.all(AeroSpace.md),
      child: Column(
        children: [
          const SectionHeader(
            title: 'Section Header Preview',
            margin: EdgeInsets.zero,
          ),
          const SizedBox(height: AeroSpace.sm),
          SectionHeader(
            title: 'With Trailing Action',
            margin: EdgeInsets.zero,
            trailing: TextButton(
              onPressed: () {},
              child: const Text('Clear All'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRowSection(BuildContext context, AeroColors colors) {
    return AeroCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SettingsRow(
            icon: Symbols.cookie_rounded,
            title: 'YouTube Cookie Session',
            subtitle: 'Import browser cookies for 1080p+ and member content',
            trailing: StatusPill.success(label: 'Connected'),
            onTap: () {
              AeroSnack.success(context, message: 'Cookie settings opened');
            },
          ),
          Divider(height: 1, color: colors.outline),
          SettingsRow(
            icon: Symbols.high_quality_rounded,
            title: 'Prefer Highest Quality',
            subtitle: 'Default to 4K / 1080p when streams are available',
            trailing: Switch(
              value: _settingsSwitch1,
              onChanged: (val) => setState(() => _settingsSwitch1 = val),
            ),
          ),
          Divider(height: 1, color: colors.outline),
          SettingsRow(
            icon: Symbols.notifications_active_rounded,
            title: 'Completion Notifications',
            subtitle: 'Play audio and show system alert when done',
            trailing: Switch(
              value: _settingsSwitch2,
              onChanged: (val) => setState(() => _settingsSwitch2 = val),
            ),
          ),
          Divider(height: 1, color: colors.outline),
          SettingsRow(
            icon: Symbols.folder_open_rounded,
            title: 'Download Location',
            subtitle: 'C:/Users/mtech/Downloads/AeroTube',
            onTap: () {
              AeroSnack.info(context, message: 'Opening folder picker...');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildButtonSection(BuildContext context) {
    return AeroCard(
      padding: const EdgeInsets.all(AeroSpace.lg),
      child: Wrap(
        spacing: AeroSpace.md,
        runSpacing: AeroSpace.md,
        children: [
          AeroButton(
            text: 'Primary Button',
            icon: const Icon(Symbols.download_rounded),
            variant: AeroButtonVariant.primary,
            density: _density,
            onPressed: () {
              AeroSnack.success(context, message: 'Primary button pressed!');
            },
          ),
          AeroButton(
            text: 'Tonal Button',
            icon: const Icon(Symbols.settings_rounded),
            variant: AeroButtonVariant.tonal,
            density: _density,
            onPressed: () {
              AeroSnack.info(context, message: 'Tonal button pressed');
            },
          ),
          AeroButton(
            text: 'Ghost Button',
            variant: AeroButtonVariant.ghost,
            density: _density,
            onPressed: () {
              AeroSnack.info(context, message: 'Ghost button pressed');
            },
          ),
          AeroButton(
            text: 'Danger Button',
            icon: const Icon(Symbols.delete_rounded),
            variant: AeroButtonVariant.danger,
            density: _density,
            onPressed: () {
              AeroSnack.error(context, message: 'Danger action executed');
            },
          ),
          AeroButton(
            text: 'Loading...',
            variant: AeroButtonVariant.primary,
            density: _density,
            isLoading: true,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildChipsSection(BuildContext context) {
    final qualities = [
      '2160p 4K',
      '1440p',
      '1080p',
      '720p',
      'Audio Only (MP3)',
    ];

    return AeroCard(
      padding: const EdgeInsets.all(AeroSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AeroSpace.sm,
            runSpacing: AeroSpace.sm,
            children: qualities.map((q) {
              final isSelected = _selectedQuality == q;
              return AeroChip(
                text: q,
                selected: isSelected,
                density: _density,
                onTap: () {
                  setState(() => _selectedQuality = q);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldSection(BuildContext context) {
    return AeroCard(
      padding: const EdgeInsets.all(AeroSpace.lg),
      child: Column(
        children: [
          AeroTextField(
            hintText: 'Paste YouTube video or playlist link...',
            prefixIcon: const Icon(Symbols.link_rounded),
            density: _density,
          ),
          const SizedBox(height: AeroSpace.md),
          AeroTextField(
            hintText: 'Error demonstration',
            errorText: 'Invalid YouTube link format',
            prefixIcon: const Icon(Symbols.error_rounded),
            density: _density,
          ),
        ],
      ),
    );
  }

  Widget _buildCardsSection(BuildContext context, AeroColors colors) {
    return Row(
      children: [
        Expanded(
          child: AeroCard(
            padding: const EdgeInsets.all(AeroSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Standard AeroCard', style: AeroText.titleSm),
                const SizedBox(height: 4),
                Text('surface1 + hairline outline', style: AeroText.caption),
              ],
            ),
          ),
        ),
        const SizedBox(width: AeroSpace.md),
        Expanded(
          child: AeroCard(
            selected: true,
            padding: const EdgeInsets.all(AeroSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected AeroCard',
                  style: AeroText.titleSm.copyWith(color: colors.primary),
                ),
                const SizedBox(height: 4),
                Text('primarySoft + primary hairline', style: AeroText.caption),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogSection(BuildContext context) {
    return AeroCard(
      padding: const EdgeInsets.all(AeroSpace.lg),
      child: Wrap(
        spacing: AeroSpace.md,
        runSpacing: AeroSpace.md,
        children: [
          AeroButton(
            text: 'Open AeroDialog (Centered)',
            variant: AeroButtonVariant.tonal,
            onPressed: () {
              showAeroDialog(
                context: context,
                builder: (dContext) => AeroDialog(
                  titleText: 'Clear Download History',
                  content: Text(
                    'Are you sure you want to remove all finished downloads? Downloaded files on disk will be preserved.',
                    style: AeroText.bodySm.copyWith(
                      color: dContext.aero.onSurfaceMuted,
                    ),
                  ),
                  actions: [
                    AeroButton(
                      text: 'Cancel',
                      variant: AeroButtonVariant.ghost,
                      onPressed: () => Navigator.pop(dContext),
                    ),
                    AeroButton(
                      text: 'Clear All',
                      variant: AeroButtonVariant.danger,
                      onPressed: () {
                        Navigator.pop(dContext);
                        AeroSnack.success(context, message: 'History cleared');
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          AeroButton(
            text: 'Open Adaptive AeroSheet',
            variant: AeroButtonVariant.tonal,
            onPressed: () {
              showAeroSheet(
                context: context,
                titleText: 'Format Stream Options',
                builder: (sContext) => Padding(
                  padding: const EdgeInsets.only(bottom: AeroSpace.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SettingsRow(
                        icon: Symbols.video_library_rounded,
                        title: '1080p Full HD (60fps)',
                        subtitle: 'Video H.264 · 245 MB',
                        onTap: () => Navigator.pop(sContext),
                      ),
                      SettingsRow(
                        icon: Symbols.audio_file_rounded,
                        title: 'Audio 320kbps MP3',
                        subtitle: 'Extracted AAC · 9.4 MB',
                        onTap: () => Navigator.pop(sContext),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSnackSection(BuildContext context) {
    return AeroCard(
      padding: const EdgeInsets.all(AeroSpace.lg),
      child: Wrap(
        spacing: AeroSpace.sm,
        runSpacing: AeroSpace.sm,
        children: [
          AeroButton(
            text: 'Success Snack',
            variant: AeroButtonVariant.tonal,
            density: AeroDensity.compact,
            onPressed: () => AeroSnack.success(
              context,
              message: 'Video downloaded successfully!',
              actionLabel: 'OPEN',
              onAction: () {},
            ),
          ),
          AeroButton(
            text: 'Warning Snack',
            variant: AeroButtonVariant.tonal,
            density: AeroDensity.compact,
            onPressed: () => AeroSnack.warning(
              context,
              message: 'Session expires in 10 minutes.',
            ),
          ),
          AeroButton(
            text: 'Error Snack',
            variant: AeroButtonVariant.tonal,
            density: AeroDensity.compact,
            onPressed: () => AeroSnack.error(
              context,
              message: 'Download failed: ffmpeg binary exit code 1',
              actionLabel: 'RETRY',
              onAction: () {},
            ),
          ),
          AeroButton(
            text: 'Info Snack',
            variant: AeroButtonVariant.tonal,
            density: AeroDensity.compact,
            onPressed: () =>
                AeroSnack.info(context, message: 'Clipboard link detected'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateSection(BuildContext context, AeroColors colors) {
    return AeroCard(
      padding: EdgeInsets.zero,
      child: EmptyState(
        icon: Symbols.file_download_off_rounded,
        title: 'No Active Downloads',
        description:
            'Paste a link above or search for music and videos to begin.',
        actionLabel: 'Explore Popular',
        onAction: () {
          AeroSnack.info(context, message: 'Navigating to explore...');
        },
        secondaryActionLabel: 'Paste URL',
        onSecondaryAction: () {
          AeroSnack.info(context, message: 'URL pasted');
        },
      ),
    );
  }
}
