import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/utils/error_helper.dart';
import 'glass_card.dart';

class UrlInputCard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onFetch;
  final bool isLoading;
  final String? statusMessage;
  final String? errorMessage;

  const UrlInputCard({
    super.key,
    required this.controller,
    required this.onFetch,
    this.isLoading = false,
    this.errorMessage,
    this.statusMessage,
  });

  @override
  State<UrlInputCard> createState() => _UrlInputCardState();
}

class _UrlInputCardState extends State<UrlInputCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorMessage != null;
    final errorHelper = hasError ? ErrorHelper.parse(widget.errorMessage!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          borderRadius: 100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          opacity: 0.05,
          backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.4),
          border: Border.all(
            color: hasError
                ? theme.colorScheme.error
                : _isFocused
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.15),
            width: 1.2,
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Focus(
                  onFocusChange: (focused) {
                    setState(() => _isFocused = focused);
                  },
                  child: TextField(
                    controller: widget.controller,
                    style: theme.textTheme.bodyLarge?.copyWith(

                      color: theme.colorScheme.onSurface,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Paste YouTube URL here...',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      prefixIcon: Icon(
                        Icons.link_rounded,
                        color: _isFocused ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      suffixIcon: widget.controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
                              onPressed: () {
                                widget.controller.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (widget.controller.text.isNotEmpty) {
                        widget.onFetch();
                      }
                    },
                  ),
                ),
              ),
              // Paste button
              IconButton(
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    widget.controller.text = data!.text!;
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.content_paste_rounded),
                tooltip: 'Paste from clipboard',
                style: IconButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  backgroundColor: Colors.transparent,
                  hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                ),
              ),
              const SizedBox(width: 4),
              // Fetch Button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: FilledButton(
                  onPressed: widget.isLoading || widget.controller.text.isEmpty ? null : widget.onFetch,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    elevation: 0,
                  ),
                  child: widget.isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                          ),
                        )
                      : const Text(
                          'Fetch',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        
        // Error Message
        if (hasError && errorHelper != null)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        errorHelper.friendlyMessage,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (errorHelper.suggestion != null)
                        Text(
                          errorHelper.suggestion!,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0),

        // Status Message (Loading)
        if (widget.isLoading && widget.statusMessage != null)
           _buildLoadingStatus(theme, widget.statusMessage!),
      ],
    );
  }

  Widget _buildLoadingStatus(ThemeData theme, String status) {
    // Choose icon based on status phase
    IconData icon = Icons.hourglass_empty_rounded;
    if (status.contains('Connecting')) {
      icon = Icons.wifi_rounded;
    } else if (status.contains('Fetching') || status.contains('Loading')) {
      icon = Icons.cloud_download_rounded;
    } else if (status.contains('Processing')) {
      icon = Icons.settings_rounded;
    } else if (status.contains('Found playlist')) {
      icon = Icons.playlist_play_rounded;
    } else if (status.contains('Retrying')) {
      icon = Icons.refresh_rounded;
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                status,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha:0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 150.ms);
  }
}
