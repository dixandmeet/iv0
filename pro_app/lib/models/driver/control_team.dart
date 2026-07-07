import 'package:flutter/material.dart';

import '../../theme/driver_home_palette.dart';

/// Type d'équipe. Le module Contrôle est livré en v1 ; Intervention et UMTC
/// sont prévus côté schéma pour une extension ultérieure.
enum TeamType {
  control('control', 'Contrôle'),
  intervention('intervention', 'Intervention'),
  umtc('umtc', 'UMTC');

  final String dbValue;
  final String label;

  const TeamType(this.dbValue, this.label);

  static TeamType fromDb(String? value) => TeamType.values.firstWhere(
    (t) => t.dbValue == value,
    orElse: () => TeamType.control,
  );
}

/// Statut d'une équipe.
enum TeamStatus {
  draft('draft', 'Brouillon'),
  planned('planned', 'Planifiée'),
  awaitingAgents('awaiting_agents', 'En attente agents'),
  ready('ready', 'Prête départ');

  final String dbValue;
  final String label;

  const TeamStatus(this.dbValue, this.label);

  static TeamStatus fromDb(String? value) => TeamStatus.values.firstWhere(
    (s) => s.dbValue == value,
    orElse: () => TeamStatus.draft,
  );

  Color get color {
    switch (this) {
      case TeamStatus.draft:
        return DriverHomePalette.textSecondary;
      case TeamStatus.planned:
        return DriverHomePalette.primary;
      case TeamStatus.awaitingAgents:
        return DriverHomePalette.warning;
      case TeamStatus.ready:
        return DriverHomePalette.blue;
    }
  }
}

/// Statut d'invitation d'un agent au sein d'une équipe.
enum InvitationStatus {
  invited('invited', 'Invité'),
  accepted('accepted', 'Accepté'),
  declined('declined', 'Refusé'),
  pending('pending', 'En attente'),
  removed('removed', 'Retiré'),
  unavailable('unavailable', 'Indisponible');

  final String dbValue;
  final String label;

  const InvitationStatus(this.dbValue, this.label);

  static InvitationStatus fromDb(String? value) =>
      InvitationStatus.values.firstWhere(
        (s) => s.dbValue == value,
        orElse: () => InvitationStatus.invited,
      );
}

/// Mode de déplacement de l'équipe (véhicule ou à pied).
enum TeamMobilityMode {
  vehicle('vehicle', 'Véhicule'),
  onFoot('on_foot', 'À pied');

  final String dbValue;
  final String label;

  const TeamMobilityMode(this.dbValue, this.label);

  static TeamMobilityMode? fromDb(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final m in TeamMobilityMode.values) {
      if (m.dbValue == value) return m;
    }
    return null;
  }
}

/// Créneau horaire (vacation) d'une équipe.
class TeamVacation {
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  const TeamVacation({this.startTime, this.endTime});

  bool get isEmpty => startTime == null && endTime == null;

  bool get isComplete => startTime != null && endTime != null;

  bool get isValid {
    if (!isComplete) return false;
    return _toMinutes(endTime!) > _toMinutes(startTime!);
  }

  TeamVacation copyWith({TimeOfDay? startTime, TimeOfDay? endTime}) {
    return TeamVacation(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'start_time': timeOfDayToSql(startTime),
    'end_time': timeOfDayToSql(endTime),
  };

  factory TeamVacation.fromJson(Map<String, dynamic> json) => TeamVacation(
    startTime: ControlTeam._parseTime(json['start_time'] as String?),
    endTime: ControlTeam._parseTime(json['end_time'] as String?),
  );

  static int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
}

/// Consigne opérationnelle avec créneau horaire optionnel.
class TeamInstruction {
  final String text;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  const TeamInstruction({required this.text, this.startTime, this.endTime});

  bool get hasTimes => startTime != null || endTime != null;

  bool get timesValid {
    if (startTime == null || endTime == null) return true;
    return TeamVacation._toMinutes(endTime!) >
        TeamVacation._toMinutes(startTime!);
  }

  String get timeLabel {
    if (startTime == null && endTime == null) return '';
    return '${formatTimeLabel(startTime)} → ${formatTimeLabel(endTime)}';
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    if (startTime != null) 'start_time': timeOfDayToSql(startTime),
    if (endTime != null) 'end_time': timeOfDayToSql(endTime),
  };

