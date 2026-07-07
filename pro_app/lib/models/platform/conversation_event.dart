import 'package:intl/intl.dart';

/// Événement de cycle de vie d'une conversation, mappé depuis `resource_events`.
///
/// Générique : le même modèle sert annonce, mission, équipe… Le libellé humain
/// est dérivé d'[eventType] et du [payload].
class ConversationEvent {
  final String eventType;
  final String? actorDisplay;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const ConversationEvent({
    required this.eventType,
    this.actorDisplay,
    this.payload = const {},
    required this.createdAt,
  });

  factory ConversationEvent.fromJson(Map<String, dynamic> json) {
    return ConversationEvent(
      eventType: json['event_type'] as String,
      actorDisplay: json['actor_display'] as String?,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  /// Libellé de timeline lisible (FR).
  String get timelineLabel {
    switch (eventType) {
      case 'published':
        return 'Annonce publiée';
      case 'contacted':
        final who = actorDisplay;
        return who != null ? '$who a contacté l\'auteur' : 'Mise en relation';
      case 'modified':
        final changes = payload['changes'];
        if (changes is List && changes.isNotEmpty) {
          return 'Annonce modifiée · ${changes.join(', ')}';
        }
        return 'Annonce modifiée';
      case 'resolved':
        return 'Échange confirmé';
      case 'cancelled':
        return 'Annonce annulée';
      case 'closed':
        return 'Discussions clôturées';
      case 'relanced':
        return 'Annonce relancée';
      default:
        return eventType;
    }
  }

  String get timeLabel => DateFormat('d MMM · HH:mm', 'fr_FR').format(createdAt);
}
