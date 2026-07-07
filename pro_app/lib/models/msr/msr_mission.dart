import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Statut d'une mission MSR.
enum MsrMissionStatus { upcoming, inProgress, completed, cancelled }

extension MsrMissionStatusX on MsrMissionStatus {
  String get label {
    switch (this) {
      case MsrMissionStatus.upcoming:
        return 'À venir';
      case MsrMissionStatus.inProgress:
        return 'En cours';
      case MsrMissionStatus.completed:
        return 'Terminée';
      case MsrMissionStatus.cancelled:
        return 'Annulée';
    }
  }

  Color get color {
    switch (this) {
      case MsrMissionStatus.upcoming:
        return const Color(0xFF1B66F5);
      case MsrMissionStatus.inProgress:
        return const Color(0xFF1F9D55);
      case MsrMissionStatus.completed:
        return const Color(0xFF6B7280);
      case MsrMissionStatus.cancelled:
        return const Color(0xFFD64545);
    }
  }

  IconData get icon {
    switch (this) {
      case MsrMissionStatus.upcoming:
        return LucideIcons.clock;
      case MsrMissionStatus.inProgress:
        return LucideIcons.play;
      case MsrMissionStatus.completed:
        return LucideIcons.check;
      case MsrMissionStatus.cancelled:
        return LucideIcons.x;
    }
  }

  /// Valeur stockée en base (`msr_missions.status`). « À venir » correspond à
  /// une mission planifiée/assignée à l'agent.
  String get dbValue {
    switch (this) {
      case MsrMissionStatus.upcoming:
        return 'assigned';
      case MsrMissionStatus.inProgress:
        return 'in_progress';
      case MsrMissionStatus.completed:
        return 'completed';
      case MsrMissionStatus.cancelled:
        return 'cancelled';
    }
  }

  static MsrMissionStatus fromDb(String value) {
    switch (value) {
      case 'in_progress':
        return MsrMissionStatus.inProgress;
      case 'completed':
        return MsrMissionStatus.completed;
      case 'cancelled':
        return MsrMissionStatus.cancelled;
      default:
        return MsrMissionStatus.upcoming;
    }
  }
}

/// Type de mission MSR (service Contrôle ou Intervention).
enum MsrMissionKind { controle, intervention }

extension MsrMissionKindX on MsrMissionKind {
  String get dbValue =>
      this == MsrMissionKind.intervention ? 'intervention' : 'controle';

  String get label =>
      this == MsrMissionKind.intervention ? 'Intervention' : 'Contrôle';
}

/// Mission MSR (contrôle terrain). Modèle de scaffold : les champs sont
/// volontairement minimaux, la couche données réelle (Supabase `msr_missions`)
/// sera branchée au lot MSR.
class MsrMission {
  final String id;
  final String title;
  final String sector;
  final DateTime scheduledAt;
  final MsrMissionStatus status;
  final String? zoneLabel;
  final String? instructions;
  final String? teamLabel;
  final MsrMissionKind kind;

  const MsrMission({
    required this.id,
    required this.title,
    required this.sector,
    required this.scheduledAt,
    required this.status,
    this.zoneLabel,
    this.instructions,
    this.teamLabel,
    this.kind = MsrMissionKind.controle,
  });

  MsrMission copyWith({MsrMissionStatus? status}) {
    return MsrMission(
      id: id,
      title: title,
      sector: sector,
      scheduledAt: scheduledAt,
      status: status ?? this.status,
      zoneLabel: zoneLabel,
      instructions: instructions,
      teamLabel: teamLabel,
      kind: kind,
    );
  }

  factory MsrMission.fromJson(Map<String, dynamic> json) {
    return MsrMission(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Mission',
      sector: json['sector'] as String? ?? '—',
      scheduledAt:
          DateTime.tryParse(json['scheduled_at'] as String? ?? '') ??
          DateTime.now(),
      status: MsrMissionStatusX.fromDb(json['status'] as String? ?? 'upcoming'),
      zoneLabel: json['zone_label'] as String?,
      instructions: json['instructions'] as String?,
      teamLabel: json['team_label'] as String?,
      kind: json['kind'] == 'intervention'
          ? MsrMissionKind.intervention
          : MsrMissionKind.controle,
    );
  }

  /// Missions de démonstration (TODO : brancher Supabase `msr_missions`).
  static List<MsrMission> get mockMissions => [
    MsrMission(
      id: 'demo-1',
      title: 'Contrôle ligne 2 — Commerce',
      sector: 'Centre',
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      status: MsrMissionStatus.upcoming,
      zoneLabel: 'Zone Centre-ville',
      teamLabel: 'Équipe A',
      instructions: 'Contrôle des titres de transport aux heures de pointe.',
      kind: MsrMissionKind.controle,
    ),
    MsrMission(
      id: 'demo-2',
      title: 'Présence Busway — Haluchère',
      sector: 'Est',
      scheduledAt: DateTime.now(),
      status: MsrMissionStatus.inProgress,
      zoneLabel: 'Zone Est',
      teamLabel: 'Équipe B',
      kind: MsrMissionKind.controle,
    ),
    MsrMission(
      id: 'demo-3',
      title: 'Contrôle tram 1 — Bellevue',
      sector: 'Ouest',
      scheduledAt: DateTime.now().subtract(const Duration(hours: 3)),
      status: MsrMissionStatus.completed,
      zoneLabel: 'Zone Ouest',
      kind: MsrMissionKind.controle,
    ),
    MsrMission(
      id: 'demo-4',
      title: 'Intervention incident — Gare Centrale',
      sector: 'Centre',
      scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      status: MsrMissionStatus.upcoming,
      zoneLabel: 'Zone Gare Centrale',
      teamLabel: 'Équipe I1',
      instructions: 'Renfort suite à incident voyageur.',
      kind: MsrMissionKind.intervention,
    ),
    MsrMission(
      id: 'demo-5',
      title: 'Intervention sécurité — Ligne C6',
      sector: 'Nord',
      scheduledAt: DateTime.now(),
      status: MsrMissionStatus.inProgress,
      zoneLabel: 'Zone Nord',
      teamLabel: 'Équipe I2',
      kind: MsrMissionKind.intervention,
    ),
  ];

  static List<MsrMission> missionsForKind(MsrMissionKind kind) =>
      mockMissions.where((m) => m.kind == kind).toList();
}
