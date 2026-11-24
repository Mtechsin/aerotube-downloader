import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

class AnimatedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double scale;
  final Duration duration;
  final Curve curve;

  const AnimatedButton({
    super.key,
    this.onPressed,
    required this.child,
    this.scale = 0.95,
    this.duration = const Duration(milliseconds: 150),
    this.curve = Curves.linear,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (!_isPressed) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final Widget content = TweenAnimationBuilder<double>(
      tween: Tween(end: _isPressed ? widget.scale : 1.0),
      // Use the same duration in both directions for steady press feedback.
      duration: appMotionDuration(context, widget.duration),
      curve: _isPressed ? widget.curve : AppMotion.linear,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: widget.child,
    );

    if (!enabled) {
      // H26: disabled buttons must not accept pointer events and should
      // visually read as disabled with proper a11y semantics.
      return Semantics(
        button: true,
        enabled: false,
        child: Opacity(opacity: 0.5, child: content),
      );
    }

    return GestureDetector(
      // Own the full bounds: children without a decoration (transparent
      // containers, bare text) would otherwise only hit-test on their glyphs.
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: content,
    );
  }
}
