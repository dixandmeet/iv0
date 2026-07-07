import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/control_team.dart';
import '../../services/driver/control_team_service.dart';
import '../../services/driver/driver_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../widgets/driver/control_create/control_create_widgets.dart';

enum _LeaveAction { cancel, discard, saveDraft }

/// Création d'une équipe de contrôle : informations générales et agents.
class ControlTeamCreateScreen extends StatefulWidget {
  final ControlTeam? team;

  const ControlTeamCreateScreen({super.key, this.team});

  @override
  State<ControlTeamCreateScreen> createState() =>
      _ControlTeamCreateScreenState();
}

class _ControlTeamCreateScreenState extends State<ControlTeamCreateScreen> {
  final _nameController = TextEditingController();
  final _lineController = TextEditingController();
  final _zoneController = TextEditingController();

  final List<TeamVacation> _vacations = [const TeamVacation()];
  TeamMobilityMode? _mobilityMode;

  final List<TeamInstruction> _consignes = [];
  final List<TeamMember> _members = [];

  String? _editingTeamId;
  bool _dirty = false;
  bool _leaveAfterSave = false;

  bool get _isEditing => _editingTeamId != null;

  @override
  void initState() {
    super.initState();
    _hydrateFromTeam(widget.team);
    _lineController.addListener(_markDirty);
    _zoneController.addListener(_markDirty);
  }

