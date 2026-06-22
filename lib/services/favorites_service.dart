import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Favoris de l'utilisateur : arrêts (par `stopId`) et lignes (par `routeId`).
///
/// Source de vérité = local (SharedPreferences), pour rester offline-first.
/// Quand un passager est connecté (session non anonyme), les favoris sont
/// aussi synchronisés avec la table `user_favorites` de Supabase afin d'être
/// retrouvés sur tous ses appareils.
class FavoritesService extends ChangeNotifier {
  static const _stopsKey = 'favorite_stop_ids';
  static const _linesKey = 'favorite_route_ids';

  static const _kindStop = 'stop';
  static const _kindLine = 'line';

  final SupabaseService? _supabaseService;

  final Set<String> _stopIds = {};
  final Set<String> _routeIds = {};
  bool _loaded = false;

  StreamSubscription<AuthState>? _authSub;
  String? _syncedUserId;

  FavoritesService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService {
    _listenToAuth();
  }

  bool get isLoaded => _loaded;

  // --- Arrêts ---------------------------------------------------------------
  List<String> get stopIds => List.unmodifiable(_stopIds);
  int get count => _stopIds.length;
  bool isFavorite(String stopId) => _stopIds.contains(stopId);

  // --- Lignes ---------------------------------------------------------------
  List<String> get routeIds => List.unmodifiable(_routeIds);
  int get lineCount => _routeIds.length;
  bool isFavoriteLine(String routeId) => _routeIds.contains(routeId);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _stopIds
        ..clear()
        ..addAll(prefs.getStringList(_stopsKey) ?? const []);
      _routeIds
        ..clear()
        ..addAll(prefs.getStringList(_linesKey) ?? const []);
    } catch (e) {
      debugPrint('Aule: favorites load failed ($e)');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggle(String stopId) async {
    final added = _stopIds.add(stopId);
    if (!added) _stopIds.remove(stopId);
    notifyListeners();
    await _persist(_stopsKey, _stopIds);
    unawaited(_pushRemoteChange(_kindStop, stopId, added));
  }

  Future<void> toggleLine(String routeId) async {
    final added = _routeIds.add(routeId);
    if (!added) _routeIds.remove(routeId);
    notifyListeners();
    await _persist(_linesKey, _routeIds);
    unawaited(_pushRemoteChange(_kindLine, routeId, added));
  }

  Future<void> _persist(String key, Set<String> values) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, values.toList());
    } catch (e) {
      debugPrint('Aule: favorites persist failed ($e)');
    }
  }

  // --- Synchronisation compte ----------------------------------------------

  SupabaseClient? get _client {
    final svc = _supabaseService;
    if (svc == null || svc.isOfflineMode) return null;
    return svc.client;
  }

  /// Utilisateur connecté avec un vrai compte (≠ anonyme), sinon null.
  String? get _accountUserId {
    final user = _client?.auth.currentUser;
    if (user == null || user.isAnonymous) return null;
    return user.id;
  }

  void _listenToAuth() {
    final client = _client;
    if (client == null) return;
    _authSub = client.auth.onAuthStateChange.listen((_) {
      final userId = _accountUserId;
      if (userId == null) {
        // Déconnexion / retour anonyme : on garde le local, on arrête la sync.
        _syncedUserId = null;
      } else if (userId != _syncedUserId) {
        _syncedUserId = userId;
        unawaited(_mergeWithAccount());
      }
    });
  }

  /// Fusionne favoris locaux et distants (union), persiste et pousse le tout.
  Future<void> _mergeWithAccount() async {
    final client = _client;
    if (client == null || _accountUserId == null) return;

    try {
      final rows = await client
          .from('user_favorites')
          .select('kind, ref_id');

      final remoteStops = <String>{};
      final remoteLines = <String>{};
      for (final row in rows as List) {
        final kind = row['kind'] as String?;
        final ref = row['ref_id'] as String?;
        if (ref == null) continue;
        if (kind == _kindStop) {
          remoteStops.add(ref);
        } else if (kind == _kindLine) {
          remoteLines.add(ref);
        }
      }

      // Favoris locaux absents du distant → à pousser.
      final stopsToPush = _stopIds.difference(remoteStops);
      final linesToPush = _routeIds.difference(remoteLines);

      // Union devient l'état actif (local source de vérité enrichie du distant).
      _stopIds.addAll(remoteStops);
      _routeIds.addAll(remoteLines);
      await _persist(_stopsKey, _stopIds);
      await _persist(_linesKey, _routeIds);
      notifyListeners();

      final userId = _accountUserId;
      if (userId != null) {
        final payload = [
          for (final id in stopsToPush)
            {'user_id': userId, 'kind': _kindStop, 'ref_id': id},
          for (final id in linesToPush)
            {'user_id': userId, 'kind': _kindLine, 'ref_id': id},
        ];
        if (payload.isNotEmpty) {
          await client.from('user_favorites').upsert(payload);
        }
      }
    } catch (e) {
      debugPrint('Aule: favorites merge failed ($e)');
    }
  }

  /// Réplique best-effort un ajout/retrait sur le compte connecté.
  Future<void> _pushRemoteChange(String kind, String refId, bool added) async {
    final client = _client;
    final userId = _accountUserId;
    if (client == null || userId == null) return;

    try {
      if (added) {
        await client.from('user_favorites').upsert(
          {'user_id': userId, 'kind': kind, 'ref_id': refId},
        );
      } else {
        await client
            .from('user_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('kind', kind)
            .eq('ref_id', refId);
      }
    } catch (e) {
      debugPrint('Aule: favorite remote sync failed ($e)');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
