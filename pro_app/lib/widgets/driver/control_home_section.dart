import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/control_plan_context.dart';
import '../../screens/driver/control_mission_workspace_screen.dart';
import '../../screens/driver/control_plan_screen.dart';
import '../../services/driver/control_plan_service.dart';
import '../../theme/driver_home_palette.dart';

const _purple = Color(0xFF6460EF);
const _purpleDark = Color(0xFF5B58E8);
const _green = Color(0xFF159B68);
const _orange = Color(0xFFF18B20);
const _softShadow = Color(0x140D2D22);

/// Dashboard de l'accueil Contrôle, branché sur le contexte mission existant.
class ControlHomeSection extends StatefulWidget {
  final VoidCallback? onOpenTerrain;

  const ControlHomeSection({super.key, this.onOpenTerrain});

  @override
  State<ControlHomeSection> createState() => _ControlHomeSectionState();
}

class _ControlHomeSectionState extends State<ControlHomeSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = context.read<ControlPlanService>();
      if (!service.loaded && !service.loading) {
        service.fetchMyContext();
      }
    });
  }

  void _openWorkspace(ControlMissionSummary mission) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ControlMissionWorkspaceScreen(mission: mission),
      ),
    );
  }

  void _openPlan() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ControlPlanScreen()));
  }

  void _showAlerts() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Le détail des alertes arrive bientôt.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ControlPlanService>();
    final ctx = service.context;
    final mission = ctx?.displayMission;
    final missionCount = mission == null ? 0 : 1;
    final teamCount = ctx?.teams.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MissionCard(
          service: service,
          contextData: ctx,
          onOpenPlan: _openPlan,
          onOpenMission: _openWorkspace,
        ),
        if (service.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            service.errorMessage!,
            style: const TextStyle(color: DriverHomePalette.danger),
          ),
        ],
        const SizedBox(height: 18),
        _SummaryCards(
          missionCount: missionCount,
          teamCount: teamCount,
          alertCount: 2,
          onMissions: _openPlan,
          onTeams: _openPlan,
          onAlerts: _showAlerts,
        ),
        const SizedBox(height: 18),
        _QuickActionsSection(
          onMissions: _openPlan,
          onTerrain: widget.onOpenTerrain,
        ),
      ],
    );
  }
}

class _MissionCard extends StatelessWidget {
  final ControlPlanService service;
  final ControlPlanContext? contextData;
  final VoidCallback onOpenPlan;
  final ValueChanged<ControlMissionSummary> onOpenMission;

  const _MissionCard({
    required this.service,
    required this.contextData,
    required this.onOpenPlan,
    required this.onOpenMission,
  });

  @override
  Widget build(BuildContext context) {
    final state = _stateFor(contextData);
    final loading = service.loading && !service.loaded;
    final mission = contextData?.displayMission;
    final buttonAction = loading
        ? null
        : mission != null &&
              state == _MissionVisualState.active &&
              !contextData!.hasPendingInvitation
        ? () => onOpenMission(mission)
        : onOpenPlan;
    final buttonLabel = switch (state) {
      _MissionVisualState.loading => 'Chargement…',
      _MissionVisualState.empty => 'Créer un service',
      _MissionVisualState.active => 'Ouvrir le service',
      _MissionVisualState.invitation => 'Voir l’invitation',
      _MissionVisualState.expired => 'Ouvrir mes services',
      _MissionVisualState.declined => 'Voir l’historique',
    };

    return Container(
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6E6AF7), _purpleDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _purpleDark.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(top: -16, right: -20, child: _DotPattern()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      LucideIcons.clipboardCheck,
                      color: _purple,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Service de contrôle',
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          height: 1.05,
                          letterSpacing: -0.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Votre espace de préparation des services de contrôle.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _MissionStateContent(
                    key: ValueKey(state),
                    state: state,
                    contextData: contextData,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _MissionActionButton(
                label: buttonLabel,
                enabled: buttonAction != null,
                onTap: buttonAction,
              ),
            ],
          ),
        ],
      ),
    );
  }

  _MissionVisualState _stateFor(ControlPlanContext? ctx) {
    if (service.loading && !service.loaded) {
      return _MissionVisualState.loading;
    }
    if (ctx == null) return _MissionVisualState.loading;
    if (ctx.isExpiredInvitation) return _MissionVisualState.expired;
    if (ctx.effectiveInvitationStatus == EffectiveInvitationStatus.declined) {
      return _MissionVisualState.declined;
    }
    if (ctx.hasPendingInvitation) return _MissionVisualState.invitation;
    if (ctx.displayMission != null) return _MissionVisualState.active;
    return _MissionVisualState.empty;
  }
}

enum _MissionVisualState {
  loading,
  empty,
  active,
  invitation,
  expired,
  declined,
}

class _MissionStateContent extends StatelessWidget {
  final _MissionVisualState state;
  final ControlPlanContext? contextData;

