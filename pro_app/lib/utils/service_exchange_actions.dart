import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/driver/service_exchange_post.dart';
import '../screens/hub/channel_discussion_screen.dart';
import '../services/auth_service.dart';
import '../services/driver/service_exchange_service.dart';
import '../services/platform/conversation_context_service.dart';
import '../services/platform/discussion_service.dart';

/// Action transverse « Contacter l'auteur » : ouvre/recycle un DM 1:1 lié à
/// l'annonce, envoie un premier message d'intérêt, puis ouvre la conversation.
abstract final class ServiceExchangeActions {
  static Future<void> contactAuthor(
    BuildContext context,
    ServiceExchangePost post,
  ) async {
    final service = context.read<ServiceExchangeService>();
    final discussion = context.read<DiscussionService>();
    final ctxService = context.read<ConversationContextService>();
    final userId = context.read<AuthService>().profile?.id;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final result = await service.contactAuthor(post.id);
    if (result == null) {
      messenger.showSnackBar(SnackBar(
        content: Text(service.error ?? 'Impossible de contacter l\'auteur'),
      ));
      return;
    }

    if (userId != null) {
      await discussion.openChannel(result.channelId, userId: userId);
      await discussion.sendMessage(
        senderId: userId,
        body: 'Bonjour, je suis intéressé(e) par votre annonce : ${post.title}',
        linkedEntityType: 'service_exchange_post',
        linkedEntityId: post.id,
      );
      await ctxService.load(result.channelId);
    }

    if (!context.mounted) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChannelDiscussionScreen(
          channelId: result.channelId,
          title: 'Échange de service',
        ),
      ),
    );
  }
}
