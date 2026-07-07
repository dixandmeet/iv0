import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';

/// Fil de discussion d'un canal (capability discussion).
class DiscussionService with ChangeNotifier {
  DiscussionService({required SupabaseService supabaseService})
      : _supabase = supabaseService;

  final SupabaseService _supabase;

  static const quickReplies = [
    'Bien reçu',
    'Je suis bloqué',
    'Besoin assistance',
    'Retard en cours',
    'Véhicule complet',
  ];

  String? _channelId;
  List<PlatformMessage> _messages = [];
  final Map<String, _SenderProfile> _senders = {};
  bool _loading = false;
  bool _sending = false;
  String? _error;
  RealtimeChannel? _channel;

  String? get channelId => _channelId;
  List<PlatformMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get sending => _sending;
  String? get error => _error;

  String? senderName(String? senderId) =>
      senderId == null ? null : _senders[senderId]?.name;
  String? senderAvatar(String? senderId) =>
      senderId == null ? null : _senders[senderId]?.avatarUrl;

  Future<void> openChannel(String channelId, {String? userId}) async {
    if (_channelId == channelId) return;
    _channel?.unsubscribe();
    _channelId = channelId;
    _messages = [];
    _senders.clear();
    notifyListeners();
    await _ensureAccess(channelId);
    await _loadSenders(channelId);
    await fetchMessages();
    _subscribe(channelId);
    if (userId != null) await markRead(userId);
  }

  /// Garantit l'adhésion + le rôle can_write (sinon l'insert de message
  /// est rejeté par la RLS). Géré côté serveur (RPC SECURITY DEFINER).
  Future<void> _ensureAccess(String channelId) async {
    final client = _supabase.client;
    if (client == null) return;
    try {
      await client.rpc('ensure_self_channel_access', params: {
        'p_channel_id': channelId,
      });
    } catch (e) {
      debugPrint('Aule: ensureAccess failed ($e)');
    }
  }

  Future<void> _loadSenders(String channelId) async {
    final client = _supabase.client;
    if (client == null) return;
    try {
      final rows = await client.rpc('get_channel_member_profiles', params: {
        'p_channel_id': channelId,
      });
      if (rows is List) {
        for (final r in rows) {
          final map = Map<String, dynamic>.from(r as Map);
          final id = map['id'] as String?;
          if (id == null) continue;
          _senders[id] = _SenderProfile(
            name: (map['display_name'] as String?)?.trim().isNotEmpty == true
                ? map['display_name'] as String
                : 'Membre',
            avatarUrl: map['avatar_url'] as String?,
          );
        }
      }
    } catch (e) {
      debugPrint('Aule: loadSenders failed ($e)');
    }
  }

  Future<void> openForResource(String resourceId, {String? userId}) async {
    final client = _supabase.client;
    if (client == null) return;
    final channelId = await client.rpc('ensure_discussion_channel', params: {
      'p_resource_id': resourceId,
    });
    if (channelId is String) {
      await openChannel(channelId, userId: userId);
    }
  }

  Future<void> fetchMessages({bool silent = false}) async {
    final client = _supabase.client;
    if (client == null || _channelId == null) return;

    if (!silent) {
      _loading = true;
      notifyListeners();
    }

    try {
      final rows = await client
          .from(Tables.messages)
          .select()
          .eq('channel_id', _channelId!)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: true)
          .limit(100);
      _messages = (rows as List)
          .map((r) => PlatformMessage.fromJson(r as Map<String, dynamic>))
          .toList();
      _error = null;
    } catch (e) {
      debugPrint('Aule: fetchMessages failed ($e)');
      _error = 'Impossible de charger les messages';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage({
    required String senderId,
    required String body,
    PlatformMessageType type = PlatformMessageType.text,
    String? linkedEntityType,
    String? linkedEntityId,
  }) async {
    final client = _supabase.client;
    final text = body.trim();
    if (client == null || _channelId == null || text.isEmpty) return false;

    _sending = true;
    notifyListeners();

    try {
      final msg = PlatformMessage(
        id: '',
        channelId: _channelId!,
        senderId: senderId,
        messageType: type,
        body: text,
        linkedEntityType: linkedEntityType,
        linkedEntityId: linkedEntityId,
        createdAt: DateTime.now(),
      );
      await client.from(Tables.messages).insert(msg.toInsertJson(
            channelId: _channelId!,
            senderId: senderId,
          ));
      await fetchMessages(silent: true);
      return true;
    } catch (e) {
      debugPrint('Aule: sendMessage failed ($e)');
      _error = 'Échec de l\'envoi';
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String userId) async {
    final client = _supabase.client;
    if (client == null || _channelId == null) return;
    await client.from(Tables.channelMembers).update({
      'last_read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('channel_id', _channelId!).eq('user_id', userId);
  }

  void _subscribe(String channelId) {
    final client = _supabase.client;
    if (client == null) return;
    // Couvre insert/update/delete (édition, suppression douce, nouveaux messages).
    _channel = client
        .channel('discussion-$channelId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: Tables.messages,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel_id',
            value: channelId,
          ),
          callback: (_) => fetchMessages(silent: true),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

class _SenderProfile {
  final String name;
  final String? avatarUrl;
  const _SenderProfile({required this.name, this.avatarUrl});
}
