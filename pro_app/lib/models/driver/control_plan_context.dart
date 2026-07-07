import 'control_team.dart';
import 'mission_models.dart';

/// Statut d'un plan de contrôle (table `control_plans`).
enum ControlPlanStatus {
  draft('draft', 'Brouillon'),
  active('active', 'Actif'),
  completed('completed', 'Terminé'),
  suspended('suspended', 'Suspendu');

  final String dbValue;
  final String label;

  const ControlPlanStatus(this.dbValue, this.label);

  static ControlPlanStatus fromDb(String? value) =>
      ControlPlanStatus.values.firstWhere(
        (s) => s.dbValue == value,
        orElse: () => ControlPlanStatus.draft,
      );
}

/// Statut effectif d'invitation (inclut `expired` calculé côté RPC).
enum EffectiveInvitationStatus {
  invited('invited'),
  accepted('accepted'),
  declined('declined'),
  expired('expired');

  final String dbValue;

  const EffectiveInvitationStatus(this.dbValue);

  static EffectiveInvitationStatus? fromDb(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final s in EffectiveInvitationStatus.values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }
}

/// Statut mission MSR (table `msr_missions`).
enum ControlMissionStatus {
  assigned('assigned', 'Assignée'),
  inProgress('in_progress', 'En cours'),
  completed('completed', 'Terminée'),
  cancelled('cancelled', 'Annulée'),
  draft('draft', 'Brouillon');

  final String dbValue;
  final String label;

  const ControlMissionStatus(this.dbValue, this.label);

  static ControlMissionStatus fromDb(String? value) =>
      ControlMissionStatus.values.firstWhere(
        (s) => s.dbValue == value,
        orElse: () => ControlMissionStatus.assigned,
      );
}

/// Résumé d'un plan de contrôle actif pour l'agent.
class ControlPlanSummary {
  final String id;
  final String name;
  final ControlPlanStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final String objective;
  final List<String> instructions;
  final MissionPriority priority;
  final int? missionDisplayNumber;
  final String? missionReference;
  final String? operationalResponsibleName;

  const ControlPlanSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.objective,
    this.instructions = const [],
    this.priority = MissionPriority.standard,
    this.missionDisplayNumber,
    this.missionReference,
    this.operationalResponsibleName,
  });

  factory ControlPlanSummary.fromJson(Map<String, dynamic> json) {
    final rawInstructions = json['instructions'];
    final instructions = <String>[];
    if (rawInstructions is List) {
      for (final item in rawInstructions) {
        if (item is String && item.trim().isNotEmpty) {
          instructions.add(item.trim());
        }
      }
    }

    return ControlPlanSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Service de contrôle',
      status: ControlPlanStatus.fromDb(json['status'] as String?),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      objective: json['objective'] as String? ?? '',
      instructions: instructions,
      priority: MissionPriority.fromDb(json['priority'] as String?),
      missionDisplayNumber: json['mission_display_number'] as int?,
      missionReference: json['mission_reference'] as String?,
      operationalResponsibleName:
          json['operational_responsible_name'] as String?,
    );
  }

  String get periodLabel {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${fmt(startDate)} → ${fmt(endDate)}';
  }
}

/// Mission MSR liée au plan (preview ou full selon RPC).
class ControlMissionSummary {
  final String id;
  final String? controlPlanId;
  final String planName;
  final String? teamId;
  final String teamName;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String? creatorName;
  final ControlMissionStatus status;
  final bool fullAccess;
  final String? zoneId;
  final String? zoneLabel;
  final String? lineId;
  final List<String> instructions;
  final List<TeamMember> teamMembers;
  final InvitationStatus? invitationStatus;
  final int? missionDisplayNumber;
  final String? objective;
  final String? priorityDb;
  final DateTime? interventionStartedAt;
  final String? channelId;

