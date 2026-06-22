import 'package:flutter/material.dart';

import '../../models/driver/driver_message.dart';
import '../supabase_service.dart';

/// Messagerie régulateur ↔ conducteur (table `driver_messages`).
class DriverMessageService with ChangeNotifier {
  final SupabaseService _supabase;

  DriverMessageService({required SupabaseService supabaseService})
      : _supabase = supabaseService;

  /// Réponses rapides proposées au conducteur.
  static const List<String> quickReplies = [
    'Bien reçu',
    'Je suis bloqué',
    'Besoin assistance',
    'Retard en cours',
    'Véhicule complet',
  ];

  List<DriverMessage> _messages = [];
  bool _loading = false;
  bool _sending = false;
  String? _errorMessage;

  List<DriverMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get sending => _sending;
  String? get errorMessage => _errorMessage;

  int get unreadCount =>
      _messages.where((m) => m.isFromRegulator && !m.isRead).length;

  /// Charge le fil de discussion du conducteur (ordre chronologique).
  Future<void> fetchMessages(String driverId, {bool silent = false}) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) return;

    if (!silent) {
      _loading = true;
      notifyListeners();
    }

    try {
      final rows = await client
          .from('driver_messages')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: true)
          .limit(100);
      _messages = (rows as List)
          .map((r) => DriverMessage.fromJson(r as Map<String, dynamic>))
          .toList();
      _errorMessage = null;
    } catch (e) {
      debugPrint('Wazibus: driver messages fetch failed ($e)');
      _errorMessage = 'Impossible de charger les messages';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Envoie une réponse du conducteur puis rafraîchit le fil.
  Future<bool> sendReply(String driverId, String message) async {
    final client = _supabase.client;
    final text = message.trim();
    if (client == null || _supabase.isOfflineMode || text.isEmpty) return false;

    _sending = true;
    notifyListeners();

    try {
      await client.from('driver_messages').insert({
        'driver_id': driverId,
        'sender_type': 'driver',
        'message': text,
        'is_read': true,
      });
      await fetchMessages(driverId, silent: true);
      _sending = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Wazibus: driver message send failed ($e)');
      _errorMessage = 'Échec de l\'envoi du message';
      _sending = false;
      notifyListeners();
      return false;
    }
  }

  /// Marque les messages du régulateur comme lus.
  Future<void> markRegulatorMessagesRead(String driverId) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) return;
    if (unreadCount == 0) return;

    try {
      await client
          .from('driver_messages')
          .update({'is_read': true})
          .eq('driver_id', driverId)
          .eq('sender_type', 'regulator')
          .eq('is_read', false);
      _messages = _messages
          .map((m) => m.isFromRegulator && !m.isRead
              ? DriverMessage(
                  id: m.id,
                  driverId: m.driverId,
                  senderType: m.senderType,
                  message: m.message,
                  isRead: true,
                  createdAt: m.createdAt,
                )
              : m)
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Wazibus: mark messages read failed ($e)');
    }
  }
}
