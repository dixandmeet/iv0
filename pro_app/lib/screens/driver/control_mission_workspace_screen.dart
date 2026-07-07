import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/control_plan_context.dart';
import '../../models/driver/control_team.dart';
import '../../models/driver/mission_models.dart';
import '../../services/auth_service.dart';
import '../../services/driver/driver_service.dart';
import '../../services/driver/control_plan_service.dart';
import '../../services/driver/mission_actions.dart';
import '../../services/driver/control_presence_service.dart';
import '../../services/platform/discussion_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../widgets/driver/control_mission/mission_terrain_tab.dart';
import '../../widgets/driver/control_mission/mission_shared_widgets.dart';
import '../../widgets/driver/control_mission/mission_summary_banner.dart';
import '../../widgets/resource_panels/discussion_panel.dart';
import 'control_mission_debrief_screen.dart';
import 'control_team_create_screen.dart';

/// Workspace temporaire mission : bandeau + 4 onglets.
class ControlMissionWorkspaceScreen extends StatefulWidget {
  final ControlMissionSummary mission;
  final bool readOnly;

  const ControlMissionWorkspaceScreen({
    super.key,
    required this.mission,
    this.readOnly = false,
  });

  @override
  State<ControlMissionWorkspaceScreen> createState() =>
      _ControlMissionWorkspaceScreenState();
}

