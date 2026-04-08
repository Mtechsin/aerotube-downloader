import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/utils/error_helper.dart';

class UrlInputCard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onFetch;
  final bool isLoading;
  final String? statusMessage;
  final String? errorMessage;
  final bool showPasteButton;
  final FocusNode? focusNode;

  const UrlInputCard({
    super.key,
    required this.controller,
    required this.onFetch,
    this.isLoading = false,
    this.errorMessage,
    this.statusMessage,
    this.showPasteButton = true,
    this.focusNode,
  });

  @override
  State<UrlInputCard> createState() => _UrlInputCardState();
}

class _UrlInputCardState extends State<UrlInputCard> {
  FocusNode? _internalFocusNode;
  bool _isFocused = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode == null ? FocusNode() : null;
    widget.controller.addListener(_onControllerChanged);
    _effectiveFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onControllerChanged);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() => _isFocused = _effectiveFocusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorMessage != null;
    final hasText = widget.controller.text.trim().isNotEmpty;
    final errorHelper = hasError
        ? ErrorHelper.parse(widget.errorMessage!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 78),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: hasError
                  ? theme.colorScheme.error.withValues(alpha: 0.45)
                  : _isFocused
                  ? theme.colorScheme.primary.withValues(alpha: 0.45)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.18),
              width: hasError
                  ? 1.6
                  : _isFocused
                  ? 1.4
                  : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      color: hasError
                          ? theme.colorScheme.error.withValues(alpha: 0.1)
                          : _isFocused
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.link_rounded,
                      color: hasError
                          ? theme.colorScheme.error
                          : _isFocused
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _effectiveFocusNode,
                        textInputAction: TextInputAction.go,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Paste URL',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.35,
                            ),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (hasText) {
                            widget.onFetch();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                if (hasText) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.45,
                      ),
                      size: 20,
                    ),
                    tooltip: 'Clear URL',
                    onPressed: () {
                      widget.controller.clear();
                      setState(() {});
                    },
                  ),
                ],
                if (widget.showPasteButton) ...[
                  const SizedBox(width: 2),
                  _buildIconButton(
                    icon: Icons.content_paste_rounded,
                    tooltip: 'Paste from clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      final text = data?.text?.trim();
                      if (text != null && text.isNotEmpty) {
                        if (!mounted) return;
                        widget.controller.text = text;
                        widget.controller.selection = TextSelection.collapsed(
                          offset: text.length,
                        );
                        setState(() {});
                        _effectiveFocusNode.requestFocus();
                      }
                    },
                  ),
                ],
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: widget.isLoading || !hasText
                        ? null
                        : widget.onFetch,
                    style: FilledButton.styleFrom(
                      backgroundColor: hasError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      minimumSize: const Size(118, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    icon: widget.isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(
                      widget.isLoading ? 'Loading' : 'Fetch',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Error Message
        if (hasError && errorHelper != null)
          Container(
                margin: const EdgeInsets.only(top: 16, left: 8, right: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                      theme.colorScheme.errorContainer.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            errorHelper.friendlyMessage,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (errorHelper.suggestion != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              errorHelper.suggestion!,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 13,
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
              .fadeIn(duration: 300.ms)
              .slideY(begin: -0.2, end: 0, curve: Curves.easeOut),

        // Status Message (Loading)
        if (widget.isLoading && widget.statusMessage != null)
          _buildLoadingStatus(theme, widget.statusMessage!),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingStatus(ThemeData theme, String status) {
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

    return Container(
      margin: const EdgeInsets.only(top: 12, left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated dot
          _PulsingDot(color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              status,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0);
  }
}

// A small pulsing dot used as the single loading indicator
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
