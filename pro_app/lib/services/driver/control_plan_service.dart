import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/driver/control_plan_context.dart';
import '../../models/driver/control_team.dart';
import '../../models/driver/mission_models.dart';
import 'mission_event_bus.dart';
import '../supabase_service.dart';

/// Formate une consigne équipe pour persistance plan de contrôle.
String formatControlPlanInstruction(TeamInstruction instruction) {
  final text = instruction.text.trim();
  if (text.isEmpty) return '';
  if (instruction.hasTimes) return '${instruction.timeLabel} · $text';
  return text;
}

/// Résultat d'une tentative de création de mission.
class MissionSaveResult {
  final bool success;
  final String? id;
  final String? error;

  const MissionSaveResult._(this.success, {this.id, this.error});

  factory MissionSaveResult.ok(String id) => MissionSaveResult._(true, id: id);
  factory MissionSaveResult.fail(String error) =>
      MissionSaveResult._(false, error: error);
}

class MissionTransitionResult {
  final bool success;
  final String message;
  final MissionDebrief? debrief;

  const MissionTransitionResult({
    required this.success,
    required this.message,
    this.debrief,
  });
}

class PresenceResult {
  final bool success;
  final String message;

  const PresenceResult({required this.success, required this.message});
}

/// Charge le contexte mission de contrôle via RPC Supabase.
class ControlPlanService with ChangeNotifier {
  final SupabaseService _supabase;
  final MissionEventBus eventBus;

  ControlPlanService({
    required SupabaseService supabaseService,
    MissionEventBus? eventBus,
  }) : _supabase = supabaseService,
       eventBus = eventBus ?? MissionEventBus();

  ControlPlanContext? _context;
  List<ControlMissionSummary> _historyMissions = [];
  List<ControlMissionSummary> _upcomingMissions = [];
  bool _historyHasMore = false;
  bool _upcomingHasMore = false;
  bool _historyLoading = false;
  bool _upcomingLoading = false;
  bool _loading = false;
  bool _loaded = false;
  bool _saving = false;
  String? _errorMessage;
  TeamReadiness? _readiness;
  RealtimeChannel? _missionRealtimeChannel;
  Timer? _realtimeDebounce;
  String? _subscribedTeamId;

  ControlPlanContext? get context => _context;
  TeamReadiness? get readiness => _readiness ?? _context?.readiness;
  List<ControlMissionSummary> get historyMissions =>
      List.unmodifiable(_historyMissions);
  List<ControlMissionSummary> get upcomingMissions =>
      List.unmodifiable(_upcomingMissions);
  bool get historyHasMore => _historyHasMore;
  bool get upcomingHasMore => _upcomingHasMore;
  bool get historyLoading => _historyLoading;
  bool get upcomingLoading => _upcomingLoading;
  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get saving => _saving;
  String? get errorMessage => _errorMessage;

  bool get canViewFull => _context?.canViewFull ?? false;
  bool get isCreator => _context?.isCreator ?? false;
  EffectiveInvitationStatus? get effectiveInvitationStatus =>
      _context?.effectiveInvitationStatus;
  ControlMissionSummary? get currentMission => _context?.currentMission;

  void _emit(
    MissionEventType type, {
    String? planId,
    Map<String, dynamic>? payload,
  }) {
    eventBus.emit(
      MissionEvent(
        type: type,
        planId: planId,
        payload: payload ?? const {},
        at: DateTime.now(),
      ),
    );
  }