class _ControlMissionWorkspaceScreenState
    extends State<ControlMissionWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _acting = false;
  bool _contextLoading = false;
  ControlPlanContext? _workspaceContext;
  ControlPresenceService? _presence;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWorkspace();
    });
  }

  Future<void> _initializeWorkspace() async {
    final service = context.read<ControlPlanService>();
    final global = service.context;
    if (global?.currentMission?.id == widget.mission.id) {
      _workspaceContext = global;
    } else {
      if (mounted) setState(() => _contextLoading = true);
      _workspaceContext = await service.fetchMissionContext(widget.mission.id);
      if (mounted) setState(() => _contextLoading = false);
    }
    if (!mounted) return;
    _openDiscussionAndPresence();
  }

  Future<void> _reloadWorkspaceContext() async {
    final loaded = await context.read<ControlPlanService>().fetchMissionContext(
      widget.mission.id,
    );
    if (!mounted || loaded == null) return;
    setState(() => _workspaceContext = loaded);
  }

  void _openDiscussionAndPresence() {
    final ctx = _workspaceContext;
    final mission = ctx?.currentMission ?? widget.mission;
    final channelId = mission.channelId ?? ctx?.channelId;
    if (channelId != null) {
      try {
        final userId = context.read<AuthService>().profile?.id;
        context.read<DiscussionService>().openChannel(
          channelId,
          userId: userId,
        );
      } catch (_) {}
    }
    if (!widget.readOnly) {
      _presence = _presenceService(context);
      final teamId = mission.teamId ?? ctx?.myTeamId;
      if (teamId != null) _presence?.startWatching(teamId);
    }
  }

  @override
  void dispose() {
    _presence?.stopWatching();
    _tabs.dispose();
    super.dispose();
  }

  String? _driverId(BuildContext context) {
    try {
      return context.read<DriverService>().driver?.id;
    } catch (_) {
      return null;
    }
  }

  ControlPresenceService? _presenceService(BuildContext context) {
    try {
      return context.read<ControlPresenceService>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _snack(String msg) {
    return Future.microtask(() {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  Future<void> _respond(bool accept) async {
    final mission = _workspaceContext?.currentMission ?? widget.mission;
    final teamId = mission.teamId ?? _workspaceContext?.myTeamId;
    if (teamId == null) return;
    setState(() => _acting = true);
    final result = await context
        .read<ControlPlanService>()
        .respondTeamInvitation(teamId: teamId, accept: accept);
    if (!mounted) return;
    setState(() => _acting = false);
    await _snack(result.message);
    if (!mounted) return;
    if (result.success) Navigator.of(context).pop(true);
  }

  Future<void> _declarePresence() async {
    final mission = _workspaceContext?.currentMission ?? widget.mission;
    final teamId = mission.teamId ?? _workspaceContext?.myTeamId;
    if (teamId == null) return;
    setState(() => _acting = true);
    final result = await context.read<ControlPlanService>().declarePresence(
      teamId,
    );
    if (!mounted) return;
    setState(() => _acting = false);
    await _snack(result.message);
    if (result.success) await _reloadWorkspaceContext();
  }

  Future<void> _confirmPresence(String memberDriverId) async {
    final mission = _workspaceContext?.currentMission ?? widget.mission;
    final teamId = mission.teamId ?? _workspaceContext?.myTeamId;
    if (teamId == null) return;
    setState(() => _acting = true);
    final result = await context.read<ControlPlanService>().confirmPresence(
      teamId,
      memberDriverId,
    );
    if (!mounted) return;
    setState(() => _acting = false);
    await _snack(result.message);
    if (result.success) await _reloadWorkspaceContext();
  }

  Future<void> _manageTeam(ControlTeam team) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ControlTeamCreateScreen(team: team)),
    );
    if (!mounted) return;
    await context.read<ControlPlanService>().fetchMyContext(silent: true);
    await _reloadWorkspaceContext();
  }

  Future<void> _toggleMemberRole(
    ControlTeam team,
    TeamMember member,
    TeamMention mention,
  ) async {
    final service = context.read<ControlPlanService>();
    setState(() => _acting = true);

    if (!member.hasMention(mention) && mention.isUnique) {
      for (final other in team.members) {
        if (other.userId == member.userId || !other.hasMention(mention)) {
          continue;
        }
        final previousRoles = Set<TeamMention>.from(other.mentions)
          ..remove(mention);
        final removed = await service.updateMemberRoles(
          teamId: team.id,
          memberDriverId: other.userId,
          mentions: previousRoles,
        );
        if (!removed.success) {
          if (!mounted) return;
          setState(() => _acting = false);
          await _snack(removed.message);
          return;
        }
      }
    }

    final nextRoles = Set<TeamMention>.from(member.mentions);
    if (!nextRoles.add(mention)) nextRoles.remove(mention);
    final result = await service.updateMemberRoles(
      teamId: team.id,
      memberDriverId: member.userId,
      mentions: nextRoles,
    );
    if (!mounted) return;
    setState(() => _acting = false);
    await _snack(result.message);
    if (result.success) await _reloadWorkspaceContext();
  }

  Future<void> _deleteMission(ControlPlanContext? ctx) async {
    final planId = widget.mission.controlPlanId ?? ctx?.plan?.id;
    if (planId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le service ?'),
        content: const Text(
          'Le service et son espace temporaire seront définitivement supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _acting = true);
    final result = await context.read<ControlPlanService>().deleteMission(
      planId: planId,
    );
    if (!mounted) return;
    setState(() => _acting = false);
    await _snack(
      result.success ? 'Service supprimé' : (result.error ?? 'Échec'),
    );
    if (result.success && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _editMission(ControlPlanContext? ctx) async {
    final plan = ctx?.plan;
    final planId = widget.mission.controlPlanId ?? plan?.id;
    if (planId == null) return;
    final objectiveController = TextEditingController(
      text: plan?.objective ?? widget.mission.objective ?? '',
    );
    var priority =
        plan?.priority ?? MissionPriority.fromDb(widget.mission.priorityDb);

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Modifier le service'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: objectiveController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Objectif'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<MissionPriority>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Priorité'),
                items: MissionPriority.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => priority = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (save != true || !mounted) {
      objectiveController.dispose();
      return;
    }

    setState(() => _acting = true);
    final result = await context
        .read<ControlPlanService>()
        .updateMissionDetails(
          planId: planId,
          objective: objectiveController.text,
          priority: priority,
        );
    objectiveController.dispose();
    if (!mounted) return;
    setState(() => _acting = false);
    await _snack(
      result.success ? 'Service modifié' : (result.error ?? 'Échec'),
    );
    if (result.success) await _reloadWorkspaceContext();
  }

  Future<void> _transition({required bool start}) async {
    setState(() => _acting = true);
    final result = await context.read<ControlPlanService>().transitionMission(
      missionId: widget.mission.id,
      start: start,
    );
    if (!mounted) return;
    setState(() => _acting = false);
    await _snack(result.message);
    if (!mounted) return;
    if (result.success && !start && result.debrief != null) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ControlMissionDebriefScreen(debrief: result.debrief!),
        ),
      );
    } else if (result.success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ControlPlanService>();
    final globalContext = service.context;
    final ctx =
        _workspaceContext ??
        (globalContext?.currentMission?.id == widget.mission.id
            ? globalContext
            : null);
    final mission = ctx?.currentMission ?? widget.mission;
    final driverId = _driverId(context);
    final isPad = ctx?.isPadFor(driverId) ?? false;
    final isCreator = ctx?.isCreator ?? false;
    final phase = mission.phase;
    final readiness = ctx?.readiness ?? TeamReadiness.fromTeam(ctx?.myTeam);
    final accepted =
        ctx?.effectiveInvitationStatus == EffectiveInvitationStatus.accepted ||
        ctx?.myInvitationStatus == InvitationStatus.accepted ||
        isCreator;
    final actions = widget.readOnly
        ? const MissionActionSet(readOnly: true)
        : MissionActions.resolve(
            phase: phase,
            role: MissionActions.resolveRole(
              isCreator: isCreator,
              isPad: isPad,
            ),
            hasPendingInvitation: ctx?.hasPendingInvitation ?? false,
            isAcceptedParticipant: accepted,
          );
    final priority = ctx != null
        ? missionPriorityFromContext(ctx)
        : MissionPriority.fromDb(mission.priorityDb);

    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      appBar: AppBar(
        title: const Text('Service de contrôle'),
        backgroundColor: DriverHomePalette.gradientStart,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          dividerColor: Colors.white24,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Service'),
            Tab(text: 'Équipe'),
            Tab(text: 'Terrain'),
            Tab(text: 'Discussion'),
          ],
        ),
      ),
      body: Column(
        children: [
          MissionSummaryBanner(
            mission: mission,
            phase: phase,
            readiness: readiness,
            messageCount: ctx?.messageCount ?? 0,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _missionTab(ctx, mission, priority, readiness, actions),
                _teamTab(ctx, mission, actions),
                MissionTerrainTab(mission: mission),
                _discussionTab(ctx, mission, phase),
              ],
            ),
          ),
          if (_contextLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (!widget.readOnly)
            _actionBar(ctx, actions, phase, readiness),
        ],
      ),
    );
  }

  Widget _missionTab(
    ControlPlanContext? ctx,
    ControlMissionSummary mission,
    MissionPriority priority,
    TeamReadiness readiness,
    MissionActionSet actions,
  ) {
    final objective = ctx?.plan?.objective ?? mission.objective ?? '—';
    final responsible = ctx?.operationalResponsibleName;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _MissionPanel(
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
                        const Text(
                          'Détails opérationnels',
                          style: TextStyle(
                            color: DriverHomePalette.textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          objective,
                          style: const TextStyle(
                            color: DriverHomePalette.textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  MissionPriorityBadge(priority: priority),
                ],
              ),
              const SizedBox(height: 18),
              _InfoTile(
                icon: LucideIcons.target,
                label: 'Objectif',
                value: objective,
                accent: DriverHomePalette.primary,
              ),
              const SizedBox(height: 10),
              _InfoTile(
                icon: LucideIcons.mapPin,
                label: 'Secteur',
                value: missionSectorLabel(mission),
                accent: DriverHomePalette.controlAccent,
              ),
              const SizedBox(height: 10),
              _InfoTile(
                icon: LucideIcons.clock,
                label: 'Horaires',
                value: mission.scheduleLabel,
                accent: DriverHomePalette.warning,
              ),
              if (responsible != null) ...[
                const SizedBox(height: 10),
                _InfoTile(
                  icon: LucideIcons.shieldCheck,
                  label: 'Responsable',
                  value: responsible,
                  accent: DriverHomePalette.blue,
                ),
              ],
            ],
          ),
        ),
        if (mission.phase == MissionPhase.preparation) ...[
          const SizedBox(height: 14),
          _MissionPanel(child: PreparationChecklist(readiness: readiness)),
        ],
        if (mission.instructions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _MissionPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      LucideIcons.clipboardList,
                      color: DriverHomePalette.primary,
                      size: 19,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Consignes',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...mission.instructions.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(
                            LucideIcons.dot,
                            size: 18,
                            color: DriverHomePalette.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            c,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _teamTab(
    ControlPlanContext? ctx,
    ControlMissionSummary mission,
    MissionActionSet actions,
  ) {
    final team = ctx?.myTeam;
    final members = team?.members ?? mission.teamMembers;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (team != null && actions.canInvite) ...[
          OutlinedButton.icon(
            onPressed: _acting ? null : () => _manageTeam(team),
            icon: const Icon(LucideIcons.usersRound),
            label: const Text('Gérer l’équipe et les rôles'),
          ),
          const SizedBox(height: 14),
        ],
        if (members.isEmpty)
          const _MissionPanel(
            child: Text('Aucun membre visible pour ce service.'),
          ),
        ...members.map((m) {
          final role = m.mentions.isEmpty ? null : m.mentions.first;
          final presence = MemberPresenceStatus.fromTeamMember(m);
          final present = presence == MemberPresenceStatus.present;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MissionPanel(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: present
                        ? DriverHomePalette.lightGreen
                        : DriverHomePalette.background,
                    child: Text(
                      m.initials,
                      style: TextStyle(
                        color: present
                            ? DriverHomePalette.primary
                            : DriverHomePalette.textSecondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.nameOrFallback,
                          style: const TextStyle(
                            color: DriverHomePalette.textDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          presence.label,
                          style: TextStyle(
                            color: present
                                ? DriverHomePalette.primary
                                : DriverHomePalette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MissionRoleBadge(mention: role),
                      if (actions.canConfirmPresence &&
                          m.invitationStatus == InvitationStatus.accepted &&
                          !present) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _acting
                              ? null
                              : () => _confirmPresence(m.userId),
                          child: const Text('Confirmer'),
                        ),
                      ],
                      if (team != null && actions.canEditRoles)
                        PopupMenuButton<TeamMention>(
                          enabled: !_acting,
                          tooltip: 'Modifier les rôles',
                          icon: const Icon(LucideIcons.badgeCheck, size: 19),
                          onSelected: (mention) =>
                              _toggleMemberRole(team, m, mention),
                          itemBuilder: (_) => TeamMention.values
                              .map(
                                (mention) => CheckedPopupMenuItem<TeamMention>(
                                  value: mention,
                                  checked: m.hasMention(mention),
                                  child: Text(mention.label),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _discussionTab(
    ControlPlanContext? ctx,
    ControlMissionSummary mission,
    MissionPhase phase,
  ) {
    final channelId = mission.channelId ?? ctx?.channelId;
    if (channelId == null) {
      return const Center(child: Text('Discussion indisponible'));
    }
    return DiscussionPanel(
      resourceId: '',
      channelId: channelId,
      readOnly:
          widget.readOnly ||
          phase == MissionPhase.archived ||
          phase == MissionPhase.debrief,
    );
  }

  Widget _actionBar(
    ControlPlanContext? ctx,
    MissionActionSet actions,
    MissionPhase phase,
    TeamReadiness readiness,
  ) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: DriverHomePalette.card,
          border: Border(top: BorderSide(color: DriverHomePalette.border)),
          boxShadow: [
            BoxShadow(
              color: DriverHomePalette.cardShadow,
              blurRadius: 18,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actions.canStartIntervention && !readiness.ready) ...[
              Row(
                children: [
                  const Icon(
                    LucideIcons.info,
                    size: 16,
                    color: DriverHomePalette.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      readiness.blockingLabel ??
                          'La checklist doit être complète avant le démarrage.',
                      style: const TextStyle(
                        color: DriverHomePalette.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (actions.canJoin)
              MissionGradientButton(
                label: 'Rejoindre le service',
                icon: LucideIcons.userCheck,
                loading: _acting,
                onPressed: () => _respond(true),
              ),
            if (actions.canDeclarePresence)
              MissionGradientButton(
                label: 'Je suis arrivé',
                icon: LucideIcons.mapPin,
                loading: _acting,
                onPressed: _declarePresence,
              ),
            if (actions.canStartIntervention)
              MissionGradientButton(
                label: 'Démarrer l\'intervention',
                icon: LucideIcons.play,
                loading: _acting,
                onPressed: readiness.ready
                    ? () => _transition(start: true)
                    : null,
              ),
            if (actions.canEndIntervention)
              MissionGradientButton(
                label: 'Terminer l\'intervention',
                icon: LucideIcons.circleStop,
                loading: _acting,
                onPressed: () => _transition(start: false),
              ),
            if (actions.canAddNote || actions.canReportIncident) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (actions.canAddNote)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _snack('Notes bientôt disponibles'),
                        icon: const Icon(LucideIcons.notebookPen),
                        label: const Text('Note'),
                      ),
                    ),
                  if (actions.canAddNote && actions.canReportIncident)
                    const SizedBox(width: 8),
                  if (actions.canReportIncident)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _snack('Signalement bientôt disponible'),
                        icon: const Icon(LucideIcons.triangleAlert),
                        label: const Text('Incident'),
                      ),
                    ),
                ],
              ),
            ],
            if (actions.canDelete) ...[
              const SizedBox(height: 8),
              if (actions.canEditMission)
                OutlinedButton.icon(
                  onPressed: _acting ? null : () => _editMission(ctx),
                  icon: const Icon(LucideIcons.pencil),
                  label: const Text('Modifier le service'),
                ),
              TextButton.icon(
                onPressed: _acting ? null : () => _deleteMission(ctx),
                icon: const Icon(LucideIcons.trash2),
                label: const Text('Supprimer le service'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissionPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _MissionPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DriverHomePalette.border),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DriverHomePalette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: DriverHomePalette.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
