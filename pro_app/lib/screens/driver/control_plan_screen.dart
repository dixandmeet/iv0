import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/control_plan_context.dart';
import '../../models/driver/control_team.dart';
import '../../services/driver/control_plan_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../widgets/driver/control_mission/mission_invitation_card.dart';
import '../../widgets/driver/control_mission/mission_shared_widgets.dart';
import '../../widgets/driver/control_mission/mission_status_card.dart';
import 'control_mission_create_screen.dart';
import 'control_mission_workspace_screen.dart';

/// Mes services — Aujourd'hui · À venir · Historique
class ControlPlanScreen extends StatefulWidget {
  const ControlPlanScreen({super.key});

  @override
  State<ControlPlanScreen> createState() => _ControlPlanScreenState();
}

class _ControlPlanScreenState extends State<ControlPlanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _historyLoaded = false;
  bool _upcomingLoaded = false;
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ControlPlanService>().fetchMyContext();
    });
  }

  void _onTab() {
    if (!_tabs.indexIsChanging) {
      if (_tabs.index == 1 && !_upcomingLoaded) {
        _upcomingLoaded = true;
        context.read<ControlPlanService>().fetchUpcoming();
      }
      if (_tabs.index == 2 && !_historyLoaded) {
        _historyLoaded = true;
        context.read<ControlPlanService>().fetchHistory();
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTab);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final s = context.read<ControlPlanService>();
    await s.fetchMyContext(silent: true);
    if (_tabs.index == 1) await s.fetchUpcoming();
    if (_tabs.index == 2) await s.fetchHistory();
  }

  Future<void> _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
    return Future.value();
  }

  Future<void> _respond({required String teamId, required bool accept}) async {
    if (_responding) return;
    setState(() => _responding = true);
    final result = await context
        .read<ControlPlanService>()
        .respondTeamInvitation(teamId: teamId, accept: accept);
    if (!mounted) return;
    setState(() => _responding = false);
    await _snack(result.message);
    if (result.success) await _refresh();
  }

  Future<void> _openWorkspace(
    ControlMissionSummary mission, {
    bool readOnly = false,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ControlMissionWorkspaceScreen(mission: mission, readOnly: readOnly),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _createMission() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ControlMissionCreateScreen()),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ControlPlanService>();

    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: _createMission,
              icon: const Icon(LucideIcons.plus),
              label: const Text('Créer le service'),
              backgroundColor: DriverHomePalette.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: [
          _hero(),
          if (service.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                service.errorMessage!,
                style: const TextStyle(color: DriverHomePalette.danger),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: _todayTab(service),
                ),
                RefreshIndicator(
                  onRefresh: () async {
                    _upcomingLoaded = true;
                    await service.fetchUpcoming();
                  },
                  child: _listTab(
                    loading: service.upcomingLoading,
                    empty: 'Aucun service à venir',
                    missions: service.upcomingMissions,
                    onTap: _openWorkspace,
                    hasMore: service.upcomingHasMore,
                    onLoadMore: () => service.fetchUpcoming(
                      offset: service.upcomingMissions.length,
                    ),
                  ),
                ),
                RefreshIndicator(
                  onRefresh: () async {
                    _historyLoaded = true;
                    await service.fetchHistory();
                  },
                  child: _listTab(
                    loading: service.historyLoading,
                    empty: 'Aucun service passé',
                    missions: service.historyMissions,
                    onTap: (m) => _openWorkspace(m, readOnly: true),
                    hasMore: service.historyHasMore,
                    onLoadMore: () => service.fetchHistory(
                      offset: service.historyMissions.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayTab(ControlPlanService service) {
    if (service.loading && !service.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final ctx = service.context ?? const ControlPlanContext();
    final mission = ctx.displayMission;
    final readiness = service.readiness ?? ctx.readiness;
    final proposedRole = _proposedRole(ctx);

    if (ctx.isExpiredInvitation) {
      return const _MissionInfoState(
        icon: LucideIcons.clockAlert,
        title: 'Service dépassé',
        message: 'Cette invitation n’est plus active.',
      );
    }

    if (ctx.effectiveInvitationStatus == EffectiveInvitationStatus.declined) {
      return const _MissionInfoState(
        icon: LucideIcons.userX,
        title: 'Invitation refusée',
        message: 'Le service reste consultable dans votre historique.',
      );
    }

    if (ctx.hasPendingInvitation && ctx.myTeamId != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          MissionInvitationCard(
            mission: mission,
            team: ctx.myTeam,
            teamName: ctx.myTeam?.name ?? 'équipe',
            proposedRole: proposedRole,
            loading: _responding,
            onAccept: () => _respond(teamId: ctx.myTeamId!, accept: true),
            onDecline: () => _respond(teamId: ctx.myTeamId!, accept: false),
          ),
          if (mission != null)
            MissionStatusCard(
              ctx: ctx,
              mission: mission,
              readiness: readiness,
              phase: mission.phase,
              messageCount: ctx.messageCount,
              onOpen: () => _openWorkspace(mission),
            ),
        ],
      );
    }

    if (mission != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          MissionStatusCard(
            ctx: ctx,
            mission: mission,
            readiness: readiness,
            phase: mission.phase,
            messageCount: ctx.messageCount,
            onOpen: () => _openWorkspace(mission),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 100),
      children: [
        Center(
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: DriverHomePalette.lightGreen,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              LucideIcons.clipboardList,
              size: 42,
              color: DriverHomePalette.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Aucun service aujourd\'hui',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Créez le service de contrôle de votre équipe pour démarrer la préparation.',
          textAlign: TextAlign.center,
          style: TextStyle(color: DriverHomePalette.textSecondary, height: 1.4),
        ),
      ],
    );
  }

  Widget _listTab({
    required bool loading,
    required String empty,
    required List<ControlMissionSummary> missions,
    required void Function(ControlMissionSummary) onTap,
    bool hasMore = false,
    Future<void> Function()? onLoadMore,
  }) {
    if (loading && missions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (missions.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Text(
            empty,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: missions.length + (hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == missions.length) {
          return Center(
            child: OutlinedButton(
              onPressed: loading || onLoadMore == null
                  ? null
                  : () => onLoadMore(),
              child: const Text('Charger plus'),
            ),
          );
        }
        final m = missions[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: DriverHomePalette.card,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              title: Text('${m.planName} · ${m.displayNumberLabel}'),
              subtitle: Text('${m.scheduleLabel} · ${missionSectorLabel(m)}'),
              trailing: Text(
                m.phase.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () => onTap(m),
            ),
          ),
        );
      },
    );
  }

  TeamMention? _proposedRole(ControlPlanContext ctx) {
    if (!ctx.hasPendingInvitation) return null;
    for (final m in ctx.myTeam?.members ?? const <TeamMember>[]) {
      if (m.invitationStatus == InvitationStatus.invited &&
          m.mentions.isNotEmpty) {
        return m.mentions.first;
      }
    }
    return null;
  }

  Widget _hero() {
    const labels = ['Aujourd\'hui', 'À venir', 'Historique'];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              DriverHomePalette.gradientStart,
              DriverHomePalette.gradientEnd,
            ],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(
                        LucideIcons.arrowLeft,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Mes services',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Votre service du jour',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                Row(
                  children: List.generate(3, (i) {
                    final sel = _tabs.index == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _tabs.animateTo(i),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? Colors.white : Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: sel
                                  ? DriverHomePalette.primary
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MissionInfoState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MissionInfoState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 100),
      children: [
        Icon(icon, size: 48, color: DriverHomePalette.textSecondary),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: DriverHomePalette.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
