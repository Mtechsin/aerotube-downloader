import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/playlist_info.dart';

class PlaylistVideoCard extends StatelessWidget {
  final PlaylistVideoItem video;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  const PlaylistVideoCard({
    super.key,
    required this.video,
    required this.isSelected,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Selection Style Logic (matching DownloadItemCard)
    final borderColor = isSelected 
        ? colorScheme.primary.withValues(alpha: 0.5) 
        : theme.colorScheme.onSurface.withValues(alpha: 0.1);
        
    final backgroundColor = isSelected 
        ? colorScheme.primary.withValues(alpha: 0.15) 
        : theme.colorScheme.surfaceContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onLongPress: onToggleSelection,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: InkWell(
            onTap: onToggleSelection,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Align to top for larger thumbnail
                children: [
                  // Thumbnail (Larger & Immersive)
                  Container(
                    width: 180, // Increased for immersion (16:9 approx)
                    height: 101, 
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      color: Colors.black26, 
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        video.thumbnailUrl != null
                            ? CachedNetworkImage(
                                imageUrl: video.thumbnailUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 360, // Optimize memory (2x width)
                                placeholder: (context, url) => Container(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.black26,
                                  child: const Icon(Icons.music_note, color: Colors.white54),
                                ),
                              )
                            : Container(
                                color: Colors.black26,
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                        
                        // Gradient Overlay for better text readability if needed, keeping it clean for now
                        
                        // Duration badge
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              video.formattedDuration,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8), // Align with top of thumbnail nicely
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? colorScheme.primary : theme.colorScheme.onSurface,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              child: Icon(Icons.person, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                            const SizedBox(width: 8),
                            Expanded( // Use Flexible if needed, but Expanded is fine here because of maxLines
                              child: Text(
                                video.channel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Checkbox
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0, top: 2), // Align somewhat with title
                    child: Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => onToggleSelection(),
                        activeColor: colorScheme.primary,
                        checkColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.3), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
