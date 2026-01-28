import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  final Widget? child;
  
  const GradientBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}
