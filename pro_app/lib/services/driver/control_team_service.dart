import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/driver/control_team.dart';
import '../supabase_service.dart';

/// Résultat d'une tentative de création / sauvegarde d'équipe.
class TeamSaveResult {
  final bool success;
  final String? teamId;
  final String? error;
  const TeamSaveResult._(this.success, {this.teamId, this.error});

  factory TeamSaveResult.ok(String teamId) =>
      TeamSaveResult._(true, teamId: teamId);
  factory TeamSaveResult.fail(String error) =>
      TeamSaveResult._(false, error: error);
}

/// Gestion des équipes de contrôle (tables `teams` / `team_members`).
///
/// Réservé aux agents habilités Contrôle ; les écritures sont garanties par la
/// RLS côté Supabase. Module extensible : la création vise `type = 'control'`,
/// les modules Intervention / UMTC s'ajouteront via le même service.
class ControlTeamService with ChangeNotifier {
  final SupabaseService _supabase;

  ControlTeamService({required SupabaseService supabaseService})
    : _supabase = supabaseService;

  List<ControlTeam> _teams = [];
  bool _loading = false;
  bool _loaded = false;
  bool _saving = false;
  String? _errorMessage;

  List<ControlTeam> get teams => List.unmodifiable(_teams);
  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get saving => _saving;
  String? get errorMessage => _errorMessage;

