import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/tokens/colors.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/typography.dart';

/// A 16:9 video thumbnail tile with rounded corners, duration chip,
/// skeleton shimmer placeholder, and cached network image loading.
class ThumbnailTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = context.aero;
    final radius = widgetOrDefaultRadius();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalW = width ?? 360.0;
    final memCacheWidth = (logicalW * dpr).round().clamp(160, 720);

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
            _buildImage(context, colors, memCacheWidth),
            if (overlay != null) overlay!,
            if (duration != null && duration!.isNotEmpty)
              Positioned(
                right: AeroSpace.sm,
                bottom: AeroSpace.sm,
                child: _buildDurationChip(),
              ),
          ],
        ),
      ),
    );

    if (width != null || height != null) {
      content = SizedBox(width: width, height: height, child: content);
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(onTap: onTap, borderRadius: radius, child: content),
      );
    }

    return Semantics(
      label: semanticsLabel ?? 'Video thumbnail',
      button: onTap != null,
      child: content,
    );
  }

  BorderRadius widgetOrDefaultRadius() =>
      borderRadius ?? AeroRadius.mdBorderRadius;

  Widget _buildImage(
    BuildContext context,
    AeroColors colors,
    int memCacheWidth,
  ) {
    if (imageFile != null) {
      return Image.file(
        imageFile!,
        fit: fit,
        cacheWidth: memCacheWidth,
        errorBuilder: (context, _, __) =>
            _buildNetworkOrFallback(context, colors, memCacheWidth),
      );
    }

    if (imagePath != null && imagePath!.isNotEmpty) {
      return Image.file(
        File(imagePath!),
        fit: fit,
        cacheWidth: memCacheWidth,
        errorBuilder: (context, _, __) =>
            _buildNetworkOrFallback(context, colors, memCacheWidth),
      );
    }

    return _buildNetworkOrFallback(context, colors, memCacheWidth);
  }

  Widget _buildNetworkOrFallback(
    BuildContext context,
    AeroColors colors,
    int memCacheWidth,
  ) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _buildFallback(colors);
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholder: (context, _) => _ThumbnailShimmer(colors: colors),
      errorWidget: (context, _, __) => _buildFallback(colors),
    );
  }

  Widget _buildFallback(AeroColors colors) {
    if (fallback != null) {
      return fallback!;
    }

    return Center(
      child: Icon(
        Symbols.play_circle_rounded,
        size: 32,
        color: colors.onSurfaceFaint,
      ),
    );
  }

  Widget _buildDurationChip() {
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
        duration!,
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

/// Dedicated shimmer widget scoped solely to [CachedNetworkImage.placeholder].
/// Unmounting when the image loads automatically disposes the ticker.
class _ThumbnailShimmer extends StatefulWidget {
  final AeroColors colors;

  const _ThumbnailShimmer({required this.colors});

  @override
  State<_ThumbnailShimmer> createState() => _ThumbnailShimmerState();
}

class _ThumbnailShimmerState extends State<_ThumbnailShimmer>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = appMotionDuration(
      context,
      const Duration(milliseconds: 1200),
    );
    if (motion == Duration.zero) {
      _controller?.stop();
    } else {
      _controller ??= AnimationController(vsync: this, duration: motion);
      if (!_controller!.isAnimating) {
        _controller!.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.isAnimating) {
      return ColoredBox(color: widget.colors.surface2);
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-2.0 + controller.value * 4.0, -0.3),
                end: Alignment(-0.5 + controller.value * 4.0, 0.3),
                colors: [
                  widget.colors.surface2,
                  widget.colors.surface3,
                  widget.colors.surface2,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
