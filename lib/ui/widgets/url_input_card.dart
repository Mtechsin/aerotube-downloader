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
    final errorHelper = hasError
        ? ErrorHelper.parse(widget.errorMessage!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Input Card
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 30,
                spreadRadius: -5,
                offset: const Offset(0, 8),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Row(
              children: [
                const SizedBox(width: 8),
                // URL Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasError
                        ? theme.colorScheme.error.withValues(alpha: 0.1)
                        : _isFocused
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.link_rounded,
                    color: hasError
                        ? theme.colorScheme.error
                        : _isFocused
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Text Input
                Expanded(
                  child: Focus(
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
                      decoration: InputDecoration(
                        hintText: 'Paste YouTube URL here...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.35,
                          ),
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 20,
                        ),
                        suffixIcon: widget.controller.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                onPressed: () {
                                  widget.controller.clear();
                                  setState(() {});
                                },
                              )
                            : null,
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
                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Paste Button
                    _buildIconButton(
                      icon: Icons.content_paste_rounded,
                      tooltip: 'Paste from clipboard',
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          widget.controller.text = data!.text!;
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    // Fetch Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: FilledButton(
                        onPressed:
                            widget.isLoading || widget.controller.text.isEmpty
                            ? null
                            : widget.onFetch,
                        style: FilledButton.styleFrom(
                          backgroundColor: hasError
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: widget.isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Fetch',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),

        // Error Message
        if (hasError && errorHelper != null)
          Container(
                margin: const EdgeInsets.only(top: 16, left: 8, right: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                      theme.colorScheme.errorContainer.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            errorHelper.friendlyMessage,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (errorHelper.suggestion != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              errorHelper.suggestion!,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 13,
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

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
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
      margin: const EdgeInsets.only(top: 16, left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
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
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              status,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0);
  }
}