  /// Charge les équipes visibles par l'utilisateur (ordre antéchronologique),
  /// avec leurs membres.
  Future<void> fetchTeams({bool silent = false}) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      _loaded = true;
      return;
    }

    if (!silent) {
      _loading = true;
      notifyListeners();
    }

    try {
      final rows = await client
          .from('teams')
          .select('*, team_members(*)')
          .order('created_at', ascending: false)
          .limit(100);

      final teams = (rows as List).map((r) {
        final map = r as Map<String, dynamic>;
        final memberRows = (map['team_members'] as List?) ?? const [];
        final members = memberRows
            .map((m) => TeamMember.fromJson(m as Map<String, dynamic>))
            .toList();
        return ControlTeam.fromJson(map, members: members);
      }).toList();
      _teams = await _hydrateTeamMemberProfiles(client, teams);
      _errorMessage = null;
    } catch (e) {
      debugPrint('Aule: teams fetch failed ($e)');
      _errorMessage = 'Impossible de charger les équipes';
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  /// Recherche d'agents par nom ou matricule (RPC `search_team_agents`).
  Future<List<TeamAgent>> searchAgents(String query) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) return const [];

    try {
      final rows = await client.rpc(
        'search_team_agents',
        params: {'p_query': query.trim()},
      );
      return (rows as List)
          .map((r) => TeamAgent.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Aule: agent search failed ($e)');
      return const [];
    }
  }

  /// Crée une équipe et ses membres. `createdByDriverId` est l'id de la fiche
  /// conducteur courante (colonne `created_by`).
  Future<TeamSaveResult> createTeam({
    required String createdByDriverId,
    required String name,
    String? depotId,
    required TeamStatus status,
    List<TeamVacation> vacations = const [],
    TeamMobilityMode? mobilityMode,
    TimeOfDay? departureTime,
    TimeOfDay? returnTime,
    String? lineId,
    String? vehicleId,
    String? zone,
    List<TeamInstruction> instructions = const [],
    required List<TeamMember> members,
    TeamType type = TeamType.control,
  }) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      return TeamSaveResult.fail('Création indisponible hors ligne');
    }

    _saving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final validVacations = vacations.where((v) => v.isValid).toList();
      final firstVacation = validVacations.isNotEmpty
          ? validVacations.first
          : null;

      final teamRow = await client
          .from('teams')
          .insert({
            'name': name.trim(),
            'type': type.dbValue,
            'depot_id': depotId,
            'status': status.dbValue,
            'departure_time': timeOfDayToSql(
              departureTime ?? firstVacation?.startTime,
            ),
            'return_time': timeOfDayToSql(returnTime ?? firstVacation?.endTime),
            'vacations': validVacations.map((v) => v.toJson()).toList(),
            'mobility_mode': mobilityMode?.dbValue,
            'line_id': _nullIfBlank(lineId),
            'vehicle_id': _nullIfBlank(vehicleId),
            'zone': _nullIfBlank(zone),
            'instructions': instructions.map((i) => i.toJson()).toList(),
            'created_by': createdByDriverId,
          })
          .select()
          .single();

      final teamId = teamRow['id'] as String;

      if (members.isNotEmpty) {
        await client
            .from('team_members')
            .insert(
              _buildMemberPayload(
                teamId: teamId,
                members: members,
                creatorDriverId: createdByDriverId,
              ),
            );
      }

      await fetchTeams(silent: true);
      _saving = false;
      notifyListeners();
      return TeamSaveResult.ok(teamId);
    } catch (e) {
      debugPrint('Aule: team create failed ($e)');
      _errorMessage = _teamSaveError(e, 'Échec de la création de l\'équipe');
      _saving = false;
      notifyListeners();
      return TeamSaveResult.fail(_errorMessage!);
    }
  }

  Future<TeamSaveResult> updateTeam({
    required String teamId,
    required String name,
    required TeamStatus status,
    List<TeamVacation> vacations = const [],
    TeamMobilityMode? mobilityMode,
    TimeOfDay? departureTime,
    TimeOfDay? returnTime,
    String? lineId,
    String? vehicleId,
    String? zone,
    List<TeamInstruction> instructions = const [],
    required List<TeamMember> members,
    String? creatorDriverId,
  }) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      return TeamSaveResult.fail('Modification indisponible hors ligne');
    }

    _saving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final validVacations = vacations.where((v) => v.isValid).toList();
      final firstVacation = validVacations.isNotEmpty
          ? validVacations.first
          : null;

      await client
          .from('teams')
          .update({
            'name': name.trim(),
            'status': status.dbValue,
            'departure_time': timeOfDayToSql(
              departureTime ?? firstVacation?.startTime,
            ),
            'return_time': timeOfDayToSql(returnTime ?? firstVacation?.endTime),
            'vacations': validVacations.map((v) => v.toJson()).toList(),
            'mobility_mode': mobilityMode?.dbValue,
            'line_id': _nullIfBlank(lineId),
            'vehicle_id': _nullIfBlank(vehicleId),
            'zone': _nullIfBlank(zone),
            'instructions': instructions.map((i) => i.toJson()).toList(),
          })
          .eq('id', teamId);

      final existingRows = await client
          .from('team_members')
          .select('id, user_id')
          .eq('team_id', teamId);
      final existingByUser = <String, String>{
        for (final row in existingRows as List)
          (row as Map<String, dynamic>)['user_id'] as String:
              row['id'] as String,
      };
      final desiredUserIds = members.map((m) => m.userId).toSet();

      for (final entry in existingByUser.entries) {
        if (!desiredUserIds.contains(entry.key)) {
          await client
              .from('team_members')
              .update({'invitation_status': InvitationStatus.removed.dbValue})
              .eq('id', entry.value);
        }
      }

      for (final member in members) {
        final status =
            creatorDriverId != null && member.userId == creatorDriverId
            ? InvitationStatus.accepted
            : member.invitationStatus;
        final payload = {
          'invitation_status': status.dbValue,
          'mentions': member.mentionsJson,
        };
        final existingId = existingByUser[member.userId];
        if (existingId != null) {
          // Ne pas toucher à presence_status / present_at / accepted_at.
          await client
              .from('team_members')
              .update(payload)
              .eq('id', existingId);
        } else {
          await client.from('team_members').insert({
            'team_id': teamId,
            'user_id': member.userId,
            ...payload,
          });
        }
      }

      await fetchTeams(silent: true);
      _saving = false;
      notifyListeners();
      return TeamSaveResult.ok(teamId);
    } catch (e) {
      debugPrint('Aule: team update failed ($e)');
      _errorMessage = _teamSaveError(e, 'Échec de la mise à jour de l\'équipe');
      _saving = false;
      notifyListeners();
      return TeamSaveResult.fail(_errorMessage!);
    }
  }

  /// Supprime une équipe (créateur ou staff — RLS).
  Future<TeamSaveResult> deleteTeam(String teamId) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      return TeamSaveResult.fail('Suppression indisponible hors ligne');
    }

    _saving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await client.from('teams').delete().eq('id', teamId);
      _teams.removeWhere((t) => t.id == teamId);
      await fetchTeams(silent: true);
      _saving = false;
      notifyListeners();
      return TeamSaveResult.ok(teamId);
    } catch (e) {
      debugPrint('Aule: team delete failed ($e)');
      _errorMessage = _teamSaveError(e, 'Impossible de supprimer l\'équipe');
      _saving = false;
      notifyListeners();
      return TeamSaveResult.fail(_errorMessage!);
    }
  }

  static String _teamSaveError(Object e, String fallback) {
    if (e is PostgrestException) {
      final message = e.message.trim();
      if (message.isNotEmpty) return message;
    }
    return fallback;
  }

  void clear() {
    _teams = [];
    _loaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  static String? _nullIfBlank(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static Future<List<ControlTeam>> _hydrateTeamMemberProfiles(
    SupabaseClient client,
    List<ControlTeam> teams,
  ) async {
    final ids = <String>{
      for (final team in teams)
        for (final member in team.members)
          if (member.displayName == null || member.driverNumber == null)
            member.userId,
    };
    if (ids.isEmpty) return teams;

    try {
      final rows = await client
          .from('drivers')
          .select('id, first_name, last_name, driver_number')
          .inFilter('id', ids.toList());
      final profiles = <String, Map<String, dynamic>>{
        for (final row in rows as List)
          (row as Map<String, dynamic>)['id'] as String: row,
      };

      return teams
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
    } catch (e) {
      debugPrint('Aule: team member profile hydrate failed ($e)');
      return teams;
    }
  }

  static List<Map<String, dynamic>> _buildMemberPayload({
    required String teamId,
    required List<TeamMember> members,
    String? creatorDriverId,
  }) {
    return members.map((m) {
      final status = creatorDriverId != null && m.userId == creatorDriverId
          ? InvitationStatus.accepted
          : m.invitationStatus;
      return {
        'team_id': teamId,
        'user_id': m.userId,
        'invitation_status': status.dbValue,
        'mentions': m.mentionsJson,
      };
    }).toList();
  }
}
