import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/video_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/mobile_download_provider.dart';
import '../../core/utils/platform_utils.dart';
import 'package:flutter/services.dart';

class MobileShell extends StatefulWidget {
  final List<Widget> screens;

  const MobileShell({super.key, required this.screens});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (navigationProvider.currentIndex != 0) {
          navigationProvider.setIndex(0);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: IndexedStack(
          index: navigationProvider.currentIndex,
          children: widget.screens,
        ),
        bottomNavigationBar: _buildBottomNavBar(
          context,
          theme,
          navigationProvider,
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(
    BuildContext context,
    ThemeData theme,
    NavigationProvider navProvider,
  ) {
    final activeDownloads = PlatformUtils.isAndroid
        ? context.watch<MobileDownloadProvider>().activeDownloadsCount
        : context.watch<DownloadProvider>().activeCount;

    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.scaffoldBackgroundColor;
    final isDark = theme.brightness == Brightness.dark;
    final systemBottomInset = MediaQuery.of(context).viewPadding.bottom;
    final bottomSpacing = PlatformUtils.isAndroid ? 2.0 : 6.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomSpacing + systemBottomInset,
      ),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.14),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: navProvider.currentIndex == 0,
                  color: primaryColor,
                  onTap: () => navProvider.setIndex(0),
                ),
                _NavItem(
                  icon: Icons.search_outlined,
                  activeIcon: Icons.search_rounded,
                  label: 'Search',
                  isSelected: navProvider.currentIndex == 1,
                  color: primaryColor,
                  onTap: () => navProvider.setIndex(1),
                ),
                _NavItem(
                  icon: Icons.download_outlined,
                  activeIcon: Icons.download_rounded,
                  label: 'Files',
                  isSelected: navProvider.currentIndex == 2,
                  color: primaryColor,
                  badge: activeDownloads > 0 ? activeDownloads : null,
                  onTap: () => navProvider.setIndex(2),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: navProvider.currentIndex == 3,
                  color: primaryColor,
                  onTap: () => navProvider.setIndex(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final Color color;
  final int? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconScale = widget.isSelected ? 1.04 : 1.0;
    final iconOffsetY = widget.isSelected ? -1.0 : 0.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSlide(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  offset: Offset(0, iconOffsetY / 24),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    scale: iconScale,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? widget.color.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.isSelected ? widget.activeIcon : widget.icon,
                        color: widget.isSelected ? widget.color : textColor,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                if (widget.badge != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        widget.badge! > 9 ? '9+' : '${widget.badge}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 10,
                fontWeight: widget.isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isDark
                    ? Colors.white
                    : (widget.isSelected ? Colors.black : Colors.black87),
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MobileHomeLayout extends StatefulWidget {
  const MobileHomeLayout({super.key});

  @override
  State<MobileHomeLayout> createState() => _MobileHomeLayoutState();
}

class _MobileHomeLayoutState extends State<MobileHomeLayout> {
  final TextEditingController _urlController = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _urlController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_onTextChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _handleProcess(VideoProvider videoProvider) {
    final url = _urlController.text.trim();
    if (url.isEmpty || videoProvider.isLoading) {
      return;
    }

    videoProvider.fetchVideoInfo(url);
  }

  void _clearUrl() {
    _urlController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final videoProvider = context.watch<VideoProvider>();

    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = theme.colorScheme.onSurface;
    final hintColor = isDark ? Colors.grey.shade500 : Colors.grey.shade500;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              'AeroTube',
              style: TextStyle(
                color: textColor,
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 8.0),
            Text(
              'Paste a link to download',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 15.0,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 300.ms, delay: 50.ms),
            const SizedBox(height: 32.0),
            _buildUrlInput(
              videoProvider,
              primaryColor,
              surfaceColor,
              textColor,
              hintColor,
              isDark,
            ),
            if (videoProvider.hasVideo ||
                videoProvider.hasPlaylist ||
                videoProvider.isLoading) ...[
              const SizedBox(height: 28.0),
              if (videoProvider.hasError)
                _buildErrorCard(videoProvider, isDark)
              else
                _buildVideoPreview(
                  context,
                  videoProvider,
                  surfaceColor,
                  primaryColor,
                  textColor,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withValues(alpha: 0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutCubic);
  }

  Widget _buildUrlInput(
    VideoProvider videoProvider,
    Color primaryColor,
    Color surfaceColor,
    Color textColor,
    Color hintColor,
    bool isDark,
  ) {
    final isLoading = videoProvider.isLoading;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _urlController,
              style: TextStyle(color: textColor, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Paste YouTube link...',
                hintStyle: TextStyle(color: hintColor, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 16,
                ),
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _handleProcess(videoProvider),
            ),
          ),
          _buildGoButton(primaryColor, isLoading),
          const SizedBox(width: 12),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms, delay: 100.ms);
  }

  Widget _buildGoButton(Color primaryColor, bool isLoading) {
    if (isLoading) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
        ),
      );
    }

    return GestureDetector(
      onTap: _hasText
          ? () => _handleProcess(context.read<VideoProvider>())
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _hasText ? primaryColor : primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.arrow_forward_rounded,
          color: _hasText ? Colors.white : primaryColor.withValues(alpha: 0.3),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildErrorCard(VideoProvider videoProvider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              videoProvider.errorMessage ?? 'Error loading video',
              style: TextStyle(
                color: isDark ? Colors.red.shade300 : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview(
    BuildContext context,
    VideoProvider videoProvider,
    Color surfaceColor,
    Color primaryColor,
    Color textColor,
  ) {
    if (videoProvider.isLoading) {
      return Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 16),
            Text(
              videoProvider.loadingStatus,
              style: TextStyle(color: textColor.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (videoProvider.hasVideo && videoProvider.videoInfo != null) {
      final video = videoProvider.videoInfo!;
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.play_circle_outline, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Duration: ${_formatDuration(video.duration)}',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (video.formats.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${video.formats.length} formats available',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showFormatSelection(context),
                  icon: const Icon(Icons.high_quality, size: 18),
                  label: const Text('Select Format'),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (videoProvider.hasPlaylist && videoProvider.playlistInfo != null) {
      final playlist = videoProvider.playlistInfo!;
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.playlist_play, color: primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.videoCount} videos',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showFormatSelection(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Format selection coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  Widget _buildAppBar(BuildContext context, bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                context.read<NavigationProvider>().setIndex(1);
              },
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: textColor.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Search...',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.5),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'AeroTube',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: textColor.withValues(alpha: 0.7),
            ),
            onPressed: () {
              context.read<NavigationProvider>().setIndex(3);
            },
          ),
        ],
      ),
    );
  }
}
