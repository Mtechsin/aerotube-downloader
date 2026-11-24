import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/typography.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/platform_settings_provider.dart';

/// Redesigned Desktop Top Strip matching redesign spec 6.3:
/// - 48 px transparent window drag area.
/// - Left: Breadcrumb / Page Title (e.g. "AeroTube / Home").
/// - Right: Global StatusPill cluster (yt-dlp, ffmpeg, account/cookies) replacing floating stack.
class AeroDesktopTopStrip extends StatelessWidget {
  final int currentIndex;

  const AeroDesktopTopStrip({super.key, required this.currentIndex});

  String _getPageTitle() {
    switch (currentIndex) {
      case 0:
        return 'Home';
      case 1:
        return 'Search';
      case 2:
        return 'Library';
      case 3:
        return 'Settings';
      default:
        return 'Home';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final sp = context.watch<PlatformSettingsProvider>();
    final nav = context.read<NavigationProvider>();

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.outline, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Breadcrumb / Page Title on left
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AeroTube',
                style: AeroText.caption.copyWith(
                  color: colors.onSurfaceFaint,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '/',
                  style: AeroText.caption.copyWith(
                    color: colors.onSurfaceFaint,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                _getPageTitle(),
                style: AeroText.caption.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const Spacer(),
          _buildReadiness(context, sp, nav),
        ],
      ),
    );
  }

  Widget _buildReadiness(
    BuildContext context,
    PlatformSettingsProvider settings,
    NavigationProvider navigation,
  ) {
    final colors = context.aero;
    final checking = !settings.isInitialized || !settings.hasCheckedTools;
    final missingDownloader = !checking && !settings.isYtdlpAvailable;
    final missingConverter = !checking && !settings.isFfmpegAvailable;
    final label = checking
        ? 'Checking tools'
        : missingDownloader
        ? 'Set up downloader'
        : missingConverter
        ? 'Set up converter'
        : 'Ready';
    final tone = checking
        ? colors.onSurfaceMuted
        : missingDownloader
        ? colors.danger
        : missingConverter
        ? colors.warning
        : colors.success;
    return Tooltip(
      message: checking
          ? 'Checking download tools'
          : 'Downloader: ${settings.ytdlpVersion ?? "unavailable"}\nConverter: ${settings.ffmpegVersion ?? "unavailable"}',
      child: TextButton.icon(
        onPressed: navigation.switchToSettings,
        icon: Icon(
          checking ? Symbols.more_horiz_rounded : Symbols.circle_rounded,
          size: checking ? 16 : 6,
          color: tone,
        ),
        label: Text(label, style: AeroText.caption.copyWith(color: tone)),
      ),
    );
  }
}
