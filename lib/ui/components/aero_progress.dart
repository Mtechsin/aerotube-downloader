import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';

/// A sleek 4 px linear progress indicator featuring the Aero design language.
///
/// Highlights:
/// - 4 px default track height with full radius (999).
/// - Primary fill with a faint glow at the progress head for determinate progress.
/// - Smooth shimmer sweep for indeterminate state.
/// - Integrated motion duration scaling honoring user/OS reduced motion.
class AeroProgress extends StatefulWidget {
  /// Progress value between 0.0 and 1.0, or null for indeterminate.
  final double? value;

  /// Height of the progress track. Defaults to 4.0 px.
  final double height;

  /// Custom bar color. Defaults to [AeroColors.primary].
  final Color? color;

  /// Custom track background color. Defaults to [AeroColors.surface3].
  final Color? backgroundColor;

  /// Custom glow color at the head of the progress. Defaults to [AeroColors.primaryGlow].
  final Color? glowColor;

  /// Optional custom border radius. Defaults to [AeroRadius.fullBorderRadius].
  final BorderRadius? borderRadius;

  /// Semantics label for accessibility screen readers.
  final String? semanticsLabel;

  /// Semantics value for accessibility screen readers.
  final String? semanticsValue;

  const AeroProgress({
    super.key,
    this.value,
    this.height = 4.0,
    this.color,
    this.backgroundColor,
    this.glowColor,
    this.borderRadius,
    this.semanticsLabel,
    this.semanticsValue,
  });

  @override
  State<AeroProgress> createState() => _AeroProgressState();
}

class _AeroProgressState extends State<AeroProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didUpdateWidget(covariant AeroProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null && _shimmerController.isAnimating) {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final primaryColor = widget.color ?? colors.primary;
    final trackColor = widget.backgroundColor ?? colors.surface3;
    final glow = widget.glowColor ?? colors.primaryGlow;
    final radius = widget.borderRadius ?? AeroRadius.fullBorderRadius;

    final isIndeterminate = widget.value == null;
    final motionEnabled =
        appMotionDuration(context, AppMotion.short) != Duration.zero;
    if (isIndeterminate && motionEnabled) {
      if (!_shimmerController.isAnimating) _shimmerController.repeat();
    } else {
      _shimmerController.stop();
    }

    final semanticValueString =
        widget.semanticsValue ??
        (widget.value != null ? '${(widget.value! * 100).toInt()}%' : null);

    return Semantics(
      label: widget.semanticsLabel ?? 'Download progress',
      value: semanticValueString,
      child: SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: radius,
          child: isIndeterminate
              ? _buildIndeterminateTrack(trackColor, primaryColor, glow)
              : _buildDeterminateTrack(context, trackColor, primaryColor, glow),
        ),
      ),
    );
  }

  Widget _buildIndeterminateTrack(
    Color trackColor,
    Color activeColor,
    Color glowColor,
  ) {
    final effectiveDuration = appMotionDuration(
      context,
      const Duration(milliseconds: 1400),
    );

    if (effectiveDuration == Duration.zero) {
      // Reduced motion: steady soft progress bar
      return Container(
        color: trackColor,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            child: Container(color: activeColor),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _IndeterminateShimmerPainter(
            animationValue: _shimmerController.value,
            trackColor: trackColor,
            shimmerColor: activeColor,
            glowColor: glowColor,
          ),
        );
      },
    );
  }

  Widget _buildDeterminateTrack(
    BuildContext context,
    Color trackColor,
    Color activeColor,
    Color glowColor,
  ) {
    final targetValue = (widget.value ?? 0.0).clamp(0.0, 1.0);
    final motionDuration = appMotionDuration(context, AppMotion.fast);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetValue),
      duration: motionDuration,
      curve: Curves.linear,
      builder: (context, animatedValue, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _DeterminateProgressPainter(
            progress: animatedValue,
            trackColor: trackColor,
            activeColor: activeColor,
            glowColor: glowColor,
          ),
        );
      },
    );
  }
}

class _DeterminateProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color activeColor;
  final Color glowColor;

  _DeterminateProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.activeColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final trackRRect = RRect.fromRectAndRadius(rect, radius);

    // Track background
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRRect, trackPaint);

    if (progress <= 0.0) return;

    final fillWidth = (size.width * progress).clamp(0.0, size.width);
    final activeRect = Rect.fromLTWH(0, 0, fillWidth, size.height);
    final activeRRect = RRect.fromRectAndRadius(activeRect, radius);

    canvas.save();
    canvas.clipRRect(trackRRect);

    // Active progress fill
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(activeRRect, activePaint);

    // Faint glow at the head
    if (fillWidth > 2.0 && fillWidth < size.width) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(
        Offset(fillWidth, size.height / 2),
        size.height * 1.2,
        glowPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DeterminateProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.glowColor != glowColor;
  }
}

class _IndeterminateShimmerPainter extends CustomPainter {
  final double animationValue;
  final Color trackColor;
  final Color shimmerColor;
  final Color glowColor;

  _IndeterminateShimmerPainter({
    required this.animationValue,
    required this.trackColor,
    required this.shimmerColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final trackRRect = RRect.fromRectAndRadius(rect, radius);

    // Draw track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRRect, trackPaint);

    canvas.save();
    canvas.clipRRect(trackRRect);

    // Calculate shimmer band (width is 45% of total width)
    final bandWidth = size.width * 0.45;
    final totalDistance = size.width + bandWidth * 2;
    final currentLeft = (animationValue * totalDistance) - bandWidth;

    final bandRect = Rect.fromLTWH(currentLeft, 0, bandWidth, size.height);

    final gradient = LinearGradient(
      colors: [
        shimmerColor.withValues(alpha: 0.0),
        shimmerColor.withValues(alpha: 0.4),
        shimmerColor,
        shimmerColor.withValues(alpha: 0.4),
        shimmerColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    final shimmerPaint = Paint()
      ..shader = gradient.createShader(bandRect)
      ..style = PaintingStyle.fill;

    canvas.drawRect(bandRect, shimmerPaint);

    // Subtle glow at the head
    final headX = currentLeft + bandWidth * 0.75;
    if (headX > 0 && headX < size.width) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(Offset(headX, size.height / 2), size.height, glowPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IndeterminateShimmerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.shimmerColor != shimmerColor ||
        oldDelegate.glowColor != glowColor;
  }
}
