import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/navigation_provider.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/platform_settings_provider.dart';
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

    final enableAnimations = context.select<PlatformSettingsProvider, bool>(
      (provider) => provider.enableAnimations,
    );

    // Search FAB — Android only, only on home screen
    final showSearchFab =
        PlatformUtils.isAndroid && currentIndex == 0;

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
        body: AnimatedSwitcher(
          duration: enableAnimations
              ? const Duration(milliseconds: 300)
              : Duration.zero,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.02, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: IndexedStack(
            key: ValueKey(currentIndex),
            index: currentIndex,
            children: widget.screens,
          ),
        ),
        // Search FAB — Android only
        floatingActionButton: showSearchFab
            ? Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: _SearchFab(
                  onTap: () => navigationProvider.setIndex(1),
                  enableAnimations: enableAnimations,
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

class _SearchFab extends StatelessWidget {
  final VoidCallback onTap;
  final bool enableAnimations;

  const _SearchFab({required this.onTap, required this.enableAnimations});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FloatingActionButton(
      onPressed: onTap,
      elevation: 2,
      highlightElevation: 4,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      tooltip: 'Search',
      child: Icon(
        Icons.search_rounded,
        size: 24,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
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
