import 'package:material_symbols_icons/symbols.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';

/// A 16:9 video thumbnail tile with rounded corners, duration chip,
/// skeleton shimmer placeholder, and cached network image loading.
class ThumbnailTile extends StatefulWidget {
  final String? imageUrl;
  final File? imageFile;
  final String? imagePath;
  final String? duration;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallback;
  final Widget? overlay;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const ThumbnailTile({
    super.key,
    this.imageUrl,
    this.imageFile,
    this.imagePath,
    this.duration,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallback,
    this.overlay,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  State<ThumbnailTile> createState() => _ThumbnailTileState();
}

class _ThumbnailTileState extends State<ThumbnailTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.aero;
    final radius = widget.borderRadius ?? AeroRadius.mdBorderRadius;
    final effectiveMotion = appMotionDuration(
      context,
      const Duration(milliseconds: 1500),
    );

    Widget content = AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: radius,
          border: Border.all(color: colors.outline, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImage(context, colors, effectiveMotion),
            if (widget.overlay != null) widget.overlay!,
            if (widget.duration != null && widget.duration!.isNotEmpty)
              Positioned(
                right: AeroSpace.sm,
                bottom: AeroSpace.sm,
                child: _buildDurationChip(context),
              ),
          ],
        ),
      ),
    );

    if (widget.width != null || widget.height != null) {
      content = SizedBox(
        width: widget.width,
        height: widget.height,
        child: content,
      );
    }

    if (widget.onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          child: content,
        ),
      );
    }

    return Semantics(
      label: widget.semanticsLabel ?? 'Video thumbnail',
      button: widget.onTap != null,
      child: content,
    );
  }

  Widget _buildImage(
    BuildContext context,
    AeroColors colors,
    Duration effectiveMotion,
  ) {
    if (widget.imageFile != null && widget.imageFile!.existsSync()) {
      return Image.file(
        widget.imageFile!,
        fit: widget.fit,
        cacheWidth: 480,
        errorBuilder: (context, _, __) => _buildFallback(colors),
      );
    }

    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      final file = File(widget.imagePath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: widget.fit,
          cacheWidth: 480,
          errorBuilder: (context, _, __) => _buildFallback(colors),
        );
      }
    }

    final url = widget.imageUrl?.trim();

    if (url == null || url.isEmpty) {
      return _buildFallback(colors);
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      placeholder: (context, _) =>
          _buildShimmerSkeleton(colors, effectiveMotion),
      errorWidget: (context, _, __) => _buildFallback(colors),
    );
  }

  Widget _buildFallback(AeroColors colors) {
    if (_shimmerController.isAnimating) {
      _shimmerController.stop();
    }
    if (widget.fallback != null) {
      return widget.fallback!;
    }

    return Center(
      child: Icon(
        Symbols.play_circle_rounded,
        size: 32,
        color: colors.onSurfaceFaint,
      ),
    );
  }

  Widget _buildShimmerSkeleton(AeroColors colors, Duration effectiveMotion) {
    if (!_shimmerController.isAnimating && effectiveMotion > Duration.zero) {
      _shimmerController.repeat();
    }

    if (effectiveMotion == Duration.zero) {
      return Container(color: colors.surface2);
    }

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-2.0 + _shimmerController.value * 4.0, -0.3),
              end: Alignment(-0.5 + _shimmerController.value * 4.0, 0.3),
              colors: [colors.surface2, colors.surface3, colors.surface2],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDurationChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Text(
        widget.duration!,
        style: AeroText.tabularFigures(
          AeroText.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
