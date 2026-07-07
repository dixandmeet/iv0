import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';

/// Vues Hub : Activité, Discussions, Notifications, Tâches, Documents.
enum HubView { activity, discussions, notifications, tasks, documents }

/// Moteur unique — mêmes données, filtres différents.
class HubEngine with ChangeNotifier {
  HubEngine({required SupabaseService supabaseService})
      : _supabase = supabaseService;

  final SupabaseService _supabase;

  HubView _view = HubView.activity;
  bool _loading = false;
  String? _error;

  List<PlatformResourceEvent> _activity = [];
  List<HubDiscussion> _discussions = [];
  List<PlatformNotification> _notifications = [];
  List<PlatformTask> _tasks = [];
  List<PlatformFile> _files = [];

  final Set<HubView> _loaded = {};

  int _unreadNotifications = 0;
  int _unreadDiscussions = 0;

  RealtimeChannel? _notifChannel;
  RealtimeChannel? _eventsChannel;

  /// Invoqué pour chaque notification insérée en temps réel — branché par la
  /// coquille pour relayer vers une bannière système (notifications locales).
  ValueChanged<PlatformNotification>? onIncomingNotification;

  HubView get view => _view;
  bool get loading => _loading;
  String? get error => _error;

  bool hasLoaded(HubView v) => _loaded.contains(v);

  List<PlatformResourceEvent> get activity => List.unmodifiable(_activity);
  List<HubDiscussion> get discussions => List.unmodifiable(_discussions);
  List<PlatformNotification> get notifications =>
      List.unmodifiable(_notifications);
  List<PlatformTask> get tasks => List.unmodifiable(_tasks);
  List<PlatformFile> get files => List.unmodifiable(_files);

  /// Non-lus serveur (indépendant de la vue chargée) — alimente les badges.
  int get unreadNotificationCount => _unreadNotifications;
  int get unreadDiscussionCount => _unreadDiscussions;

  /// Badge global du menu : notifications + discussions non lues.
  int get badgeCount => _unreadNotifications + _unreadDiscussions;

  Future<void> setView(HubView next) async {
    if (_view == next) return;
    _view = next;
    notifyListeners();
    // Ne recharge que si la vue n'a jamais été chargée (pull-to-refresh force).
    if (!_loaded.contains(next)) {
      await refresh();
    }
  }

  Future<void> refresh({HubView? viewOverride}) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) return;

    final v = viewOverride ?? _view;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final viewKey = switch (v) {
        HubView.activity => 'activity',
        HubView.discussions => 'discussions',
        HubView.notifications => 'notifications',
        HubView.tasks => 'tasks',
        HubView.documents => 'documents',
      };

      final raw = await client.rpc('get_hub_feed', params: {
        'p_view': viewKey,
        'p_limit': 50,
      });

      final list = _asList(raw);

      switch (v) {
        case HubView.activity:
          _activity = list
              .map((e) => PlatformResourceEvent.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
        case HubView.discussions:
          _discussions =
              list.map((e) => HubDiscussion.fromJson(e)).toList();
        case HubView.notifications:
          _notifications = list
              .map((e) => PlatformNotification.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
          _unreadNotifications =
              _notifications.where((n) => n.isUnread).length;
        case HubView.tasks:
          _tasks = list
              .map((e) => PlatformTask.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        case HubView.documents:
          _files = list
              .map((e) => PlatformFile.fromJson(Map<String, dynamic>.from(e)))
              .toList();
      }
      _loaded.add(v);
    } catch (e) {
      debugPrint('Aule: hub refresh failed ($e)');
      _error = 'Impossible de charger l\'activité';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Compteurs non-lus pour les badges, sans charger les listes.
  Future<void> refreshCounts() async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) return;
    try {
      final raw = await client.rpc('get_unread_counts');
      if (raw is Map) {
        _unreadNotifications = (raw['notifications'] as num?)?.toInt() ?? 0;
        _unreadDiscussions = (raw['discussions'] as num?)?.toInt() ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Aule: refreshCounts failed ($e)');
    }
  }

  Future<void> markNotificationRead(String id) async {
    final client = _supabase.client;
    if (client == null) return;
    final target = _notifications.firstWhere(
      (n) => n.id == id,
      orElse: () => throw StateError('notification introuvable'),
    );
    if (!target.isUnread) return;
    await client.from(Tables.userNotifications).update({
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
    _notifications = _notifications
        .map((n) => n.id == id ? n.copyWith(readAt: DateTime.now()) : n)
        .toList();
    _unreadNotifications = _notifications.where((n) => n.isUnread).length;
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    final client = _supabase.client;
    if (client == null) return;
    if (_unreadNotifications == 0) return;
    try {
      await client.rpc('mark_all_notifications_read');
      final now = DateTime.now();
      _notifications = _notifications
          .map((n) => n.isUnread ? n.copyWith(readAt: now) : n)
          .toList();
      _unreadNotifications = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Aule: markAllNotificationsRead failed ($e)');
    }
  }

  /// Bascule le statut d'une tâche (assigned/in_progress/completed).
  Future<void> setTaskStatus(String taskId, String status) async {
    final client = _supabase.client;
    if (client == null) return;
    try {
      await client.from(Tables.channelTasks).update({
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', taskId);
      // La vue Tâches n'affiche que les non-complétées : on retire si terminé.
      if (status == 'completed') {
        _tasks = _tasks.where((t) => t.id != taskId).toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Aule: setTaskStatus failed ($e)');
    }
  }

  void subscribeRealtime(String userId) {
    final client = _supabase.client;
    if (client == null) return;
    _notifChannel?.unsubscribe();
    _eventsChannel?.unsubscribe();

    _notifChannel = client
        .channel('hub-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: Tables.userNotifications,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            refreshCounts();
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              try {
                onIncomingNotification?.call(
                  PlatformNotification.fromJson(
                    Map<String, dynamic>.from(record),
                  ),
                );
              } catch (e) {
                debugPrint('Aule: notif payload parse failed ($e)');
              }
            }
            if (_view == HubView.notifications) {
              refresh(viewOverride: HubView.notifications);
            }
          },
        )
        .subscribe();
  }

  void disposeEngine() {
    _notifChannel?.unsubscribe();
    _eventsChannel?.unsubscribe();
  }

  List<Map<String, dynamic>> _asList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }
}
