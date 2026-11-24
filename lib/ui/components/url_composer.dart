import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import '../../core/utils/error_helper.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/utils/url_validator.dart';
import 'aero_density.dart';
import 'aero_progress.dart';

/// States of the [UrlComposer] state machine.
enum UrlComposerState {
  /// Empty or neutral text input.
  idle,

  /// Valid media / YouTube URL parsed.
  valid,

  /// In-flight fetch active; displays inline progress line along the bottom edge.
  loading,

  /// Fetch or validation failure; displays inline error below the field.
  error,
}

/// Unified URL input composer component replacing legacy URL input cards.
///
/// Features:
/// - Heights: 56 dp (Android / comfortable) vs 48 px (Windows / compact).
/// - Corner radius: [AeroRadius.xl] (24 px).
/// - Fill: [AeroColors.surface2].
/// - Focus ring: [AeroColors.primary] hairline + 3 px [AeroColors.primaryGlow] ring.
/// - Integrated state machine: [UrlComposerState.idle], [UrlComposerState.valid],
///   [UrlComposerState.loading], [UrlComposerState.error].
/// - Inline bottom-edge progress indicator during [UrlComposerState.loading].
/// - Inline error reporting below the field during [UrlComposerState.error].
/// - Inline Paste and Fetch action buttons.
/// - Strictly adheres to H27 privacy rule: never reads clipboard until the user
///   explicitly taps Paste or triggers the Paste shortcut.
class UrlComposer extends StatefulWidget {
  /// Controller for the URL text input. If not provided, an internal controller is used.
  final TextEditingController? controller;

  /// Focus node for the text field. If not provided, an internal focus node is used.
  final FocusNode? focusNode;

  /// Callback triggered when the user initiates a fetch.
  final VoidCallback onFetch;

  /// Optional callback to cancel an in-flight fetch operation.
  final VoidCallback? onCancel;

  /// Optional change listener for input text.
  final ValueChanged<String>? onChanged;

  /// Whether a fetch operation is currently active.
  final bool isLoading;

  /// Error message to display inline below the field.
  final String? errorMessage;

  /// Status message describing the current loading stage (e.g. "Connecting to YouTube...").
  final String? statusMessage;

  /// Placeholder text when the field is empty. Defaults to "Paste a video or playlist URL…".
  final String? hintText;

  /// Whether to show the inline Paste button. Defaults to `true`.
  final bool showPasteButton;

  /// Whether to show the inline Fetch button. Defaults to `true`.
  final bool showFetchButton;

  /// Whether to autofocus the text field. Defaults to `false`.
  final bool autofocus;

  /// Whether input interaction is enabled. Defaults to `true`.
  final bool enabled;

  /// Density override (compact 48px vs comfortable 56dp).
  final AeroDensity? density;

  /// Optional height override for the field container.
  final double? height;

  /// Optional maximum width constraint for the composer widget.
  final double? maxWidth;

  const UrlComposer({
    super.key,
    this.controller,
    this.focusNode,
    required this.onFetch,
    this.onCancel,
    this.onChanged,
    this.isLoading = false,
    this.errorMessage,
    this.statusMessage,
    this.hintText,
    this.showPasteButton = true,
    this.showFetchButton = true,
    this.autofocus = false,
    this.enabled = true,
    this.density,
    this.height,
    this.maxWidth,
  });

  @override
  State<UrlComposer> createState() => _UrlComposerState();
}

class _UrlComposerState extends State<UrlComposer> {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;