  const _MissionStateContent({
    super.key,
    required this.state,
    required this.contextData,
  });

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      _MissionVisualState.loading => const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6),
      ),
      _MissionVisualState.empty => const _EmptyMissionContent(),
      _MissionVisualState.active => _ActiveMissionContent(
        mission: contextData!.displayMission!,
      ),
      _MissionVisualState.invitation => _MessageMissionContent(
        icon: LucideIcons.mailOpen,
        title: 'Invitation en attente',
        message: 'Une équipe vous invite à rejoindre son service de contrôle.',
        detail: contextData?.myTeam?.name,
      ),
      _MissionVisualState.expired => const _MessageMissionContent(
        icon: LucideIcons.clockAlert,
        title: 'Service dépassé',
        message: 'Cette invitation n’est plus active.',
      ),
      _MissionVisualState.declined => const _MessageMissionContent(
        icon: LucideIcons.userX,
        title: 'Invitation refusée',
        message: 'Le service reste disponible dans votre historique.',
      ),
    };
  }
}

class _EmptyMissionContent extends StatelessWidget {
  const _EmptyMissionContent();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 300;
        return Row(
          children: [
            Container(
              width: compact ? 58 : 72,
              height: compact ? 68 : 82,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    LucideIcons.clipboardList,
                    size: compact ? 42 : 52,
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                  Icon(
                    LucideIcons.clipboardCheck,
                    size: compact ? 29 : 36,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
            SizedBox(width: compact ? 12 : 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aucun service aujourd’hui',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Créez un service afin de préparer votre équipe et démarrer la journée.',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActiveMissionContent extends StatelessWidget {
  final ControlMissionSummary mission;

  const _ActiveMissionContent({required this.mission});

  @override
  Widget build(BuildContext context) {
    final start = mission.scheduledStart == null
        ? 'Horaire à confirmer'
        : DateFormat('HH:mm').format(mission.scheduledStart!);
    final location = mission.zoneLabel?.trim().isNotEmpty == true
        ? mission.zoneLabel!
        : mission.lineId?.trim().isNotEmpty == true
        ? 'Ligne ${mission.lineId}'
        : 'Secteur à confirmer';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                mission.displayNumberLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                mission.status.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _MissionMetaRow(icon: LucideIcons.users, label: mission.teamName),
        const SizedBox(height: 8),
        _MissionMetaRow(icon: LucideIcons.mapPin, label: location),
        const SizedBox(height: 8),
        _MissionMetaRow(icon: LucideIcons.clock3, label: start),
      ],
    );
  }
}

class _MissionMetaRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MissionMetaRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.72)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageMissionContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? detail;

  const _MessageMissionContent({
    required this.icon,
    required this.title,
    required this.message,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 6),
                Text(
                  detail!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MissionActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _MissionActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 46,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7672FA), _purpleDark],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  label == 'Créer un service'
                      ? LucideIcons.plus
                      : LucideIcons.arrowRight,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _purpleDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotPattern extends StatelessWidget {
  const _DotPattern();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(
          36,
          (_) => Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final int missionCount;
  final int teamCount;
  final int alertCount;
  final VoidCallback onMissions;
  final VoidCallback onTeams;
  final VoidCallback onAlerts;

  const _SummaryCards({
    required this.missionCount,
    required this.teamCount,
    required this.alertCount,
    required this.onMissions,
    required this.onTeams,
    required this.onAlerts,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: LucideIcons.clipboardList,
            color: _purple,
            softColor: const Color(0xFFEDEBFF),
            count: missionCount,
            label: 'Services',
            linkLabel: 'Voir toutes',
            onTap: onMissions,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: LucideIcons.users,
            color: _green,
            softColor: const Color(0xFFE5F6EE),
            count: teamCount,
            label: 'Équipes',
            linkLabel: 'Voir toutes',
            onTap: onTeams,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: LucideIcons.bell,
            color: _orange,
            softColor: const Color(0xFFFFEDD9),
            count: alertCount,
            label: 'Alertes',
            linkLabel: 'Voir détails',
            onTap: onAlerts,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color softColor;
  final int count;
  final String label;
  final String linkLabel;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.softColor,
    required this.count,
    required this.label,
    required this.linkLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: _softShadow, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 11, 9, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: softColor,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: color,
                            fontSize: 22,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DriverHomePalette.textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        linkLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, color: color, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onMissions;
  final VoidCallback? onTerrain;

  const _QuickActionsSection({
    required this.onMissions,
    required this.onTerrain,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Actions rapides',
                style: TextStyle(
                  color: DriverHomePalette.textDark,
                  fontSize: 16,
                  letterSpacing: -0.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            InkWell(
              onTap: onMissions,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Tout voir',
                      style: TextStyle(
                        color: _green,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(LucideIcons.chevronRight, color: _green, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _QuickActionCard(
          icon: LucideIcons.clipboardList,
          iconColor: _purple,
          iconBackground: const Color(0xFFEDEBFF),
          title: 'Mes services',
          subtitle: 'Consulter tous vos services.',
          onTap: onMissions,
        ),
        const SizedBox(height: 14),
        _QuickActionCard(
          icon: LucideIcons.map,
          iconColor: _green,
          iconBackground: const Color(0xFFE5F6EE),
          title: 'Carte Terrain',
          subtitle: 'Voir les équipes et véhicules sur la carte.',
          onTap: onTerrain,
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: _softShadow, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DriverHomePalette.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DriverHomePalette.textSecondary,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBackground.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.chevronRight,
                    color: iconColor,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