  factory TeamInstruction.fromJson(dynamic raw) {
    if (raw is String) {
      final text = raw.trim();
      return TeamInstruction(text: text.isEmpty ? raw : text);
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      return TeamInstruction(
        text: map['text'] as String? ?? '',
        startTime: ControlTeam._parseTime(map['start_time'] as String?),
        endTime: ControlTeam._parseTime(map['end_time'] as String?),
      );
    }
    return const TeamInstruction(text: '');
  }
}

/// Mention opérationnelle attribuable à un agent.
///
/// Les valeurs DB sont volontairement les libellés courts ("PAD", "Chef",
/// "TPE") stockés tels quels dans le tableau JSONB `mentions`.
enum TeamMention {
  pad('PAD'),
  chef('Chef'),
  tpe('TPE');

  /// Valeur stockée en base (et libellé affiché).
  final String dbValue;

  const TeamMention(this.dbValue);

  String get label => dbValue;

  static TeamMention? fromDb(String? value) {
    for (final m in TeamMention.values) {
      if (m.dbValue == value) return m;
    }
    return null;
  }

  Color get color {
    switch (this) {
      case TeamMention.pad:
        return DriverHomePalette.primary;
      case TeamMention.chef:
        return DriverHomePalette.purple;
      case TeamMention.tpe:
        return DriverHomePalette.blue;
    }
  }

  /// Une équipe ne peut avoir qu'un seul PAD et qu'un seul Chef ; les TPE
  /// peuvent être multiples.
  bool get isUnique => this == TeamMention.pad || this == TeamMention.chef;
}

/// Agent retourné par la recherche (RPC `search_team_agents`).
class TeamAgent {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? driverNumber;
  final String? depotName;

  /// Équipe active à laquelle l'agent est déjà affecté (le cas échéant).
  final String? activeTeamId;
  final String? activeTeamName;

  const TeamAgent({
    required this.id,
    this.firstName,
    this.lastName,
    this.driverNumber,
    this.depotName,
    this.activeTeamId,
    this.activeTeamName,
  });

  bool get hasActiveTeam => activeTeamId != null;

  String get fullName {
    final parts = [
      firstName,
      lastName,
    ].where((p) => p != null && p.trim().isNotEmpty).map((p) => p!.trim());
    final joined = parts.join(' ');
    return joined.isNotEmpty ? joined : (driverNumber ?? 'Agent');
  }

