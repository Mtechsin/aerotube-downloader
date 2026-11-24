import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/update_provider.dart';
import '../components/aero_button.dart';
import '../components/aero_chip.dart';
import '../components/aero_density.dart';
import '../components/aero_dialog.dart';
import '../components/aero_progress.dart';

/// Aero-styled update modal dialog.
///
/// Features (redesign_spec 7.7):
/// - Wrapped in [AeroDialog] (24 px radius xl, surface1, hairline outline).
/// - Version chip, 3 bullet changelog, Update now / Later actions.
/// - Inline download progress using [AeroProgress].
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UpdateProvider>(
      builder: (context, updateProvider, child) {
        return _buildContent(context, updateProvider);
      },
    );
  }

  Widget _buildContent(BuildContext context, UpdateProvider provider) {
    final colors = context.aero;

    switch (provider.status) {
      case UpdateStatus.checking:
        return _buildCheckingState(context, colors);
      case UpdateStatus.available:
        return _buildAvailableState(context, provider, colors);
      case UpdateStatus.downloading:
        return _buildDownloadingState(context, provider, colors);
      case UpdateStatus.readyToInstall:
        return _buildReadyToInstallState(context, provider, colors);
      case UpdateStatus.needsInstallPermission:
        return _buildNeedsInstallPermissionState(context, provider, colors);
      case UpdateStatus.upToDate:
        return _buildUpToDateState(context, colors);
      case UpdateStatus.error:
        return _buildErrorState(context, provider, colors);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCheckingState(BuildContext context, AeroColors colors) {
    return AeroDialog(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Icon(Symbols.sync_rounded, size: 20, color: colors.primary),
      ),
      titleText: 'Checking for Updates',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Checking GitHub for the latest AeroTube release…',
            style: AeroText.body.copyWith(color: colors.onSurfaceMuted),
          ),
          const SizedBox(height: AeroSpace.lg),
          const AeroProgress(value: null),
        ],
      ),
      actions: [
        AeroButton(
          variant: AeroButtonVariant.ghost,
          text: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _buildAvailableState(
    BuildContext context,
    UpdateProvider provider,
    AeroColors colors,
  ) {
    final updateInfo = provider.updateInfo!;
    final bullets = _extractChangelogBullets(updateInfo.releaseNotes);

    return AeroDialog(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Symbols.system_update_rounded,
          size: 20,
          color: colors.primary,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Update Available',
              style: AeroText.title.copyWith(color: colors.onSurface),
            ),
          ),
          AeroChip(
            text: 'v${updateInfo.version}',
            density: AeroDensity.compact,
            selected: true,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (updateInfo.assetSize != null) ...[
            Text(
              'Download size: ${_formatFileSize(updateInfo.assetSize!)}',
              style: AeroText.caption.copyWith(color: colors.onSurfaceMuted),
            ),
            const SizedBox(height: AeroSpace.md),
          ],
          Text(
            "What's New",
            style: AeroText.label.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AeroSpace.sm),
          Container(
            padding: const EdgeInsets.all(AeroSpace.md),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: AeroRadius.mdBorderRadius,
              border: Border.all(color: colors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < bullets.length; i++) ...[
                  if (i > 0) const SizedBox(height: AeroSpace.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6, right: 10),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          bullets[i],
                          style: AeroText.bodySm.copyWith(
                            color: colors.onSurface,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        AeroButton(
          variant: AeroButtonVariant.ghost,
          text: 'Later',
          onPressed: () {
            provider.skipUpdate();
            Navigator.of(context).pop();
          },
        ),
        AeroButton(
          variant: AeroButtonVariant.primary,
          text: 'Update now',
          icon: const Icon(Symbols.download_rounded, size: 18),
          onPressed: () => provider.downloadUpdate(),
        ),
      ],
    );
  }

  Widget _buildDownloadingState(
    BuildContext context,
    UpdateProvider provider,
    AeroColors colors,
  ) {
    final progress = (provider.downloadProgress * 100).toInt();
    final sizeLabel = provider.updateInfo?.assetSize != null
        ? _formatFileSize(provider.updateInfo!.assetSize!)
        : null;
    final receivedLabel = sizeLabel != null
        ? _formatFileSize(
            (provider.updateInfo!.assetSize! * provider.downloadProgress)
                .round(),
          )
        : null;

    final subtitle = sizeLabel != null && receivedLabel != null
        ? '$receivedLabel of $sizeLabel'
        : 'Downloading in background…';

    return AeroDialog(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Symbols.downloading_rounded,
          size: 20,
          color: colors.primary,
        ),
      ),
      titleText: 'Downloading Update',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subtitle,
                style: AeroText.bodySm.copyWith(color: colors.onSurfaceMuted),
              ),
              Text(
                '$progress%',
                style: AeroText.label.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AeroSpace.sm),
          AeroProgress(value: provider.downloadProgress),
        ],
      ),
      actions: [
        AeroButton(
          variant: AeroButtonVariant.danger,
          text: 'Cancel Download',
          onPressed: () => provider.cancelDownload(),
        ),
      ],
    );
  }

  Widget _buildReadyToInstallState(
    BuildContext context,
    UpdateProvider provider,
    AeroColors colors,
  ) {
    final isAndroid = PlatformUtils.isAndroid;

    return AeroDialog(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Symbols.check_circle_rounded,
          size: 20,
          color: colors.success,
        ),
      ),
      titleText: 'Update Ready',
      content: Text(
        isAndroid
            ? 'Tap Install to open the system package installer. Your downloads and settings stay intact.'
            : 'The update is ready to install. AeroTube will restart automatically.',
        style: AeroText.body.copyWith(color: colors.onSurfaceMuted),
      ),
      actions: [
        AeroButton(
          variant: AeroButtonVariant.ghost,
          text: 'Later',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AeroButton(
          variant: AeroButtonVariant.primary,
          text: isAndroid ? 'Install' : 'Install & Restart',
          icon: Icon(
            isAndroid
                ? Symbols.install_mobile_rounded
                : Symbols.install_desktop_rounded,
            size: 18,
          ),
          onPressed: () => provider.installUpdate(),
        ),
      ],
    );
  }

  Widget _buildNeedsInstallPermissionState(
    BuildContext context,
    UpdateProvider provider,
    AeroColors colors,
  ) {
    return AeroDialog(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.warning.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(Symbols.security_rounded, size: 20, color: colors.warning),
      ),
      titleText: 'Permission Needed',
      content: Text(
        'Android blocked the install because "Install unknown apps" is off for AeroTube.\n\nEnable it in system settings, return here, then tap Install.',
        style: AeroText.body.copyWith(color: colors.onSurfaceMuted),
      ),
      actions: [
        AeroButton(
          variant: AeroButtonVariant.ghost,
          text: 'Later',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AeroButton(
          variant: AeroButtonVariant.primary,
          text: 'Open Settings',
          icon: const Icon(Symbols.settings_rounded, size: 18),
          onPressed: () async {
            final granted = await provider.openInstallSettings();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  granted
                      ? 'Permission granted — tap Install to continue.'
                      : 'After enabling the toggle, return and tap Install.',
                ),
              ),
            );
            await provider.refreshInstallPermission();
          },
        ),
      ],
    );
  }

  Widget _buildUpToDateState(BuildContext context, AeroColors colors) {
    return AeroDialog(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Symbols.check_circle_rounded,
          size: 20,
          color: colors.success,
        ),
      ),
      titleText: "You're Up to Date",
      content: Text(
        'You have the latest version of AeroTube Downloader installed.',
        style: AeroText.body.copyWith(color: colors.onSurfaceMuted),
      ),
      actions: [
        AeroButton(
          variant: AeroButtonVariant.primary,
          text: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    UpdateProvider provider,
    AeroColors colors,
  ) {
    return AeroDialog(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(Symbols.error_rounded, size: 20, color: colors.danger),
      ),
      titleText: 'Update Failed',
      content: Text(
        provider.errorMessage ??
            'An unexpected error occurred while checking for updates.',
        style: AeroText.body.copyWith(color: colors.onSurfaceMuted),
      ),
      actions: [
        AeroButton(
          variant: AeroButtonVariant.ghost,
          text: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AeroButton(
          variant: AeroButtonVariant.primary,
          text: 'Try Again',
          icon: const Icon(Symbols.refresh_rounded, size: 18),
          onPressed: () {
            provider.reset();
            provider.checkForUpdates();
          },
        ),
      ],
    );
  }

  List<String> _extractChangelogBullets(String releaseNotes) {
    final lines = releaseNotes
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map((line) => line.replaceFirst(RegExp(r'^[-*•]\s*'), ''))
        .where((line) => line.isNotEmpty)
        .take(3)
        .toList();

    if (lines.isEmpty) {
      return const [
        'Engine stability and compatibility improvements.',
        'Updated YouTube format extractors.',
        'Refined interface and performance enhancements.',
      ];
    }
    return lines;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// Extension to show the update dialog
extension UpdateDialogExtension on BuildContext {
  Future<void> showUpdateDialog() async {
    await showAeroDialog<void>(
      context: this,
      barrierDismissible: false,
      builder: (context) => const UpdateDialog(),
    );
  }
}
