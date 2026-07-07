import 'package:flutter/material.dart';

import '../../models/driver/service_exchange_post.dart';
import '../../models/platform/conversation_context.dart';
import '../../screens/driver/service_exchange_detail_screen.dart';
import '../../theme/driver_home_palette.dart';
import '../driver/service_exchange_chat_card.dart';

/// Builder de widget pour un type de contexte de conversation.
typedef ConversationContextWidgetBuilder = Widget Function(
  BuildContext context,
  ConversationContext ctx,
);

/// Registre générique : associe un `context_type` aux widgets de rendu
/// (carte live + bandeau d'en-tête) affichés dans la messagerie.
///
/// Ajouter un nouveau contexte (mission, équipe, véhicule…) = enregistrer un
/// builder, sans toucher aux composants de messagerie.
abstract final class ConversationContextRegistry {
  static final Map<String, ConversationContextWidgetBuilder> _cards = {};
  static final Map<String, ConversationContextWidgetBuilder> _headers = {};
  static bool _initialized = false;

  static void register(
    String contextType, {
    ConversationContextWidgetBuilder? card,
    ConversationContextWidgetBuilder? header,
  }) {
    if (card != null) _cards[contextType] = card;
    if (header != null) _headers[contextType] = header;
  }

  static bool supports(String contextType) =>
      _cards.containsKey(contextType) || _headers.containsKey(contextType);

  static Widget? buildCard(BuildContext context, ConversationContext ctx) {
    ensureRegistered();
    final builder = _cards[ctx.contextType];
    if (builder == null || ctx.payload == null) return null;
    return builder(context, ctx);
  }

  static Widget? buildHeader(BuildContext context, ConversationContext ctx) {
    ensureRegistered();
    final builder = _headers[ctx.contextType];
    if (builder == null || ctx.payload == null) return null;
    return builder(context, ctx);
  }

  /// Enregistre les contextes v1 (idempotent).
  static void ensureRegistered() {
    if (_initialized) return;
    _initialized = true;

    register(
      'service_exchange',
      card: (context, ctx) {
        final post = ServiceExchangePost.fromJson(ctx.payload!);
        return ServiceExchangeChatCard(
          post: post,
          onView: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ServiceExchangeDetailScreen(postId: post.id),
            ),
          ),
        );
      },
      header: (context, ctx) {
        final post = ServiceExchangePost.fromJson(ctx.payload!);
        final ref = post.serviceRefLabel;
        final subtitle = [
          '${post.serviceDateLabel} · ${post.periodLabel}',
          if (ref != null) ref,
        ].join(' · ');
        return _ServiceExchangeHeaderBanner(post: post, subtitle: subtitle);
      },
    );
  }
}

class _ServiceExchangeHeaderBanner extends StatelessWidget {
  final ServiceExchangePost post;
  final String subtitle;

  const _ServiceExchangeHeaderBanner({
    required this.post,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        color: DriverHomePalette.lightGreen,
        border: Border(
          bottom: BorderSide(color: DriverHomePalette.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${post.postKind.emoji} Échange de service',
                        style: const TextStyle(
                          color: DriverHomePalette.textDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        )),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: post.statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        post.statusLabel,
                        style: TextStyle(
                          color: post.statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ServiceExchangeDetailScreen(postId: post.id),
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: DriverHomePalette.primary,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Voir',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
