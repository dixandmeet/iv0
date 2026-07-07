import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/driver_workspace_mode.dart';
import '../../models/msr/msr_mission.dart';
import '../../screens/msr/msr_mission_detail_screen.dart';
import '../../services/msr/msr_mission_service.dart';
import '../../theme/driver_home_palette.dart';

/// Liste compacte des missions MSR réelles pour l'accueil conducteur.
class MsrMissionList extends StatelessWidget {
  final DriverWorkspaceMode mode;
  final VoidCallback? onOpenTerrain;

  const MsrMissionList({super.key, required this.mode, this.onOpenTerrain});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MsrMissionService>();
    if (!service.loaded && !service.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!service.loaded && !service.loading) service.fetchMissions();
      });
    }
    final kind = mode == DriverWorkspaceMode.intervention
        ? MsrMissionKind.intervention
        : MsrMissionKind.controle;
    final missions = service.missions.where((m) => m.kind == kind).toList();
    final accent = mode.accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.92),
                accent.withValues(alpha: 0.78),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: DriverHomePalette.cardShadow,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    mode == DriverWorkspaceMode.intervention
                        ? LucideIcons.shieldAlert
                        : LucideIcons.clipboardCheck,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Missions ${mode.label.toLowerCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                mode == DriverWorkspaceMode.intervention
                    ? 'Interventions terrain assignées à votre équipe.'
                    : 'Points et zones de contrôle du jour.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (service.loading && !service.loaded)
          const Center(child: CircularProgressIndicator())
        else if (missions.isEmpty)
          const _EmptyMissions()
        else
          ...missions.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MissionTile(mission: m),
            ),
          ),
        if (onOpenTerrain != null) ...[
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: onOpenTerrain,
            icon: const Icon(LucideIcons.map, size: 18),
            label: const Text('Voir sur la carte Terrain'),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MissionTile extends StatelessWidget {
  final MsrMission mission;
  const _MissionTile({required this.mission});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat(
      'EEE d MMM · HH:mm',
      'fr_FR',
    ).format(mission.scheduledAt);
    return Material(
      color: DriverHomePalette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MsrMissionDetailScreen(mission: mission),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DriverHomePalette.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.title,
                      style: const TextStyle(
                        color: DriverHomePalette.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${mission.sector} · $time',
                      style: const TextStyle(
                        color: DriverHomePalette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: mission.status),
            ],
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
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyMissions extends StatelessWidget {
  const _EmptyMissions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: const Column(
        children: [
          Icon(
            LucideIcons.clipboardList,
            size: 36,
            color: DriverHomePalette.textSecondary,
          ),
          SizedBox(height: 10),
          Text(
            'Aucune mission pour le moment',
            style: TextStyle(color: DriverHomePalette.textSecondary),
          ),
        ],
      ),
    );
  }
}
