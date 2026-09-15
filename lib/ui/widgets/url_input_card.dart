import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/video_provider.dart';
import '../../core/utils/error_helper.dart';
import 'url_input_helper.dart';

class UrlInputCard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onFetch;
  final VoidCallback? onCancel;
  final bool isLoading;
  final String? statusMessage;
  final String? errorMessage;
  final bool showPasteButton;
  final FocusNode? focusNode;

  const UrlInputCard({
    super.key,
    required this.controller,
    required this.onFetch,
    this.onCancel,
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
  bool _isHovered = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode == null ? FocusNode() : null;
    widget.controller.addListener(_onControllerChanged);
    _effectiveFocusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant UrlInputCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      // Detach from old effective node
      final oldEffective = oldWidget.focusNode ?? _internalFocusNode;
      oldEffective?.removeListener(_onFocusChanged);
      // Manage internal node lifecycle when switching between external/internal
      if (oldWidget.focusNode == null && widget.focusNode != null) {
        // Was using internal, now using external: dispose orphaned internal node? Keep for reuse but remove listener already done.
        // Create disposed flag: dispose old internal if we had one and now external supplied
        _internalFocusNode?.dispose();
        _internalFocusNode = null;
      } else if (oldWidget.focusNode != null && widget.focusNode == null) {
        // Was using external, now need internal
        _internalFocusNode = FocusNode();
      }
      // Attach to new effective node
      _effectiveFocusNode.addListener(_onFocusChanged);
      // Sync focus state immediately
      _isFocused = _effectiveFocusNode.hasFocus;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
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

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;

    widget.controller.text = text;
    widget.controller.selection = TextSelection.collapsed(offset: text.length);
    _effectiveFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasError = widget.errorMessage != null;
    final hasText = widget.controller.text.trim().isNotEmpty;
    final enableAnimations = context.select<PlatformSettingsProvider, bool>(
      (p) => p.enableAnimations,
    );
    final animDuration = enableAnimations
        ? const Duration(milliseconds: 220)
        : Duration.zero;

    final errorHelper = hasError
        ? ErrorHelper.parse(widget.errorMessage!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedScale(
            duration: animDuration,
            curve: Curves.easeOutCubic,
            scale: _isFocused ? 1.012 : 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: AnimatedContainer(
                  duration: animDuration,
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(minHeight: 56),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(
                            alpha: _isFocused || _isHovered ? 0.065 : 0.04,
                          )
                        : theme.colorScheme.surface.withValues(
                            alpha: _isFocused || _isHovered ? 0.82 : 0.6,
                          ),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      if (_isFocused)
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.16,
                          ),
                          blurRadius: 28,
                          spreadRadius: -8,
                          offset: const Offset(0, 12),
                        )
                      else if (_isHovered)
                        BoxShadow(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.06,
                          ),
                          blurRadius: 18,
                          spreadRadius: -10,
                          offset: const Offset(0, 10),
                        ),
                    ],
                    border: Border.all(
                      color: hasError
                          ? theme.colorScheme.error.withValues(alpha: 0.45)
                          : _isFocused
                          ? theme.colorScheme.primary.withValues(alpha: 0.4)
                          : isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      width: hasError
                          ? 1.6
                          : _isFocused
                          ? 1.4
                          : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Icon(
                                Icons.link_rounded,
                                color: hasError
                                    ? theme.colorScheme.error
                                    : _isFocused
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.45,
                                      ),
                                size: 20,
                              ),
                            )
                            .animate(target: _isFocused ? 1 : 0)
                            .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.08, 1.08),
                              duration: enableAnimations
                                  ? 180.ms
                                  : Duration.zero,
                              curve: Curves.easeOutCubic,
                            ),
                        Expanded(
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _effectiveFocusNode,
                            textInputAction: TextInputAction.go,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Paste a video or playlist URL (YouTube, Vimeo, Twitter…)',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.35,
                                ),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) {
                              if (hasText) {
                                widget.onFetch();
                              }
                            },
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: animDuration,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: _actionTransition,
                          child: widget.showPasteButton
                              ? Padding(
                                  key: const ValueKey('paste-button'),
                                  padding: const EdgeInsets.only(left: 6),
                                  child: SizedBox(
                                    height: 44,
                                    width: 92,
                                    child: OutlinedButton.icon(
                                      onPressed: widget.isLoading
                                          ? null
                                          : _pasteFromClipboard,
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        foregroundColor:
                                            theme.colorScheme.onSurface,
                                        side: BorderSide(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.08),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      icon: Icon(
                                        Icons.content_paste_rounded,
                                        size: 16,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.62),
                                      ),
                                      label: const Text('Paste'),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('no-paste'),
                                ),
                        ),
                        AnimatedSwitcher(
                          duration: animDuration,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: _actionTransition,
                          // Hidden while a fetch runs: the slot button below
                          // is the single cancel affordance then.
                          child: hasText && !widget.isLoading
                              ? Padding(
                                  key: const ValueKey('clear-button'),
                                  padding: const EdgeInsets.only(left: 4),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.45),
                                      size: 18,
                                    ),
                                    tooltip: 'Clear URL',
                                    onPressed: () {
                                      widget.controller.clear();
                                      setState(() {});
                                    },
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('no-clear'),
                                ),
                        ),
                        AnimatedSwitcher(
                          duration: animDuration,
                          child: widget.isLoading
                              ? IconButton(
                                  key: const ValueKey('cancel'),
                                  padding: const EdgeInsets.all(2),
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  tooltip: 'Cancel fetch',
                                  onPressed: widget.onCancel,
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 22,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.55),
                                  ),
                                )
                              : IconButton(
                                  key: const ValueKey('fetch'),
                                  padding: const EdgeInsets.all(2),
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                  ),
                                  onPressed: !hasText ? null : widget.onFetch,
                                  icon: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 24,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                          if (errorHelper.category ==
                                  ErrorCategory.outdatedTool ||
                              errorHelper.category ==
                                  ErrorCategory.toolUpdate) ...[
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                context
                                    .read<VideoProvider>()
                                    .updateYtdlpAndRetry();
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Update & Retry'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
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
              .fadeIn(duration: enableAnimations ? 300.ms : Duration.zero)
              .slideY(
                begin: enableAnimations ? -0.2 : 0,
                end: 0,
                curve: Curves.easeOut,
              ),

        // Status Message (Loading)
        if (widget.isLoading && widget.statusMessage != null)
          _buildLoadingStatus(theme, widget.statusMessage!, enableAnimations),
      ],
    );
  }

  Widget _actionTransition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SizeTransition(
        sizeFactor: curved,
        axis: Axis.horizontal,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLoadingStatus(
    ThemeData theme,
    String status,
    bool enableAnimations,
  ) {
    final IconData icon = UrlInputHelper.getStatusIcon(status);

    return Container(
          margin: const EdgeInsets.only(top: 12, left: 8),
          child: Row(
            children: [
              // Animated dot
              _PulsingDot(color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Icon(icon, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
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
              // No Cancel pill here: the single cancel affordance lives in the
              // input row's action slot (the fetch button swaps to an ×).
            ],
          ),
        )
        .animate()
        .fadeIn(duration: enableAnimations ? 200.ms : Duration.zero)
        .slideY(begin: enableAnimations ? -0.1 : 0, end: 0);
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