  TextEditingController get _effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _effectiveController.addListener(_onControllerChanged);
    _effectiveFocusNode.addListener(_onFocusChanged);
    _isFocused = _effectiveFocusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant UrlComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      _effectiveController.addListener(_onControllerChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      _effectiveFocusNode.addListener(_onFocusChanged);
      _isFocused = _effectiveFocusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_onControllerChanged);
    _effectiveFocusNode.removeListener(_onFocusChanged);
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() => _isFocused = _effectiveFocusNode.hasFocus);
    }
  }

  /// Determines whether a string is a valid media URL for fetch operations.
  bool _isValidUrl(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    try {
      UrlValidator.validate(trimmed);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Evaluates the current state machine phase.
  UrlComposerState get _currentState {
    if (widget.isLoading) return UrlComposerState.loading;
    if (widget.errorMessage != null && widget.errorMessage!.trim().isNotEmpty) {
      return UrlComposerState.error;
    }
    final text = _effectiveController.text.trim();
    if (text.isNotEmpty && _isValidUrl(text)) {
      return UrlComposerState.valid;
    }
    return UrlComposerState.idle;
  }

  /// Strictly obeys H27 privacy rule: only called upon explicit user gesture (Paste button / Ctrl+V).
  Future<void> _handlePaste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (!mounted) return;

      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard is empty'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      _effectiveController.text = text;
      _effectiveController.selection = TextSelection.collapsed(
        offset: text.length,
      );
      _effectiveFocusNode.requestFocus();
      widget.onChanged?.call(text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read clipboard'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleClear() {
    _effectiveController.clear();
    widget.onChanged?.call('');
    _effectiveFocusNode.requestFocus();
  }

  void _submitFetch() {
    if (widget.isLoading) return;
    final text = _effectiveController.text.trim();
    if (text.isEmpty) {
      _effectiveFocusNode.requestFocus();
      return;
    }
    widget.onFetch();
  }

  /// Resolves the icon for loading status messages.
  IconData _getStatusIcon(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('connect')) return Symbols.wifi_rounded;
    if (lower.contains('fetch') || lower.contains('load')) {
      return Symbols.cloud_download_rounded;
    }
    if (lower.contains('process')) return Symbols.settings_rounded;
    if (lower.contains('playlist')) return Symbols.playlist_play_rounded;
    if (lower.contains('retry')) return Symbols.refresh_rounded;
    return Symbols.hourglass_top_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final density = AeroDensity.resolve(context, widget.density);
    final isDesktop = PlatformUtils.isDesktop;
    final currentState = _currentState;

    final double effectiveHeight =
        widget.height ?? (density.isCompact ? 48.0 : 56.0);
    final animDuration = appMotionDuration(
      context,
      const Duration(milliseconds: 150),
    );

    // Box border & glow ring resolution based on state machine
    BoxBorder border;
    List<BoxShadow>? shadows;

    if (currentState == UrlComposerState.error) {
      border = Border.all(color: colors.danger, width: 1.2);
      shadows = [
        BoxShadow(
          color: colors.danger.withValues(alpha: 0.25),
          spreadRadius: 2.0,
          blurRadius: 0,
        ),
      ];
    } else if (_isFocused) {
      border = Border.all(color: colors.primary, width: 1.2);
      shadows = [
        BoxShadow(color: colors.primaryGlow, spreadRadius: 3.0, blurRadius: 0),
      ];
    } else if (_isHovered) {
      border = Border.all(color: colors.outlineStrong, width: 1.0);
    } else {
      border = Border.all(color: colors.outline, width: 1.0);
    }

    final hasText = _effectiveController.text.isNotEmpty;

    // Leading icon tint
    final Color leadingIconColor;
    if (currentState == UrlComposerState.error) {
      leadingIconColor = colors.danger;
    } else if (_isFocused || currentState == UrlComposerState.valid) {
      leadingIconColor = colors.primary;
    } else {
      leadingIconColor = colors.onSurfaceFaint;
    }

    // Composer row container
    Widget composerContainer = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: animDuration,
        curve: AppMotion.decelerate,
        height: effectiveHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: AeroRadius.mdBorderRadius,
          border: border,
          boxShadow: shadows,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Main input content row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AeroSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Leading link glyph
                  Icon(Symbols.link_rounded, size: 20, color: leadingIconColor),
                  const SizedBox(width: AeroSpace.sm),

                  // Text input field
                  Expanded(
                    child: TextField(
                      controller: _effectiveController,
                      focusNode: _effectiveFocusNode,
                      enabled:
                          widget.enabled &&
                          currentState != UrlComposerState.loading,
                      autofocus: widget.autofocus,
                      style: AeroText.body.copyWith(color: colors.onSurface),
                      cursorColor: colors.primary,
                      textInputAction: TextInputAction.go,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: widget.onChanged,
                      onSubmitted: (_) => _submitFetch(),
                      decoration: InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText:
                            widget.hintText ?? 'Paste a video or playlist URL…',
                        hintStyle: AeroText.body.copyWith(
                          color: colors.onSurfaceFaint,
                        ),
                      ),
                    ),
                  ),

                  // Clear action button
                  if (hasText && currentState != UrlComposerState.loading) ...[
                    _InlineIconButton(
                      icon: Symbols.close_rounded,
                      tooltip: 'Clear (Esc)',
                      onTap: _handleClear,
                      color: colors.onSurfaceMuted,
                    ),
                    const SizedBox(width: AeroSpace.xs),
                  ],

                  // Inline Paste action button
                  if (widget.showPasteButton &&
                      currentState != UrlComposerState.loading) ...[
                    _InlineIconButton(
                      icon: Symbols.content_paste_rounded,
                      tooltip: isDesktop ? 'Paste (Ctrl+V)' : 'Paste',
                      onTap: _handlePaste,
                      color: colors.onSurfaceMuted,
                    ),
                    const SizedBox(width: AeroSpace.xs),
                  ],

                  // Inline Fetch / Cancel action button
                  if (widget.showFetchButton) ...[
                    _buildActionButton(context, currentState, colors, density),
                  ],
                ],
              ),
            ),

            // Inline progress line along the bottom edge
            if (currentState == UrlComposerState.loading)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AeroProgress(
                  height: 3.0,
                  backgroundColor: Colors.transparent,
                ),
              ),
          ],
        ),
      ),
    );

    // Keyboard navigation shortcuts
    composerContainer = CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (currentState == UrlComposerState.loading &&
              widget.onCancel != null) {
            widget.onCancel!();
          } else if (hasText) {
            _handleClear();
          } else {
            _effectiveFocusNode.unfocus();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _handlePaste,
        const SingleActivator(LogicalKeyboardKey.enter): _submitFetch,
      },
      child: composerContainer,
    );

    // Assemble full composer column with inline error & loading status
    final List<Widget> columnChildren = [composerContainer];

    // Inline status message (e.g. "Connecting to YouTube...")
    if (currentState == UrlComposerState.loading &&
        widget.statusMessage != null &&
        widget.statusMessage!.trim().isNotEmpty) {
      columnChildren.add(const SizedBox(height: AeroSpace.sm));
      columnChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AeroSpace.sm),
          child: Row(
            children: [
              Icon(
                _getStatusIcon(widget.statusMessage!),
                size: 14,
                color: colors.primary,
              ),
              const SizedBox(width: AeroSpace.xs + 2),
              Expanded(
                child: Text(
                  widget.statusMessage!,
                  style: AeroText.caption.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Inline error reporting below the field
    if (currentState == UrlComposerState.error &&
        widget.errorMessage != null &&
        widget.errorMessage!.trim().isNotEmpty) {
      final parsedError = ErrorHelper.parse(widget.errorMessage!);
      final displayMessage =
          parsedError.suggestion ?? parsedError.friendlyMessage;

      columnChildren.add(const SizedBox(height: AeroSpace.sm));
      columnChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AeroSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Symbols.error_rounded, size: 15, color: colors.danger),
              const SizedBox(width: AeroSpace.xs + 2),
              Expanded(
                child: Text(
                  displayMessage,
                  style: AeroText.caption.copyWith(color: colors.danger),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget result = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: columnChildren,
    );

    if (widget.maxWidth != null) {
      result = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth!),
        child: result,
      );
    }

    return result;
  }

  /// Builds the trailing action button (Fetch arrow or Cancel button).
  Widget _buildActionButton(
    BuildContext context,
    UrlComposerState state,
    AeroColors colors,
    AeroDensity density,
  ) {
    final double buttonSize = density.isCompact ? 32.0 : 38.0;

    if (state == UrlComposerState.loading) {
      if (widget.onCancel != null) {
        return Tooltip(
          message: 'Cancel',
          child: InkWell(
            onTap: widget.onCancel,
            borderRadius: BorderRadius.circular(buttonSize / 2),
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                color: colors.surface3,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.close_rounded,
                size: 18,
                color: colors.onSurfaceMuted,
              ),
            ),
          ),
        );
      }
      return SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
        ),
      );
    }

    final isValid = state == UrlComposerState.valid;
    final isDesktop = PlatformUtils.isDesktop;
    final buttonTooltip = isDesktop ? 'Fetch (Enter)' : 'Fetch';

    if (isDesktop && MediaQuery.sizeOf(context).width >= 600) {
      return Tooltip(
        message: buttonTooltip,
        child: FilledButton.icon(
          onPressed:
              widget.enabled && _effectiveController.text.trim().isNotEmpty
              ? _submitFetch
              : null,
          icon: const Icon(Symbols.arrow_forward_rounded, size: 16),
          label: const Text('Get options'),
          style: FilledButton.styleFrom(
            minimumSize: Size(0, buttonSize),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: AeroRadius.mdBorderRadius,
            ),
            textStyle: AeroText.label,
          ),
        ),
      );
    }

    final Color bgColor = isValid ? colors.primary : colors.surface3;
    final Color iconColor = isValid ? Colors.white : colors.onSurfaceFaint;

    return Tooltip(
      message: buttonTooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _submitFetch,
          borderRadius: BorderRadius.circular(buttonSize / 2),
          child: AnimatedContainer(
            duration: appMotionDuration(
              context,
              const Duration(milliseconds: 150),
            ),
            curve: AppMotion.decelerate,
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(
              Symbols.arrow_forward_rounded,
              size: 18,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact inline icon button for the composer bar.
class _InlineIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _InlineIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
