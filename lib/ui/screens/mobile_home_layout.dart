import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/navigation_provider.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/platform_utils.dart';
import 'mobile_home_screen.dart';

class MobileShell extends StatefulWidget {
  final List<Widget> screens;

  const MobileShell({super.key, required this.screens});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final theme = Theme.of(context);
    final currentIndex = navigationProvider.currentIndex;

    // Search FAB — Android only, only on home screen
    final showSearchFab = PlatformUtils.isAndroid && currentIndex == 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (navigationProvider.currentIndex != 0) {
          navigationProvider.setIndex(0);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: IndexedStack(index: currentIndex, children: widget.screens),
        // Search FAB — Android only
        floatingActionButton: showSearchFab
            ? Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: _SearchFab(onTap: () => navigationProvider.setIndex(1)),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

class _SearchFab extends StatefulWidget {
  final VoidCallback onTap;

  const _SearchFab({required this.onTap});

  @override
  State<_SearchFab> createState() => _SearchFabState();
}

class _SearchFabState extends State<_SearchFab> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _pressed ? 1.0 : 0.0),
        // Squish fast on press, spring back with the corners rounding out.
        duration: appMotionDuration(
          context,
          _pressed ? AppMotion.fast : AppMotion.medium,
        ),
        curve: _pressed ? AppMotion.accelerate : AppMotion.snappySpringCurve,
        builder: (context, t, child) {
          return Transform.scale(
            scale: 1.0 - 0.04 * t,
            child: FloatingActionButton(
              onPressed: widget.onTap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.0 + 10.0 * t),
                side: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              tooltip: 'Search',
              child: child,
            ),
          );
        },
        child: Icon(
          Icons.search_rounded,
          size: 24,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class MobileHomeLayout extends StatelessWidget {
  const MobileHomeLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return const MobileHomeScreen();
  }
}
