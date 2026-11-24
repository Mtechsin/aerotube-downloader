import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';

/// Aero-styled centered dialog container with 24 px (xl) radius,
/// surface1 background, hairline border, and 480 px max width.
class AeroDialog extends StatelessWidget {
  final Widget? title;
  final String? titleText;
  final Widget? content;
  final List<Widget>? actions;
  final Widget? leading;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;
  final bool showCloseButton;

  const AeroDialog({
    super.key,
    this.title,
    this.titleText,
    this.content,
    this.actions,
    this.leading,
    this.padding,
    this.maxWidth = 480.0,
    this.showCloseButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.40)
        : Colors.black.withValues(alpha: 0.12);

    Widget? header;
    if (title != null ||
        titleText != null ||
        leading != null ||
        showCloseButton) {
      header = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AeroSpace.md),
          ],
          Expanded(
            child:
                title ??
                Text(
                  titleText ?? '',
                  style: AeroText.title.copyWith(color: colors.onSurface),
                ),
          ),
          if (showCloseButton)
            IconButton(
              icon: const Icon(Symbols.close_rounded, size: 20),
              color: colors.onSurfaceMuted,
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Close',
              splashRadius: 18,
            ),
        ],
      );
    }

    Widget? actionsRow;
    if (actions != null && actions!.isNotEmpty) {
      actionsRow = Padding(
        padding: const EdgeInsets.only(top: AeroSpace.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (int i = 0; i < actions!.length; i++) ...[
              if (i > 0) const SizedBox(width: AeroSpace.sm),
              actions![i],
            ],
          ],
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AeroSpace.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: AeroRadius.xlBorderRadius,
            border: Border.all(color: colors.outline, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: padding ?? const EdgeInsets.all(AeroSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) ...[
                header,
                const SizedBox(height: AeroSpace.lg),
              ],
              if (content != null) Flexible(child: content!),
              if (actionsRow != null) actionsRow,
            ],
          ),
        ),
      ),
    );
  }
}

/// Aero-styled modal bottom sheet with 24 px (xl) top radius,
/// drag handle, and surface1 background.
class AeroSheet extends StatelessWidget {
  final Widget child;
  final Widget? title;
  final String? titleText;
  final bool showDragHandle;
  final EdgeInsetsGeometry? padding;

  const AeroSheet({
    super.key,
    required this.child,
    this.title,
    this.titleText,
    this.showDragHandle = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;

    Widget? header;
    if (title != null || titleText != null) {
      header = Padding(
        padding: const EdgeInsets.only(
          left: AeroSpace.xxl,
          right: AeroSpace.xxl,
          bottom: AeroSpace.md,
        ),
        child:
            title ??
            Text(
              titleText ?? '',
              style: AeroText.title.copyWith(color: colors.onSurface),
            ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AeroRadius.xl),
        ),
        border: Border(top: BorderSide(color: colors.outline, width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDragHandle) _buildDragHandle(colors),
            if (header != null) header,
            Padding(
              padding:
                  padding ??
                  const EdgeInsets.symmetric(
                    horizontal: AeroSpace.xxl,
                    vertical: AeroSpace.sm,
                  ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(AeroColors colors) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: AeroSpace.md, bottom: AeroSpace.sm),
        decoration: BoxDecoration(
          color: colors.outlineStrong,
          borderRadius: AeroRadius.fullBorderRadius,
        ),
      ),
    );
  }
}

/// Shows a standard [AeroDialog] centered on screen.
Future<T?> showAeroDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.54),
    builder: builder,
  );
}

/// Adaptive modal helper:
/// - Windows / Desktop: renders centered [AeroDialog] constrained to 480 px width.
/// - Android / Mobile: renders modal bottom [AeroSheet] with drag handle.
Future<T?> showAeroSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? titleText,
  bool isDismissible = true,
  bool enableDrag = true,
  bool isScrollControlled = true,
  bool showDragHandle = true,
}) {
  final platform = Theme.of(context).platform;
  final isDesktop =
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux ||
      platform == TargetPlatform.macOS;

  if (isDesktop) {
    return showAeroDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (dialogContext) {
        return AeroDialog(
          titleText: titleText,
          maxWidth: 480,
          showCloseButton: isDismissible,
          content: builder(dialogContext),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.54),
    builder: (sheetContext) {
      return AeroSheet(
        titleText: titleText,
        showDragHandle: showDragHandle,
        child: builder(sheetContext),
      );
    },
  );
}
