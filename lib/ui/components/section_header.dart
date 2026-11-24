import 'package:flutter/material.dart';

import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';

/// A section header following the Aero design specification.
///
/// Features:
/// - Label typography style, uppercase, styled in [AeroColors.onSurfaceMuted].
/// - Default 24 px top margin.
/// - Optional trailing action widget (e.g. "Clear all", count pill, or view more).
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;

    final effectiveMargin =
        margin ??
        const EdgeInsets.only(
          top: AeroSpace.xxl, // 24 px
          bottom: AeroSpace.sm, // 8 px
        );

    final titleText = Text(
      title.toUpperCase(),
      style: AeroText.label.copyWith(
        color: colors.onSurfaceMuted,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Padding(
      padding: effectiveMargin,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: trailing == null
            ? titleText
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: titleText),
                  const SizedBox(width: AeroSpace.sm),
                  trailing!,
                ],
              ),
      ),
    );
  }
}
