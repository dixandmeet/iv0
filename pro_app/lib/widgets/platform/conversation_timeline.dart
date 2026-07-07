import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/platform/conversation_event.dart';
import '../../services/platform/conversation_context_service.dart';
import '../../theme/driver_home_palette.dart';

/// Timeline générique d'une conversation : rend les `resource_events` scellés
/// au canal (confidentialité 1:1) renvoyés par `get_conversation_timeline`.
class ConversationTimeline extends StatelessWidget {
  final String channelId;

  const ConversationTimeline({super.key, required this.channelId});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ConversationContextService>();
    final events = service.timelineFor(channelId);
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.history,
                  size: 14, color: DriverHomePalette.textSecondary),
              SizedBox(width: 6),
              Text(
                'Historique',
                style: TextStyle(
                  color: DriverHomePalette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...events.map((e) => _TimelineRow(event: e)),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final ConversationEvent event;
  const _TimelineRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: DriverHomePalette.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.timelineLabel,
                  style: const TextStyle(
                    color: DriverHomePalette.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  event.timeLabel,
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
