import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/video_provider.dart';
import '../../core/utils/error_helper.dart';
import 'url_input_helper.dart';

/// Mobile-optimized URL input card — minimalist single-row layout
class MobileUrlInputCard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onFetch;
  final VoidCallback? onCancel;
  final bool isLoading;
  final String? statusMessage;
  final String? errorMessage;

  const MobileUrlInputCard({
    super.key,
    required this.controller,
    required this.onFetch,
    this.onCancel,
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
      // Accept any http(s) media URL — yt-dlp supports hundreds of sites.
      final isMediaUrl =
          text.isNotEmpty &&
          (text.startsWith('http://') || text.startsWith('https://')) &&
          Uri.tryParse(text)?.host.contains('.') == true;
      if (mounted) {
        setState(() {
          _clipboardYoutubeUrl = isMediaUrl ? text : null;
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
    final errorHelper = hasError
        ? ErrorHelper.parse(widget.errorMessage!)
        : null;

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

    final animDuration = enableAnimations
        ? const Duration(milliseconds: 300)
        : Duration.zero;
    final shortAnimDuration = enableAnimations
        ? const Duration(milliseconds: 200)
        : Duration.zero;

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
                        hintText: 'Paste a video URL…',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.35,
                          ),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
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
                // Clear Button — only when text present and not loading;
                // the slot button below is the single cancel affordance then
                if (widget.controller.text.isNotEmpty && !widget.isLoading)
                  _iconBtn(
                    icon: Icons.clear_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    size: 18,
                    onTap: () {
                      widget.controller.clear();
                      setState(() {});
                    },
                  ),
                // Fetch / Cancel Button
                _iconBtn(
                  icon: widget.isLoading
                      ? Icons.close_rounded
                      : Icons.arrow_forward_rounded,
                  color: widget.isLoading
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.55)
                      : widget.controller.text.isEmpty
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.22)
                      : theme.colorScheme.primary,
                  size: 22,
                  onTap: widget.isLoading
                      ? widget.onCancel
                      : (widget.controller.text.isEmpty
                            ? null
                            : widget.onFetch),
                  loading: false,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.18,
                        ),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.content_paste_rounded,
                          size: 13,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.75,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Paste copied URL',
                          style: TextStyle(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.85,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: animDuration)
              .slideY(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.15,
                  ),
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
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                          if (errorHelper.category ==
                                  ErrorCategory.outdatedTool ||
                              errorHelper.category ==
                                  ErrorCategory.toolUpdate) ...[
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                context
                                    .read<VideoProvider>()
                                    .updateYtdlpAndRetry();
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 15),
                              label: const Text(
                                'Update & Retry',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                visualDensity: VisualDensity.compact,
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
                duration: animDuration,
              ),

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
    ThemeData theme,
    String status,
    Duration animDuration,
  ) {
    final IconData icon = UrlInputHelper.getStatusIcon(status);

    return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
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
              // No Cancel pill here: the single cancel affordance lives in the
              // input row's action slot (the fetch button swaps to an ×).
            ],
          ),
        )
        .animate()
        .fadeIn(duration: animDuration)
        .slideY(begin: -0.1, end: 0, duration: animDuration);
  }
}
