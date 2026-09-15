import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/download_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../models/download_item.dart';
import '../widgets/downloads/active_downloads_tab.dart';
import '../widgets/downloads/history_downloads_tab.dart';
import '../widgets/animated_button.dart';
import '../widgets/motion_effects.dart';
import '../../core/theme/app_motion.dart';
import '../../services/core/file_action_service.dart';
import '../widgets/error_details_dialog.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildStatusIndicators(context),
          const SizedBox(height: 16),
          // Tab Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTabSegmentedControl(),
          ),
          const SizedBox(height: 16),

          // Content View — lists isolated via selectors so per-progress ticks rebuild only the list, not header/tabs.
          // Single M3 expressive transition for the Active⇄History swap:
          // fade + a slight slide along the tab order (shared-axis feel).
          Expanded(
            child: AnimatedSwitcher(
              duration: appMotionDuration(context, AppMotion.medium),
              switchInCurve: AppMotion.emphasized,
              switchOutCurve: AppMotion.accelerate,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(_selectedIndex == 0 ? -0.08 : 0.08, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_selectedIndex),
                child: PlatformUtils.isAndroid
                    ? (_selectedIndex == 0
                          ? const _MobileActiveDownloadsView()
                          : const _MobileHistoryDownloadsView())
                    : (_selectedIndex == 0
                          ? const ActiveDownloadsTab()
                          : const HistoryDownloadsTab()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Downloads',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 32.0,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              if (PlatformUtils.isAndroid)
                IconButton(
                  icon: Icon(
                    Icons.home_outlined,
                    size: 22,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  tooltip: 'Home',
                  onPressed: () =>
                      context.read<NavigationProvider>().switchToHome(),
                ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.folder_open_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                onPressed: () async {
                  try {
                    final settingsProvider = context
                        .read<PlatformSettingsProvider>();
                    final outputPath =
                        settingsProvider.settings.outputPath ??
                        await settingsProvider.getDefaultOutputPath();

                    if (!context.mounted) return;

                    final dir = Directory(outputPath);
                    if (!await dir.exists()) {
                      await dir.create(recursive: true);
                    }

                    if (!context.mounted) return;

                    final opened = await FileActionService().openFolder(
                      outputPath,
                    );
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
                },
                tooltip: 'Open Downloads Folder',
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  if (value == 'clear_finished') {
                    if (PlatformUtils.isMobile) {
                      context.read<MobileDownloadProvider>().clearCompleted();
                      context.read<MobileDownloadProvider>().clearFailed();
                      context.read<MobileDownloadProvider>().clearCancelled();
                    } else {
                      context.read<DownloadProvider>().clearCompleted();
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'clear_finished',
                    child: Row(
                      children: [
                        Icon(
                          Icons.clear_all_rounded,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Clear Finished',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
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

  Widget _buildTabSegmentedControl() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    // Single selection capsule that glides between the two segments behind
    // the labels (M3 expressive indicator) — the labels just crossfade.
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: appMotionDuration(context, AppMotion.medium),
                curve: AppMotion.emphasized,
                left: _selectedIndex == 0 ? 0 : segmentWidth,
                width: segmentWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _buildSegmentLabel('Active', 0, isDark),
                  _buildSegmentLabel('History', 1, isDark),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSegmentLabel(String label, int index, bool isDark) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: AnimatedButton(
        onPressed: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: appMotionDuration(context, AppMotion.short),
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicators(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (PlatformUtils.isMobile) {
      final activeCount = context.select<MobileDownloadProvider, int>(
        (p) => p.activeDownloadsCount,
      );
      final doneCount = context.select<MobileDownloadProvider, int>(
        (p) => p.completedDownloads.length,
      );
      final failedCount = context.select<MobileDownloadProvider, int>(
        (p) => p.failedDownloads.length,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildMobileStatusIndicator(
              label: 'Active',
              count: activeCount,
              color: primaryColor,
            ),
            const SizedBox(width: 12),
            _buildMobileStatusIndicator(
              label: 'Done',
              count: doneCount,
              color: Colors.green,
            ),
            const SizedBox(width: 12),
            _buildMobileStatusIndicator(
              label: 'Failed',
              count: failedCount,
              color: Colors.red,
            ),
          ],
        ),
      );
    }

    final activeRunningCount = context.select<DownloadProvider, int>(
      (p) => p.activeRunningCount,
    );
    final pendingCount = context.select<DownloadProvider, int>(
      (p) => p.pendingCount,
    );
    final pausedCount = context.select<DownloadProvider, int>(
      (p) => p.pausedCount,
    );
    final completedCount = context.select<DownloadProvider, int>(
      (p) => p.completedCount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatusIndicator(
            context,
            label: 'Active',
            count: activeRunningCount,
            color: primaryColor,
            icon: Icons.downloading_rounded,
          ),
          const SizedBox(width: 12),
          _buildStatusIndicator(
            context,
            label: 'Pending',
            count: pendingCount,
            color: Colors.orange,
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(width: 12),
          _buildStatusIndicator(
            context,
            label: 'Paused',
            count: pausedCount,
            color: Colors.amber,
            icon: Icons.pause_circle_outline_rounded,
          ),
          const SizedBox(width: 12),
          _buildStatusIndicator(
            context,
            label: 'Done',
            count: completedCount,
            color: Colors.green,
            icon: Icons.check_circle_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileStatusIndicator({
    required String label,
    required int count,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Active tab isolated — selects only activeDownloads, rebuilds only this subtree on progress
class _MobileActiveDownloadsView extends StatelessWidget {
  const _MobileActiveDownloadsView();

  @override
  Widget build(BuildContext context) {
    final downloads = context
        .select<MobileDownloadProvider, List<DownloadItem>>(
          (p) => p.activeDownloads,
        );
    return Column(
      children: [
        const _OemBatteryGuidanceBanner(),
        Expanded(
          child: _buildMobileListShared(
            context,
            downloads,
            emptyTitle: 'No active downloads',
            emptySubtitle: 'Paste a URL to start!',
            emptyIcon: Icons.download_outlined,
            onAction: (item) =>
                context.read<MobileDownloadProvider>().cancelDownload(item.id),
            isHistory: false,
          ),
        ),
      ],
    );
  }
}

/// Dismissible banner shown on aggressive OEM devices (MIUI/HyperOS, ColorOS, etc.)
/// guiding user to grant Autostart / Unrestricted battery permissions.
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

    final theme = Theme.of(context);
    final rawManufacturer = settings.deviceManufacturer ?? 'device';
    final manufacturer = rawManufacturer.isNotEmpty
        ? '${rawManufacturer[0].toUpperCase()}${rawManufacturer.substring(1)}'
        : 'Device';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.battery_alert_rounded,
            color: theme.colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Background Downloads May Pause',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$manufacturer battery manager may stop background downloads. Tap to allow autostart.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
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
            icon: const Icon(Icons.close, size: 16),
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

/// History tab isolated — selects only completed+failed, rebuilds only this subtree
class _MobileHistoryDownloadsView extends StatelessWidget {
  const _MobileHistoryDownloadsView();

  @override
  Widget build(BuildContext context) {
    // Select counts first to minimize rebuilds when unrelated fields change;
    // then select lists — this widget is small, so combined list rebuild is cheap
    final completed = context
        .select<MobileDownloadProvider, List<DownloadItem>>(
          (p) => p.completedDownloads,
        );
    final failed = context.select<MobileDownloadProvider, List<DownloadItem>>(
      (p) => p.failedDownloads,
    );
    final downloads = [...completed, ...failed];
    return _buildMobileListShared(
      context,
      downloads,
      emptyTitle: 'No finished downloads yet',
      emptySubtitle: null,
      emptyIcon: Icons.history,
      onAction: (item) async =>
          context.read<MobileDownloadProvider>().removeDownload(item.id),
      isHistory: true,
    );
  }
}

Widget _buildMobileListShared(
  BuildContext context,
  List<DownloadItem> downloads, {
  required String emptyTitle,
  required String? emptySubtitle,
  required IconData emptyIcon,
  required Future<void> Function(DownloadItem item) onAction,
  required bool isHistory,
}) {
  if (downloads.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              emptyIcon,
              size: 56,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            emptyTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (emptySubtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  return ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    // ignore: deprecated_member_use
    cacheExtent: 600,
    itemCount: downloads.length,
    itemBuilder: (context, index) {
      final item = downloads[index];
      // No per-card entrance here: the view-level shared-axis transition on
      // the tab switch is the single motion for this screen.
      return isHistory
          ? CompletionPop.recent(
              item,
              child: _MobileDownloadItem(
                key: ValueKey(item.id),
                item: item,
                onDelete: () => onAction(item),
              ),
            )
          : CompletionPop(
              completed: item.status == DownloadStatus.completed,
              child: _MobileDownloadItem(
                key: ValueKey(item.id),
                item: item,
                onCancel: () => onAction(item),
                onPause: () {
                  context.read<MobileDownloadProvider>().pauseDownload(item.id);
                },
                onResume: () {
                  context.read<MobileDownloadProvider>().resumeDownload(
                    item.id,
                  );
                },
              ),
            );
    },
  );
}

typedef _MobileDownloadItem = MobileDownloadItem;

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
    final theme = Theme.of(context);
    final isActive =
        item.status == DownloadStatus.downloadingVideo ||
        item.status == DownloadStatus.downloadingAudio ||
        item.status == DownloadStatus.merging ||
        item.status == DownloadStatus.pending ||
        item.status == DownloadStatus.queued;
    final isPaused = item.status == DownloadStatus.paused;
    final isFailed = item.status == DownloadStatus.failed;
    final isCompleted = item.status == DownloadStatus.completed;

    final cardColor = theme.brightness == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : theme.colorScheme.surface;

    return AnimatedContainer(
      duration: appMotionDuration(context, AppMotion.short),
      curve: AppMotion.emphasized,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : theme.colorScheme.outline.withValues(alpha: 0.05),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isCompleted ? () => _handleOpenFile(context, item) : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 86,
                          height: 86,
                          child: _buildThumbnail(context),
                        ),
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
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.audioOnly
                                ? 'Audio Download'
                                : 'Video Download',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
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
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onPressed: onCancel,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (onDelete != null)
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(
                            isPaused
                                ? Colors.amber
                                : (item.status == DownloadStatus.merging
                                      ? Colors.orange
                                      : theme.colorScheme.primary),
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
                              '${(item.progress * 100).toStringAsFixed(1)}% ${item.totalBytes != null ? 'of ${_formatSize(item.totalBytes!)}' : ''}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: appMotionDuration(
                                context,
                                AppMotion.short,
                              ),
                              child: Text(
                                isPaused
                                    ? (item.statusText ?? 'Paused')
                                    : (item.speed > 0
                                          ? '${item.formattedSpeed} • ${item.eta > 0 ? 'ETA ${item.formattedEta}' : ''}'
                                          : (item.statusText ??
                                                'Processing...')),
                                key: ValueKey(
                                  isPaused
                                      ? 'paused-${item.statusText}'
                                      : '${item.speed}-${item.eta}-${item.statusText}',
                                ),
                                style: TextStyle(
                                  color: isPaused
                                      ? Colors.amber
                                      : theme.colorScheme.onSurfaceVariant,
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
                          onTap: isPaused
                              ? (onResume ?? () {})
                              : (onPause ?? () {}),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isPaused
                                          ? Colors.amber
                                          : theme.colorScheme.primary)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    (isPaused
                                            ? Colors.amber
                                            : theme.colorScheme.primary)
                                        .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPaused
                                      ? Icons.play_arrow_rounded
                                      : Icons.pause_rounded,
                                  size: 18,
                                  color: isPaused
                                      ? Colors.amber
                                      : theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isPaused ? 'Resume' : 'Pause',
                                  style: TextStyle(
                                    color: isPaused
                                        ? Colors.amber
                                        : theme.colorScheme.primary,
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
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (isCompleted) ...[
                        IconButton(
                          icon: Icon(
                            Icons.play_arrow_rounded,
                            color: theme.colorScheme.primary,
                            size: 22,
                          ),
                          tooltip: 'Open',
                          onPressed: () => _handleOpenFile(context, item),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: Icon(
                            Icons.share_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 18,
                          ),
                          tooltip: 'Share',
                          onPressed: () => _handleShareFile(context, item),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: Icon(
                            Icons.folder_open_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 19,
                          ),
                          tooltip: 'Show in folder',
                          onPressed: () => _handleOpenFolder(context, item),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                        ),
                        const SizedBox(width: 2),
                        PopupMenuButton<String>(
                          tooltip: 'More actions',
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 19,
                          ),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          onSelected: (value) {
                            switch (value) {
                              case 'open':
                                _handleOpenFile(context, item);
                                break;
                              case 'open_with':
                                _handleOpenFile(
                                  context,
                                  item,
                                  useChooser: true,
                                );
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
                                  Icon(Icons.play_arrow_rounded, size: 20),
                                  SizedBox(width: 12),
                                  Text('Open'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'open_with',
                              child: Row(
                                children: [
                                  Icon(Icons.open_in_new_rounded, size: 20),
                                  SizedBox(width: 12),
                                  Text('Open with...'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share_rounded, size: 20),
                                  SizedBox(width: 12),
                                  Text('Share'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'show_folder',
                              child: Row(
                                children: [
                                  Icon(Icons.folder_open_rounded, size: 20),
                                  SizedBox(width: 12),
                                  Text('Show in folder'),
                                ],
                              ),
                            ),
                            if (onDelete != null)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
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
                                    Icons.info_outline_rounded,
                                    size: 14,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      item.error!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
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
          ),
        ),
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
    final theme = Theme.of(context);
    final localPath = item.thumbnailPath;

    if (localPath != null && item.thumbnailExists) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        cacheWidth: 256,
        errorBuilder: (_, __, ___) => _buildThumbnailFallback(theme),
      );
    }

    if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        item.thumbnailUrl!,
        fit: BoxFit.cover,
        cacheWidth: 256,
        errorBuilder: (_, __, ___) => _buildThumbnailFallback(theme),
      );
    }

    return _buildThumbnailFallback(theme);
  }

  Widget _buildThumbnailFallback(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        item.audioOnly ? Icons.music_note_rounded : Icons.movie_rounded,
        color: theme.colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final theme = Theme.of(context);

    Color color;
    String text;
    IconData icon;

    switch (item.status) {
      case DownloadStatus.pending:
        color = theme.colorScheme.outline;
        text = 'Pending';
        icon = Icons.schedule_rounded;
        break;
      case DownloadStatus.queued:
        color = Colors.orange;
        text = 'Queued';
        icon = Icons.queue_rounded;
        break;
      case DownloadStatus.downloadingVideo:
        color = theme.colorScheme.primary;
        text = 'Video';
        icon = Icons.videocam_rounded;
        break;
      case DownloadStatus.downloadingAudio:
        color = Colors.amber;
        text = 'Audio';
        icon = Icons.music_note_rounded;
        break;
      case DownloadStatus.merging:
        color = Colors.orange;
        text = 'Merging';
        icon = Icons.merge_rounded;
        break;
      case DownloadStatus.completed:
        color = Colors.green;
        text = 'Done';
        icon = Icons.check_circle_rounded;
        break;
      case DownloadStatus.failed:
        color = theme.colorScheme.error;
        text = 'Failed';
        icon = Icons.error_rounded;
        break;
      case DownloadStatus.cancelled:
        color = theme.colorScheme.outline;
        text = 'Cancelled';
        icon = Icons.cancel_rounded;
        break;
      case DownloadStatus.paused:
        color = Colors.amber;
        text = 'Paused';
        icon = Icons.pause_circle_outline_rounded;
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
