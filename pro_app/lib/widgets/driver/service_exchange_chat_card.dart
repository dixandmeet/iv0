import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/driver/service_exchange_post.dart';
import '../../theme/driver_home_palette.dart';

/// Carte « live » d'une annonce affichée dans une conversation.
///
/// Rendue par le `ConversationContextRegistry` pour le `context_type`
/// `service_exchange`. Reflète l'état courant de l'annonce (statut, horaires).
class ServiceExchangeChatCard extends StatelessWidget {
  final ServiceExchangePost post;
  final VoidCallback? onView;

  const ServiceExchangeChatCard({
    super.key,
    required this.post,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final ref = post.serviceRefLabel;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DriverHomePalette.border),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(post.postKind.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Échange de service',
                  style: TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              _StatusPill(post: post),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.title,
            style: const TextStyle(
              color: DriverHomePalette.textDark,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          _line(LucideIcons.calendarDays,
              '${post.serviceDateLabel} · ${post.periodLabel}'),
          if (ref != null) ...[
            const SizedBox(height: 3),
            _line(LucideIcons.bus, ref),
          ],
          if (post.depotName != null) ...[
            const SizedBox(height: 3),
            _line(LucideIcons.mapPin, post.depotName!),
          ],
          if (onView != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onView,
                style: TextButton.styleFrom(
                  foregroundColor: DriverHomePalette.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(LucideIcons.arrowUpRight, size: 16),
                label: const Text('Voir l\'annonce',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: DriverHomePalette.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: DriverHomePalette.textDark,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ServiceExchangePost post;
  const _StatusPill({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: post.statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        post.statusLabel,
        style: TextStyle(
          color: post.statusColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
