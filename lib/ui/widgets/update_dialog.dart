import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:youtube_downloader/providers/update_provider.dart';
import 'package:youtube_downloader/providers/platform_settings_provider.dart';
import 'package:youtube_downloader/core/utils/platform_utils.dart';

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final enableAnimations = context.select<PlatformSettingsProvider, bool>(
      (p) => p.enableAnimations,
    );

    return Consumer<UpdateProvider>(
      builder: (context, updateProvider, child) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: _buildContent(context, updateProvider, enableAnimations),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    UpdateProvider provider,
    bool enableAnimations,
  ) {
    switch (provider.status) {
      case UpdateStatus.checking:
        return _buildCheckingState(context, enableAnimations);
      case UpdateStatus.available:
        return _buildAvailableState(context, provider, enableAnimations);
      case UpdateStatus.downloading:
        return _buildDownloadingState(context, provider, enableAnimations);
      case UpdateStatus.readyToInstall:
        return _buildReadyToInstallState(context, provider, enableAnimations);
      case UpdateStatus.needsInstallPermission:
        return _buildNeedsInstallPermissionState(
          context,
          provider,
          enableAnimations,
        );
      case UpdateStatus.upToDate:
        return _buildUpToDateState(context, enableAnimations);
      case UpdateStatus.error:
        return _buildErrorState(context, provider, enableAnimations);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCheckingState(BuildContext context, bool enableAnimations) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Checking for Updates',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we check for the latest version...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: enableAnimations ? 300.ms : Duration.zero);
  }

  Widget _buildAvailableState(
    BuildContext context,
    UpdateProvider provider,
    bool enableAnimations,
  ) {
    final theme = Theme.of(context);
    final updateInfo = provider.updateInfo!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.2),
                theme.colorScheme.primary.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Update Available!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version ${updateInfo.version}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (updateInfo.assetSize != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Size: ${_formatFileSize(updateInfo.assetSize!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Release Notes
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What\'s New:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    updateInfo.releaseNotes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Actions
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    provider.skipUpdate();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Later'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => provider.downloadUpdate(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_rounded),
                      SizedBox(width: 8),
                      Text(
                        'Download Update',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: enableAnimations ? 300.ms : Duration.zero).slideY(begin: enableAnimations ? 0.1 : 0, end: 0);
  }

  Widget _buildDownloadingState(
    BuildContext context,
    UpdateProvider provider,
    bool enableAnimations,
  ) {
    final theme = Theme.of(context);
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

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: provider.downloadProgress,
                  strokeWidth: 6,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                '$progress%',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Downloading Update',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sizeLabel != null && receivedLabel != null
                ? '$receivedLabel of $sizeLabel'
                : 'Please don\'t close the application',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: provider.downloadProgress,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            color: theme.colorScheme.primary,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => provider.cancelDownload(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel Download'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: enableAnimations ? 300.ms : Duration.zero);
  }

  Widget _buildReadyToInstallState(
    BuildContext context,
    UpdateProvider provider,
    bool enableAnimations,
  ) {
    final theme = Theme.of(context);
    final isAndroid = PlatformUtils.isAndroid;

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 48,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Download Complete!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAndroid
                ? 'Tap Install to open the system installer. Your data stays intact.'
                : 'The update is ready to install. The application will restart automatically.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => provider.installUpdate(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAndroid
                      ? Icons.install_mobile_rounded
                      : Icons.install_desktop_rounded,
                ),
                const SizedBox(width: 8),
                Text(
                  isAndroid ? 'Install Update' : 'Install & Restart',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: enableAnimations ? 300.ms : Duration.zero);
  }

  Widget _buildNeedsInstallPermissionState(
    BuildContext context,
    UpdateProvider provider,
    bool enableAnimations,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.install_mobile_rounded,
              size: 48,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Permission Needed',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Android blocked the install because "Install unknown apps" is off for AeroTube.\n\nEnable it in system settings, return here, then tap Install again. Your downloaded update is kept.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
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
              // Re-check in case the native result arrived via onResume.
              await provider.refreshInstallPermission();
            },
            icon: const Icon(Icons.settings_rounded),
            label: const Text(
              'Open Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () async {
                  final granted = await provider.refreshInstallPermission();
                  if (!context.mounted) return;
                  if (granted) {
                    await provider.installUpdate();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Still blocked — enable "Allow from this source" first.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('I enabled it — Retry'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: enableAnimations ? 300.ms : Duration.zero);
  }

  Widget _buildUpToDateState(BuildContext context, bool enableAnimations) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'You\'re Up to Date!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have the latest version of AeroTube Downloader.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Great!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: enableAnimations ? 300.ms : Duration.zero);
  }

  Widget _buildErrorState(
    BuildContext context,
    UpdateProvider provider,
    bool enableAnimations,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Update Failed',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.errorMessage ?? 'An unexpected error occurred',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  provider.reset();
                  provider.checkForUpdates();
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: enableAnimations ? 300.ms : Duration.zero);
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
    return showDialog(
      context: this,
      barrierDismissible: false,
      builder: (context) => const UpdateDialog(),
    );
  }
}
