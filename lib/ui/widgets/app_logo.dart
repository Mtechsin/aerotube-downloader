import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool useAnimations;
  final bool showGlow;

  const AppLogo({
    super.key,
    this.size = 120,
    this.useAnimations = true,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget logoBody = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (useAnimations) {
      logoBody = logoBody
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: -5, end: 5, duration: 2500.ms, curve: Curves.easeInOut)
          .animate(onPlay: (c) => c.repeat())
          .shimmer(delay: 5000.ms, duration: 2000.ms, color: Colors.white.withValues(alpha: 0.3));
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showGlow)
            Container(
              width: size * 0.8,
              height: size * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: size * 0.5,
                    spreadRadius: size * 0.1,
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 2000.ms),
          
          logoBody,
        ],
      ),
    );
  }
}
