import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/driver/control_team.dart';
import '../../theme/driver_home_palette.dart';

/// Carte résumé d'une équipe de contrôle.
class ControlTeamCard extends StatelessWidget {
  final ControlTeam team;
  final VoidCallback? onTap;
  final bool highlighted;
  final String? badgeLabel;

  const ControlTeamCard({
    super.key,
    required this.team,
    this.onTap,
    this.highlighted = false,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDraft = team.status == TeamStatus.draft;
    final activeMembers = team.members
        .where((m) => m.invitationStatus != InvitationStatus.removed)
        .toList();
    final padCount =
        activeMembers.where((m) => m.hasMention(TeamMention.pad)).length;
    final chefCount =
        activeMembers.where((m) => m.hasMention(TeamMention.chef)).length;
    final tpeCount =
        activeMembers.where((m) => m.hasMention(TeamMention.tpe)).length;

    final borderColor = highlighted
        ? DriverHomePalette.primary
        : isDraft
            ? DriverHomePalette.primary.withValues(alpha: 0.35)
            : DriverHomePalette.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DriverHomePalette.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: highlighted ? 1.5 : 1,
            ),
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
                  Expanded(
                    child: Text(
                      team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: DriverHomePalette.textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (badgeLabel != null) ...[
                    _Badge(label: badgeLabel!),
                    const SizedBox(width: 8),
                  ],
                  ControlTeamStatusPill(status: team.status),
                ],
              ),
              if (isDraft) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      LucideIcons.pencil,
                      size: 14,
                      color: DriverHomePalette.primary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Appuyer pour reprendre',
                      style: TextStyle(
                        color: DriverHomePalette.primary.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  ControlTeamInfoChip(
                    icon: LucideIcons.users,
                    label: '${activeMembers.length} agent'
                        '${activeMembers.length > 1 ? 's' : ''}',
                  ),
                  const SizedBox(width: 8),
                  ControlTeamInfoChip(
                    icon: LucideIcons.clock,
                    label:
                        '${formatTimeLabel(team.departureTime)} → ${formatTimeLabel(team.returnTime)}',
                  ),
                ],
              ),
              if (padCount + chefCount + tpeCount > 0) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (padCount > 0)
                      ControlTeamMentionTag(
                        mention: TeamMention.pad,
                        count: padCount,
                      ),
                    if (chefCount > 0)
                      ControlTeamMentionTag(
                        mention: TeamMention.chef,
                        count: chefCount,
                      ),
                    if (tpeCount > 0)
                      ControlTeamMentionTag(
                        mention: TeamMention.tpe,
                        count: tpeCount,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ControlTeamStatusPill extends StatelessWidget {
  final TeamStatus status;
  const ControlTeamStatusPill({super.key, required this.status});

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
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ControlTeamInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const ControlTeamInfoChip({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: DriverHomePalette.textSecondary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: DriverHomePalette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class ControlTeamMentionTag extends StatelessWidget {
  final TeamMention mention;
  final int count;
  const ControlTeamMentionTag({
    super.key,
    required this.mention,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: mention.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 1 ? '${mention.label} ×$count' : mention.label,
        style: TextStyle(
          color: mention.color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DriverHomePalette.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: DriverHomePalette.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