  void _hydrateFromTeam(ControlTeam? team) {
    if (team == null) return;
    _editingTeamId = team.id;
    _nameController.text = team.name;
    _mobilityMode = team.mobilityMode;
    _members.addAll(team.members);
    _consignes.addAll(team.instructions);
    _lineController.text = team.lineId ?? '';
    _zoneController.text = team.zone ?? '';

    _vacations.clear();
    if (team.vacations.isNotEmpty) {
      _vacations.addAll(team.vacations);
    } else if (team.departureTime != null || team.returnTime != null) {
      _vacations.add(
        TeamVacation(startTime: team.departureTime, endTime: team.returnTime),
      );
    } else {
      _vacations.add(const TeamVacation());
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _lineController.removeListener(_markDirty);
    _zoneController.removeListener(_markDirty);
    _nameController.dispose();
    _lineController.dispose();
    _zoneController.dispose();
    super.dispose();
  }

  // --- Règles métier --------------------------------------------------------

  List<TeamVacation> get _filledVacations =>
      _vacations.where((v) => v.isComplete).toList();

  /// Liste des conditions manquantes pour passer au statut « Planifiée ».
  List<String> get _missingForPlanned {
    final missing = <String>[];
    if (_nameController.text.trim().isEmpty) {
      missing.add('le nom de l\'équipe');
    }
    if (_members.length < 2) {
      missing.add('au moins 2 agents');
    }
    return missing;
  }

  bool get _canPlan => _missingForPlanned.isEmpty;

  bool get _hasDraftContent =>
      _nameController.text.trim().isNotEmpty ||
      _members.isNotEmpty ||
      _lineController.text.trim().isNotEmpty ||
      _zoneController.text.trim().isNotEmpty ||
      _consignes.isNotEmpty;

  bool get _canSaveDraft => _hasDraftContent;

  bool get _shouldConfirmLeave => _dirty && _hasDraftContent;

  // --- Agents ----------------------------------------------------------------

  void _addAgent(TeamAgent agent) {
    if (_members.any((m) => m.userId == agent.id)) return;
    _markDirty();
    setState(() => _members.add(TeamMember.fromAgent(agent)));
  }

  void _removeMember(TeamMember member) {
    _markDirty();
    setState(() => _members.removeWhere((m) => m.userId == member.userId));
  }

  /// Active / désactive une mention en respectant l'unicité PAD / Chef.
  void _toggleMention(TeamMember member, TeamMention mention) {
    _markDirty();
    setState(() {
      final idx = _members.indexWhere((m) => m.userId == member.userId);
      if (idx < 0) return;
      final willEnable = !_members[idx].hasMention(mention);

      // PAD et Chef sont uniques : on les retire des autres agents avant de
      // les attribuer ici.
      if (willEnable && mention.isUnique) {
        for (var i = 0; i < _members.length; i++) {
          if (i != idx && _members[i].hasMention(mention)) {
            _members[i] = _members[i].toggleMention(mention);
          }
        }
      }
      _members[idx] = _members[idx].toggleMention(mention);
    });
  }

  // --- Sauvegarde ------------------------------------------------------------

  String _resolveTeamName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) return name;
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final mo = now.month.toString().padLeft(2, '0');
    return 'Brouillon · $dd/$mo $hh:$mm';
  }

  Future<bool> _save({required TeamStatus status}) async {
    final driver = context.read<DriverService>().driver;
    if (driver == null) {
      _snack('Session conducteur introuvable');
      return false;
    }

    if (status == TeamStatus.draft && !_canSaveDraft) {
      _snack('Ajoutez au moins une information avant d\'enregistrer');
      return false;
    }

    final service = context.read<ControlTeamService>();
    final resolvedName = _resolveTeamName();
    final TeamSaveResult result;
    if (_editingTeamId != null) {
      result = await service.updateTeam(
        teamId: _editingTeamId!,
        name: resolvedName,
        status: status,
        vacations: _filledVacations,
        mobilityMode: _mobilityMode,
        lineId: _lineController.text,
        zone: _zoneController.text,
        instructions: _consignes,
        members: _members,
        creatorDriverId: driver.id,
      );
    } else {
      result = await service.createTeam(
        createdByDriverId: driver.id,
        name: resolvedName,
        status: status,
        vacations: _filledVacations,
        mobilityMode: _mobilityMode,
        lineId: _lineController.text,
        zone: _zoneController.text,
        instructions: _consignes,
        members: _members,
      );
    }

    if (!mounted) return false;
    if (result.success) {
      _editingTeamId ??= result.teamId;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = resolvedName;
      }
      setState(() {
        _dirty = false;
      });
      _snack(
        status == TeamStatus.draft
            ? 'Brouillon enregistré'
            : 'Équipe planifiée',
      );
      if (_leaveAfterSave && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
      return true;
    }

    _snack(result.error ?? 'Échec de l\'enregistrement');
    return false;
  }

  Future<void> _saveDraftInPlace() async {
    _leaveAfterSave = false;
    final ok = await _save(status: TeamStatus.draft);
    if (ok && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_shouldConfirmLeave) return true;

    final canSave = _canSaveDraft;
    final action = await showDialog<_LeaveAction>(
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
        content: Text(
          canSave
              ? 'Enregistrez un brouillon pour reprendre la création plus tard, '
                    'ou quittez sans enregistrer.'
              : 'Certaines informations sont invalides. '
                    'Corrigez-les ou quittez sans enregistrer.',
          style: const TextStyle(
            color: DriverHomePalette.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveAction.cancel),
            child: const Text('Continuer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveAction.discard),
            style: TextButton.styleFrom(
              foregroundColor: DriverHomePalette.danger,
            ),
            child: const Text('Quitter sans enregistrer'),
          ),
          if (canSave)
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(_LeaveAction.saveDraft),
              style: FilledButton.styleFrom(
                backgroundColor: DriverHomePalette.primary,
              ),
              child: const Text('Enregistrer en brouillon'),
            ),
        ],
      ),
    );

    switch (action) {
      case _LeaveAction.saveDraft:
        _leaveAfterSave = true;
        return _save(status: TeamStatus.draft);
      case _LeaveAction.discard:
        return true;
      case _LeaveAction.cancel:
      case null:
        return false;
    }
  }

  Future<void> _requestLeave() async {
    if (!_shouldConfirmLeave) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final shouldLeave = await _confirmLeave();
    if (!shouldLeave || !mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(_leaveAfterSave);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<ControlTeamService>().saving;
    final title = _isEditing
        ? (widget.team?.status == TeamStatus.draft
              ? 'Reprendre le brouillon'
              : 'Modifier l\'équipe')
        : 'Créer une équipe de contrôle';

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
            Expanded(child: _buildTeamStep()),
          ],
        ),
        bottomNavigationBar: ControlCreateBottomBar(
          step: 0,
          singleStep: true,
          saving: saving,
          canPlan: _canPlan,
          canSaveDraft: _canSaveDraft,
          missingForPlanned: _missingForPlanned,
          onNext: () {},
          onBack: () {},
          onSaveDraft: () => unawaited(_saveDraftInPlace()),
          submitLabel: _isEditing ? 'Enregistrer' : 'Créer l\'équipe',
          onPlan: () {
            _leaveAfterSave = true;
            _save(status: TeamStatus.planned);
          },
        ),
      ),
    );
  }

  Widget _buildTeamStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        ControlTeamGeneralSection(
          nameController: _nameController,
          onNameChanged: () {
            _markDirty();
            setState(() {});
          },
        ),
        const SizedBox(height: 18),
        ControlAgentsSection(
          members: _members,
          alreadyAddedIds: _members.map((m) => m.userId).toSet(),
          onAgentSelected: _addAgent,
          onRemove: _removeMember,
          onToggleMention: _toggleMention,
          showMentions: false,
          subtitle: 'Agents disponibles pour les services',
          emptyMessage: 'Aucun agent ajouté. Ajoutez au moins 2 agents.',
        ),
      ],
    );
  }

  Widget _hero({required String title, required bool saving}) {
    final activeMembers = _members
        .where((m) => m.invitationStatus != InvitationStatus.removed)
        .length;
    final statusLabel = _isEditing
        ? (widget.team?.status.label ?? 'Équipe')
        : (_canPlan ? 'Prête à planifier' : 'Composition');

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
              Positioned(top: -42, right: -24, child: _glow(150, 0.12)),
              Positioned(bottom: -50, left: -28, child: _glow(132, 0.08)),
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
                            icon: LucideIcons.x,
                            onTap: saving ? null : _requestLeave,
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
                              LucideIcons.usersRound,
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
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  statusLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HeroMetricChip(
                            icon: LucideIcons.users,
                            label:
                                '$activeMembers agent'
                                '${activeMembers > 1 ? 's' : ''}',
                          ),
                          const _HeroMetricChip(
                            icon: LucideIcons.badgeCheck,
                            label: 'Rôles en service',
                          ),
                        ],
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

  Widget _glow(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

class _HeroMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroMetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
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
