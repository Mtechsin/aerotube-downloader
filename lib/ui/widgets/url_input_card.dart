import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/error_helper.dart';
import '../../providers/video_provider.dart';
import '../components/aero_button.dart';
import '../components/aero_density.dart';
import '../components/url_composer.dart';

/// Compatibility wrapper for older callers. New screens should use
/// [UrlComposer] directly so the URL field has one consistent interaction and
/// visual treatment across the app.
class UrlInputCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onFetch;
  final VoidCallback? onCancel;
  final bool isLoading;
  final String? statusMessage;
  final String? errorMessage;
  final bool showPasteButton;
  final FocusNode? focusNode;

  const UrlInputCard({
    super.key,
    required this.controller,
    required this.onFetch,
    this.onCancel,
    this.isLoading = false,
    this.errorMessage,
    this.statusMessage,
    this.showPasteButton = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final error = errorMessage == null
        ? null
        : ErrorHelper.parse(errorMessage!);
    final canUpdateAndRetry =
        error?.category == ErrorCategory.outdatedTool ||
        error?.category == ErrorCategory.toolUpdate;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UrlComposer(
          controller: controller,
          focusNode: focusNode,
          onFetch: onFetch,
          onCancel: onCancel,
          isLoading: isLoading,
          statusMessage: statusMessage,
          errorMessage: errorMessage,
          showPasteButton: showPasteButton,
          density: AeroDensity.resolve(context),
        ),
        if (canUpdateAndRetry) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AeroButton(
              variant: AeroButtonVariant.tonal,
              text: 'Update tools and retry',
              icon: const Icon(Symbols.refresh_rounded, size: 16),
              onPressed: () =>
                  context.read<VideoProvider>().updateYtdlpAndRetry(),
            ),
          ),
        ],
      ],
    );
  }
}
