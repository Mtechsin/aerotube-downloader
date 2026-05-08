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
      filterQuality: FilterQuality.medium,
      cacheWidth: (size * MediaQuery.of(context).devicePixelRatio).round(),
    );

    if (useAnimations) {
      logoBody = logoBody
          .animate()
          .fadeIn(duration: 260.ms)
          .scale(
            begin: const Offset(0.96, 0.96),
            end: const Offset(1, 1),
            duration: 260.ms,
            curve: Curves.easeOutCubic,
          );
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showGlow)
            Container(
              width: size * 1.0,
              height: size * 1.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.18),
                    blurRadius: size * 0.6,
                    spreadRadius: size * 0.05,
                  ),
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    blurRadius: size * 1.2,
                    spreadRadius: size * 0.15,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

          logoBody,
        ],
      ),
    );
  }
}
