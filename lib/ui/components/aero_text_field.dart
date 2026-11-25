import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/typography.dart';
import 'aero_density.dart';

/// AeroTextField delivers layered input aesthetics with a signature focus glow ring.
///
/// Features:
/// - Heights:
///   - Android (comfortable): 56 dp
///   - Windows (compact): 48 px
/// - Corner radius: [AeroRadius.xl] (24 px)
/// - Background: [AeroColors.surface2] fill
/// - Focus state: [AeroColors.primary] hairline border + 3 px [AeroColors.primaryGlow] ring
/// - Respects [appMotionDuration] / reduce-motion
class AeroTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final AeroDensity? density;
  final List<TextInputFormatter>? inputFormatters;
  final EdgeInsetsGeometry? contentPadding;
  final double? height;

  const AeroTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.density,
    this.inputFormatters,
    this.contentPadding,
    this.height,
  });

  @override
  State<AeroTextField> createState() => _AeroTextFieldState();
}

class _AeroTextFieldState extends State<AeroTextField> {
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_handleFocusChange);
    _isFocused = _effectiveFocusNode.hasFocus;
  }

  @override
  void didUpdateWidget(AeroTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)?.removeListener(
        _handleFocusChange,
      );
      _effectiveFocusNode.addListener(_handleFocusChange);
      _isFocused = _effectiveFocusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted && _isFocused != _effectiveFocusNode.hasFocus) {
      setState(() {
        _isFocused = _effectiveFocusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aero = context.aero;
    final effectiveDensity = AeroDensity.resolve(context, widget.density);
    final isCompact = effectiveDensity.isCompact;

    final double defaultHeight = isCompact ? 48.0 : 56.0;
    final double? singleLineHeight = widget.maxLines == 1
        ? (widget.height ?? defaultHeight)
        : null;
    final double minMultiLineHeight = widget.height ?? defaultHeight;

    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    // Focus / error styling
    final BoxBorder border;
    final List<BoxShadow>? boxShadow;

    if (hasError) {
      border = Border.all(color: aero.danger, width: 1.0);
      boxShadow = _isFocused
          ? [
              BoxShadow(
                color: aero.danger.withValues(alpha: 0.35),
                spreadRadius: 3,
                blurRadius: 0,
              ),
            ]
          : null;
    } else if (_isFocused) {
      border = Border.all(color: aero.primary, width: 1.0);
      boxShadow = [
        BoxShadow(color: aero.primaryGlow, spreadRadius: 3, blurRadius: 0),
      ];
    } else {
      border = Border.all(color: aero.outline, width: 1.0);
      boxShadow = null;
    }

    final duration = appMotionDuration(context, AppMotion.short);

    final inputTextStyle = AeroText.body.copyWith(
      color: widget.enabled ? aero.onSurface : aero.onSurfaceFaint,
    );

    final hintTextStyle = AeroText.body.copyWith(color: aero.onSurfaceFaint);

    final double horizontalPadding = widget.prefixIcon != null ? 8.0 : 18.0;
    final effectiveContentPadding =
        widget.contentPadding ??
        EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: isCompact ? 10.0 : 14.0,
        );

    final Widget textField = TextField(
      controller: widget.controller,
      focusNode: _effectiveFocusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      inputFormatters: widget.inputFormatters,
      style: inputTextStyle,
      cursorColor: aero.primary,
      cursorWidth: 2.0,
      cursorRadius: const Radius.circular(2.0),
      decoration: InputDecoration(
        filled: false,
        isDense: true,
        hintText: widget.hintText,
        hintStyle: hintTextStyle,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: effectiveContentPadding,
      ),
    );

    Widget containerContent;
    if (widget.prefixIcon != null || widget.suffixIcon != null) {
      containerContent = Row(
        crossAxisAlignment: widget.maxLines == 1
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (widget.prefixIcon != null)
            Padding(
              padding: const EdgeInsets.only(left: 14.0, right: 4.0),
              child: IconTheme(
                data: IconThemeData(
                  color: _isFocused ? aero.primary : aero.onSurfaceMuted,
                  size: isCompact ? 20.0 : 22.0,
                ),
                child: widget.prefixIcon!,
              ),
            ),
          Expanded(child: textField),
          if (widget.suffixIcon != null)
            Padding(
              padding: const EdgeInsets.only(left: 4.0, right: 12.0),
              child: IconTheme(
                data: IconThemeData(
                  color: aero.onSurfaceMuted,
                  size: isCompact ? 20.0 : 22.0,
                ),
                child: widget.suffixIcon!,
              ),
            ),
        ],
      );
    } else {
      containerContent = textField;
    }

    final boxDecoration = BoxDecoration(
      color: widget.enabled ? aero.surface2 : aero.surface1,
      borderRadius: AeroRadius.xlBorderRadius,
      border: border,
      boxShadow: boxShadow,
    );

    Widget fieldBox;
    if (widget.maxLines == 1) {
      fieldBox = AnimatedContainer(
        duration: duration,
        curve: AppMotion.emphasized,
        height: singleLineHeight,
        alignment: Alignment.center,
        decoration: boxDecoration,
        child: containerContent,
      );
    } else {
      fieldBox = AnimatedContainer(
        duration: duration,
        curve: AppMotion.emphasized,
        constraints: BoxConstraints(minHeight: minMultiLineHeight),
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        decoration: boxDecoration,
        child: containerContent,
      );
    }

    if (widget.labelText == null && !hasError) {
      return fieldBox;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.labelText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Text(
              widget.labelText!,
              style: AeroText.label.copyWith(
                color: _isFocused ? aero.primary : aero.onSurfaceMuted,
              ),
            ),
          ),
        ],
        fieldBox,
        if (hasError) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 6.0),
            child: Text(
              widget.errorText!,
              style: AeroText.caption.copyWith(color: aero.danger),
            ),
          ),
        ],
      ],
    );
  }
}
