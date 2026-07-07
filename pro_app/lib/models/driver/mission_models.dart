import 'control_plan_context.dart';
import 'control_team.dart';

/// Phase UX d'une mission de contrôle.
enum MissionPhase {
  preparation('Préparation'),
  intervention('Intervention'),
  debrief('Débrief'),
  archived('Archivée'),
  suspended('Suspendue');

  final String label;
  const MissionPhase(this.label);

  static MissionPhase fromMission(ControlMissionSummary? mission) {
    if (mission == null) return MissionPhase.preparation;
    switch (mission.status) {
      case ControlMissionStatus.inProgress:
        return MissionPhase.intervention;
      case ControlMissionStatus.completed:
        return MissionPhase.archived;
      case ControlMissionStatus.cancelled:
        return MissionPhase.archived;
      default:
        return MissionPhase.preparation;
    }
  }
}

/// Priorité affichée.
enum MissionPriority {
  standard('low', 'Standard'),
  reinforced('medium', 'Renforcée'),
  priority('high', 'Prioritaire');

  final String dbValue;
  final String label;
  const MissionPriority(this.dbValue, this.label);

  static MissionPriority fromDb(String? value) {
    for (final p in MissionPriority.values) {
      if (p.dbValue == value) return p;
    }
    return MissionPriority.standard;
  }
}

/// Objectif opérationnel prédéfini d'une mission de contrôle.
enum MissionObjectivePreset {
  informationsEtControles('Informations & Contrôles'),
  informations('Informations'),
  autre('Autre');

  final String label;
  const MissionObjectivePreset(this.label);

  static MissionObjectivePreset? fromStored(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    for (final preset in MissionObjectivePreset.values) {
      if (preset != MissionObjectivePreset.autre && preset.label == trimmed) {
        return preset;
      }
    }
    return MissionObjectivePreset.autre;
  }
}

/// Types d'événements métier mission.
enum MissionEventType {
  missionCreated('MISSION_CREATED'),
  memberJoined('MEMBER_JOINED'),
  memberDeclined('MEMBER_DECLINED'),
  memberPresent('MEMBER_PRESENT'),
  roleUpdated('ROLE_UPDATED'),
  sectorUpdated('SECTOR_UPDATED'),
  missionStarted('MISSION_STARTED'),
  missionCompleted('MISSION_COMPLETED'),
  missionSuspended('MISSION_SUSPENDED');

  final String value;
  const MissionEventType(this.value);
}

/// Item checklist préparation.
class ReadinessItem {
  final String key;
  final String label;
  final bool done;
  final String? blocking;

  const ReadinessItem({
    required this.key,
    required this.label,
    required this.done,
    this.blocking,
  });

  factory ReadinessItem.fromJson(Map<String, dynamic> json) {
    return ReadinessItem(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      blocking: json['blocking'] as String?,
    );
  }
}

/// Checklist équipe prête.
class TeamReadiness {
  final List<ReadinessItem> items;
  final bool ready;
  final String? blockingLabel;
  final int joinedCount;
  final int joinedTotal;
  final int presentCount;

  const TeamReadiness({
    this.items = const [],
    this.ready = false,
    this.blockingLabel,
    this.joinedCount = 0,
    this.joinedTotal = 0,
    this.presentCount = 0,
  });

  factory TeamReadiness.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TeamReadiness();
    final raw = json['items'];
    final items = <ReadinessItem>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          items.add(ReadinessItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return TeamReadiness(
      items: items,
      ready: json['ready'] as bool? ?? false,
      blockingLabel: json['blocking_label'] as String?,
      joinedCount: json['joined_count'] as int? ?? 0,
      joinedTotal: json['joined_total'] as int? ?? 0,
      presentCount: json['present_count'] as int? ?? 0,
    );
  }

