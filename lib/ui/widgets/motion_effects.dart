import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../models/download_item.dart';

/// One-shot spring pop (scale 0.92 -> 1 with slight overshoot) for a card
/// whose download just completed. Plays on a false->true [completed]
/// transition and, via [playOnMount], for cards that appear already
/// completed (history lists) when the completion is only seconds old —
/// the moment a finished download is actually seen. The ticker rests at
/// scale 1.0 and only runs for the pop itself.
class CompletionPop extends StatefulWidget {
  final bool completed;
  final bool playOnMount;
  final Widget child;

  const CompletionPop({
    super.key,
    required this.completed,
    this.playOnMount = false,
    required this.child,
  });

  /// Pop for a card in a history list whose download finished only seconds
  /// ago — the moment a finished download is actually seen. Older history
  /// items mount at rest.
  factory CompletionPop.recent(DownloadItem item, {required Widget child}) {
    final date = item.completedDate;
    final justFinished =
        item.status == DownloadStatus.completed &&
        date != null &&
        DateTime.now().difference(date) < const Duration(seconds: 5);
    return CompletionPop(
      completed: item.status == DownloadStatus.completed,
      playOnMount: justFinished,
      child: child,
    );
  }

  @override
  State<CompletionPop> createState() => _CompletionPopState();
}

class _CompletionPopState extends State<CompletionPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 1.0);
    if (widget.playOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(covariant CompletionPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed && !oldWidget.completed) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _controller.duration = appMotionDuration(context, AppMotion.medium);
    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: AppMotion.bounceSpringCurve,
        ),
      ),
      child: widget.child,
    );
  }
}
