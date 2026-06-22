import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/msr/msr_mission.dart';

/// Détail d'une mission MSR (scaffold).
/// Les actions (prendre / terminer la mission, signaler un incident, contrôle
/// terrain) sont des emplacements désactivés en attendant le lot MSR.
class MsrMissionDetailScreen extends StatelessWidget {
  final MsrMission mission;
  const MsrMissionDetailScreen({super.key, required this.mission});

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Action disponible prochainement')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final time =
        DateFormat('EEEE d MMMM y · HH:mm', 'fr_FR').format(mission.scheduledAt);
    return Scaffold(
      appBar: AppBar(title: const Text('Mission')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            mission.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Statut', value: mission.status.label),
          _InfoRow(label: 'Secteur', value: mission.sector),
          _InfoRow(label: 'Planifiée', value: time),
          if (mission.zoneLabel != null)
            _InfoRow(label: 'Zone d\'intervention', value: mission.zoneLabel!),
          if (mission.teamLabel != null)
            _InfoRow(label: 'Équipe', value: mission.teamLabel!),
          if (mission.instructions != null) ...[
            const SizedBox(height: 16),
            Text('Consignes', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(mission.instructions!),
          ],
          const SizedBox(height: 28),
          if (mission.status == MsrMissionStatus.upcoming)
            FilledButton(
              onPressed: () => _soon(context),
              child: const Text('Prendre la mission'),
            ),
          if (mission.status == MsrMissionStatus.inProgress)
            FilledButton(
              onPressed: () => _soon(context),
              child: const Text('Terminer la mission'),
            ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _soon(context),
            child: const Text('Signaler un incident'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
