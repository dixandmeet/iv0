import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/msr/msr_mission.dart';
import '../supabase_service.dart';

/// Suivi des missions MSR de l'utilisateur courant (table `msr_missions`).
///
/// Flux manuel MVP : l'agent voit, crée et supprime ses propres missions. La RLS
/// Supabase (`msr_missions_access`, migration 006) garantit l'isolation par
/// `agent_id = auth.uid()`. Le planificateur (zones/géométrie, Phase 5) viendra
/// enrichir la même table.
class MsrMissionService with ChangeNotifier {
  final SupabaseService _supabase;

  MsrMissionService({required SupabaseService supabaseService})
    : _supabase = supabaseService;

  List<MsrMission> _missions = [];
  bool _loading = false;
  bool _loaded = false;
  String? _errorMessage;

  List<MsrMission> get missions => List.unmodifiable(_missions);
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get errorMessage => _errorMessage;

  /// Vrai si l'utilisateur a une mission MSR en cours.
  bool get hasActiveMissionForCurrentUser =>
      _missions.any((mission) => mission.status == MsrMissionStatus.inProgress);

  /// Charge les missions de l'agent courant (antéchronologique).
  Future<void> fetchMissions({bool silent = false}) async {
    final client = _supabase.client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || _supabase.isOfflineMode || userId == null) {
      _loaded = true;
      if (!silent) notifyListeners();
      return;
    }

    if (!silent) {
      _loading = true;
      notifyListeners();
    }

    try {
      final rows = await client
          .from('msr_missions')
          .select()
          .eq('agent_id', userId)
          .order('scheduled_at', ascending: false)
          .limit(200);
      _missions = (rows as List)
          .map((r) => MsrMission.fromJson(r as Map<String, dynamic>))
          .toList();
      _errorMessage = null;
    } catch (e) {
      debugPrint('Aule: msr missions fetch failed ($e)');
      _errorMessage = 'Impossible de charger les missions';
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  /// Crée une mission assignée à l'agent courant. Retourne la mission insérée,
  /// ou null en cas d'échec (message dans [errorMessage]).
  Future<MsrMission?> createMission({
    required String title,
    required String sector,
    required DateTime scheduledAt,
    required MsrMissionKind kind,
    String? zoneLabel,
    String? teamLabel,
    String? instructions,
  }) async {
    final client = _supabase.client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || _supabase.isOfflineMode || userId == null) {
      _errorMessage = 'Création indisponible hors ligne';
      notifyListeners();
      return null;
    }

    try {
      final row = await client
          .from('msr_missions')
          .insert({
            'agent_id': userId,
            'title': title.trim(),
            'sector': sector.trim(),
            'scheduled_at': scheduledAt.toIso8601String(),
            'kind': kind.dbValue,
            'status': MsrMissionStatus.upcoming.dbValue,
            'zone_label': _nullIfBlank(zoneLabel),
            'team_label': _nullIfBlank(teamLabel),
            'instructions': _nullIfBlank(instructions),
          })
          .select()
          .single();
      final mission = MsrMission.fromJson(row);
      _missions.insert(0, mission);
      _errorMessage = null;
      notifyListeners();
      return mission;
    } catch (e) {
      debugPrint('Aule: msr mission create failed ($e)');
      _errorMessage = _saveError(e, 'Échec de la création de la mission');
      notifyListeners();
      return null;
    }
  }

  /// Supprime une mission. Retrait optimiste avec restauration si l'appel échoue.
  Future<bool> deleteMission(String id) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      _errorMessage = 'Suppression indisponible hors ligne';
      notifyListeners();
      return false;
    }

    final index = _missions.indexWhere((m) => m.id == id);
    final removed = index >= 0 ? _missions.removeAt(index) : null;
    if (removed != null) notifyListeners();

    try {
      await client.from('msr_missions').delete().eq('id', id);
      _errorMessage = null;
      return true;
    } catch (e) {
      debugPrint('Aule: msr mission delete failed ($e)');
      if (removed != null) _missions.insert(index, removed);
      _errorMessage = 'Échec de la suppression';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateMissionStatus(String id, MsrMissionStatus status) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      _errorMessage = 'Action indisponible hors ligne';
      notifyListeners();
      return false;
    }
    final index = _missions.indexWhere((mission) => mission.id == id);
    if (index < 0) return false;
    final previous = _missions[index];
    _missions[index] = previous.copyWith(status: status);
    notifyListeners();
    try {
      await client
          .from('msr_missions')
          .update({'status': status.dbValue})
          .eq('id', id);
      _errorMessage = null;
      return true;
    } catch (e) {
      debugPrint('Aule: msr mission status update failed ($e)');
      _missions[index] = previous;
      _errorMessage = 'Impossible de mettre à jour la mission';
      notifyListeners();
      return false;
    }
  }

  void clear() {
    _missions = [];
    _loaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  static String? _nullIfBlank(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static String _saveError(Object e, String fallback) {
    if (e is PostgrestException) {
      final m = e.message.trim();
      if (m.isNotEmpty) return m;
    }
    return fallback;
  }
}
