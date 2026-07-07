import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/platform/conversation_context_service.dart';
import 'conversation_context_registry.dart';

/// En-tête de conversation générique : rend un bandeau par `context_type` via
/// le `ConversationContextRegistry`. Vide si le canal n'a aucun contexte connu.
class ConversationContextHeader extends StatelessWidget {
  final String channelId;

  const ConversationContextHeader({super.key, required this.channelId});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ConversationContextService>();
    final contexts = service.contextsFor(channelId);
    if (contexts.isEmpty) return const SizedBox.shrink();

    final banners = <Widget>[];
    for (final ctx in contexts) {
      final banner = ConversationContextRegistry.buildHeader(context, ctx);
      if (banner != null) banners.add(banner);
    }
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: banners,
    );
  }
}
