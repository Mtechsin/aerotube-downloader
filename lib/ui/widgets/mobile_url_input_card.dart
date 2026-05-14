import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../core/utils/error_helper.dart';

/// Mobile-optimized URL input card — minimalist single-row layout
class MobileUrlInputCard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onFetch;
  final bool isLoading;
  final String? statusMessage;
  final String? errorMessage;

  const MobileUrlInputCard({
    super.key,
    required this.controller,
    required this.onFetch,
    this.isLoading = false,
    this.errorMessage,
    this.statusMessage,
  });

  @override
  State<MobileUrlInputCard> createState() => _MobileUrlInputCardState();
}

class _MobileUrlInputCardState extends State<MobileUrlInputCard> {
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();
  String? _clipboardYoutubeUrl;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _checkClipboard();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      final isYouTube = text.contains('youtube.com/') ||
          text.contains('youtu.be/') ||
          text.contains('youtube.com/shorts/') ||
          text.contains('music.youtube.com/');
      if (mounted) {
        setState(() {
          _clipboardYoutubeUrl = isYouTube ? text : null;
        });
      }
    } catch (_) {
      // clipboard unavailable — ignore
    }
  }

  void _pasteClipboardUrl() {
    if (_clipboardYoutubeUrl != null) {
      widget.controller.text = _clipboardYoutubeUrl!;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorMessage != null;
    final errorHelper = hasError ? ErrorHelper.parse(widget.errorMessage!) : null;

    final enableAnimations = context.select<PlatformSettingsProvider, bool>(
      (p) => p.enableAnimations,
    );
    final isCookieActive = context.select<PlatformSettingsProvider, bool>(
      (p) => p.isCookieActive,
    );
    final isYouTubeLoggedIn = context.select<PlatformSettingsProvider, bool>(
      (p) => p.isYouTubeLoggedIn,
    );
    final cookieStatus = context.select<PlatformSettingsProvider, String>(
      (p) => p.cookieStatus,
    );

    final animDuration =
        enableAnimations ? const Duration(milliseconds: 300) : Duration.zero;
    final shortAnimDuration =
        enableAnimations ? const Duration(milliseconds: 200) : Duration.zero;

    // Border styling
    final Color borderColor = hasError
        ? theme.colorScheme.error.withValues(alpha: 0.55)
        : _isFocused
            ? theme.colorScheme.primary.withValues(alpha: 0.45)
            : theme.colorScheme.onSurface.withValues(alpha: 0.15);
    final double borderWidth = hasError
        ? 1.4
        : _isFocused
            ? 1.4
            : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Main Input Card ──────────────────────────────────────────
        AnimatedContainer(
          duration: shortAnimDuration,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 16),
                // Text Input
                Expanded(
                  child: Focus(
                    focusNode: _focusNode,
                    onFocusChange: (focused) {
                      setState(() => _isFocused = focused);
                      if (focused) _checkClipboard();
                    },
                    child: TextField(
                      controller: widget.controller,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Paste YouTube URL...',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.35),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (widget.controller.text.isNotEmpty) {
                          widget.onFetch();
                        }
                      },
                    ),
                  ),
                ),
                // Clear Button — only when text present
                if (widget.controller.text.isNotEmpty)
                  _iconBtn(
                    icon: Icons.clear_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    size: 18,
                    onTap: () {
                      widget.controller.clear();
                      setState(() {});
                    },
                  ),
                // Fetch Arrow Button
                _iconBtn(
                  icon: Icons.arrow_forward_rounded,
                  color: widget.controller.text.isEmpty
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.22)
                      : theme.colorScheme.primary,
                  size: 22,
                  onTap: widget.isLoading || widget.controller.text.isEmpty
                      ? null
                      : widget.onFetch,
                  loading: widget.isLoading,
                  loadingColor: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),

        // ── Paste YouTube URL pill ───────────────────────────────────
        if (_clipboardYoutubeUrl != null &&
            widget.controller.text != _clipboardYoutubeUrl)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: _pasteClipboardUrl,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.18),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.content_paste_rounded,
                      size: 13,
                      color: theme.colorScheme.primary.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Paste copied URL',
                      style: TextStyle(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: animDuration).slideY(
                begin: -0.15,
                end: 0,
                curve: Curves.easeOut,
                duration: animDuration,
              ),

        // ── Cookie / Auth indicator ──────────────────────────────────
        if (isCookieActive)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isYouTubeLoggedIn
                        ? Colors.green.withValues(alpha: 0.8)
                        : Colors.orange.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  cookieStatus,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

        // ── Error Message ────────────────────────────────────────────
        if (hasError && errorHelper != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: theme.colorScheme.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        errorHelper.friendlyMessage,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (errorHelper.suggestion != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          errorHelper.suggestion!,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: animDuration)
              .slideY(
                  begin: -0.2,
                  end: 0,
                  curve: Curves.easeOut,
                  duration: animDuration),

        // ── Loading Status ───────────────────────────────────────────
        if (widget.isLoading && widget.statusMessage != null)
          _buildLoadingStatus(theme, widget.statusMessage!, shortAnimDuration),
      ],
    );
  }

  /// Small square icon button helper
  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required double size,
    VoidCallback? onTap,
    bool loading = false,
    Color? loadingColor,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        icon: loading
            ? SizedBox(
                width: size - 4,
                height: size - 4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: loadingColor,
                ),
              )
            : Icon(icon, color: color, size: size),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildLoadingStatus(
      ThemeData theme, String status, Duration animDuration) {
    IconData icon = Icons.hourglass_empty_rounded;
    if (status.contains('Connecting')) {
      icon = Icons.wifi_rounded;
    } else if (status.contains('Fetching') || status.contains('Loading')) {
      icon = Icons.cloud_download_rounded;
    } else if (status.contains('Processing')) {
      icon = Icons.settings_rounded;
    } else if (status.contains('Found playlist')) {
      icon = Icons.playlist_play_rounded;
    } else if (status.contains('Retrying')) {
      icon = Icons.refresh_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: animDuration)
        .slideY(begin: -0.1, end: 0, duration: animDuration);
  }
}
