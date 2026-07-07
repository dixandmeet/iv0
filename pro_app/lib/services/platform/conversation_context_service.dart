import 'package:flutter/foundation.dart';

import '../../models/platform/conversation_context.dart';
import '../../models/platform/conversation_event.dart';
import '../supabase_service.dart';

/// Service générique de contexte de conversation.
///
/// Indépendant du domaine : il lit `conversation_contexts` et `resource_events`
/// pour n'importe quel canal. Le rendu par `context_type` est délégué au
/// `ConversationContextRegistry` côté widgets.
class ConversationContextService with ChangeNotifier {
  ConversationContextService({required SupabaseService supabaseService})
      : _supabase = supabaseService;

  final SupabaseService _supabase;

  final Map<String, List<ConversationContext>> _contexts = {};
  final Map<String, List<ConversationEvent>> _timelines = {};
  bool _loading = false;

  bool get loading => _loading;

  List<ConversationContext> contextsFor(String? channelId) =>
      channelId == null ? const [] : (_contexts[channelId] ?? const []);

  List<ConversationEvent> timelineFor(String? channelId) =>
      channelId == null ? const [] : (_timelines[channelId] ?? const []);

  /// Charge contexte + timeline d'un canal. Silencieux par défaut.
  Future<void> load(String channelId, {bool silent = true}) async {
    final client = _supabase.client;
    if (client == null) return;

    if (!silent) {
      _loading = true;
      notifyListeners();
    }

    try {
      final ctxRaw = await client
          .rpc('get_conversation_context', params: {'p_channel_id': channelId});
      if (ctxRaw is List) {
        _contexts[channelId] = ctxRaw
            .map((e) =>
                ConversationContext.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      final tlRaw = await client
          .rpc('get_conversation_timeline', params: {'p_channel_id': channelId});
      if (tlRaw is List) {
        _timelines[channelId] = tlRaw
            .map((e) =>
                ConversationEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('Aule: conversation context load failed ($e)');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearChannel(String channelId) {
    _contexts.remove(channelId);
    _timelines.remove(channelId);
  }
}
