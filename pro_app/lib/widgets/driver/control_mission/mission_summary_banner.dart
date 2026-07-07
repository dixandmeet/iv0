import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../models/driver/control_plan_context.dart';
import '../../../models/driver/mission_models.dart';
import '../../../theme/driver_home_palette.dart';
import 'mission_shared_widgets.dart';

class MissionSummaryBanner extends StatelessWidget {
  final ControlMissionSummary mission;
  final MissionPhase phase;
  final TeamReadiness readiness;
  final int messageCount;
  final int incidentCount;
  final int noteCount;

  const MissionSummaryBanner({
    super.key,
    required this.mission,
    required this.phase,
    required this.readiness,
    this.messageCount = 0,
    this.incidentCount = 0,
    this.noteCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final phaseColor = missionPhaseColor(phase);
    final title = _title(mission);
    final subtitle = _subtitle(mission);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        border: Border(bottom: BorderSide(color: DriverHomePalette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: DriverHomePalette.textDark,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DriverHomePalette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: phaseColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  phase.label,
                  style: TextStyle(
                    color: phaseColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                LucideIcons.users,
                '${readiness.presentCount}/${readiness.joinedTotal} prêts',
              ),
              _chip(
                LucideIcons.mapPin,
                missionSectorLabel(mission),
                expanded: true,
              ),
              if (phase == MissionPhase.intervention &&
                  mission.interventionStartedAt != null)
                _chip(
                  LucideIcons.clock,
                  'Depuis ${_since(mission.interventionStartedAt!)}',
                )
              else if (mission.scheduledStart != null)
                _chip(
                  LucideIcons.clock,
                  'Début ${_fmt(mission.scheduledStart!)}',
                ),
              if (mission.scheduledEnd != null)
                _chip(LucideIcons.clock, 'Fin ${_fmt(mission.scheduledEnd!)}'),
              if (mission.scheduledEnd != null)
                _chip(
                  LucideIcons.home,
                  'Retour dépôt ${_fmt(mission.scheduledEnd!)}',
                ),
              if (messageCount > 0)
                _chip(LucideIcons.messageCircle, '$messageCount messages'),
              if (incidentCount > 0)
                _chip(LucideIcons.triangleAlert, '$incidentCount incident'),
              if (noteCount > 0)
                _chip(LucideIcons.notebookPen, '$noteCount notes'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, {bool expanded = false}) {
    return Container(
      constraints: expanded ? const BoxConstraints(maxWidth: 190) : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: DriverHomePalette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DriverHomePalette.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  static String _title(ControlMissionSummary mission) {
    if (mission.missionDisplayNumber != null) return mission.displayNumberLabel;
    return mission.planName;
  }

  static String? _subtitle(ControlMissionSummary mission) {
    if (mission.missionDisplayNumber == null) return null;
    final normalizedPlan = mission.planName.trim();
    final normalizedNumber = mission.displayNumberLabel.trim();
    if (normalizedPlan.isEmpty || normalizedPlan == normalizedNumber) {
      return null;
    }
    return normalizedPlan;
  }

  static String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _since(DateTime start) {
    final d = DateTime.now().difference(start);
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60}';
    return '${d.inMinutes} min';
  }
}
