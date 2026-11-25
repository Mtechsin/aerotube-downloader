import 'package:material_symbols_icons/symbols.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/platform_utils.dart';
import '../../models/download_item.dart';
import '../../providers/download_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../services/core/file_action_service.dart';
import '../components/aero_button.dart';
import '../components/aero_card.dart';
import '../components/aero_chip.dart';
import '../components/aero_density.dart';
import '../components/aero_dialog.dart';
import '../components/aero_text_field.dart';
import '../components/empty_state.dart';
import '../components/section_header.dart';
import '../widgets/download_item_card.dart';
import '../widgets/error_details_dialog.dart';

enum HistoryFilter {
  all('All'),
  video('Video'),
  audio('Audio'),
  failed('Failed');

  final String label;
  const HistoryFilter(this.label);
}

enum HistoryDateGroup {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This week'),
  earlier('Earlier');

  final String title;
  const HistoryDateGroup(this.title);
}

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final aero = context.aero;

    // Counts for count badges
    final activeCount = PlatformUtils.isMobile
        ? context.select<MobileDownloadProvider, int>(
            (p) => p.activeDownloadsCount,
          )
        : context.select<DownloadProvider, int>(
            (p) => p.activeDownloads.length,
          );

    final historyCount = PlatformUtils.isMobile
        ? context.select<MobileDownloadProvider, int>(
            (p) =>
                p.completedDownloads.length +
                p.failedDownloads.length +
                p.cancelledDownloads.length,
          )
        : context.select<DownloadProvider, int>(
            (p) => p.historyDownloads.length,
          );

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context, aero),
          const SizedBox(height: AeroSpace.md),

          // Segmented tabs: Active | History with count badges
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AeroSpace.lg),
            child: PlatformUtils.isWindows
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 420,
                      child: _buildTabSegmentedControl(
                        context,
                        activeCount,
                        historyCount,
                      ),
                    ),
                  )
                : _buildTabSegmentedControl(context, activeCount, historyCount),
          ),
          const SizedBox(height: AeroSpace.md),

          // Content View with shared-axis expressive transition
          Expanded(
            child: AnimatedSwitcher(
              duration: appMotionDuration(context, AppMotion.short),
              switchInCurve: AppMotion.decelerate,
              switchOutCurve: AppMotion.accelerate,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(_selectedIndex == 0 ? -0.03 : 0.03, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_selectedIndex),
                child: _selectedIndex == 0
                    ? const _ActiveDownloadsView()
                    : const _HistoryDownloadsView(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDownloadsFolder(BuildContext context) async {
    try {
      final settingsProvider = context.read<PlatformSettingsProvider>();
      final outputPath =
          settingsProvider.settings.outputPath ??
          await settingsProvider.getDefaultOutputPath();

      if (!context.mounted) return;

      final dir = Directory(outputPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      if (!context.mounted) return;

      final opened = await FileActionService().openFolder(outputPath);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloads folder: $outputPath'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open downloads folder: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildHeader(BuildContext context, AeroColors aero) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(
        AeroSpace.xl,
        AeroSpace.lg,
        AeroSpace.xl,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Downloads',
                  style: AeroText.headline.copyWith(
                    color: aero.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Track transfers and manage your saved media.',
                  style: AeroText.bodySm.copyWith(color: aero.onSurfaceMuted),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (PlatformUtils.isAndroid)
                IconButton(
                  icon: Icon(
                    Symbols.home_rounded,
                    size: 22,
                    color: aero.onSurfaceMuted,
                  ),
                  tooltip: 'Home',
                  onPressed: () =>
                      context.read<NavigationProvider>().switchToHome(),
                ),
              if (PlatformUtils.isWindows)
                AeroButton.tonal(
                  text: 'Open folder',
                  icon: const Icon(Symbols.folder_open_rounded),
                  density: AeroDensity.compact,
                  onPressed: () => _openDownloadsFolder(context),
                )
              else
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: aero.surface2,
                      borderRadius: AeroRadius.smBorderRadius,
                      border: Border.all(color: aero.outline),
                    ),
                    child: Icon(
                      Symbols.folder_open_rounded,
                      color: aero.primary,
                      size: 20,
                    ),
                  ),
                  onPressed: () => _openDownloadsFolder(context),
                  tooltip: 'Open Downloads Folder',
                ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: aero.surface2,
                    borderRadius: AeroRadius.smBorderRadius,
                    border: Border.all(color: aero.outline),
                  ),
                  child: Icon(
                    Symbols.more_vert_rounded,
                    color: aero.onSurfaceMuted,
                    size: 20,
                  ),
                ),
                color: aero.surface2,
                shape: RoundedRectangleBorder(
                  borderRadius: AeroRadius.mdBorderRadius,
                  side: BorderSide(color: aero.outline),
                ),
                onSelected: (value) async {
                  if (value == 'clear_finished') {
                    final confirmed = await showAeroDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AeroDialog(
                        titleText: 'Clear finished downloads?',
                        content: Text(
                          'Completed, failed, and cancelled items will be '
                          'removed from history. Downloaded files are not deleted.',
                          style: AeroText.body.copyWith(
                            color: aero.onSurfaceMuted,
                          ),
                        ),
                        actions: [
                          AeroButton(
                            variant: AeroButtonVariant.ghost,
                            text: 'Cancel',
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                          ),
                          AeroButton(
                            variant: AeroButtonVariant.danger,
                            text: 'Clear',
                            onPressed: () => Navigator.pop(dialogContext, true),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    if (PlatformUtils.isMobile) {
                      context.read<MobileDownloadProvider>().clearCompleted();
                      context.read<MobileDownloadProvider>().clearFailed();
                      context.read<MobileDownloadProvider>().clearCancelled();
                    } else {
                      await context.read<DownloadProvider>().clearCompleted();
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'clear_finished',
                    child: Row(
                      children: [
                        Icon(
                          Symbols.clear_all_rounded,
                          color: aero.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Clear Finished',
                          style: TextStyle(
                            color: aero.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSegmentedControl(
    BuildContext context,
    int activeCount,
    int historyCount,
  ) {
    final aero = context.aero;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: aero.surface2,
        borderRadius: AeroRadius.lgBorderRadius,
        border: Border.all(color: aero.outline, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = (constraints.maxWidth - 8) / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: appMotionDuration(context, AppMotion.short),
                curve: AppMotion.emphasized,
                left: _selectedIndex == 0 ? 0 : segmentWidth,
                width: segmentWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: aero.primarySoft,
                    borderRadius: AeroRadius.mdBorderRadius,
                    border: Border.all(color: aero.primary, width: 1.0),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildSegment(
                    context,
                    label: 'Active',
                    count: activeCount,
                    index: 0,
                  ),
                  _buildSegment(
                    context,
                    label: 'History',
                    count: historyCount,
                    index: 1,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required String label,
    required int count,
    required int index,
  }) {
    final aero = context.aero;
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        borderRadius: AeroRadius.mdBorderRadius,
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AeroText.body.copyWith(
                  color: isSelected ? aero.primary : aero.onSurfaceMuted,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? aero.primary : aero.surface3,
                    borderRadius: AeroRadius.fullBorderRadius,
                  ),
                  child: Text(
                    count.toString(),
                    style: AeroText.caption.withTabularFigures().copyWith(
                      color: isSelected ? Colors.white : aero.onSurfaceMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ACTIVE DOWNLOADS VIEW
// ==========================================
class _ActiveDownloadsView extends StatelessWidget {
  const _ActiveDownloadsView();

  @override
  Widget build(BuildContext context) {
    final List<DownloadItem> downloads = PlatformUtils.isMobile
        ? context.select<MobileDownloadProvider, List<DownloadItem>>(
            (p) => p.activeDownloads,
          )
        : context.select<DownloadProvider, List<DownloadItem>>(
            (p) => p.activeDownloads,
          );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Column(
          children: [
            const _OemBatteryGuidanceBanner(),
            Expanded(
              child: downloads.isEmpty
                  ? EmptyState(
                      icon: Symbols.download_rounded,
                      title: 'No active downloads',
                      description:
                          'Add a video URL on Home and your transfer progress will appear here.',
                      actionLabel: 'Go to Home',
                      onAction: () =>
                          context.read<NavigationProvider>().switchToHome(),
                    )
                  : ListView.builder(
                      cacheExtent: 400,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AeroSpace.lg,
                        vertical: AeroSpace.sm,
                      ),
                      itemCount: downloads.length,
                      itemBuilder: (context, index) {
                        final item = downloads[index];
                        return DownloadItemCard(
                          key: ValueKey(item.id),
                          item: item,
                          onCancel: () {
                            if (PlatformUtils.isMobile) {
                              context
                                  .read<MobileDownloadProvider>()
                                  .cancelDownload(item.id);
                            } else {
                              context.read<DownloadProvider>().cancelDownload(
                                item.id,
                              );
                            }
                          },
                          onPause: () {
                            if (PlatformUtils.isMobile) {
                              context
                                  .read<MobileDownloadProvider>()
                                  .pauseDownload(item.id);
                            } else {
                              context.read<DownloadProvider>().pauseDownload(
                                item.id,
                              );
                            }
                          },
                          onResume: () {
                            if (PlatformUtils.isMobile) {
                              context
                                  .read<MobileDownloadProvider>()
                                  .resumeDownload(item.id);
                            } else {
                              context.read<DownloadProvider>().resumeDownload(
                                item.id,
                              );
                            }
                          },
                          onRetry: () {
                            if (PlatformUtils.isMobile) {
                              context
                                  .read<MobileDownloadProvider>()
                                  .retryDownload(item.id);
                            } else {
                              context.read<DownloadProvider>().retryDownload(
                                item.id,
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HISTORY DOWNLOADS VIEW
// ==========================================
class _HistoryDownloadsView extends StatefulWidget {
  const _HistoryDownloadsView();

  @override
  State<_HistoryDownloadsView> createState() => _HistoryDownloadsViewState();
}

class _HistoryDownloadsViewState extends State<_HistoryDownloadsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  HistoryFilter _selectedFilter = HistoryFilter.all;
  final Set<String> _selectedIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  HistoryDateGroup _getGroupForDate(
    DateTime? date,
    DateTime todayStart,
    DateTime yesterdayStart,
    DateTime weekStart,
  ) {
    if (date == null) return HistoryDateGroup.earlier;

    final itemDate = DateTime(date.year, date.month, date.day);
    if (itemDate.isAtSameMomentAs(todayStart) || itemDate.isAfter(todayStart)) {
      return HistoryDateGroup.today;
    } else if (itemDate.isAtSameMomentAs(yesterdayStart)) {
      return HistoryDateGroup.yesterday;
    } else if (itemDate.isAfter(weekStart)) {
      return HistoryDateGroup.thisWeek;
    } else {
      return HistoryDateGroup.earlier;
    }
  }

  List<DownloadItem> _applyFilters(List<DownloadItem> downloads) {
    return downloads.where((item) {
      // 1. Text filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = item.title.toLowerCase().contains(query);
        final matchesUrl = item.url.toLowerCase().contains(query);
        if (!matchesTitle && !matchesUrl) return false;
      }

      // 2. Chip filter
      switch (_selectedFilter) {
        case HistoryFilter.all:
          return true;
        case HistoryFilter.video:
          return !item.audioOnly &&
              item.status != DownloadStatus.failed &&
              item.status != DownloadStatus.cancelled;
        case HistoryFilter.audio:
          return item.audioOnly &&
              item.status != DownloadStatus.failed &&
              item.status != DownloadStatus.cancelled;
        case HistoryFilter.failed:
          return item.status == DownloadStatus.failed ||
              item.status == DownloadStatus.cancelled;
      }
    }).toList();
  }

  Future<void> _handleDeleteSingle(
    BuildContext context,
    DownloadItem item,
  ) async {
    final aero = context.aero;
    final confirmed = await showAeroDialog<bool>(
      context: context,
      builder: (dialogContext) => AeroDialog(
        titleText: 'Remove download?',
        content: Text(
          '"${item.title}" will be removed from history. '
          'The downloaded file is not deleted.',
          style: AeroText.body.copyWith(color: aero.onSurfaceMuted),
        ),
        actions: [
          AeroButton(
            variant: AeroButtonVariant.ghost,
            text: 'Cancel',
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AeroButton(
            variant: AeroButtonVariant.danger,
            text: 'Remove',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (PlatformUtils.isMobile) {
      context.read<MobileDownloadProvider>().removeDownload(item.id);
    } else {
      context.read<DownloadProvider>().deleteFromHistory(item.id);
    }
    _selectedIds.remove(item.id);
  }

  Future<void> _handleDeleteSelected(BuildContext context) async {
    final count = _selectedIds.length;
    if (count == 0) return;

    final aero = context.aero;
    final confirmed = await showAeroDialog<bool>(
      context: context,
      builder: (dialogContext) => AeroDialog(
        titleText: 'Remove $count downloads?',
        content: Text(
          'Selected items will be removed from history. '
          'The downloaded files will not be deleted.',
          style: AeroText.body.copyWith(color: aero.onSurfaceMuted),
        ),
        actions: [
          AeroButton(
            variant: AeroButtonVariant.ghost,
            text: 'Cancel',
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AeroButton(
            variant: AeroButtonVariant.danger,
            text: 'Remove',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ids = _selectedIds.toList();
    if (PlatformUtils.isMobile) {
      final provider = context.read<MobileDownloadProvider>();
      for (final id in ids) {
        provider.removeDownload(id);
      }
    } else {
      final provider = context.read<DownloadProvider>();
      for (final id in ids) {
        provider.deleteFromHistory(id);
      }
    }
    setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final aero = context.aero;

    final List<DownloadItem> rawDownloads = PlatformUtils.isMobile
        ? context.select<MobileDownloadProvider, List<DownloadItem>>(
            (p) => p.historyDownloads,
          )
        : context.select<DownloadProvider, List<DownloadItem>>(
            (p) => p.historyDownloads,
          );

    final filteredDownloads = _applyFilters(rawDownloads);

    // Grouping by date (compute date boundaries once outside the loop)
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 7));
    final Map<HistoryDateGroup, List<DownloadItem>> grouped = {};
    for (final item in filteredDownloads) {
      final group = _getGroupForDate(
        item.completedDate,
        todayStart,
        yesterdayStart,
        weekStart,
      );
      grouped.putIfAbsent(group, () => []).add(item);
    }

    final hasActiveSelection = _selectedIds.isNotEmpty;
    final showCheckboxes = PlatformUtils.isWindows || hasActiveSelection;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Column(
          children: [
            // Search and filter chips at top of History
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AeroSpace.lg),
              child: Column(
                children: [
                  AeroTextField(
                    controller: _searchController,
                    hintText: 'Search history...',
                    prefixIcon: const Icon(Symbols.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Symbols.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: AeroSpace.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        AeroChip(
                          text: 'All',
                          selected: _selectedFilter == HistoryFilter.all,
                          onTap: () => setState(
                            () => _selectedFilter = HistoryFilter.all,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AeroChip(
                          text: 'Video',
                          icon: const Icon(Symbols.videocam_rounded),
                          selected: _selectedFilter == HistoryFilter.video,
                          onTap: () => setState(
                            () => _selectedFilter = HistoryFilter.video,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AeroChip(
                          text: 'Audio',
                          icon: const Icon(Symbols.audiotrack_rounded),
                          selected: _selectedFilter == HistoryFilter.audio,
                          onTap: () => setState(
                            () => _selectedFilter = HistoryFilter.audio,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AeroChip(
                          text: 'Failed',
                          icon: const Icon(Symbols.error_rounded),
                          selected: _selectedFilter == HistoryFilter.failed,
                          onTap: () => setState(
                            () => _selectedFilter = HistoryFilter.failed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Windows Multi-select toolbar
            if (hasActiveSelection) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AeroSpace.lg,
                  AeroSpace.sm,
                  AeroSpace.lg,
                  0,
                ),
                child: AeroCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedIds.length} selected',
                        style: AeroText.label.copyWith(
                          color: aero.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      AeroButton(
                        text: 'Select all',
                        variant: AeroButtonVariant.ghost,
                        height: 32,
                        onPressed: () {
                          setState(() {
                            _selectedIds.addAll(
                              filteredDownloads.map((e) => e.id),
                            );
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      AeroButton(
                        text: 'Delete',
                        icon: const Icon(Symbols.delete_rounded, size: 16),
                        variant: AeroButtonVariant.danger,
                        height: 32,
                        onPressed: () => _handleDeleteSelected(context),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Symbols.close_rounded, size: 18),
                        tooltip: 'Cancel',
                        onPressed: () => setState(() => _selectedIds.clear()),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: AeroSpace.sm),

            // List Content or Empty State
            Expanded(
              child: rawDownloads.isEmpty
                  ? EmptyState(
                      icon: Symbols.history_rounded,
                      title: 'Nothing here yet',
                      description: 'Your finished downloads will appear here',
                      actionLabel: 'Go to Home',
                      onAction: () =>
                          context.read<NavigationProvider>().switchToHome(),
                    )
                  : filteredDownloads.isEmpty
                  ? const EmptyState(
                      icon: Symbols.search_off_rounded,
                      title: 'No matching downloads',
                      description: 'Try adjusting your search or filters',
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AeroSpace.lg,
                        vertical: AeroSpace.xs,
                      ),
                      children: [
                        for (final group in HistoryDateGroup.values)
                          if (grouped.containsKey(group) &&
                              grouped[group]!.isNotEmpty) ...[
                            SectionHeader(title: group.title),
                            for (final item in grouped[group]!)
                              DownloadItemCard(
                                key: ValueKey(item.id),
                                item: item,
                                isHistory: true,
                                showCheckbox: showCheckboxes,
                                isSelected: _selectedIds.contains(item.id),
                                onSelectChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedIds.add(item.id);
                                    } else {
                                      _selectedIds.remove(item.id);
                                    }
                                  });
                                },
                                onDelete: () =>
                                    _handleDeleteSingle(context, item),
                                onRetry:
                                    (item.status == DownloadStatus.failed ||
                                        item.status == DownloadStatus.cancelled)
                                    ? () {
                                        if (PlatformUtils.isMobile) {
                                          context
                                              .read<MobileDownloadProvider>()
                                              .retryDownload(item.id);
                                        } else {
                                          context
                                              .read<DownloadProvider>()
                                              .retryDownload(item.id);
                                        }
                                      }
                                    : null,
                              ),
                          ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// OEM BATTERY BANNER (Android aggressive battery management)
// =========================================================================
class _OemBatteryGuidanceBanner extends StatefulWidget {
  const _OemBatteryGuidanceBanner();

  @override
  State<_OemBatteryGuidanceBanner> createState() =>
      _OemBatteryGuidanceBannerState();
}

class _OemBatteryGuidanceBannerState extends State<_OemBatteryGuidanceBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    if (!PlatformUtils.isAndroid) return const SizedBox.shrink();

    final settings = context.watch<PlatformSettingsProvider?>();
    if (settings == null) return const SizedBox.shrink();

    final showBanner =
        settings.isAggressiveOem && !settings.isBatteryOptimizationIgnored;
    if (!showBanner) return const SizedBox.shrink();

    final aero = context.aero;
    final rawManufacturer = settings.deviceManufacturer ?? 'device';
    final manufacturer = rawManufacturer.isNotEmpty
        ? '${rawManufacturer[0].toUpperCase()}${rawManufacturer.substring(1)}'
        : 'Device';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: aero.danger.withValues(alpha: 0.12),
        borderRadius: AeroRadius.mdBorderRadius,
        border: Border.all(color: aero.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Symbols.battery_alert_rounded, color: aero.danger, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Background Downloads May Pause',
                  style: AeroText.label.copyWith(
                    fontWeight: FontWeight.bold,
                    color: aero.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$manufacturer battery manager may stop background downloads. Tap to allow autostart.',
                  style: AeroText.caption.copyWith(color: aero.onSurfaceMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(48, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => settings.openOemAutostartSettings(),
            child: const Text(
              'Fix',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.close_rounded, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: 'Dismiss',
            onPressed: () => setState(() => _dismissed = true),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// MobileDownloadItem
// Retained for backward-compatibility with UI unit/stress tests:

class MobileDownloadItem extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  const MobileDownloadItem({
    super.key,
    required this.item,
    this.onCancel,
    this.onDelete,
    this.onPause,
    this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final aero = context.aero;
    final isActive =
        item.status == DownloadStatus.downloadingVideo ||
        item.status == DownloadStatus.downloadingAudio ||
        item.status == DownloadStatus.merging ||
        item.status == DownloadStatus.pending ||
        item.status == DownloadStatus.queued;
    final isPaused = item.status == DownloadStatus.paused;
    final isFailed = item.status == DownloadStatus.failed;
    final isCompleted = item.status == DownloadStatus.completed;

    return AeroCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      onTap: isCompleted ? () => _handleOpenFile(context, item) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AeroRadius.mdBorderRadius,
                child: SizedBox(
                  width: 86,
                  height: 86,
                  child: _buildThumbnail(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AeroText.titleSm.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        color: aero.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.audioOnly ? 'Audio Download' : 'Video Download',
                      style: TextStyle(
                        color: aero.onSurfaceMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onCancel != null)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: aero.surface3,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Symbols.close_rounded,
                      size: 16,
                      color: aero.onSurfaceMuted,
                    ),
                  ),
                  onPressed: onCancel,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
              if (onDelete != null)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: aero.surface3,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Symbols.delete_rounded,
                      size: 16,
                      color: aero.onSurfaceMuted,
                    ),
                  ),
                  onPressed: onDelete,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
            ],
          ),

          if (isActive || isPaused) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('progress-${item.id}'),
                duration: appMotionDuration(
                  context,
                  const Duration(milliseconds: 320),
                ),
                curve: AppMotion.decelerate,
                tween: Tween<double>(begin: 0, end: item.progress),
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value > 0 ? value : null,
                    backgroundColor: aero.surface3,
                    valueColor: AlwaysStoppedAnimation(
                      isPaused
                          ? aero.warning
                          : (item.status == DownloadStatus.merging
                                ? Colors.orange
                                : aero.primary),
                    ),
                    minHeight: 6,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        () {
                          final statusText = item.statusText;
                          final phaseLabel =
                              item.status == DownloadStatus.merging ||
                              (statusText != null &&
                                  (statusText.contains('audio') ||
                                      statusText.contains('Merg') ||
                                      statusText.contains('Convert') ||
                                      statusText.contains('Finaliz')));
                          if (phaseLabel) {
                            return statusText ??
                                (item.audioOnly
                                    ? 'Converting audio...'
                                    : 'Merging video + audio...');
                          }
                          final sizePart = item.totalBytes != null
                              ? ' of ${_formatSize(item.totalBytes!)}'
                              : '';
                          return '${(item.progress * 100).toStringAsFixed(1)}%$sizePart';
                        }(),
                        style: TextStyle(
                          color: item.status == DownloadStatus.merging
                              ? Colors.orange
                              : aero.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: appMotionDuration(context, AppMotion.short),
                        child: Text(
                          isPaused
                              ? (item.statusText ?? 'Paused')
                              : item.status == DownloadStatus.merging
                              ? (item.statusText ?? 'Merging...')
                              : (item.speed > 0
                                    ? '${item.formattedSpeed}${item.eta > 0 ? ' • ETA ${item.formattedEta}' : ''}'
                                    : (item.statusText ?? 'Processing...')),
                          key: ValueKey(
                            isPaused
                                ? 'paused-${item.statusText}'
                                : '${item.speed}-${item.eta}-${item.statusText}',
                          ),
                          style: TextStyle(
                            color: isPaused
                                ? aero.warning
                                : aero.onSurfaceMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive || isPaused)
                  InkWell(
                    onTap: isPaused ? (onResume ?? () {}) : (onPause ?? () {}),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: (isPaused ? aero.warning : aero.primary)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isPaused ? aero.warning : aero.primary)
                              .withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPaused
                                ? Symbols.play_arrow_rounded
                                : Symbols.pause_rounded,
                            size: 18,
                            color: isPaused ? aero.warning : aero.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPaused ? 'Resume' : 'Pause',
                            style: TextStyle(
                              color: isPaused ? aero.warning : aero.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],

          if (isCompleted || isFailed) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatusBadge(context),
                if (isCompleted) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatSize(item.totalBytes ?? 0),
                    style: TextStyle(
                      color: aero.onSurfaceMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                if (isCompleted) ...[
                  IconButton(
                    icon: Icon(
                      Symbols.play_arrow_rounded,
                      color: aero.primary,
                      size: 22,
                    ),
                    tooltip: 'Open',
                    onPressed: () => _handleOpenFile(context, item),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: const EdgeInsets.all(6),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: Icon(
                      Symbols.share_rounded,
                      color: aero.onSurfaceMuted,
                      size: 18,
                    ),
                    tooltip: 'Share',
                    onPressed: () => _handleShareFile(context, item),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: const EdgeInsets.all(6),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: Icon(
                      Symbols.folder_open_rounded,
                      color: aero.onSurfaceMuted,
                      size: 19,
                    ),
                    tooltip: 'Show in folder',
                    onPressed: () => _handleOpenFolder(context, item),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: const EdgeInsets.all(6),
                  ),
                  const SizedBox(width: 2),
                  PopupMenuButton<String>(
                    tooltip: 'More actions',
                    icon: Icon(
                      Symbols.more_vert_rounded,
                      color: aero.onSurfaceMuted,
                      size: 19,
                    ),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'open':
                          _handleOpenFile(context, item);
                          break;
                        case 'open_with':
                          _handleOpenFile(context, item, useChooser: true);
                          break;
                        case 'share':
                          _handleShareFile(context, item);
                          break;
                        case 'show_folder':
                          _handleOpenFolder(context, item);
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'open',
                        child: Row(
                          children: [
                            Icon(Symbols.play_arrow_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Open'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'open_with',
                        child: Row(
                          children: [
                            Icon(Symbols.open_in_new_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Open with...'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Symbols.share_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Share'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'show_folder',
                        child: Row(
                          children: [
                            Icon(Symbols.folder_open_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Show in folder'),
                          ],
                        ),
                      ),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Symbols.delete_rounded,
                                size: 20,
                                color: aero.danger,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Delete',
                                style: TextStyle(color: aero.danger),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                if (isFailed && item.error != null)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        ErrorDetailsDialog.show(
                          context,
                          error: item.error!,
                          customTitle: 'Download Failed',
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Symbols.info_rounded,
                              size: 14,
                              color: aero.danger,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                item.error!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: aero.danger,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleOpenFile(
    BuildContext context,
    DownloadItem item, {
    bool useChooser = false,
  }) async {
    final filePath = item.savePath ?? item.outputPath;
    final service = FileActionService();
    final success = await service.openFile(filePath, useChooser: useChooser);

    if (!success && context.mounted) {
      final msg = service.lastError ?? 'Could not open file.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _handleShareFile(BuildContext context, DownloadItem item) async {
    final filePath = item.savePath ?? item.outputPath;
    final service = FileActionService();
    final success = await service.shareFile(filePath, title: item.title);

    if (!success && context.mounted) {
      final msg = service.lastError ?? 'Could not share file.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _handleOpenFolder(
    BuildContext context,
    DownloadItem item,
  ) async {
    final targetPath = item.savePath ?? item.outputPath;
    final service = FileActionService();
    final success = await service.openFolder(targetPath);

    if (!success && context.mounted) {
      final msg = service.lastError ?? 'Could not open folder.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Widget _buildThumbnail(BuildContext context) {
    final aero = context.aero;
    final localPath = item.thumbnailPath;

    if (localPath != null && item.thumbnailExists) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        cacheWidth: 256,
        errorBuilder: (_, __, ___) => _buildThumbnailFallback(aero),
      );
    }

    if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        item.thumbnailUrl!,
        fit: BoxFit.cover,
        cacheWidth: 256,
        errorBuilder: (_, __, ___) => _buildThumbnailFallback(aero),
      );
    }

    return _buildThumbnailFallback(aero);
  }

  Widget _buildThumbnailFallback(AeroColors aero) {
    return Container(
      color: aero.surface3,
      child: Icon(
        item.audioOnly ? Symbols.music_note_rounded : Symbols.movie_rounded,
        color: aero.onSurfaceMuted,
        size: 32,
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final aero = context.aero;

    Color color;
    String text;
    IconData icon;

    switch (item.status) {
      case DownloadStatus.pending:
        color = aero.onSurfaceMuted;
        text = 'Pending';
        icon = Symbols.schedule_rounded;
        break;
      case DownloadStatus.queued:
        color = Colors.orange;
        text = 'Queued';
        icon = Symbols.queue_rounded;
        break;
      case DownloadStatus.downloadingVideo:
        color = aero.primary;
        text = 'Video';
        icon = Symbols.videocam_rounded;
        break;
      case DownloadStatus.downloadingAudio:
        color = aero.warning;
        text = 'Audio';
        icon = Symbols.music_note_rounded;
        break;
      case DownloadStatus.merging:
        color = Colors.orange;
        text = 'Merging';
        icon = Symbols.merge_rounded;
        break;
      case DownloadStatus.completed:
        color = aero.success;
        text = 'Done';
        icon = Symbols.check_circle_rounded;
        break;
      case DownloadStatus.failed:
        color = aero.danger;
        text = 'Failed';
        icon = Symbols.error_rounded;
        break;
      case DownloadStatus.cancelled:
        color = aero.onSurfaceMuted;
        text = 'Cancelled';
        icon = Symbols.cancel_rounded;
        break;
      case DownloadStatus.paused:
        color = aero.warning;
        text = 'Paused';
        icon = Symbols.pause_circle_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
