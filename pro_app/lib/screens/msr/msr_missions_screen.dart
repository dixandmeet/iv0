import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/msr/msr_mission.dart';
import '../../services/msr/msr_mission_service.dart';
import 'msr_mission_detail_screen.dart';

/// Liste des missions de l'agent MSR (table Supabase `msr_missions`).
///
/// Flux manuel MVP : l'agent voit, crée et supprime ses propres missions via
/// [MsrMissionService]. La RLS Supabase garantit l'isolation par agent.
class MsrMissionsScreen extends StatefulWidget {
  const MsrMissionsScreen({super.key});

  @override
  State<MsrMissionsScreen> createState() => _MsrMissionsScreenState();
}

class _MsrMissionsScreenState extends State<MsrMissionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<MsrMissionService>();
      if (!service.loaded) service.fetchMissions();
    });
  }

  Future<void> _createMission() async {
    final draft = await showModalBottomSheet<MsrMission>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _MissionForm(),
    );
    if (draft == null || !mounted) return;

    final service = context.read<MsrMissionService>();
    final created = await service.createMission(
      title: draft.title,
      sector: draft.sector,
      scheduledAt: draft.scheduledAt,
      kind: draft.kind,
      zoneLabel: draft.zoneLabel,
      teamLabel: draft.teamLabel,
      instructions: draft.instructions,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created != null
              ? 'Mission créée'
              : (service.errorMessage ?? 'Échec de la création'),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(MsrMission mission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la mission ?'),
        content: Text(mission.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteMission(MsrMission mission) async {
    final service = context.read<MsrMissionService>();
    final ok = await service.deleteMission(mission.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '« ${mission.title} » supprimée'
              : (service.errorMessage ?? 'Échec de la suppression'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MsrMissionService>();
    final missions = service.missions;

    Widget body;
    if (service.loading && missions.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (missions.isEmpty) {
      body = _EmptyState(error: service.errorMessage);
    } else {
      body = RefreshIndicator(
        onRefresh: () => service.fetchMissions(silent: true),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: missions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final mission = missions[i];
            return Dismissible(
              key: ValueKey(mission.id),
              direction: DismissDirection.endToStart,
              background: _DismissBackground(),
              confirmDismiss: (_) => _confirmDelete(mission),
              onDismissed: (_) => _deleteMission(mission),
              child: _MissionCard(mission: mission),
            );
          },
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createMission,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Nouvelle mission'),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(LucideIcons.trash2, color: Colors.white),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final MsrMission mission;
  const _MissionCard({required this.mission});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('EEE d MMM · HH:mm', 'fr_FR').format(
      mission.scheduledAt,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          mission.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${mission.sector} · $time'),
        ),
        trailing: _StatusChip(status: mission.status),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MsrMissionDetailScreen(mission: mission),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MsrMissionStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? error;
  const _EmptyState({this.error});

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError ? LucideIcons.triangleAlert : LucideIcons.clipboardList,
              size: 48,
              color: hasError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 12),
            Text(hasError ? error! : 'Aucune mission pour le moment'),
            const SizedBox(height: 4),
            Text(
              'Appuyez sur « Nouvelle mission » pour en créer une.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulaire de création d'une mission MSR (feuille modale).
class _MissionForm extends StatefulWidget {
  const _MissionForm();

  @override
  State<_MissionForm> createState() => _MissionFormState();
}

class _MissionFormState extends State<_MissionForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _sectorCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController();
  final _teamCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  MsrMissionKind _kind = MsrMissionKind.controle;
  DateTime _scheduledAt = DateTime.now().add(const Duration(hours: 1));

  @override
  void dispose() {
    _titleCtrl.dispose();
    _sectorCtrl.dispose();
    _zoneCtrl.dispose();
    _teamCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final mission = MsrMission(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      sector: _sectorCtrl.text.trim(),
      scheduledAt: _scheduledAt,
      status: MsrMissionStatus.upcoming,
      zoneLabel: _zoneCtrl.text.trim().isEmpty ? null : _zoneCtrl.text.trim(),
      teamLabel: _teamCtrl.text.trim().isEmpty ? null : _teamCtrl.text.trim(),
      instructions: _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
      kind: _kind,
    );
    Navigator.of(context).pop(mission);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final schedule =
        DateFormat('EEE d MMM · HH:mm', 'fr_FR').format(_scheduledAt);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Nouvelle mission',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SegmentedButton<MsrMissionKind>(
                segments: const [
                  ButtonSegment(
                    value: MsrMissionKind.controle,
                    icon: Icon(LucideIcons.clipboardCheck, size: 18),
                    label: Text('Contrôle'),
                  ),
                  ButtonSegment(
                    value: MsrMissionKind.intervention,
                    icon: Icon(LucideIcons.shieldAlert, size: 18),
                    label: Text('Intervention'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Titre *',
                  hintText: 'Contrôle ligne 2 — Commerce',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sectorCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Secteur *',
                  hintText: 'Centre',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Secteur requis' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.calendarClock),
                title: const Text('Planifiée'),
                subtitle: Text(schedule),
                trailing: TextButton(
                  onPressed: _pickSchedule,
                  child: const Text('Modifier'),
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _zoneCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Zone d\'intervention',
                  hintText: 'Zone Centre-ville',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _teamCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Équipe',
                  hintText: 'Équipe A',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructionsCtrl,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Consignes',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(LucideIcons.check),
                label: const Text('Créer la mission'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