  Future<void> fetchMyContext({bool silent = false}) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      _context = const ControlPlanContext();
      _loaded = true;
      notifyListeners();
      return;
    }

    if (!silent) {
      _loading = true;
      notifyListeners();
    }

    try {
      final raw = await client.rpc('my_control_plan_context');
      if (raw is Map) {
        var parsed = ControlPlanContext.fromJson(
          Map<String, dynamic>.from(raw),
        );
        final missionId = parsed.currentMission?.id;
        if (missionId != null) {
          try {
            final detailedRaw = await client.rpc(
              'control_mission_workspace_context',
              params: {'p_mission_id': missionId},
            );
            if (detailedRaw is Map && detailedRaw['current_mission'] is Map) {
              parsed = ControlPlanContext.fromJson(
                Map<String, dynamic>.from(detailedRaw),
              );
            }
          } catch (e) {
            debugPrint('Aule: current mission enrichment failed ($e)');
          }
        }
        _context = await _hydrateContextMemberProfiles(client, parsed);
        await _refreshReadiness();
        _subscribeMissionRealtime();
      } else {
        _context = const ControlPlanContext();
      }
      _errorMessage = null;
    } catch (e) {
      debugPrint('Aule: mission context fetch failed ($e)');
      _errorMessage = 'Impossible de charger vos services';
      _context ??= const ControlPlanContext();
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  void _subscribeMissionRealtime() {
    final client = _supabase.client;
    final teamId = _context?.myTeamId;
    if (client == null) {
      return;
    }
    if (teamId == null) {
      _missionRealtimeChannel?.unsubscribe();
      _missionRealtimeChannel = null;
      _subscribedTeamId = null;
      return;
    }
    if (teamId == _subscribedTeamId) return;
    _missionRealtimeChannel?.unsubscribe();
    _subscribedTeamId = teamId;
    _missionRealtimeChannel = client
        .channel('mission-context-$teamId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'team_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'msr_missions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        .subscribe();
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(
      const Duration(milliseconds: 250),
      () => fetchMyContext(silent: true),
    );
  }

  /// Charge un contexte isolé pour une mission des listes À venir/Historique.
  ///
  /// Le contexte global reste celui de la mission du jour : l'ouverture d'une
  /// autre mission ne peut donc plus réutiliser son équipe, ses droits ou son
  /// canal de discussion.
  Future<ControlPlanContext?> fetchMissionContext(String missionId) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) return null;
    try {
      final raw = await client.rpc(
        'control_mission_workspace_context',
        params: {'p_mission_id': missionId},
      );
      if (raw is! Map) return null;
      final parsed = ControlPlanContext.fromJson(
        Map<String, dynamic>.from(raw),
      );
      return _hydrateContextMemberProfiles(client, parsed);
    } catch (e) {
      debugPrint('Aule: mission workspace context fetch failed ($e)');
      return null;
    }
  }

  Future<ControlPlanContext> _hydrateContextMemberProfiles(
    SupabaseClient client,
    ControlPlanContext context,
  ) async {
    final ids = <String>{
      for (final team in context.teams)
        for (final member in team.members)
          if (member.displayName == null || member.driverNumber == null)
            member.userId,
    };
    if (ids.isEmpty) return context;

    try {
      final rows = await client
          .from('drivers')
          .select('id, first_name, last_name, driver_number')
          .inFilter('id', ids.toList());
      final profiles = <String, Map<String, dynamic>>{
        for (final row in rows as List)
          (row as Map<String, dynamic>)['id'] as String: row,
      };

      final teams = context.teams
          .map(
            (team) => team.copyWith(
              members: team.members.map((member) {
                final profile = profiles[member.userId];
                if (profile == null) return member;
                final firstName = profile['first_name'] as String?;
                final lastName = profile['last_name'] as String?;
                final displayName = [firstName, lastName]
                    .where((part) => part != null && part.trim().isNotEmpty)
                    .map((part) => part!.trim())
                    .join(' ');
                return member.copyWith(
                  displayName: displayName.isEmpty ? null : displayName,
                  driverNumber: profile['driver_number'] as String?,
                );
              }).toList(),
            ),
          )
          .toList();
      return context.copyWith(teams: teams);
    } catch (e) {
      debugPrint('Aule: mission context member profile hydrate failed ($e)');
      return context;
    }
  }

  Future<void> _refreshReadiness() async {
    final teamId = _context?.myTeamId;
    if (teamId == null) {
      _readiness = TeamReadiness.fromTeam(_context?.myTeam);
      return;
    }
    final client = _supabase.client;
    if (client == null) return;
    try {
      final raw = await client.rpc(
        'get_mission_team_readiness',
        params: {'p_team_id': teamId},
      );
      if (raw is Map) {
        _readiness = TeamReadiness.fromJson(Map<String, dynamic>.from(raw));
      } else {
        _readiness = TeamReadiness.fromTeam(_context?.myTeam);
      }
    } catch (_) {
      _readiness = TeamReadiness.fromTeam(_context?.myTeam);
    }
  }

  Future<void> fetchUpcoming({int limit = 20, int offset = 0}) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      _upcomingMissions = [];
      _upcomingHasMore = false;
      notifyListeners();
      return;
    }

    _upcomingLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final raw = await client.rpc(
        'my_control_plan_upcoming',
        params: {'p_limit': limit, 'p_offset': offset},
      );
      if (raw is Map) {
        final page = ControlPlanHistoryPage.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (offset == 0) {
          _upcomingMissions = page.missions;
        } else {
          _upcomingMissions = [..._upcomingMissions, ...page.missions];
        }
        _upcomingHasMore = page.hasMore;
      }
    } catch (e) {
      debugPrint('Aule: upcoming missions fetch failed ($e)');
      _errorMessage = 'Impossible de charger les services à venir';
    } finally {
      _upcomingLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchHistory({int limit = 20, int offset = 0}) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      _historyMissions = [];
      _historyHasMore = false;
      notifyListeners();
      return;
    }

    _historyLoading = true;
    notifyListeners();

    try {
      final raw = await client.rpc(
        'my_control_plan_history',
        params: {'p_limit': limit, 'p_offset': offset},
      );
      if (raw is Map) {
        final page = ControlPlanHistoryPage.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (offset == 0) {
          _historyMissions = page.missions;
        } else {
          _historyMissions = [..._historyMissions, ...page.missions];
        }
        _historyHasMore = page.hasMore;
      }
    } catch (e) {
      debugPrint('Aule: mission history fetch failed ($e)');
      _errorMessage = 'Impossible de charger l\'historique';
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }

  Future<TeamInvitationResult> respondTeamInvitation({
    required String teamId,
    required bool accept,
  }) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      return const TeamInvitationResult(
        success: false,
        status: 'error',
        message: 'Action indisponible hors ligne',
      );
    }

    try {
      final raw = await client.rpc(
        'respond_team_invitation',
        params: {'p_team_id': teamId, 'p_accept': accept},
      );
      final result = raw is Map
          ? TeamInvitationResult.fromJson(Map<String, dynamic>.from(raw))
          : const TeamInvitationResult(
              success: false,
              status: 'error',
              message: 'Réponse invalide',
            );
      if (result.success) {
        _emit(
          accept
              ? MissionEventType.memberJoined
              : MissionEventType.memberDeclined,
          planId: _context?.plan?.id,
          payload: {'team_id': teamId},
        );
        await fetchMyContext(silent: true);
      }
      return result;
    } catch (e) {
      debugPrint('Aule: respond team invitation failed ($e)');
      return TeamInvitationResult(
        success: false,
        status: 'error',
        message: _planSaveError(e, 'Impossible de traiter l\'invitation'),
      );
    }
  }

  Future<PresenceResult> declarePresence(String teamId) async {
    return _presenceRpc('declare_team_presence', {'p_team_id': teamId});
  }

  Future<PresenceResult> syncPresence(
    String teamId,
    double lat,
    double lng,
  ) async {
    return _presenceRpc('sync_team_presence', {
      'p_team_id': teamId,
      'p_lat': lat,
      'p_lng': lng,
    });
  }

  Future<PresenceResult> confirmPresence(
    String teamId,
    String memberDriverId,
  ) async {
    return _presenceRpc('confirm_member_presence', {
      'p_team_id': teamId,
      'p_member_driver_id': memberDriverId,
    });
  }

  Future<PresenceResult> updateMemberRoles({
    required String teamId,
    required String memberDriverId,
    required Set<TeamMention> mentions,
  }) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      return const PresenceResult(
        success: false,
        message: 'Action indisponible hors ligne',
      );
    }
    try {
      final raw = await client.rpc(
        'update_team_member_roles',
        params: {
          'p_team_id': teamId,
          'p_member_driver_id': memberDriverId,
          'p_mentions': TeamMention.values
              .where(mentions.contains)
              .map((mention) => mention.dbValue)
              .toList(),
        },
      );
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final success = map['success'] as bool? ?? false;
      if (success) {
        _emit(
          MissionEventType.roleUpdated,
          planId: _context?.plan?.id,
          payload: {'team_id': teamId, 'member_id': memberDriverId},
        );
      }
      return PresenceResult(
        success: success,
        message: map['message'] as String? ?? 'Erreur rôles',
      );
    } catch (e) {
      return PresenceResult(
        success: false,
        message: _planSaveError(e, 'Impossible de modifier les rôles'),
      );
    }
  }

  Future<PresenceResult> _presenceRpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      return const PresenceResult(
        success: false,
        message: 'Action indisponible hors ligne',
      );
    }
    try {
      final raw = await client.rpc(name, params: params);
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final success = map['success'] as bool? ?? false;
      if (success) {
        _emit(MissionEventType.memberPresent, planId: _context?.plan?.id);
        await fetchMyContext(silent: true);
      }
      return PresenceResult(
        success: success,
        message: map['message'] as String? ?? 'Erreur présence',
      );
    } catch (e) {
      return PresenceResult(
        success: false,
        message: _planSaveError(e, 'Impossible d\'enregistrer la présence'),
      );
    }
  }

  Future<MissionTransitionResult> transitionMission({
    required String missionId,
    required bool start,
  }) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      return const MissionTransitionResult(
        success: false,
        message: 'Action indisponible hors ligne',
      );
    }
    try {
      final raw = await client.rpc(
        'transition_control_mission',
        params: {
          'p_mission_id': missionId,
          'p_action': start ? 'start' : 'complete',
        },
      );
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final success = map['success'] as bool? ?? false;
      if (success) {
        _emit(
          start
              ? MissionEventType.missionStarted
              : MissionEventType.missionCompleted,
          planId: _context?.plan?.id,
          payload: map,
        );
        await fetchMyContext(silent: true);
      }
      MissionDebrief? debrief;
      if (map['debrief'] is Map) {
        debrief = MissionDebrief.fromJson(
          Map<String, dynamic>.from(map['debrief'] as Map),
        );
      }
      return MissionTransitionResult(
        success: success,
        message: map['message'] as String? ?? 'Erreur',
        debrief: debrief,
      );
    } catch (e) {
      return MissionTransitionResult(
        success: false,
        message: _planSaveError(e, 'Impossible de mettre à jour le service'),
      );
    }
  }

  Future<MissionSaveResult> createMission({
    required String name,
    required String objective,
    required DateTime startDate,
    required DateTime endDate,
    String? teamId,
    List<String> lineIds = const [],
    List<String> zones = const [],
    List<TeamInstruction> instructions = const [],
    String? operationalResponsibleId,
    MissionPriority priority = MissionPriority.standard,
    List<String> driverIdsToEnsure = const [],
  }) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      return MissionSaveResult.fail('Création indisponible hors ligne');
    }

    _saving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _ensureDriverProfiles(client, driverIdsToEnsure);

      final resolvedResponsible = operationalResponsibleId == null
          ? null
          : await _resolveUserProfileId(client, operationalResponsibleId);

      final planId = await client.rpc(
        'create_control_plan',
        params: {
          'p_name': name.trim(),
          'p_objective': objective.trim(),
          'p_start_date': _dateToSql(startDate),
          'p_end_date': _dateToSql(endDate),
          'p_team_id': teamId,
          'p_instructions': instructions
              .map(formatControlPlanInstruction)
              .where((i) => i.isNotEmpty)
              .toList(),
          'p_line_ids': lineIds
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toList(),
          'p_zones': zones
              .map((z) => z.trim())
              .where((z) => z.isNotEmpty)
              .toList(),
          'p_operational_responsible_id': resolvedResponsible,
          'p_priority': priority.dbValue,
        },
      );

      final id = planId as String;
      _emit(MissionEventType.missionCreated, planId: id);
      await fetchMyContext(silent: true);
      _saving = false;
      notifyListeners();
      return MissionSaveResult.ok(id);
    } catch (e) {
      debugPrint('Aule: mission create failed ($e)');
      _errorMessage = _planSaveError(e, 'Échec de la création du service');
      _saving = false;
      notifyListeners();
      return MissionSaveResult.fail(_errorMessage!);
    }
  }

  Future<MissionSaveResult> deleteMission({required String planId}) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      return MissionSaveResult.fail('Suppression indisponible hors ligne');
    }

    _saving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await client.rpc('delete_control_plan', params: {'p_plan_id': planId});
      await fetchMyContext(silent: true);
      _saving = false;
      notifyListeners();
      return MissionSaveResult.ok(planId);
    } catch (e) {
      debugPrint('Aule: mission delete failed ($e)');
      _errorMessage = _planSaveError(
        e,
        'Échec de la suppression du service',
      );
      _saving = false;
      notifyListeners();
      return MissionSaveResult.fail(_errorMessage!);
    }
  }

  Future<MissionSaveResult> updateMissionDetails({
    required String planId,
    required String objective,
    required MissionPriority priority,
  }) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      return MissionSaveResult.fail('Modification indisponible hors ligne');
    }
    final normalizedObjective = objective.trim();
    if (normalizedObjective.length < 3) {
      return MissionSaveResult.fail('Renseignez un objectif valide');
    }

    _saving = true;
    notifyListeners();
    try {
      await client.rpc(
        'update_control_mission_metadata',
        params: {
          'p_plan_id': planId,
          'p_objective': normalizedObjective,
          'p_priority': priority.dbValue,
        },
      );
      await fetchMyContext(silent: true);
      return MissionSaveResult.ok(planId);
    } catch (e) {
      return MissionSaveResult.fail(
        _planSaveError(e, 'Impossible de modifier le service'),
      );
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  static String _dateToSql(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Crée les profils manquants avant une mutation plan de contrôle.
  static Future<void> _ensureDriverProfiles(
    SupabaseClient client,
    Iterable<String> driverIds,
  ) async {
    final uniqueIds = driverIds.where((id) => id.trim().isNotEmpty).toSet();
    for (final driverId in uniqueIds) {
      try {
        await client.rpc(
          'ensure_driver_user_profile',
          params: {'p_driver_id': driverId},
        );
      } catch (e) {
        debugPrint('Aule: ensure_driver_user_profile($driverId) failed ($e)');
      }
    }
  }

  /// Convertit un `drivers.id` ou `user_profiles.id` en profil utilisable.
  static Future<String?> _resolveUserProfileId(
    SupabaseClient client,
    String id,
  ) async {
    try {
      final resolved = await client.rpc(
        'resolve_user_profile_id',
        params: {'p_id': id},
      );
      if (resolved is String && resolved.isNotEmpty) return resolved;
    } catch (e) {
      debugPrint('Aule: resolve_user_profile_id failed ($e)');
    }

    return null;
  }

  static String _planSaveError(Object e, String fallback) {
    if (e is PostgrestException) {
      final message = e.message.trim();
      if (message.contains('operational_responsible_id_fkey')) {
        return 'Le responsable opérationnel sélectionné est invalide.';
      }
      if (message.contains('control_plan_agents_agent_id_fkey')) {
        return 'Un agent de l\'équipe n\'a pas de profil utilisateur valide.';
      }
      if (message.contains('control_plans_created_by_fkey')) {
        return 'Votre profil utilisateur est incomplet. Reconnectez-vous.';
      }
      if (message.isNotEmpty) return message;
    }
    return fallback;
  }

  void clear() {
    _realtimeDebounce?.cancel();
    _missionRealtimeChannel?.unsubscribe();
    _missionRealtimeChannel = null;
    _subscribedTeamId = null;
    _context = null;
    _historyMissions = [];
    _upcomingMissions = [];
    _historyHasMore = false;
    _upcomingHasMore = false;
    _readiness = null;
    _loaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _missionRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  @visibleForTesting
  void seedForTest(ControlPlanContext context) {
    _context = context;
    _loaded = true;
    _loading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @visibleForTesting
  void seedHistoryForTest(
    List<ControlMissionSummary> missions, {
    bool hasMore = false,
  }) {
    _historyMissions = missions;
    _historyHasMore = hasMore;
    notifyListeners();
  }
}
