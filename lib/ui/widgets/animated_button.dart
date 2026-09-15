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
    this.curve = Curves.easeOutCubic,
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
    return GestureDetector(
      // Own the full bounds: children without a decoration (transparent
      // containers, bare text) would otherwise only hit-test on their glyphs.
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _isPressed ? widget.scale : 1.0),
        // Press compresses quickly on the caller's curve; release springs
        // back with a subtle overshoot for the expressive feel.
        duration: appMotionDuration(
          context,
          _isPressed ? widget.duration : AppMotion.medium,
        ),
        curve: _isPressed ? widget.curve : AppMotion.snappySpringCurve,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: widget.child,
      ),
    );
  }
}
