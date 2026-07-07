import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/driver/service_exchange_post.dart';
import '../../theme/driver_home_palette.dart';
import 'driver_avatar.dart';

/// Carte d'une annonce d'échange dans une liste.
class ServiceExchangeCard extends StatelessWidget {
  final ServiceExchangePost post;
  final VoidCallback onTap;
  final VoidCallback? onContact;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onLike;
  final VoidCallback? onAuthorTap;

  const ServiceExchangeCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onContact,
    this.onFavorite,
    this.onShare,
    this.onLike,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final ref = post.serviceRefLabel;
    return Material(
      color: DriverHomePalette.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: post.isUrgent
                  ? DriverHomePalette.warning.withValues(alpha: 0.5)
                  : DriverHomePalette.border,
            ),
            boxShadow: const [
              BoxShadow(
                color: DriverHomePalette.cardShadow,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topChips(),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _serviceBadge(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DriverHomePalette.textDark,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _infoLine(LucideIcons.calendarDays,
                            '${post.serviceDateLabel} · ${post.periodLabel}'),
                        if (ref != null) ...[
                          const SizedBox(height: 2),
                          _infoLine(LucideIcons.bus, ref),
                        ],
                        if (post.depotName != null) ...[
                          const SizedBox(height: 2),
                          _infoLine(LucideIcons.mapPin, post.depotName!),
                        ],
                      ],
                    ),
                  ),
                  if (onFavorite != null)
                    IconButton(
                      onPressed: onFavorite,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        post.isFavorited
                            ? LucideIcons.bookmarkCheck
                            : LucideIcons.bookmark,
                        size: 19,
                        color: post.isFavorited
                            ? DriverHomePalette.primary
                            : DriverHomePalette.textSecondary,
                      ),
                    ),
                ],
              ),
              if (post.message != null && post.message!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.message!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1, color: DriverHomePalette.border),
              const SizedBox(height: 10),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topChips() {
    final chips = <Widget>[];
    chips.add(_statusChip());
    if (post.isUrgent) {
      chips.add(_chip('⚡ Urgent', DriverHomePalette.warning));
    }
    if (post.isNew) {
      chips.add(_chip('✨ Nouvelle', DriverHomePalette.primary));
    }
    if (post.isExpiringSoon) {
      chips.add(_chip('⏳ Bientôt expirée', DriverHomePalette.danger));
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _statusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: post.statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(post.statusIcon, size: 12, color: post.statusColor),
          const SizedBox(width: 5),
          Text(
            post.statusLabel,
            style: TextStyle(
              color: post.statusColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _serviceBadge() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: post.serviceType.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(post.serviceType.emoji, style: const TextStyle(fontSize: 22)),
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: DriverHomePalette.textSecondary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: DriverHomePalette.textSecondary,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    return Row(
      children: [
        GestureDetector(
          onTap: onAuthorTap,
          child: Row(
            children: [
              DriverAvatarCompact(
                initials: post.authorInitials,
                imageUrl: post.authorAvatarUrl,
                size: 28,
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  post.authorLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DriverHomePalette.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _stat(LucideIcons.eye, '${post.viewCount}'),
        const SizedBox(width: 10),
        _stat(LucideIcons.messageCircle, '${post.contactCount}'),
        if (onLike != null) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: onLike,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: Icon(
              LucideIcons.thumbsUp,
              size: 16,
              color: post.myReaction == ServiceExchangeReaction.like
                  ? DriverHomePalette.primary
                  : DriverHomePalette.textSecondary,
            ),
          ),
          if (post.reactionLikes > 0)
            Text(
              '${post.reactionLikes}',
              style: const TextStyle(
                color: DriverHomePalette.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
        if (onShare != null)
          IconButton(
            onPressed: onShare,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(LucideIcons.share2,
                size: 16, color: DriverHomePalette.textSecondary),
          ),
        if (onContact != null && post.canExpressInterest) ...[
          const SizedBox(width: 4),
          _contactButton(),
        ],
      ],
    );
  }

  Widget _contactButton() {
    return ElevatedButton.icon(
      onPressed: onContact,
      style: ElevatedButton.styleFrom(
        backgroundColor: DriverHomePalette.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: const Icon(LucideIcons.send, size: 14),
      label: const Text('Contacter',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
  }

  Widget _stat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: DriverHomePalette.textSecondary),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(
            color: DriverHomePalette.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
