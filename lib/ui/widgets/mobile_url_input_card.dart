import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/utils/error_helper.dart';

/// Mobile-optimized URL input card with 48dp minimum touch targets
class MobileUrlInputCard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onFetch;
  final bool isLoading;
  final String? statusMessage;
  final String? errorMessage;

  const MobileUrlInputCard({
    super.key,
    required this.controller,
    required this.onFetch,
    this.isLoading = false,
    this.errorMessage,
    this.statusMessage,
  });

  @override
  State<MobileUrlInputCard> createState() => _MobileUrlInputCardState();
}

class _MobileUrlInputCardState extends State<MobileUrlInputCard> {
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorMessage != null;
    final errorHelper = hasError
        ? ErrorHelper.parse(widget.errorMessage!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Input Card - Mobile optimized
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: -3,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: hasError
                  ? theme.colorScheme.error.withValues(alpha: 0.5)
                  : _isFocused
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: hasError
                  ? 2
                  : _isFocused
                  ? 1.5
                  : 1,
            ),
          ),
          child: Column(
            children: [
              // URL Input Row - 56dp minimum height for mobile
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    // URL Icon - 48dp touch target
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.link_rounded,
                        color: hasError
                            ? theme.colorScheme.error
                            : _isFocused
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text Input
                    Expanded(
                      child: Focus(
                        focusNode: _focusNode,
                        onFocusChange: (focused) {
                          setState(() => _isFocused = focused);
                        },
                        child: TextField(
                          controller: widget.controller,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Paste YouTube URL here...',
                            hintStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(vertical: 16),
                            isDense: true,
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
                    const SizedBox(width: 8),
                    // Clear Button - 48dp touch target
                    if (widget.controller.text.isNotEmpty)
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                            size: 24,
                          ),
                          onPressed: () {
                            widget.controller.clear();
                            setState(() {});
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              // Action Buttons Row - 48dp minimum height
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    // Paste Button - 48dp minimum
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null) {
                              widget.controller.text = data!.text!;
                              setState(() {});
                            }
                          },
                          icon: const Icon(
                            Icons.content_paste_rounded,
                            size: 20,
                          ),
                          label: const Text('Paste'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Fetch Button - 48dp minimum, expanded
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed:
                              widget.isLoading || widget.controller.text.isEmpty
                              ? null
                              : widget.onFetch,
                          icon: widget.isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.search_rounded, size: 20),
                          label: Text(
                            widget.isLoading ? 'Fetching...' : 'Fetch Info',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: hasError
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Error Message
        if (hasError && errorHelper != null)
          Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                      theme.colorScheme.errorContainer.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 24,
                      ),
                    ),
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
                              fontSize: 14,
                            ),
                          ),
                          if (errorHelper.suggestion != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              errorHelper.suggestion!,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: -0.2, end: 0, curve: Curves.easeOut),

        // Status Message (Loading)
        if (widget.isLoading && widget.statusMessage != null)
          _buildLoadingStatus(theme, widget.statusMessage!),
      ],
    );
  }

  Widget _buildLoadingStatus(ThemeData theme, String status) {
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

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0);
  }
}
