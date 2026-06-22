import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/msr/msr_mission.dart';
import 'msr_mission_detail_screen.dart';

/// Liste des missions de l'agent MSR.
///
/// Scaffold : données mockées en mémoire (TODO lot MSR : brancher Supabase
/// `msr_missions` filtré par agent). L'état vide est géré pour le cas réel.
class MsrMissionsScreen extends StatelessWidget {
  const MsrMissionsScreen({super.key});

  // Données de démonstration. À remplacer par un chargement réel.
  static final List<MsrMission> _mockMissions = [
    MsrMission(
      id: 'demo-1',
      title: 'Contrôle ligne 2 — Commerce',
      sector: 'Centre',
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      status: MsrMissionStatus.upcoming,
      zoneLabel: 'Zone Centre-ville',
      teamLabel: 'Équipe A',
      instructions: 'Contrôle des titres de transport aux heures de pointe.',
    ),
    MsrMission(
      id: 'demo-2',
      title: 'Présence Busway — Haluchère',
      sector: 'Est',
      scheduledAt: DateTime.now(),
      status: MsrMissionStatus.inProgress,
      zoneLabel: 'Zone Est',
      teamLabel: 'Équipe B',
    ),
    MsrMission(
      id: 'demo-3',
      title: 'Contrôle tram 1 — Bellevue',
      sector: 'Ouest',
      scheduledAt: DateTime.now().subtract(const Duration(hours: 3)),
      status: MsrMissionStatus.completed,
      zoneLabel: 'Zone Ouest',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final missions = _mockMissions;

    if (missions.isEmpty) {
      return const _EmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: missions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _MissionCard(mission: missions[i]),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final MsrMission mission;
  const _MissionCard({required this.mission});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('EEE d MMM · HH:mm', 'fr_FR').format(
      mission.scheduledAt,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          mission.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${mission.sector} · $time'),
        ),
        trailing: _StatusChip(status: mission.status),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MsrMissionDetailScreen(mission: mission),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MsrMissionStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.clipboardList,
              size: 48, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          const Text('Aucune mission pour le moment'),
        ],
      ),
    );
  }
}
