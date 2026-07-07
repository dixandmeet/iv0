import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/feed_post.dart';
import '../../screens/driver/driver_feed_video_screen.dart';
import '../../services/driver/driver_service.dart';
import '../../services/driver/feed_service.dart';
import '../../theme/driver_home_palette.dart';
import 'driver_avatar.dart';
import 'feed_comments_sheet.dart';

/// Carte d'un post du fil d'actualité (auteur, texte, média, like, commentaires).
class FeedPostCard extends StatelessWidget {
  final FeedPost post;
  final bool canDelete;
  final VoidCallback? onDelete;

  const FeedPostCard({
    super.key,
    required this.post,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DriverHomePalette.border),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              14,
              canDelete ? 6 : 14,
              post.hasBody || post.hasImage || post.hasVideo ? 10 : 14,
            ),
            child: Row(
              children: [
                DriverAvatarCompact(
                  initials: post.authorInitials,
                  imageUrl: post.authorAvatarUrl,
                  size: 40,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DriverHomePalette.textDark,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _relativeTime(post.createdAt),
                        style: const TextStyle(
                          color: DriverHomePalette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(LucideIcons.trash2, size: 18),
                    color: DriverHomePalette.textSecondary,
                    tooltip: 'Supprimer',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          if (post.hasBody)
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                (post.hasImage || post.hasVideo) ? 12 : 16,
              ),
              child: Text(
                post.body!.trim(),
                style: const TextStyle(
                  color: DriverHomePalette.textDark,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            ),
          if (post.hasImage) _PostImage(post: post),
          if (post.hasVideo) _PostVideoThumb(post: post),
          _ActionsRow(post: post),
        ],
      ),
    );
  }

  /// Horodatage relatif en français (« à l'instant », « il y a 5 min »…).
  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return DateFormat('d MMM', 'fr_FR').format(date);
  }
}

class _PostImage extends StatelessWidget {
  final FeedPost post;

  const _PostImage({required this.post});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Image.network(
        post.mediaUrl!,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 200,
            color: DriverHomePalette.softGreen.withValues(alpha: 0.4),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DriverHomePalette.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PostVideoThumb extends StatelessWidget {
  final FeedPost post;

  const _PostVideoThumb({required this.post});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DriverFeedVideoScreen(videoUrl: post.mediaUrl!),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (post.mediaThumbnailUrl != null)
              Image.network(
                post.mediaThumbnailUrl!,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 220,
                  color: Colors.black87,
                ),
              )
            else
              Container(height: 220, color: Colors.black87),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.play,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  final FeedPost post;

  const _ActionsRow({required this.post});

  @override
  Widget build(BuildContext context) {
    final driverId = context.watch<DriverService>().driver?.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: Row(
        children: [
          _ActionButton(
            icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
            iconColor:
                post.likedByMe ? DriverHomePalette.danger : null,
            label: post.likesCount > 0 ? '${post.likesCount}' : 'J\'aime',
            onTap: driverId == null
                ? null
                : () => context.read<FeedService>().toggleLike(
                      post,
                      driverId,
                    ),
          ),
          const SizedBox(width: 4),
          _ActionButton(
            icon: LucideIcons.messageCircle,
            label: post.commentsCount > 0
                ? '${post.commentsCount}'
                : 'Commenter',
            onTap: () => openFeedComments(context, post),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: iconColor ?? DriverHomePalette.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: iconColor ?? DriverHomePalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
