import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../models/driver/control_plan_context.dart';
import '../../../models/driver/control_team.dart';
import '../../../models/driver/mission_models.dart';
import '../../../theme/driver_home_palette.dart';

class MissionRoleBadge extends StatelessWidget {
  final TeamMention? mention;

  const MissionRoleBadge({super.key, this.mention});

  @override
  Widget build(BuildContext context) {
    if (mention == null) {
      return _pill('Agent', DriverHomePalette.textSecondary);
    }
    return switch (mention!) {
      TeamMention.pad => _pill('PAD', const Color(0xFF7C3AED)),
      TeamMention.chef => _pill('Chef', DriverHomePalette.blue),
      TeamMention.tpe => _pill('TPE', DriverHomePalette.primary),
    };
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class MissionPriorityBadge extends StatelessWidget {
  final MissionPriority priority;

  const MissionPriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      MissionPriority.standard => DriverHomePalette.primary,
      MissionPriority.reinforced => DriverHomePalette.warning,
      MissionPriority.priority => DriverHomePalette.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class PreparationChecklist extends StatelessWidget {
  final TeamReadiness readiness;
  final bool compact;

  const PreparationChecklist({
    super.key,
    required this.readiness,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final completed = readiness.items.where((item) => item.done).length;
    final total = readiness.items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact)
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Préparation du service',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: DriverHomePalette.textDark,
                  ),
                ),
              ),
              _progressPill(completed, total),
            ],
          ),
        if (!compact) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              minHeight: 8,
              backgroundColor: DriverHomePalette.border,
              color: readiness.ready
                  ? DriverHomePalette.primary
                  : DriverHomePalette.warning,
            ),
          ),
          const SizedBox(height: 14),
        ],
        ...readiness.items.map((item) {
          final pendingAgent = item.blocking != null && !item.done;
          final color = item.done
              ? DriverHomePalette.primary
              : DriverHomePalette.textSecondary;

          return Padding(
            padding: EdgeInsets.only(bottom: compact ? 8 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 24 : 30,
                  height: compact ? 24 : 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: item.done ? 0.12 : 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.45)),
                  ),
                  child: Icon(
                    item.done
                        ? LucideIcons.check
                        : pendingAgent
                        ? LucideIcons.clock
                        : LucideIcons.minus,
                    size: compact ? 14 : 16,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: compact ? 1 : 3),
                    child: Text(
                      pendingAgent ? item.blocking! : item.label,
                      style: TextStyle(
                        fontSize: compact ? 13 : 15,
                        height: 1.25,
                        color: DriverHomePalette.textDark,
                        fontWeight: item.done
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        if (!readiness.ready &&
            readiness.blockingLabel != null &&
            !compact) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DriverHomePalette.lightGreen,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: DriverHomePalette.primary.withValues(alpha: 0.18),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  LucideIcons.info,
                  color: DriverHomePalette.primary,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le service ne peut pas démarrer tant que la checklist est incomplète.',
                    style: TextStyle(
                      color: DriverHomePalette.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (readiness.ready) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(
                LucideIcons.circleCheck,
                color: DriverHomePalette.primary,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Service prêt',
                style: TextStyle(
                  color: DriverHomePalette.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _progressPill(int completed, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DriverHomePalette.lightGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$completed/$total',
        style: const TextStyle(
          color: DriverHomePalette.primary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class MissionGradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  const MissionGradientButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.loading = false,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: enabled ? null : DriverHomePalette.border,
        gradient: enabled
            ? const LinearGradient(
                colors: [
                  DriverHomePalette.gradientStart,
                  DriverHomePalette.gradientEnd,
                ],
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else ...[
                  Icon(
                    icon,
                    size: 18,
                    color: enabled
                        ? Colors.white
                        : DriverHomePalette.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: enabled
                          ? Colors.white
                          : DriverHomePalette.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color missionPhaseColor(MissionPhase phase) => switch (phase) {
  MissionPhase.preparation => DriverHomePalette.warning,
  MissionPhase.intervention => DriverHomePalette.primary,
  MissionPhase.debrief => DriverHomePalette.blue,
  MissionPhase.archived => DriverHomePalette.textSecondary,
  MissionPhase.suspended => DriverHomePalette.danger,
};

MissionPriority missionPriorityFromContext(ControlPlanContext? ctx) {
  final p = ctx?.plan?.priority;
  if (p != null) return p;
  final db = ctx?.displayMission?.priorityDb;
  return MissionPriority.fromDb(db);
}

String missionSectorLabel(ControlMissionSummary? m) {
  if (m == null) return '—';
  if (m.zoneLabel != null && m.zoneLabel!.isNotEmpty) return m.zoneLabel!;
  if (m.lineId != null && m.lineId!.isNotEmpty) return m.lineId!;
  return m.planName;
}
