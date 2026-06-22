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

  const MsrMission({
    required this.id,
    required this.title,
    required this.sector,
    required this.scheduledAt,
    required this.status,
    this.zoneLabel,
    this.instructions,
    this.teamLabel,
  });

  factory MsrMission.fromJson(Map<String, dynamic> json) {
    return MsrMission(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Mission',
      sector: json['sector'] as String? ?? '—',
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? '') ??
          DateTime.now(),
      status: MsrMissionStatusX.fromDb(json['status'] as String? ?? 'upcoming'),
      zoneLabel: json['zone_label'] as String?,
      instructions: json['instructions'] as String?,
      teamLabel: json['team_label'] as String?,
    );
  }
}
