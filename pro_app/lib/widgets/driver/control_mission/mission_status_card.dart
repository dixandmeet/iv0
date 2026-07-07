import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../models/driver/control_plan_context.dart';
import '../../../models/driver/mission_models.dart';
import '../../../theme/driver_home_palette.dart';
import 'mission_shared_widgets.dart';

class MissionStatusCard extends StatelessWidget {
  final ControlPlanContext ctx;
  final ControlMissionSummary mission;
  final TeamReadiness readiness;
  final MissionPhase phase;
  final VoidCallback onOpen;
  final int messageCount;

  const MissionStatusCard({
    super.key,
    required this.ctx,
    required this.mission,
    required this.readiness,
    required this.phase,
    required this.onOpen,
    this.messageCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final priority = missionPriorityFromContext(ctx);
    final objective = ctx.plan?.objective ?? mission.objective ?? '—';
    final sector = missionSectorLabel(mission);
    final phaseColor = missionPhaseColor(phase);

    return Material(
      color: DriverHomePalette.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DriverHomePalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${mission.planName} · ${mission.displayNumberLabel}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: DriverHomePalette.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: phaseColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      phase.label,
                      style: TextStyle(
                        color: phaseColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _row('Objectif', objective),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Priorité', style: TextStyle(color: DriverHomePalette.textSecondary)),
                  const SizedBox(width: 8),
                  MissionPriorityBadge(priority: priority),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              if (phase == MissionPhase.preparation) ...[
                Text(
                  '👥 ${readiness.presentCount}/${readiness.joinedTotal} agents prêts',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text('📍 $sector'),
                const SizedBox(height: 6),
                Text('🕒 Début ${mission.scheduledStart != null ? _time(mission.scheduledStart!) : '—'}'),
              ] else ...[
                if (mission.interventionStartedAt != null)
                  Text(
                    'Depuis ${_durationSince(mission.interventionStartedAt!)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                const SizedBox(height: 6),
                Text('👥 ${readiness.joinedCount} agents'),
                const SizedBox(height: 6),
                Text('📍 $sector'),
                if (messageCount > 0) ...[
                  const SizedBox(height: 6),
                  Text('💬 $messageCount messages'),
                ],
              ],
              const SizedBox(height: 14),
              MissionGradientButton(
                label: phase == MissionPhase.intervention ? 'Ouvrir' : 'Voir le service',
                icon: LucideIcons.arrowRight,
                onPressed: onOpen,
                height: 44,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _durationSince(DateTime start) {
    final diff = DateTime.now().difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return '${h} h ${m.toString().padLeft(2, '0')}';
    return '${m} min';
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(color: DriverHomePalette.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
