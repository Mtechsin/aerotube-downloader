import 'package:flutter/material.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';
import 'aero_button.dart';

/// An empty state placeholder displaying a 72 px tonal circle with an icon,
/// title, one-line [AeroText.bodySm] description, and optional primary action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final Widget? actionWidget;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.iconColor,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.actionWidget,
    this.padding = const EdgeInsets.all(AeroSpace.xxl),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 72 px tonal surface2 circle
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: colors.outline, width: 1.0),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 28,
                color: iconColor ?? colors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: AeroSpace.lg),
            // Title
            Text(
              title,
              style: AeroText.title.copyWith(color: colors.onSurface),
              textAlign: TextAlign.center,
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: AeroSpace.xs + 2),
              // One-line secondary body text
              Text(
                description!,
                style: AeroText.bodySm.copyWith(color: colors.onSurfaceMuted),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (actionWidget != null ||
                (actionLabel != null && onAction != null)) ...[
              const SizedBox(height: AeroSpace.xxl),
              if (actionWidget != null)
                actionWidget!
              else
                _buildActionButtons(context, colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AeroColors colors) {
    final hasSecondary =
        secondaryActionLabel != null && onSecondaryAction != null;

    final primaryButton = AeroButton(
      text: actionLabel,
      onPressed: onAction,
      variant: AeroButtonVariant.primary,
    );

    if (!hasSecondary) {
      return primaryButton;
    }

    final secondaryButton = AeroButton(
      text: secondaryActionLabel,
      onPressed: onSecondaryAction,
      variant: AeroButtonVariant.tonal,
    );

    return Wrap(
      spacing: AeroSpace.sm,
      runSpacing: AeroSpace.sm,
      alignment: WrapAlignment.center,
      children: [secondaryButton, primaryButton],
    );
  }
}
