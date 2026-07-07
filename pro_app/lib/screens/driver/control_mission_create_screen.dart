import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/gtfs.dart';
import '../../services/gtfs_service.dart';
import '../../models/driver/control_team.dart';
import '../../models/driver/mission_models.dart';
import '../../theme/driver_home_palette.dart';
import '../../widgets/driver/driver_time_picker.dart';
import '../../widgets/driver/control_create/control_create_widgets.dart';
import '../../services/driver/control_plan_service.dart';
import '../../services/driver/control_team_service.dart';
import '../../services/driver/driver_service.dart';

/// Création d'un service : composition de l'équipe, périmètre et consignes.
class ControlMissionCreateScreen extends StatefulWidget {
  const ControlMissionCreateScreen({super.key});

  @override
  State<ControlMissionCreateScreen> createState() =>
      _ControlMissionCreateScreenState();
}

class _ControlMissionCreateScreenState
    extends State<ControlMissionCreateScreen> {
  final _lineController = TextEditingController();
  final _zoneController = TextEditingController();
  final _consigneController = TextEditingController();
  final _objectiveController = TextEditingController(
    text: 'Informations & Contrôles',
  );
  final _stepScrollController = ScrollController();

  String? _selectedLineId;
  TimeOfDay? _consigneStart;
  TimeOfDay? _consigneEnd;

  late DateTime _missionDate;

  final List<TeamVacation> _vacations = [const TeamVacation()];
  TeamMobilityMode? _mobilityMode;
  final List<TeamMember> _missionMembers = [];
  final List<TeamInstruction> _consignes = [];

  bool _dirty = false;

  /// Étape courante de l'assistant (0-5).
  int _step = 0;
  MissionPriority _priority = MissionPriority.standard;
  String? _operationalResponsibleId;

  static const _stepLabels = [
    'Équipe',
    'Rôles',
    'Consignes',
    'Déplacement',
    'Vacations',
    'Validation',
  ];
  static const _stepCount = 6;
  late final List<GlobalKey> _stepPillKeys = List.generate(
    _stepCount,
    (_) => GlobalKey(),
  );

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _missionDate = today;
    _lineController.addListener(_markDirty);
    _zoneController.addListener(_markDirty);
    _objectiveController.addListener(_markDirty);
  }

  void _markDirty() {
    if (!mounted) return;
    setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _lineController.removeListener(_markDirty);
    _zoneController.removeListener(_markDirty);
    _objectiveController.removeListener(_markDirty);
    _stepScrollController.dispose();
    _lineController.dispose();
    _zoneController.dispose();
    _consigneController.dispose();
    _objectiveController.dispose();
    super.dispose();
  }

  // --- Règles métier --------------------------------------------------------

  bool get _vacationsValid {
    if (_vacations.every((v) => v.isEmpty)) return false;
    return _vacations.every((v) => v.isEmpty || v.isValid);
  }

  List<TeamVacation> get _filledVacations =>
      _vacations.where((v) => v.isComplete).toList();

  bool get _hasMobilityMode => _mobilityMode != null;

  bool get _hasEnoughMembers => _missionMembers.length >= 2;

  bool get _hasRequiredRoles =>
      _missionMembers.any((m) => m.hasMention(TeamMention.pad)) &&
      _missionMembers.any((m) => m.hasMention(TeamMention.chef)) &&
      _missionMembers.any((m) => m.hasMention(TeamMention.tpe));

  bool get _hasSector =>
      (_selectedLineId ?? _lineController.text).trim().isNotEmpty ||
      _zoneController.text.trim().isNotEmpty;

  String get _resolvedObjective => _objectiveController.text.trim();

  /// Conditions manquantes pour créer le service.
  List<String> get _missing {
    final missing = <String>[];
    if (!_hasEnoughMembers) {
      missing.add('au moins 2 agents');
    }
    if (!_hasRequiredRoles) {
      missing.add('les rôles PAD, Chef et TPE');
    }
    if (_resolvedObjective.length < 3) {
      missing.add('un objectif');
    }
    if (!_hasSector) {
      missing.add('une ligne ou une zone');
    }
    if (!_draftConsigneTimesValid) {
      missing.add('des horaires de consigne valides');
    }
    if (!_hasMobilityMode) {
      missing.add('un mode de déplacement');
    }
    if (_filledVacations.isEmpty || !_vacationsValid) {
      missing.add('des vacations valides');
    }
    return missing;
  }

  bool _canAdvanceFromStep(int step) {
    return switch (step) {
      0 => _hasEnoughMembers,
      1 => _hasRequiredRoles,
      2 =>
        _draftConsigneTimesValid &&
            _resolvedObjective.length >= 3 &&
            _hasSector,
      3 => _hasMobilityMode,
      4 => _vacationsValid,
      5 => _canPlan,
      _ => false,
    };
  }

  String? _stepBlockReason(int step) {
    return switch (step) {
      0 when !_hasEnoughMembers => 'Ajoutez au moins 2 agents à l\'équipe',
      1 when !_hasRequiredRoles => 'Attribuez les rôles PAD, Chef et TPE',
      2 when _resolvedObjective.length < 3 =>
        'Renseignez l\'objectif du service',
      2 when !_hasSector => 'Renseignez une ligne ou une zone',
      2 when !_draftConsigneTimesValid =>
        'L\'heure de fin doit être après l\'heure de début',
      3 when !_hasMobilityMode => 'Choisissez un mode de déplacement',
      4 when !_vacationsValid => 'Renseignez au moins une vacation valide',
      _ => null,
    };
  }

  List<TeamMember> get _responsibleCandidates {
    return _missionMembers
        .where((m) => m.invitationStatus != InvitationStatus.removed)
        .toList();
  }

  bool get _canPlan => _missing.isEmpty;

  bool get _shouldConfirmLeave => _dirty;

  // --- Navigation entre étapes ----------------------------------------------

  void _goToStep(int step) {
    FocusScope.of(context).unfocus();
    if (step >= 2) {
      unawaited(_ensureRoutesLoaded());
    }
    setState(() => _step = step);
    _scrollActiveStepIntoView();
  }

  void _scrollActiveStepIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stepContext = _stepPillKeys[_step].currentContext;
      if (stepContext == null) return;
      Scrollable.ensureVisible(
        stepContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    });
  }

  void _nextStep() {
    final reason = _stepBlockReason(_step);
    if (reason != null) {
      _snack(reason);
      return;
    }
    if (_step < _stepCount - 1) {
      _goToStep(_step + 1);
    }
  }

  void _prevStep() {
    if (_step > 0) _goToStep(_step - 1);
  }

  Future<void> _ensureRoutesLoaded() async {
    await context.read<GtfsService>().fetchRoutes();
    if (mounted) setState(() {});
  }

  // --- Vacations --------------------------------------------------------------

  void _addVacation() {
    _markDirty();
    setState(() => _vacations.add(const TeamVacation()));
  }

  void _removeVacation(int index) {
    if (_vacations.length <= 1) return;
    _markDirty();
    setState(() => _vacations.removeAt(index));
  }

  Future<void> _pickVacationTime({
    required int index,
    required bool isStart,
  }) async {
    final vacation = _vacations[index];
    final initial =
        (isStart ? vacation.startTime : vacation.endTime) ??
        TimeOfDay(hour: isStart ? 6 : 14, minute: 0);
    final picked = await showDriverTimePicker(
      context: context,
      initialTime: initial,
      title: isStart ? 'Heure de début' : 'Heure de fin',
    );
    if (picked == null) return;
    _markDirty();
    setState(() {
      _vacations[index] = isStart
          ? vacation.copyWith(startTime: picked)
          : vacation.copyWith(endTime: picked);
    });
  }

  void _setMobilityMode(TeamMobilityMode mode) {
    _markDirty();
    setState(() => _mobilityMode = mode);
  }

  void _toggleMissionMention(TeamMember member, TeamMention mention) {
    _markDirty();
    setState(() {
      final idx = _missionMembers.indexWhere((m) => m.userId == member.userId);
      if (idx < 0) return;
      final willEnable = !_missionMembers[idx].hasMention(mention);

      if (willEnable && mention.isUnique) {
        for (var i = 0; i < _missionMembers.length; i++) {
          if (i != idx && _missionMembers[i].hasMention(mention)) {
            _missionMembers[i] = _missionMembers[i].toggleMention(mention);
          }
        }
      }
      _missionMembers[idx] = _missionMembers[idx].toggleMention(mention);

      if (willEnable && mention == TeamMention.pad) {
        _operationalResponsibleId ??= member.userId;
      }
    });
  }

  String get _missionDateLabel {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return 'Le ${fmt(_missionDate)}';
  }

  String get _vacationsLabel {
    if (_filledVacations.isEmpty) return 'Non renseignées';
    return _filledVacations
        .map(
          (v) =>
              '${formatTimeLabel(v.startTime)} → ${formatTimeLabel(v.endTime)}',
        )
        .join(' · ');
  }

  String get _rolesLabel {
    final assigned = _missionMembers
        .where((m) => m.mentions.isNotEmpty)
        .map(
          (m) =>
              '${m.nameOrFallback} (${m.mentions.map((r) => r.label).join(', ')})',
        )
        .toList();
    if (assigned.isEmpty) return 'Aucun rôle attribué';
    return assigned.join(' · ');
  }

  // --- Consignes -------------------------------------------------------------

  bool get _draftConsigneTimesValid {
    if (_consigneStart == null || _consigneEnd == null) return true;
    final start = _consigneStart!.hour * 60 + _consigneStart!.minute;
    final end = _consigneEnd!.hour * 60 + _consigneEnd!.minute;
    return end > start;
  }

  Future<void> _pickConsigneTime({required bool isStart}) async {
    final initial =
        (isStart ? _consigneStart : _consigneEnd) ??
        TimeOfDay(hour: isStart ? 8 : 12, minute: 0);
    final picked = await showDriverTimePicker(
      context: context,
      initialTime: initial,
      title: isStart ? 'Heure de début' : 'Heure de fin',
    );
    if (picked == null) return;
    _markDirty();
    setState(() {
      if (isStart) {
        _consigneStart = picked;
      } else {
        _consigneEnd = picked;
      }
    });
  }

  void _addConsigne() {
    final text = _consigneController.text.trim();
    if (text.isEmpty) return;
    if (!_draftConsigneTimesValid) {
      _snack('L\'heure de fin doit être après l\'heure de début');
      return;
    }
    setState(() {
      _consignes.add(
        TeamInstruction(
          text: text,
          startTime: _consigneStart,
          endTime: _consigneEnd,
        ),
      );
      _consigneController.clear();
      _consigneStart = null;
      _consigneEnd = null;
    });
    _markDirty();
  }

  void _removeConsigne(int index) {
    _markDirty();
    setState(() => _consignes.removeAt(index));
  }

  void _onLineSelected(GtfsRoute route) {
    _markDirty();
    setState(() {
      _selectedLineId = route.routeId;
      _lineController.text = controlCreateRouteLabel(route);
    });
  }

  void _onLineManualEdit() {
    if (_selectedLineId != null) {
      _markDirty();
      setState(() => _selectedLineId = null);
    }
  }

  // --- Équipe (ad hoc, propre à ce service) -----------------------------------

  void _addMissionMember(TeamAgent agent) {
    if (_missionMembers.any((m) => m.userId == agent.id)) return;
    _markDirty();
    setState(() => _missionMembers.add(TeamMember.fromAgent(agent)));
  }

  void _removeMissionMember(TeamMember member) {
    _markDirty();
    setState(() {
      _missionMembers.removeWhere((m) => m.userId == member.userId);
      if (_operationalResponsibleId == member.userId) {
        _operationalResponsibleId = null;
      }
    });
  }

  // --- Sauvegarde ------------------------------------------------------------

  /// Nom du service (et de l'équipe qui lui est propre), dérivé de l'objectif.
  String _resolveServiceName() {
    final objective = _resolvedObjective;
    if (objective.isNotEmpty) return 'Service · $objective';
    return 'Service de contrôle';
  }

  Future<void> _submitMission() async {
    if (!_canPlan) {
      _snack('Complétez : ${_missing.join(', ')}.');
      return;
    }

    final driver = context.read<DriverService>().driver;
    if (driver == null) {
      _snack('Session conducteur introuvable');
      return;
    }

    final serviceName = _resolveServiceName();
    final line = (_selectedLineId ?? _lineController.text).trim();
    final zone = _zoneController.text.trim();

    final teamResult = await context.read<ControlTeamService>().createTeam(
      createdByDriverId: driver.id,
      name: serviceName,
      status: TeamStatus.planned,
      vacations: _filledVacations,
      mobilityMode: _mobilityMode,
      lineId: line,
      zone: zone,
      instructions: _consignes,
      members: _missionMembers,
    );
    if (!mounted) return;
    if (!teamResult.success) {
      _snack(teamResult.error ?? 'Impossible de créer l\'équipe du service');
      return;
    }

    final missionService = context.read<ControlPlanService>();

    final lineIds = line.isNotEmpty ? [line] : const <String>[];
    final zones = zone.isNotEmpty ? [zone] : const <String>[];

    final driverIdsToEnsure = <String>{
      driver.id,
      ..._responsibleCandidates.map((member) => member.userId),
    };

    final missionResult = await missionService.createMission(
      name: serviceName,
      objective: _resolvedObjective,
      startDate: _missionDate,
      endDate: _missionDate,
      teamId: teamResult.teamId,
      lineIds: lineIds,
      zones: zones,
      operationalResponsibleId: _operationalResponsibleId,
      priority: _priority,
      instructions: _consignes,
      driverIdsToEnsure: driverIdsToEnsure.toList(),
    );
    if (!mounted) return;
    if (missionResult.success) {
      _snack('Service créé');
      Navigator.of(context).pop(true);
      return;
    }

    _snack(missionResult.error ?? 'Échec de la création du service');
  }

  Future<bool> _confirmLeave() async {
    if (!_shouldConfirmLeave) return true;

    final action = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DriverHomePalette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Quitter la création ?',
          style: TextStyle(
            color: DriverHomePalette.textDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Les modifications non enregistrées seront perdues.',
          style: TextStyle(color: DriverHomePalette.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: DriverHomePalette.danger,
            ),
            child: const Text('Quitter sans enregistrer'),
          ),
        ],
      ),
    );

    return action ?? false;
  }

  Future<void> _requestLeave() async {
    if (!_shouldConfirmLeave) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final shouldLeave = await _confirmLeave();
    if (!shouldLeave || !mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final saving =
        context.watch<ControlPlanService>().saving ||
        context.watch<ControlTeamService>().saving;
    const title = 'Créer un service';

    return PopScope(
      canPop: !_shouldConfirmLeave,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _requestLeave();
      },
      child: Scaffold(
        backgroundColor: DriverHomePalette.background,
        body: Column(
          children: [
            _hero(title: title, saving: saving),
            Expanded(child: _buildStep()),
          ],
        ),
        bottomNavigationBar: _wizardBottomBar(saving),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _buildTeamStep(),
      1 => _buildRolesStep(),
      2 => _buildConsignesStep(),
      3 => _buildMobilityStep(),
      4 => _buildVacationsStep(),
      _ => _buildValidationStep(),
    };
  }

  Widget _wizardBottomBar(bool saving) {
    final isLast = _step == _stepCount - 1;
    final nextButton = GradientActionButton(
      onPressed: saving || (isLast && !_canPlan)
          ? null
          : (isLast ? () => unawaited(_submitMission()) : _nextStep),
      loading: saving,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isLast ? 'Créer le service' : 'Suivant',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          if (!isLast) ...[
            const SizedBox(width: 6),
            const Icon(LucideIcons.arrowRight, size: 18),
          ],
        ],
      ),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: DriverHomePalette.card,
        border: Border(top: BorderSide(color: DriverHomePalette.border)),
        boxShadow: [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: _step > 0
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: saving ? null : _prevStep,
                    style: controlCreateOutlinedButtonStyle(),
                    child: const Text(
                      'Retour',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: nextButton),
              ],
            )
          : nextButton,
    );
  }

  Widget _buildTeamStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ControlAgentsSection(
          members: _missionMembers,
          alreadyAddedIds: _missionMembers.map((m) => m.userId).toSet(),
          onAgentSelected: _addMissionMember,
          onRemove: _removeMissionMember,
          onToggleMention: _toggleMissionMention,
          subtitle: 'Sélectionnez les agents de ce service uniquement',
          emptyMessage:
              'Aucun agent ajouté. Recherchez par nom ou matricule pour '
              'composer l\'équipe de ce service.',
          showMentions: false,
        ),
      ],
    );
  }

  Widget _buildVacationsStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ControlTeamVacationsSection(
          vacations: _vacations,
          vacationsValid: _vacationsValid,
          onPickVacationTime: _pickVacationTime,
          onAddVacation: _addVacation,
          onRemoveVacation: _removeVacation,
        ),
      ],
    );
  }

  Widget _buildMobilityStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ControlTeamMobilitySection(
          mobilityMode: _mobilityMode,
          onMobilityModeChanged: _setMobilityMode,
        ),
      ],
    );
  }

  Widget _buildRolesStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ControlTeamRolesSection(
          members: _missionMembers,
          onToggleMention: _toggleMissionMention,
        ),
        const SizedBox(height: 14),
        ControlCreateSectionCard(
          title: 'Responsable opérationnel',
          subtitle: 'Référent du service, distinct du rôle PAD si besoin',
          icon: LucideIcons.shieldCheck,
          children: [
            DropdownButtonFormField<String>(
              initialValue:
                  _responsibleCandidates.any(
                    (m) => m.userId == _operationalResponsibleId,
                  )
                  ? _operationalResponsibleId
                  : null,
              decoration: controlCreateFieldDecoration(
                'Sélectionner un responsable',
              ),
              items: _responsibleCandidates
                  .map(
                    (member) => DropdownMenuItem(
                      value: member.userId,
                      child: Text(member.nameOrFallback),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                _markDirty();
                setState(() => _operationalResponsibleId = value);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValidationStep() {
    final line = _lineController.text.trim();
    final zone = _zoneController.text.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ControlCreateSectionCard(
          title: 'Récapitulatif',
          subtitle: 'Vérifiez avant création',
          icon: LucideIcons.clipboardCheck,
          children: [
            _SummaryHero(
              teamName: _resolveServiceName(),
              memberCount: _missionMembers.length,
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              icon: LucideIcons.calendarDays,
              label: 'Journée',
              value: _missionDateLabel,
            ),
            const _SummaryDivider(),
            _SummaryRow(
              icon: LucideIcons.target,
              label: 'Objectif',
              value: _resolvedObjective,
            ),
            const _SummaryDivider(),
            _SummaryRow(
              icon: LucideIcons.gauge,
              label: 'Priorité',
              value: _priority.label,
            ),
            const _SummaryDivider(),
            _SummaryRow(
              icon: LucideIcons.clock,
              label: 'Vacations',
              value: _vacationsLabel,
            ),
            const _SummaryDivider(),
            _SummaryRow(
              icon: _mobilityMode == TeamMobilityMode.onFoot
                  ? LucideIcons.footprints
                  : LucideIcons.busFront,
              label: 'Déplacement',
              value: _mobilityMode?.label ?? 'Non défini',
            ),
            const _SummaryDivider(),
            _SummaryRow(
              icon: LucideIcons.badgeCheck,
              label: 'Rôles',
              value: _rolesLabel,
              expanded: true,
            ),
            if (line.isNotEmpty || zone.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (line.isNotEmpty)
                    _SummaryTag(icon: LucideIcons.route, label: line),
                  if (zone.isNotEmpty)
                    _SummaryTag(icon: LucideIcons.mapPin, label: zone),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildConsignesStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ControlCreateSectionCard(
          title: 'Cadre du service',
          subtitle: 'Objectif et niveau de priorité',
          icon: LucideIcons.target,
          children: [
            const ControlCreateFieldLabel('Objectif'),
            TextField(
              controller: _objectiveController,
              minLines: 1,
              maxLines: 3,
              decoration: controlCreateFieldDecoration(
                'Ex. Informations & Contrôles',
              ),
            ),
            const SizedBox(height: 16),
            const ControlCreateFieldLabel('Priorité'),
            SegmentedButton<MissionPriority>(
              segments: MissionPriority.values
                  .map(
                    (priority) => ButtonSegment(
                      value: priority,
                      label: Text(priority.label),
                    ),
                  )
                  .toList(),
              selected: {_priority},
              onSelectionChanged: (selection) {
                _markDirty();
                setState(() => _priority = selection.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        ControlConsignesSection(
          lineController: _lineController,
          zoneController: _zoneController,
          consigneController: _consigneController,
          consignes: _consignes,
          consigneStart: _consigneStart,
          consigneEnd: _consigneEnd,
          draftTimesValid: _draftConsigneTimesValid,
          onLineSelected: _onLineSelected,
          onLineManualEdit: _onLineManualEdit,
          onPickConsigneTime: _pickConsigneTime,
          onAddConsigne: _addConsigne,
          onRemoveConsigne: _removeConsigne,
        ),
        if (!_hasSector) ...[
          const SizedBox(height: 10),
          const ControlCreateInlineError(
            'Renseignez au moins une ligne ou une zone d’intervention.',
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  Widget _hero({required String title, required bool saving}) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DriverHomePalette.gradientStart,
              DriverHomePalette.gradientEnd,
            ],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: DriverHomePalette.darkGreen.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
          child: Stack(
            children: [
              Positioned(top: -40, right: -30, child: _glow(150, 0.12)),
              Positioned(bottom: -40, left: -20, child: _glow(130, 0.08)),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _GlassIconButton(
                            icon: _step == 0
                                ? LucideIcons.x
                                : LucideIcons.arrowLeft,
                            onTap: saving
                                ? null
                                : (_step == 0 ? _requestLeave : _prevStep),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              LucideIcons.target,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _stepLabels[_step],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        controller: _stepScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_stepCount, (i) {
                            return Padding(
                              key: _stepPillKeys[i],
                              padding: EdgeInsets.only(
                                right: i == _stepCount - 1 ? 0 : 8,
                              ),
                              child: _stepPill(i, _stepLabels[i]),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepPill(int index, String label) {
    final selected = _step == index;
    return GestureDetector(
      onTap: () {
        if (index > _step) {
          for (var s = _step; s < index; s++) {
            if (!_canAdvanceFromStep(s)) {
              _snack(_stepBlockReason(s) ?? 'Complétez l\'étape ${s + 1}');
              return;
            }
          }
        }
        _goToStep(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0 : 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? DriverHomePalette.primary
                    : Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? DriverHomePalette.primary : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GlassIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            icon,
            size: 22,
            color: Colors.white.withValues(alpha: onTap == null ? 0.5 : 1),
          ),
        ),
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  final String teamName;
  final int memberCount;

  const _SummaryHero({required this.teamName, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.lerp(
          DriverHomePalette.background,
          DriverHomePalette.primary,
          0.05,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: DriverHomePalette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              LucideIcons.usersRound,
              color: DriverHomePalette.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DriverHomePalette.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$memberCount agent${memberCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
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

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool expanded;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: expanded
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: DriverHomePalette.lightGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 17, color: DriverHomePalette.primary),
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
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: expanded ? 4 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DriverHomePalette.textDark,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 11),
      child: Divider(height: 1, color: DriverHomePalette.border),
    );
  }
}

class _SummaryTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: DriverHomePalette.textDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
