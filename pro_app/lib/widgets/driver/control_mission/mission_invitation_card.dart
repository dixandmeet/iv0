import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../models/driver/control_plan_context.dart';
import '../../../models/driver/control_team.dart';
import '../../../theme/driver_home_palette.dart';
import 'mission_shared_widgets.dart';

class MissionInvitationCard extends StatelessWidget {
  final ControlMissionSummary? mission;
  final ControlTeam? team;
  final String teamName;
  final TeamMention? proposedRole;
  final bool loading;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const MissionInvitationCard({
    super.key,
    this.mission,
    this.team,
    required this.teamName,
    this.proposedRole,
    required this.loading,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final role = proposedRole ?? _findInvitedRole(team);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverHomePalette.lightGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DriverHomePalette.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            mission?.planName ?? 'Service de contrôle',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text('Équipe $teamName', style: const TextStyle(color: DriverHomePalette.textSecondary)),
          if (mission != null) ...[
            const SizedBox(height: 8),
            Text('📍 ${missionSectorLabel(mission)}'),
            Text('🕒 ${mission!.scheduleLabel}'),
          ],
          if (role != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Rôle proposé · '),
                MissionRoleBadge(mention: role),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton(
                onPressed: loading ? null : onDecline,
                child: const Text('Refuser'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MissionGradientButton(
                  label: 'Rejoindre le service',
                  icon: LucideIcons.userCheck,
                  loading: loading,
                  onPressed: onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static TeamMention? _findInvitedRole(ControlTeam? team) {
    for (final m in team?.members ?? const <TeamMember>[]) {
      if (m.invitationStatus == InvitationStatus.invited && m.mentions.isNotEmpty) {
        return m.mentions.first;
      }
    }
    return null;
  }
}