  const ControlMissionSummary({
    required this.id,
    this.controlPlanId,
    required this.planName,
    this.teamId,
    required this.teamName,
    this.scheduledStart,
    this.scheduledEnd,
    this.creatorName,
    this.status = ControlMissionStatus.assigned,
    this.fullAccess = false,
    this.zoneId,
    this.zoneLabel,
    this.lineId,
    this.instructions = const [],
    this.teamMembers = const [],
    this.invitationStatus,
    this.missionDisplayNumber,
    this.objective,
    this.priorityDb,
    this.interventionStartedAt,
    this.channelId,
  });

  String? get resolvedTeamId => teamId;

  String get displayNumberLabel => missionDisplayNumber != null
      ? 'Service #$missionDisplayNumber'
      : planName;

  MissionPhase get phase => MissionPhase.fromMission(this);

  bool get isPreview => !fullAccess;

  ControlMissionSummary copyWith({bool? fullAccess}) {
    return ControlMissionSummary(
      id: id,
      controlPlanId: controlPlanId,
      planName: planName,
      teamId: teamId,
      teamName: teamName,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      creatorName: creatorName,
      status: status,
      fullAccess: fullAccess ?? this.fullAccess,
      zoneId: zoneId,
      zoneLabel: zoneLabel,
      lineId: lineId,
      instructions: instructions,
      teamMembers: teamMembers,
      invitationStatus: invitationStatus,
      missionDisplayNumber: missionDisplayNumber,
      objective: objective,
      priorityDb: priorityDb,
      interventionStartedAt: interventionStartedAt,
      channelId: channelId,
    );
  }

  String get scheduleLabel {
    if (scheduledStart == null && scheduledEnd == null) return '—';
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (scheduledStart != null && scheduledEnd != null) {
      return '${fmt(scheduledStart!)} → ${fmt(scheduledEnd!)}';
    }
    if (scheduledStart != null) return fmt(scheduledStart!);
    return fmt(scheduledEnd!);
  }

