import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  final Widget? child;

  const GradientBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.brightness == Brightness.dark
        ? Colors.black
        : Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(color: backgroundColor),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