  String get initials {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory TeamAgent.fromJson(Map<String, dynamic> json) {
    return TeamAgent(
      id: json['id'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      driverNumber: json['driver_number'] as String?,
      depotName: json['depot_name'] as String?,
      activeTeamId: json['active_team_id'] as String?,
      activeTeamName: json['active_team_name'] as String?,
    );
  }
}

/// Membre d'une équipe : un agent et ses mentions.
class TeamMember {
  final String? id;
  final String userId;
  final InvitationStatus invitationStatus;
  final Set<TeamMention> mentions;
  final String? presenceStatus;

  // Identité dénormalisée pour l'affichage (renseignée à l'ajout).
  final String? displayName;
  final String? driverNumber;

  const TeamMember({
    this.id,
    required this.userId,
    this.invitationStatus = InvitationStatus.invited,
    this.mentions = const {},
    this.presenceStatus,
    this.displayName,
    this.driverNumber,
  });

  factory TeamMember.fromAgent(TeamAgent agent) => TeamMember(
    userId: agent.id,
    displayName: agent.fullName,
    driverNumber: agent.driverNumber,
  );

  String get nameOrFallback {
    final n = displayName?.trim();
    return (n != null && n.isNotEmpty) ? n : 'Agent';
  }

  String get initials {
    final parts = nameOrFallback
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool hasMention(TeamMention m) => mentions.contains(m);

  TeamMember toggleMention(TeamMention m) {
    final next = Set<TeamMention>.from(mentions);
    if (next.contains(m)) {
      next.remove(m);
    } else {
      next.add(m);
    }
    return copyWith(mentions: next);
  }

  TeamMember copyWith({
    InvitationStatus? invitationStatus,
    Set<TeamMention>? mentions,
    String? presenceStatus,
    String? displayName,
    String? driverNumber,
  }) {
    return TeamMember(
      id: id,
      userId: userId,
      invitationStatus: invitationStatus ?? this.invitationStatus,
      mentions: mentions ?? this.mentions,
      presenceStatus: presenceStatus ?? this.presenceStatus,
      displayName: displayName ?? this.displayName,
      driverNumber: driverNumber ?? this.driverNumber,
    );
  }

  /// Tableau JSONB des mentions, dans l'ordre PAD, Chef, TPE.
  List<String> get mentionsJson => TeamMention.values
      .where(mentions.contains)
      .map((m) => m.dbValue)
      .toList();

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final raw = json['mentions'];
    final mentions = <TeamMention>{};
    if (raw is List) {
      for (final v in raw) {
        final m = TeamMention.fromDb(v as String?);
        if (m != null) mentions.add(m);
      }
    }
    return TeamMember(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      invitationStatus: InvitationStatus.fromDb(
        json['invitation_status'] as String?,
      ),
      mentions: mentions,
      presenceStatus: json['presence_status'] as String?,
      displayName: json['display_name'] as String?,
      driverNumber: json['driver_number'] as String?,
    );
  }
}

/// Équipe de contrôle (table `teams`) avec ses membres.
class ControlTeam {
  final String id;
  final String name;
  final TeamType type;
  final String? depotId;
  final TeamStatus status;
  final TimeOfDay? departureTime;
  final TimeOfDay? returnTime;
  final List<TeamVacation> vacations;
  final TeamMobilityMode? mobilityMode;
  final String? lineId;
  final String? vehicleId;
  final String? zone;
  final List<TeamInstruction> instructions;
  final DateTime? createdAt;
  final String? createdBy;
  final List<TeamMember> members;

  const ControlTeam({
    required this.id,
    required this.name,
    this.type = TeamType.control,
    this.depotId,
    this.status = TeamStatus.draft,
    this.departureTime,
    this.returnTime,
    this.vacations = const [],
    this.mobilityMode,
    this.lineId,
    this.vehicleId,
    this.zone,
    this.instructions = const [],
    this.createdAt,
    this.createdBy,
    this.members = const [],
  });

  bool isManagedBy(String? driverId) =>
      driverId != null && createdBy != null && createdBy == driverId;

  int get memberCount => members.length;

  ControlTeam copyWith({
    TeamStatus? status,
    List<TeamVacation>? vacations,
    TeamMobilityMode? mobilityMode,
    String? lineId,
    String? vehicleId,
    String? zone,
    List<TeamInstruction>? instructions,
    List<TeamMember>? members,
  }) {
    return ControlTeam(
      id: id,
      name: name,
      type: type,
      depotId: depotId,
      status: status ?? this.status,
      departureTime: departureTime,
      returnTime: returnTime,
      vacations: vacations ?? this.vacations,
      mobilityMode: mobilityMode ?? this.mobilityMode,
      lineId: lineId ?? this.lineId,
      vehicleId: vehicleId ?? this.vehicleId,
      zone: zone ?? this.zone,
      instructions: instructions ?? this.instructions,
      createdAt: createdAt,
      createdBy: createdBy,
      members: members ?? this.members,
    );
  }

  factory ControlTeam.fromJson(
    Map<String, dynamic> json, {
    List<TeamMember> members = const [],
  }) {
    return ControlTeam(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Équipe',
      type: TeamType.fromDb(json['type'] as String?),
      depotId: json['depot_id'] as String?,
      status: TeamStatus.fromDb(json['status'] as String?),
      departureTime: _parseTime(json['departure_time'] as String?),
      returnTime: _parseTime(json['return_time'] as String?),
      vacations: _parseVacations(json['vacations'], json),
      mobilityMode: TeamMobilityMode.fromDb(json['mobility_mode'] as String?),
      lineId: json['line_id'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      zone: json['zone'] as String?,
      instructions: _parseInstructions(json['instructions']),
      createdAt: DateTime.tryParse(
        json['created_at'] as String? ?? '',
      )?.toLocal(),
      createdBy: json['created_by'] as String?,
      members: members,
    );
  }

  static List<TeamInstruction> _parseInstructions(dynamic raw) {
    if (raw is List) {
      return raw
          .map(TeamInstruction.fromJson)
          .where((i) => i.text.trim().isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return [TeamInstruction(text: raw.trim())];
    }
    return const [];
  }

  static List<TeamVacation> _parseVacations(
    dynamic raw,
    Map<String, dynamic> json,
  ) {
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map>()
          .map((e) => TeamVacation.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    final departure = _parseTime(json['departure_time'] as String?);
    final returnTime = _parseTime(json['return_time'] as String?);
    if (departure != null || returnTime != null) {
      return [TeamVacation(startTime: departure, endTime: returnTime)];
    }
    return const [];
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}

/// Convertit une [TimeOfDay] au format `HH:MM` attendu par une colonne TIME.
String? timeOfDayToSql(TimeOfDay? t) {
  if (t == null) return null;
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Formate une [TimeOfDay] pour l'affichage (`HH:MM`), tiret si absente.
String formatTimeLabel(TimeOfDay? t) {
  if (t == null) return '--:--';
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
