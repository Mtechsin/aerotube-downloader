import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/download_mode.dart';
import '../../providers/video_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../models/video_info.dart';
import '../widgets/video_configuration_widget.dart';
import '../widgets/url_input_card.dart';
import 'playlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController = TextEditingController();
  VideoProvider? _videoProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videoProvider = context.read<VideoProvider>();
      _videoProvider!.addListener(_onVideoProviderChange);
    });
  }

  @override
  void dispose() {
    _videoProvider?.removeListener(_onVideoProviderChange);
    _urlController.dispose();
    super.dispose();
  }

  void _onVideoProviderChange() {
    if (_videoProvider == null) return;
    if (_videoProvider!.hasError && 
        (_videoProvider!.errorMessage!.contains('Authentication') || 
         _videoProvider!.errorMessage!.contains('cookies.txt'))) {
      _showAuthErrorDialog(_videoProvider!.errorMessage!);
    }
  }

  void _showAuthErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_person_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Authentication Required'),
          ],
        ),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final videoProvider = context.watch<VideoProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    return Stack(
      children: [
        // Content Area
        Positioned.fill(
          top: 100, // Leave space for the floating capsule
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 // Warning Banners
                 if (!settingsProvider.isInitialized)
                    _buildWarningBanner(
                    context,
                    'Initializing...',
                    'Setting up necessary tools. This may take a moment.',
                    Icons.hourglass_empty_rounded,
                    isError: false,
                  )
                else if (!settingsProvider.isYtdlpAvailable)
                  _buildWarningBanner(
                    context,
                    'yt-dlp not found',
                    'Please install yt-dlp or configure its path in Settings.',
                    Icons.warning_amber_rounded,
                  ),
                
                if (settingsProvider.isInitialized && !settingsProvider.isFfmpegAvailable)
                  _buildWarningBanner(
                    context,
                    'FFmpeg not found',
                    'Some features may not work. Configure FFmpeg path in Settings.',
                    Icons.info_outline_rounded,
                    isError: false,
                  ),

                const SizedBox(height: 16),

                // Loaded State OR Empty State
                if (videoProvider.hasVideo || videoProvider.isLoading)
                  VideoConfigurationWidget(
                    onDownload: _startDownload,
                    onClear: () {
                      videoProvider.clear();
                      _urlController.clear();
                    },
                  )
                else if (!videoProvider.isLoading && !videoProvider.hasError)
                  _buildHeroEmptyState(context, videoProvider),
                  
                // Show loading or error within content area if needed, 
                // though UrlInputCard often handles small feedback.
              ],
            ),
          ),
        ),

        // Floating Command Capsule (Top)
        Positioned(
          top: 24,
          left: 24,
          right: 24,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCommandCapsule(context, videoProvider),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildCommandCapsule(BuildContext context, VideoProvider videoProvider) {
    return UrlInputCard(
      controller: _urlController,
      onFetch: () => _handleFetch(videoProvider),
      isLoading: videoProvider.isLoading,
      statusMessage: videoProvider.loadingStatus.isEmpty ? null : videoProvider.loadingStatus,
      errorMessage: videoProvider.hasError ? videoProvider.errorMessage : null,
    ).animate().slideY(begin: -1, curve: Curves.easeOutBack, duration: 600.ms);
  }

  Widget _buildHeroEmptyState(BuildContext context, VideoProvider videoProvider) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.only(top: 80),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
           Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surface,
              boxShadow: [
                 BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.download_done_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scale(begin: const Offset(1,1), end: const Offset(1.02, 1.02), duration: 3000.ms, curve: Curves.easeInOut),
           
           const SizedBox(height: 32),
           
           Text(
             'Ready to Download',
             style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
           ),
           
           const SizedBox(height: 12),
           
           Text(
             'Paste a link to start downloading videos or music',
             style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
           ),
           
           const SizedBox(height: 48),
           
           // Options Row
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               _buildOptionChip(context, 'Up to 4K', true, Icons.four_k_rounded),
               const SizedBox(width: 12),
               _buildOptionChip(context, 'Audio Only', videoProvider.audioOnly, Icons.audiotrack_rounded, onTap: () {
                 // For UI demo purposes, in real app needs provider update
               }),
               const SizedBox(width: 12),
               _buildOptionChip(context, 'Cookies', false, Icons.cookie_outlined),
             ],
           ),
        ],
      ),
    );
  }
  
  Widget _buildOptionChip(BuildContext context, String label, bool isActive, IconData icon, {VoidCallback? onTap}) {
     final theme = Theme.of(context);
     return InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.5) : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                label, 
                style: TextStyle(
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
     );
  }

  Future<void> _handleFetch(VideoProvider videoProvider) async {
    final url = _urlController.text;
    if (url.isEmpty) return;

    if (url.contains('list=') || url.contains('/playlist')) {
      // Use PlaylistProvider
      if (mounted) {
        context.read<PlaylistProvider>().fetchPlaylist(url);
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlaylistScreen()),
        );
      }
    } else {
      videoProvider.fetchVideoInfo(url);
    }
  }

  // Helper methods like _buildWarningBanner, _startDownload need to remain or be copied if they were inside.
  // Assuming they are preserved if I target correctly.
  
  Widget _buildWarningBanner(
    BuildContext context,
    String title,
    String message,
    IconData icon, {
    bool isError = true,
  }) {
    final theme = Theme.of(context);
    final color = isError ? theme.colorScheme.error : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload() async {
    final videoProvider = context.read<VideoProvider>();
    final downloadProvider = context.read<DownloadProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    if (videoProvider.videoInfo == null) return;

    final outputPath = settingsProvider.settings.outputPath ?? 
        '${Platform.environment['USERPROFILE']}\\Downloads';

    // Ensure output directory exists
    final dir = Directory(outputPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    downloadProvider.startDownload(
      video: videoProvider.videoInfo!,
      outputPath: outputPath,
      mode: videoProvider.audioOnly 
          ? DownloadMode.audioOnly 
          : DownloadMode.videoWithAudio,
      formatId: videoProvider.selectedVideoFormatId,
      audioFormatId: videoProvider.selectedAudioFormatId,
      targetHeight: videoProvider.selectedHeight,
      audioQuality: videoProvider.selectedAudioQuality.ytdlpValue,
      embedThumbnail: settingsProvider.settings.embedThumbnail,
      embedMetadata: settingsProvider.settings.embedMetadata,
    );

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Download started: ${videoProvider.videoInfo!.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Navigate to downloads tab
          },
        ),
      ),
    );

    // Clear the form
    videoProvider.clear();
    _urlController.clear();
  }
}

// Remove unnecessary classes if they were inline

