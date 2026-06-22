import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/traveler_comment.dart';
import '../../theme/app_fonts.dart';
import '../../theme/aule_theme.dart';

class TravelerCommentCard extends StatelessWidget {
  final TravelerComment comment;
  final bool compact;
  final bool hasReacted;
  final VoidCallback? onReact;
  final VoidCallback? onReport;

  const TravelerCommentCard({
    super.key,
    required this.comment,
    this.compact = false,
    this.hasReacted = false,
    this.onReact,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);

    if (comment.isHiddenByModeration) {
      return _ModeratedCommentCard(comment: comment, compact: compact);
    }

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.line),
        boxShadow: AuleTokens.cardShadow(colors.shadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(comment: comment),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          comment.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: hankenGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: colors.text,
                          ),
                        ),
                        const _CertifiedBadge(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      compact
                          ? '${comment.lineName} • ${comment.stopName} • ${comment.elapsedLabel}'
                          : '${comment.lineName} • ${comment.vehicleName} • ${comment.stopName} • ${comment.elapsedLabel}',
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: hankenGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.muted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact)
                IconButton(
                  tooltip: 'Signaler',
                  onPressed: onReport,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    LucideIcons.flag,
                    size: 18,
                    color: colors.muted,
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          Text(
            comment.message,
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.text,
              height: 1.35,
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          Row(
            children: [
              _CategoryPill(category: comment.category),
              const Spacer(),
              _ReactionCount(
                count: comment.reactionCount,
                hasReacted: hasReacted,
                onTap: onReact,
              ),
              if (compact) ...[
                const SizedBox(width: 10),
                InkWell(
                  onTap: onReport,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3,
                    ),
                    child: Text(
                      'Signaler',
                      style: hankenGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final TravelerComment comment;

  const _Avatar({required this.comment});

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.brandWeak,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.brandLine),
      ),
      alignment: Alignment.center,
      child: Text(
        comment.initials,
        style: hankenGrotesk(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: colors.brand,
        ),
      ),
    );
  }
}

class _CertifiedBadge extends StatelessWidget {
  const _CertifiedBadge();

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.brandWeak,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.shieldCheck, size: 12, color: colors.brand),
          const SizedBox(width: 4),
          Text(
            'Voyageur certifié',
            style: hankenGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: colors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final TravelerCommentCategory category;

  const _CategoryPill({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        'Catégorie : ${category.label}',
        style: hankenGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ReactionCount extends StatelessWidget {
  final int count;
  final bool hasReacted;
  final VoidCallback? onTap;

  const _ReactionCount({
    required this.count,
    required this.hasReacted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    final fg = hasReacted ? colors.brand : colors.muted;
    final bg = hasReacted ? colors.brandWeak : Colors.transparent;

    return Semantics(
      button: true,
      selected: hasReacted,
      label: 'Réagir au commentaire',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasReacted ? LucideIcons.thumbsUp : LucideIcons.thumbsUp,
                  size: 15,
                  color: fg,
                ),
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeratedCommentCard extends StatelessWidget {
  final TravelerComment comment;
  final bool compact;

  const _ModeratedCommentCard({
    required this.comment,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.line),
        boxShadow: AuleTokens.cardShadow(colors.shadow),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.eyeOff, size: 18, color: colors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ce commentaire est en cours de modération.',
                  style: hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                    height: 1.3,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${comment.lineName} • ${comment.stopName} • ${comment.elapsedLabel}',
                    style: hankenGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