  /// Calcul client si RPC readiness indisponible.
  static TeamReadiness fromTeam(ControlTeam? team) {
    if (team == null) return const TeamReadiness();
    final active = team.members
        .where((m) => m.invitationStatus != InvitationStatus.removed)
        .toList();
    final eligibleForRole = active
        .where((m) => m.invitationStatus != InvitationStatus.declined)
        .toList();
    final hasPad = eligibleForRole.any((m) => m.hasMention(TeamMention.pad));
    final hasChef = eligibleForRole.any((m) => m.hasMention(TeamMention.chef));
    final hasTpe = eligibleForRole.any((m) => m.hasMention(TeamMention.tpe));
    final joined = active
        .where((m) => m.invitationStatus == InvitationStatus.accepted)
        .toList();
    final invited = active
        .where((m) => m.invitationStatus == InvitationStatus.invited)
        .length;
    final declined = active
        .where((m) => m.invitationStatus == InvitationStatus.declined)
        .toList();
    final total = active.length;

    String? blocking;
    for (final m in joined) {
      if (!_isPresent(m)) {
        blocking = '${m.nameOrFallback} n\'est pas encore arrivé';
        break;
      }
    }
    if (blocking == null && declined.isNotEmpty) {
      blocking = '${declined.first.nameOrFallback} a refusé le service';
    }

    final items = [
      ReadinessItem(key: 'pad', label: 'PAD désigné', done: hasPad),
      ReadinessItem(key: 'chef', label: 'Chef désigné', done: hasChef),
      ReadinessItem(key: 'tpe', label: 'TPE désigné', done: hasTpe),
      ReadinessItem(
        key: 'all_joined',
        label: 'Tous les agents ont accepté',
        done:
            total > 0 &&
            invited == 0 &&
            declined.isEmpty &&
            joined.length == total,
      ),
      ReadinessItem(
        key: 'all_present',
        label: 'Tous les agents sont présents',
        done: joined.isNotEmpty && joined.every(_isPresent),
        blocking: blocking,
      ),
    ];

    final ready = items.every((i) => i.done);

    return TeamReadiness(
      items: items,
      ready: ready,
      blockingLabel: ready ? null : (blocking ?? 'Préparation incomplète'),
      joinedCount: joined.length,
      joinedTotal: total,
      presentCount: joined.where(_isPresent).length,
    );
  }

  static bool _isPresent(TeamMember m) => m.presenceStatus == 'present';
}

enum MemberPresenceStatus {
  invited,
  declined,
  participant,
  present;

  static MemberPresenceStatus fromTeamMember(TeamMember m) {
    if (m.invitationStatus == InvitationStatus.invited) {
      return MemberPresenceStatus.invited;
    }
    if (m.invitationStatus == InvitationStatus.declined) {
      return MemberPresenceStatus.declined;
    }
    if (m.presenceStatus == 'present') {
      return MemberPresenceStatus.present;
    }
    return MemberPresenceStatus.participant;
  }

  String get label => switch (this) {
    MemberPresenceStatus.invited => 'Invitation en attente',
    MemberPresenceStatus.declined => 'Refusée',
    MemberPresenceStatus.participant => 'A rejoint le service',
    MemberPresenceStatus.present => 'Présent',
  };
}

/// Payload débrief.
class MissionDebrief {
  final String missionName;
  final int durationMinutes;
  final int teamSize;
  final String? padName;
  final String? operationalResponsibleName;
  final int incidentsCount;
  final int notesCount;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? displayNumber;
  final String? referenceCode;

  const MissionDebrief({
    required this.missionName,
    this.durationMinutes = 0,
    this.teamSize = 0,
    this.padName,
    this.operationalResponsibleName,
    this.incidentsCount = 0,
    this.notesCount = 0,
    this.startedAt,
    this.completedAt,
    this.displayNumber,
    this.referenceCode,
  });

  factory MissionDebrief.fromJson(Map<String, dynamic> json) {
    return MissionDebrief(
      missionName: json['mission_name'] as String? ?? 'Service',
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      teamSize: json['team_size'] as int? ?? 0,
      padName: json['pad_name'] as String?,
      operationalResponsibleName:
          json['operational_responsible_name'] as String?,
      incidentsCount: json['incidents_count'] as int? ?? 0,
      notesCount: json['notes_count'] as int? ?? 0,
      startedAt: _dt(json['started_at']),
      completedAt: _dt(json['completed_at']),
      displayNumber: json['display_number'] as int?,
      referenceCode: json['reference_code'] as String?,
    );
  }

  static DateTime? _dt(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String get durationLabel {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}';
    return '${m}min';
  }
}

/// Ressources mission (stub V2).
enum MissionResourceKind { photo, document, audio, position, note, incident }
