
import 'dart:math' as math;
import 'package:flutter/material.dart';

class WavyProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double thickness;
  final double animationValue;

  WavyProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    this.thickness = 8.0,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    // Draw background wave (faint)
    paint.color = backgroundColor;
    _drawWave(canvas, size, paint);

    // Draw progress wave (masked)
    paint.color = color;
    
    // We want to clip the progress part
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    _drawWave(canvas, size, paint);
    canvas.restore();
  }

  void _drawWave(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final double waveHeight = size.height; // Height of the wave area
    final double midY = size.height / 2;
    // Amplitude should be less than half height minus half thickness to stay in bounds
    final double amplitude = (waveHeight - thickness) / 2 * 0.8; 
    final double wavelength = 20.0; // Distance between peaks

    path.moveTo(0, midY);

    for (double x = 0; x <= size.width; x++) {
      // Shift phase with animationValue (0..1) -> 2*pi
      final double y = midY + amplitude * math.sin(((x / wavelength) + animationValue) * 2 * math.pi);
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavyProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.backgroundColor != backgroundColor ||
           oldDelegate.animationValue != animationValue;
  }
}