  factory ControlMissionSummary.fromJson(Map<String, dynamic> json) {
    final fullAccess =
        json['full_access'] as bool? ??
        (json.containsKey('zone_config') || json.containsKey('zone_id'));
    final rawInstructions = json['instructions'];
    final instructions = <String>[];
    if (rawInstructions is List) {
      for (final item in rawInstructions) {
        if (item is String && item.trim().isNotEmpty) {
          instructions.add(item.trim());
        }
      }
    }

    final rawMembers = json['team_members'];
    final members = <TeamMember>[];
    if (fullAccess && rawMembers is List) {
      for (final item in rawMembers) {
        if (item is Map) {
          members.add(TeamMember.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return ControlMissionSummary(
      id: json['id'] as String,
      controlPlanId: json['control_plan_id'] as String?,
      planName: json['plan_name'] as String? ?? 'Service de contrôle',
      teamId: json['team_id'] as String?,
      teamName: json['team_name'] as String? ?? 'Équipe',
      scheduledStart: _parseDateTime(json['scheduled_start']),
      scheduledEnd: _parseDateTime(json['scheduled_end']),
      creatorName: json['creator_name'] as String?,
      status: ControlMissionStatus.fromDb(json['status'] as String?),
      fullAccess: fullAccess,
      zoneId: json['zone_id'] as String?,
      zoneLabel: json['zone_label'] as String?,
      lineId: json['line_id'] as String?,
      instructions: instructions,
      teamMembers: members,
      invitationStatus: json['invitation_status'] != null
          ? InvitationStatus.fromDb(json['invitation_status'] as String?)
          : null,
      missionDisplayNumber: json['mission_display_number'] as int?,
      objective: json['objective'] as String?,
      priorityDb: json['priority'] as String?,
      interventionStartedAt: _parseDateTime(json['intervention_started_at']),
      channelId: json['channel_id'] as String?,
    );
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

/// Résultat RPC `respond_team_invitation`.
class TeamInvitationResult {
  final bool success;
  final String status;
  final String message;

  const TeamInvitationResult({
    required this.success,
    required this.status,
    required this.message,
  });

  factory TeamInvitationResult.fromJson(Map<String, dynamic> json) {
    return TeamInvitationResult(
      success: json['success'] as bool? ?? false,
      status: json['status'] as String? ?? 'error',
      message: json['message'] as String? ?? 'Erreur inconnue',
    );
  }
}

/// Contexte complet renvoyé par la RPC `my_control_plan_context`.
class ControlPlanContext {
  final ControlPlanSummary? plan;
  final String? myTeamId;
  final List<ControlTeam> teams;
  final InvitationStatus? myInvitationStatus;
  final EffectiveInvitationStatus? effectiveInvitationStatus;
  final bool isCreator;
  final bool canViewFull;
  final ControlMissionSummary? currentMission;
  final TeamReadiness? teamReadiness;
  final String? operationalResponsibleName;
  final int connectedCount;
  final DateTime? lastActivityAt;
  final String? channelId;
  final int messageCount;

  const ControlPlanContext({
    this.plan,
    this.myTeamId,
    this.teams = const [],
    this.myInvitationStatus,
    this.effectiveInvitationStatus,
    this.isCreator = false,
    this.canViewFull = false,
    this.currentMission,
    this.teamReadiness,
    this.operationalResponsibleName,
    this.connectedCount = 0,
    this.lastActivityAt,
    this.channelId,
    this.messageCount = 0,
  });

  ControlPlanContext copyWith({
    ControlPlanSummary? plan,
    String? myTeamId,
    List<ControlTeam>? teams,
    InvitationStatus? myInvitationStatus,
    EffectiveInvitationStatus? effectiveInvitationStatus,
    bool? isCreator,
    bool? canViewFull,
    ControlMissionSummary? currentMission,
    TeamReadiness? teamReadiness,
    String? operationalResponsibleName,
    int? connectedCount,
    DateTime? lastActivityAt,
    String? channelId,
    int? messageCount,
  }) {
    return ControlPlanContext(
      plan: plan ?? this.plan,
      myTeamId: myTeamId ?? this.myTeamId,
      teams: teams ?? this.teams,
      myInvitationStatus: myInvitationStatus ?? this.myInvitationStatus,
      effectiveInvitationStatus:
          effectiveInvitationStatus ?? this.effectiveInvitationStatus,
      isCreator: isCreator ?? this.isCreator,
      canViewFull: canViewFull ?? this.canViewFull,
      currentMission: currentMission ?? this.currentMission,
      teamReadiness: teamReadiness ?? this.teamReadiness,
      operationalResponsibleName:
          operationalResponsibleName ?? this.operationalResponsibleName,
      connectedCount: connectedCount ?? this.connectedCount,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      channelId: channelId ?? this.channelId,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  factory ControlPlanContext.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['plan'];
    final rawTeams = json['teams'];
    final rawMission = json['current_mission'];

    final teams = <ControlTeam>[];
    if (rawTeams is List) {
      for (final item in rawTeams) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final memberRows = (map['team_members'] as List?) ?? const [];
        final members = memberRows
            .whereType<Map>()
            .map((m) => TeamMember.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        teams.add(ControlTeam.fromJson(map, members: members));
      }
    }

    final canViewFull = json['can_view_full'] as bool? ?? false;
    ControlMissionSummary? currentMission;
    if (rawMission is Map) {
      currentMission = ControlMissionSummary.fromJson(
        Map<String, dynamic>.from(rawMission),
      );
      if (canViewFull && !currentMission.fullAccess) {
        currentMission = currentMission.copyWith(fullAccess: true);
      }
    }

    return ControlPlanContext(
      plan: rawPlan is Map
          ? ControlPlanSummary.fromJson(Map<String, dynamic>.from(rawPlan))
          : null,
      myTeamId: json['my_team_id'] as String?,
      teams: teams,
      myInvitationStatus: json['my_invitation_status'] != null
          ? InvitationStatus.fromDb(json['my_invitation_status'] as String?)
          : null,
      effectiveInvitationStatus: EffectiveInvitationStatus.fromDb(
        json['my_invitation_effective_status'] as String?,
      ),
      isCreator: json['is_creator'] as bool? ?? false,
      canViewFull: canViewFull,
      currentMission: currentMission,
      teamReadiness: json['team_readiness'] is Map
          ? TeamReadiness.fromJson(
              Map<String, dynamic>.from(json['team_readiness'] as Map),
            )
          : null,
      operationalResponsibleName:
          json['operational_responsible_name'] as String?,
      connectedCount: json['connected_count'] as int? ?? 0,
      lastActivityAt: json['last_activity_at'] != null
          ? DateTime.tryParse(json['last_activity_at'] as String)
          : null,
      channelId: json['channel_id'] as String?,
      messageCount: json['message_count'] as int? ?? 0,
    );
  }

  ControlTeam? get myTeam {
    final id = myTeamId;
    if (id == null) return null;
    for (final team in teams) {
      if (team.id == id) return team;
    }
    return null;
  }

  List<ControlTeam> get otherTeams {
    final id = myTeamId;
    if (id == null) return teams;
    return teams.where((t) => t.id != id).toList();
  }

  bool get hasMyTeam => myTeamId != null && myTeam != null;

  bool get hasPendingInvitation =>
      effectiveInvitationStatus == EffectiveInvitationStatus.invited;

  bool get isExpiredInvitation =>
      effectiveInvitationStatus == EffectiveInvitationStatus.expired;

  bool isPadFor(String? driverUserId) {
    if (driverUserId == null) return false;
    final team = myTeam;
    if (team == null) return false;
    for (final m in team.members) {
      if (m.userId == driverUserId && m.hasMention(TeamMention.pad)) {
        return true;
      }
    }
    return false;
  }

  TeamReadiness get readiness =>
      teamReadiness ?? TeamReadiness.fromTeam(myTeam);

  MissionPhase get currentPhase {
    final m = displayMission;
    if (m == null) return MissionPhase.preparation;
    return m.phase;
  }

  /// Mission affichable : RPC ou repli client équipe (+ plan si présent).
  ControlMissionSummary? get displayMission {
    if (effectiveInvitationStatus == EffectiveInvitationStatus.declined) {
      return null;
    }
    if (currentMission != null) return currentMission;
    final team = myTeam;
    final teamId = myTeamId;
    if (team == null || teamId == null) return null;

    final p = plan;
    if (p == null &&
        effectiveInvitationStatus != EffectiveInvitationStatus.invited) {
      return null;
    }

    final anchorDate = p?.startDate ?? DateTime.now();

    DateTime? start;
    DateTime? end;
    final dep = team.departureTime;
    final ret = team.returnTime;
    if (dep != null) {
      start = DateTime(
        anchorDate.year,
        anchorDate.month,
        anchorDate.day,
        dep.hour,
        dep.minute,
      );
    }
    if (ret != null) {
      end = DateTime(
        anchorDate.year,
        anchorDate.month,
        anchorDate.day,
        ret.hour,
        ret.minute,
      );
      if (start != null && !end.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      }
    }

    return ControlMissionSummary(
      id: teamId,
      controlPlanId: p?.id,
      planName: p?.name ?? team.name,
      teamId: teamId,
      teamName: team.name,
      scheduledStart: start,
      scheduledEnd: end,
      status: ControlMissionStatus.assigned,
      fullAccess: canViewFull,
      zoneLabel: team.zone,
      lineId: team.lineId,
      instructions: p?.instructions ?? const [],
      teamMembers: canViewFull ? team.members : const [],
      missionDisplayNumber: p?.missionDisplayNumber,
      objective: p?.objective,
      priorityDb: p?.priority.dbValue,
    );
  }
}

/// Page d'historique missions (`my_control_plan_history`).
class ControlPlanHistoryPage {
  final List<ControlMissionSummary> missions;
  final bool hasMore;

  const ControlPlanHistoryPage({
    this.missions = const [],
    this.hasMore = false,
  });

  factory ControlPlanHistoryPage.fromJson(Map<String, dynamic> json) {
    final raw = json['missions'];
    final missions = <ControlMissionSummary>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          missions.add(
            ControlMissionSummary.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return ControlPlanHistoryPage(
      missions: missions,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}
