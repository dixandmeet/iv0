/// Lien générique entre un canal de discussion et un objet métier (annonce,
/// mission, équipe, véhicule…). Mappe la table `conversation_contexts`.
///
/// Le rendu (en-tête, carte) est piloté côté client par [contextType] via le
/// `ConversationContextRegistry`. Le [payload] contient l'objet sérialisé
/// (pour `service_exchange` : l'annonce JSON).
class ConversationContext {
  final String contextType;
  final String contextId;
  final String? role;
  final Map<String, dynamic>? payload;

  const ConversationContext({
    required this.contextType,
    required this.contextId,
    this.role,
    this.payload,
  });

  factory ConversationContext.fromJson(Map<String, dynamic> json) {
    return ConversationContext(
      contextType: json['context_type'] as String,
      contextId: json['context_id'] as String,
      role: json['role'] as String?,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
    );
  }
}
