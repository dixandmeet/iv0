import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../models/driver/control_team.dart';
import '../../../models/gtfs.dart';
import '../../../services/driver/control_team_service.dart';
import '../../../services/gtfs_service.dart';
import '../../../theme/driver_home_palette.dart';
import '../driver_date_range_picker.dart';

String controlCreateRouteLabel(GtfsRoute route) {
  final short = route.routeShortName ?? route.routeId;
  final long = route.routeLongName?.trim();
  if (long != null && long.isNotEmpty) return 'Ligne $short · $long';
  return 'Ligne $short';
}

/// Indicateur d'étapes en haut de l'assistant.
class ControlCreateStepHeader extends StatelessWidget {
  final int currentStep;
  final String step0Label;
  final String step1Label;

  const ControlCreateStepHeader({
    super.key,
    required this.currentStep,
    this.step0Label = 'Membres',
    this.step1Label = 'Consignes',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          _ControlCreateStepDot(
            index: 0,
            label: step0Label,
            active: currentStep >= 0,
          ),
          const _ControlCreateStepConnector(),
          _ControlCreateStepDot(
            index: 1,
            label: step1Label,
            active: currentStep >= 1,
          ),
        ],
      ),
    );
  }
}

class _ControlCreateStepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool active;
  const _ControlCreateStepDot({
    required this.index,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? DriverHomePalette.primary
        : DriverHomePalette.inactiveIcon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? DriverHomePalette.primary
                : DriverHomePalette.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: active ? Colors.white : DriverHomePalette.inactiveIcon,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _ControlCreateStepConnector extends StatelessWidget {
  const _ControlCreateStepConnector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: DriverHomePalette.border,
    );
  }
}

// ===========================================================================
// Sections
// ===========================================================================

class ControlCreateSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;

  const ControlCreateSectionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DriverHomePalette.border),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: DriverHomePalette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: DriverHomePalette.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: DriverHomePalette.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: DriverHomePalette.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class ControlCreateFieldLabel extends StatelessWidget {
  final String label;
  final bool optional;
  const ControlCreateFieldLabel(this.label, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: DriverHomePalette.textDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (optional) ...[
            const SizedBox(width: 6),
            const Text(
              'facultatif',
              style: TextStyle(
                color: DriverHomePalette.textSecondary,
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

InputDecoration controlCreateFieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: DriverHomePalette.inactiveIcon),
    filled: true,
    fillColor: DriverHomePalette.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: DriverHomePalette.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(
        color: DriverHomePalette.primary,
        width: 1.5,
      ),
    ),
  );
}

class ControlTeamGeneralSection extends StatelessWidget {
  final TextEditingController nameController;
  final VoidCallback onNameChanged;

  const ControlTeamGeneralSection({
    required this.nameController,
    required this.onNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ControlCreateSectionCard(
      title: 'Informations générales',
      icon: LucideIcons.clipboardList,
      children: [
        const ControlCreateFieldLabel('Nom de l\'équipe'),
        TextField(
          controller: nameController,
          onChanged: (_) => onNameChanged(),
          textInputAction: TextInputAction.next,
          decoration: controlCreateFieldDecoration(
            'Ex. Équipe contrôle ligne 1',
          ),
        ),
      ],
    );
  }
}

class ControlTeamVacationsSection extends StatelessWidget {
  final List<TeamVacation> vacations;
  final bool vacationsValid;
  final void Function({required int index, required bool isStart})
  onPickVacationTime;
  final VoidCallback onAddVacation;
  final ValueChanged<int> onRemoveVacation;

  const ControlTeamVacationsSection({
    super.key,
    required this.vacations,
    required this.vacationsValid,
    required this.onPickVacationTime,
    required this.onAddVacation,
    required this.onRemoveVacation,
  });

  @override
  Widget build(BuildContext context) {
    return ControlCreateSectionCard(
      title: 'Vacations',
      subtitle: 'Créneaux horaires de l\'équipe',
      icon: LucideIcons.clock,
      children: [
        ...vacations.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ControlVacationRow(
              index: entry.key,
              vacation: entry.value,
              canRemove: vacations.length > 1,
              onPickStart: () =>
                  onPickVacationTime(index: entry.key, isStart: true),
              onPickEnd: () =>
                  onPickVacationTime(index: entry.key, isStart: false),
              onRemove: () => onRemoveVacation(entry.key),
            ),
          ),
        ),
        if (!vacationsValid) ...[
          const ControlCreateInlineError(
            'Chaque vacation doit avoir une heure de fin après l\'heure de début.',
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: onAddVacation,
          style: OutlinedButton.styleFrom(
            foregroundColor: DriverHomePalette.primary,
            side: BorderSide(
              color: DriverHomePalette.primary.withValues(alpha: 0.45),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            minimumSize: const Size.fromHeight(44),
          ),
          icon: const Icon(LucideIcons.plus, size: 17),
          label: const Text(
            'Ajouter une vacation',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class ControlTeamMobilitySection extends StatelessWidget {
  final TeamMobilityMode? mobilityMode;
  final ValueChanged<TeamMobilityMode> onMobilityModeChanged;

  const ControlTeamMobilitySection({
    super.key,
    required this.mobilityMode,
    required this.onMobilityModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ControlCreateSectionCard(
      title: 'Mode de déplacement',
      subtitle: 'Organisation terrain de l\'équipe',
      icon: LucideIcons.route,
      children: [
        Row(
          children: TeamMobilityMode.values.map((mode) {
            final selected = mobilityMode == mode;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: mode == TeamMobilityMode.vehicle ? 8 : 0,
                ),
                child: _ControlMobilityChoice(
                  mode: mode,
                  selected: selected,
                  onTap: () => onMobilityModeChanged(mode),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ControlVacationRow extends StatelessWidget {
  final int index;
  final TeamVacation vacation;
  final bool canRemove;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onRemove;

  const _ControlVacationRow({
    required this.index,
    required this.vacation,
    required this.canRemove,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final invalid = vacation.isComplete && !vacation.isValid;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DriverHomePalette.background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: invalid ? DriverHomePalette.danger : DriverHomePalette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Vacation ${index + 1}',
                style: const TextStyle(
                  color: DriverHomePalette.textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (canRemove)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  color: DriverHomePalette.textSecondary,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Retirer',
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: ControlCreateTimeField(
                  label: 'Heure de début',
                  value: vacation.startTime,
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ControlCreateTimeField(
                  label: 'Heure de fin',
                  value: vacation.endTime,
                  onTap: onPickEnd,
                  hasError: invalid,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlMobilityChoice extends StatelessWidget {
  final TeamMobilityMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ControlMobilityChoice({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = mode == TeamMobilityMode.vehicle
        ? LucideIcons.busFront
        : LucideIcons.footprints;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? DriverHomePalette.primary.withValues(alpha: 0.12)
              : DriverHomePalette.background,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? DriverHomePalette.primary
                : DriverHomePalette.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? DriverHomePalette.primary
                  : DriverHomePalette.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              mode.label,
              style: TextStyle(
                color: selected
                    ? DriverHomePalette.primary
                    : DriverHomePalette.textDark,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ControlCreateTimeField extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;
  final bool hasError;

  const ControlCreateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = hasError
        ? DriverHomePalette.danger
        : DriverHomePalette.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ControlCreateFieldLabel(label),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: DriverHomePalette.background,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.clock,
                  size: 17,
                  color: DriverHomePalette.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  formatTimeLabel(value),
                  style: TextStyle(
                    color: value == null
                        ? DriverHomePalette.inactiveIcon
                        : DriverHomePalette.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Champ de sélection de période avec aperçu visuel.
class ControlPeriodPickerField extends StatelessWidget {
  final DateTime periodStart;
  final DateTime periodEnd;
  final bool singleDay;
  final VoidCallback onPickPeriod;

  const ControlPeriodPickerField({
    super.key,
    required this.periodStart,
    required this.periodEnd,
    required this.singleDay,
    required this.onPickPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final periodLabel = formatMissionPeriodLabel(
      start: periodStart,
      end: periodEnd,
    );
    final durationLabel = missionPeriodDurationLabel(
      start: periodStart,
      end: periodEnd,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPickPeriod,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    DriverHomePalette.gradientStart,
                    DriverHomePalette.gradientEnd,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: DriverHomePalette.primary.withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.calendarDays,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            periodLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              durationLabel,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          singleDay
              ? 'Mission sur une seule journée. Appuyez pour étendre sur '
                    'plusieurs jours.'
              : 'La mission reste active sur toute la période sélectionnée.',
          style: const TextStyle(
            color: DriverHomePalette.textSecondary,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// Section « Détails de la mission » : objectif et période de la mission.
class ControlMissionDetailsSection extends StatelessWidget {
  final TextEditingController objectiveController;
  final DateTime periodStart;
  final DateTime periodEnd;
  final bool singleDay;
  final VoidCallback onObjectiveChanged;
  final VoidCallback onPickPeriod;

  const ControlMissionDetailsSection({
    super.key,
    required this.objectiveController,
    required this.periodStart,
    required this.periodEnd,
    required this.singleDay,
    required this.onObjectiveChanged,
    required this.onPickPeriod,
  });

  @override
  Widget build(BuildContext context) {
    return ControlCreateSectionCard(
      title: 'Détails de la mission',
      subtitle: 'Objectif et période de la mission',
      icon: LucideIcons.target,
      children: [
        const ControlCreateFieldLabel('Objectif'),
        TextField(
          controller: objectiveController,
          onChanged: (_) => onObjectiveChanged(),
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.newline,
          decoration: controlCreateFieldDecoration(
            'Ex. Contrôle titres de transport',
          ),
        ),
        const SizedBox(height: 16),
        const ControlCreateFieldLabel('Période'),
        ControlPeriodPickerField(
          periodStart: periodStart,
          periodEnd: periodEnd,
          singleDay: singleDay,
          onPickPeriod: onPickPeriod,
        ),
      ],
    );
  }
}

class ControlConsignesSection extends StatelessWidget {
  final TextEditingController lineController;
  final TextEditingController zoneController;
  final TextEditingController consigneController;
  final List<TeamInstruction> consignes;
  final TimeOfDay? consigneStart;
  final TimeOfDay? consigneEnd;
  final bool draftTimesValid;
  final ValueChanged<GtfsRoute> onLineSelected;
  final VoidCallback onLineManualEdit;
  final void Function({required bool isStart}) onPickConsigneTime;
  final VoidCallback onAddConsigne;
  final ValueChanged<int> onRemoveConsigne;

  const ControlConsignesSection({
    required this.lineController,
    required this.zoneController,
    required this.consigneController,
    required this.consignes,
    required this.consigneStart,
    required this.consigneEnd,
    required this.draftTimesValid,
    required this.onLineSelected,
    required this.onLineManualEdit,
    required this.onPickConsigneTime,
    required this.onAddConsigne,
    required this.onRemoveConsigne,
  });

  @override
  Widget build(BuildContext context) {
    return ControlCreateSectionCard(
      title: 'Consignes',
      subtitle: 'Périmètre et consignes opérationnelles (facultatif)',
      icon: LucideIcons.listChecks,
      children: [
        const ControlCreateFieldLabel('Ligne concernée', optional: true),
        _ControlLineAutocompleteField(
          controller: lineController,
          onSelected: onLineSelected,
          onManualEdit: onLineManualEdit,
        ),
        const SizedBox(height: 14),
        const ControlCreateFieldLabel('Zone d\'intervention', optional: true),
        TextField(
          controller: zoneController,
          textInputAction: TextInputAction.next,
          decoration: controlCreateFieldDecoration(
            'Ex. Secteur Commerce / Bouffay',
          ),
        ),
        const SizedBox(height: 18),
        Container(height: 1, color: DriverHomePalette.border),
        const SizedBox(height: 18),
        const ControlCreateFieldLabel('Nouvelle consigne', optional: true),
        TextField(
          controller: consigneController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onAddConsigne(),
          decoration: controlCreateFieldDecoration(
            'Ex. Contrôle renforcé aux arrêts centraux',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ControlCreateTimeField(
                label: 'Heure de début',
                value: consigneStart,
                onTap: () => onPickConsigneTime(isStart: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ControlCreateTimeField(
                label: 'Heure de fin',
                value: consigneEnd,
                onTap: () => onPickConsigneTime(isStart: false),
                hasError: !draftTimesValid,
              ),
            ),
          ],
        ),
        if (!draftTimesValid) ...[
          const SizedBox(height: 8),
          const ControlCreateInlineError(
            'L\'heure de fin doit être après l\'heure de début.',
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAddConsigne,
            style: OutlinedButton.styleFrom(
              foregroundColor: DriverHomePalette.primary,
              side: const BorderSide(color: DriverHomePalette.primary),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text(
              'Ajouter la consigne',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (consignes.isEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Aucune consigne ajoutée.',
            style: TextStyle(
              color: DriverHomePalette.textSecondary,
              fontSize: 13.5,
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          ...consignes.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ControlConsigneTile(
                index: entry.key,
                instruction: entry.value,
                onRemove: () => onRemoveConsigne(entry.key),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ControlLineAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<GtfsRoute> onSelected;
  final VoidCallback onManualEdit;

  const _ControlLineAutocompleteField({
    required this.controller,
    required this.onSelected,
    required this.onManualEdit,
  });

  @override
  State<_ControlLineAutocompleteField> createState() =>
      _ControlLineAutocompleteFieldState();
}

class _ControlLineAutocompleteFieldState
    extends State<_ControlLineAutocompleteField> {
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<GtfsRoute> _results = const [];
  bool _loading = false;
  bool _showSuggestions = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _showSuggestions = _focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      _runSearch(widget.controller.text);
    }
  }

  void _onChanged(String value) {
    widget.onManualEdit();
    setState(() => _showSuggestions = true);
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _runSearch(value),
    );
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    final gtfs = context.read<GtfsService>();
    if (gtfs.cachedRoutes.isEmpty) {
      await gtfs.fetchRoutes();
    }
    if (!mounted) return;

    final q = query.trim();
    final results = q.isEmpty
        ? gtfs.cachedRoutes.take(20).toList()
        : gtfs.searchRoutes(q, limit: 20);

    setState(() {
      _results = results;
      _loading = false;
      _searched = true;
    });
  }

  void _selectRoute(GtfsRoute route) {
    widget.onSelected(route);
    _focusNode.unfocus();
    setState(() {
      _showSuggestions = false;
      _results = const [];
      _searched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _showSuggestions && (_loading || _searched);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          textInputAction: TextInputAction.next,
          decoration:
              controlCreateFieldDecoration(
                'Rechercher une ligne (ex. 1, C2, Busway)',
              ).copyWith(
                prefixIcon: const Icon(
                  LucideIcons.search,
                  size: 18,
                  color: DriverHomePalette.textSecondary,
                ),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DriverHomePalette.primary,
                          ),
                        ),
                      )
                    : widget.controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          widget.controller.clear();
                          widget.onManualEdit();
                          _onChanged('');
                        },
                        icon: const Icon(LucideIcons.x, size: 16),
                        color: DriverHomePalette.textSecondary,
                      )
                    : null,
              ),
        ),
        if (visible) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: DriverHomePalette.background,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: DriverHomePalette.border),
            ),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: DriverHomePalette.primary,
                      ),
                    ),
                  )
                : _results.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Aucune ligne trouvée.',
                      style: TextStyle(
                        color: DriverHomePalette.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _results.length,
                    separatorBuilder: (context, _) => const Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                      color: DriverHomePalette.border,
                    ),
                    itemBuilder: (_, i) {
                      final route = _results[i];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _selectRoute(route),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DriverHomePalette.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    route.routeShortName ?? route.routeId,
                                    style: const TextStyle(
                                      color: DriverHomePalette.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    route.routeLongName ?? route.routeId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: DriverHomePalette.textDark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}

class _ControlConsigneTile extends StatelessWidget {
  final int index;
  final TeamInstruction instruction;
  final VoidCallback onRemove;

  const _ControlConsigneTile({
    required this.index,
    required this.instruction,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: DriverHomePalette.background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DriverHomePalette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: DriverHomePalette.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (instruction.hasTimes) ...[
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.clock,
                          size: 14,
                          color: DriverHomePalette.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          instruction.timeLabel,
                          style: const TextStyle(
                            color: DriverHomePalette.primary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    instruction.text,
                    style: const TextStyle(
                      color: DriverHomePalette.textDark,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(LucideIcons.x, size: 16),
            color: DriverHomePalette.textSecondary,
            visualDensity: VisualDensity.compact,
            tooltip: 'Retirer',
          ),
        ],
      ),
    );
  }
}

class ControlAgentsSection extends StatelessWidget {
  final List<TeamMember> members;
  final Set<String> alreadyAddedIds;
  final ValueChanged<TeamAgent> onAgentSelected;
  final ValueChanged<TeamMember> onRemove;
  final void Function(TeamMember, TeamMention) onToggleMention;
  final String title;
  final String subtitle;
  final String searchHint;
  final String emptyMessage;
  final bool enabled;
  final bool showMentions;
  final String Function(TeamAgent agent)? blockedActiveTeamHint;

  const ControlAgentsSection({
    super.key,
    required this.members,
    required this.alreadyAddedIds,
    required this.onAgentSelected,
    required this.onRemove,
    required this.onToggleMention,
    this.title = 'Agents',
    this.subtitle = 'Minimum 2 agents · mentions facultatives',
    this.searchHint = 'Rechercher un agent (nom ou matricule)',
    this.emptyMessage = 'Aucun agent ajouté. Recherchez par nom ou matricule.',
    this.enabled = true,
    this.showMentions = true,
    this.blockedActiveTeamHint,
  });

  @override
  Widget build(BuildContext context) {
    return ControlCreateSectionCard(
      title: title,
      subtitle: subtitle,
      icon: LucideIcons.users,
      children: [
        IgnorePointer(
          ignoring: !enabled,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: _ControlAgentPickerButton(
              alreadyAddedIds: alreadyAddedIds,
              searchHint: searchHint,
              blockedActiveTeamHint: blockedActiveTeamHint,
              onAgentSelected: onAgentSelected,
            ),
          ),
        ),
        if (members.isEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: DriverHomePalette.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DriverHomePalette.border),
            ),
            child: Column(
              children: [
                const Icon(
                  LucideIcons.userPlus,
                  size: 26,
                  color: DriverHomePalette.textSecondary,
                ),
                const SizedBox(height: 10),
                Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ] else if (enabled)
          ...members.map(
            (m) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ControlMemberTile(
                member: m,
                onRemove: () => onRemove(m),
                showMentions: showMentions,
                onToggleMention: (mention) => onToggleMention(m, mention),
              ),
            ),
          ),
      ],
    );
  }
}

class ControlTeamRolesSection extends StatelessWidget {
  final List<TeamMember> members;
  final void Function(TeamMember, TeamMention) onToggleMention;

  const ControlTeamRolesSection({
    super.key,
    required this.members,
    required this.onToggleMention,
  });

  @override
  Widget build(BuildContext context) {
    return ControlCreateSectionCard(
      title: 'Attribution des rôles',
      subtitle: 'PAD, Chef et TPE pour ce service',
      icon: LucideIcons.badgeCheck,
      children: [
        if (members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: DriverHomePalette.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DriverHomePalette.border),
            ),
            child: const Text(
              'Ajoutez d\'abord des agents à l\'équipe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DriverHomePalette.textSecondary,
                fontSize: 13.5,
              ),
            ),
          )
        else
          ...members.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ControlRoleMemberTile(
                member: m,
                onToggleMention: (mention) => onToggleMention(m, mention),
              ),
            ),
          ),
      ],
    );
  }
}

class _ControlMemberTile extends StatelessWidget {
  final TeamMember member;
  final VoidCallback onRemove;
  final bool showMentions;
  final ValueChanged<TeamMention> onToggleMention;

  const _ControlMemberTile({
    required this.member,
    required this.onRemove,
    required this.showMentions,
    required this.onToggleMention,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.lerp(
          DriverHomePalette.background,
          DriverHomePalette.primary,
          0.025,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: DriverHomePalette.softGreen,
                child: Text(
                  member.initials,
                  style: const TextStyle(
                    color: DriverHomePalette.darkGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.nameOrFallback,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: DriverHomePalette.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      member.driverNumber != null
                          ? 'Matricule ${member.driverNumber}'
                          : 'Agent de contrôle',
                      style: const TextStyle(
                        color: DriverHomePalette.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Retirer',
                child: Material(
                  color: DriverHomePalette.card,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        LucideIcons.x,
                        size: 17,
                        color: DriverHomePalette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (showMentions) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TeamMention.values.map((mention) {
                final selected = member.hasMention(mention);
                return _ControlMentionChip(
                  mention: mention,
                  selected: selected,
                  onTap: () => onToggleMention(mention),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlRoleMemberTile extends StatelessWidget {
  final TeamMember member;
  final ValueChanged<TeamMention> onToggleMention;

  const _ControlRoleMemberTile({
    required this.member,
    required this.onToggleMention,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.lerp(
          DriverHomePalette.background,
          DriverHomePalette.primary,
          0.025,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: DriverHomePalette.softGreen,
                child: Text(
                  member.initials,
                  style: const TextStyle(
                    color: DriverHomePalette.darkGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.nameOrFallback,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: DriverHomePalette.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      member.driverNumber != null
                          ? 'Matricule ${member.driverNumber}'
                          : 'Agent de contrôle',
                      style: const TextStyle(
                        color: DriverHomePalette.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TeamMention.values.map((mention) {
              final selected = member.hasMention(mention);
              return _ControlMentionChip(
                mention: mention,
                selected: selected,
                onTap: () => onToggleMention(mention),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ControlMentionChip extends StatelessWidget {
  final TeamMention mention;
  final bool selected;
  final VoidCallback onTap;

  const _ControlMentionChip({
    required this.mention,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = mention.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : DriverHomePalette.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? LucideIcons.check : LucideIcons.plus,
              size: 14,
              color: selected ? Colors.white : DriverHomePalette.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              mention.label,
              style: TextStyle(
                color: selected ? Colors.white : DriverHomePalette.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ControlCreateInlineError extends StatelessWidget {
  final String message;
  const ControlCreateInlineError(this.message);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          LucideIcons.triangleAlert,
          size: 15,
          color: DriverHomePalette.danger,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: DriverHomePalette.danger,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class ControlCreateBottomBar extends StatelessWidget {
  final int step;
  final bool saving;
  final bool canPlan;
  final bool canSaveDraft;
  final List<String> missingForPlanned;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSaveDraft;
  final VoidCallback onPlan;
  final String submitLabel;
  final bool singleStep;
  final bool showDraftOnStepOne;
  final bool showDraftLinkOnStepTwo;

  const ControlCreateBottomBar({
    super.key,
    required this.step,
    required this.saving,
    required this.canPlan,
    required this.canSaveDraft,
    required this.missingForPlanned,
    required this.onNext,
    required this.onBack,
    required this.onSaveDraft,
    required this.onPlan,
    this.submitLabel = 'Créer l\'équipe',
    this.singleStep = false,
    this.showDraftOnStepOne = true,
    this.showDraftLinkOnStepTwo = true,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: singleStep
            ? _singleStep()
            : (step == 0 ? _stepOne() : _stepTwo()),
      ),
    );
  }

  List<Widget> _singleStep() {
    return [
      if (!canPlan && missingForPlanned.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ControlCreateInlineError(
            'Pour planifier : ${missingForPlanned.join(', ')}.',
          ),
        ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: (saving || !canSaveDraft) ? null : onSaveDraft,
              style: _outlinedStyle(),
              child: const Text(
                'Brouillon',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GradientActionButton(
              onPressed: (saving || !canPlan) ? null : onPlan,
              loading: saving,
              child: Text(
                submitLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  // Étape 1 : composition de l'équipe → bouton « Suivant », brouillon possible.
  List<Widget> _stepOne() {
    if (!showDraftOnStepOne) {
      return [
        GradientActionButton(
          onPressed: onNext,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Suivant',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              SizedBox(width: 6),
              Icon(LucideIcons.arrowRight, size: 18),
            ],
          ),
        ),
      ];
    }

    return [
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: (saving || !canSaveDraft) ? null : onSaveDraft,
              style: _outlinedStyle(),
              child: const Text(
                'Brouillon',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GradientActionButton(
              onPressed: onNext,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Suivant',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  SizedBox(width: 6),
                  Icon(LucideIcons.arrowRight, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  // Étape 2 : consignes → retour + création (ou brouillon).
  List<Widget> _stepTwo() {
    return [
      if (!canPlan && missingForPlanned.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ControlCreateInlineError(
            'Pour planifier : ${missingForPlanned.join(', ')}.',
          ),
        ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : onBack,
              style: _outlinedStyle(),
              child: const Text(
                'Retour',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GradientActionButton(
              onPressed: (saving || !canPlan) ? null : onPlan,
              loading: saving,
              child: Text(
                submitLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      if (showDraftLinkOnStepTwo && canSaveDraft)
        TextButton(
          onPressed: saving ? null : onSaveDraft,
          style: TextButton.styleFrom(
            foregroundColor: DriverHomePalette.textSecondary,
          ),
          child: const Text('Enregistrer en brouillon'),
        ),
    ];
  }

  ButtonStyle _outlinedStyle() => controlCreateOutlinedButtonStyle();
}

ButtonStyle controlCreateOutlinedButtonStyle() => OutlinedButton.styleFrom(
  foregroundColor: DriverHomePalette.textDark,
  side: const BorderSide(color: DriverHomePalette.border),
  padding: const EdgeInsets.symmetric(vertical: 15),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

/// Bouton d'action principal avec dégradé premium (fond du hero Contrôle).
class GradientActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool loading;

  const GradientActionButton({
    required this.onPressed,
    required this.child,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: enabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  DriverHomePalette.gradientStart,
                  DriverHomePalette.gradientEnd,
                ],
              )
            : null,
        color: enabled ? null : DriverHomePalette.inactiveIcon,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: DriverHomePalette.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            height: 50,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : DefaultTextStyle(
                      style: const TextStyle(color: Colors.white),
                      child: IconTheme(
                        data: const IconThemeData(color: Colors.white),
                        child: child,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Recherche d'agents (bottom sheet)
// ===========================================================================

class _ControlAgentPickerButton extends StatelessWidget {
  final Set<String> alreadyAddedIds;
  final String searchHint;
  final String Function(TeamAgent agent)? blockedActiveTeamHint;
  final ValueChanged<TeamAgent> onAgentSelected;

  const _ControlAgentPickerButton({
    required this.alreadyAddedIds,
    required this.searchHint,
    this.blockedActiveTeamHint,
    required this.onAgentSelected,
  });

  Future<void> _openPicker(BuildContext context) async {
    final agent = await showModalBottomSheet<TeamAgent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ControlAgentSearchSheet(
        alreadyAddedIds: alreadyAddedIds,
        searchHint: searchHint,
        blockedActiveTeamHint: blockedActiveTeamHint,
      ),
    );
    if (agent == null || !context.mounted) return;
    onAgentSelected(agent);
    _snack(context, '${agent.fullName} ajouté');
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: DriverHomePalette.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DriverHomePalette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: DriverHomePalette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.userPlus,
                  size: 18,
                  color: DriverHomePalette.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  searchHint,
                  style: const TextStyle(
                    color: DriverHomePalette.textDark,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 19,
                color: DriverHomePalette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlAgentSearchSheet extends StatefulWidget {
  final Set<String> alreadyAddedIds;
  final String searchHint;
  final String Function(TeamAgent agent)? blockedActiveTeamHint;

  const _ControlAgentSearchSheet({
    required this.alreadyAddedIds,
    required this.searchHint,
    this.blockedActiveTeamHint,
  });

  @override
  State<_ControlAgentSearchSheet> createState() =>
      _ControlAgentSearchSheetState();
}

class _ControlAgentSearchSheetState extends State<_ControlAgentSearchSheet> {
  static const _minQueryLength = 2;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<TeamAgent> _results = const [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < _minQueryLength) {
      setState(() {
        _results = const [];
        _loading = false;
        _searched = query.isNotEmpty;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().length < _minQueryLength) return;
    setState(() => _loading = true);
    final results = await context.read<ControlTeamService>().searchAgents(
      query,
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
      _searched = true;
    });
  }

  void _selectAgent(TeamAgent agent) {
    Navigator.of(context).pop(agent);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final query = _controller.text.trim();
    final queryTooShort = query.isNotEmpty && query.length < _minQueryLength;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: Container(
          decoration: const BoxDecoration(
            color: DriverHomePalette.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: DriverHomePalette.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(LucideIcons.x, size: 20),
                      color: DriverHomePalette.textSecondary,
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ajouter un agent',
                      style: TextStyle(
                        color: DriverHomePalette.textDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Recherchez par nom, prénom ou matricule.',
                      style: TextStyle(
                        color: DriverHomePalette.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.search,
                      decoration:
                          controlCreateFieldDecoration(
                            widget.searchHint,
                          ).copyWith(
                            prefixIcon: const Icon(
                              LucideIcons.search,
                              size: 18,
                              color: DriverHomePalette.textSecondary,
                            ),
                            suffixIcon: _controller.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _controller.clear();
                                      _onChanged('');
                                    },
                                    icon: const Icon(LucideIcons.x, size: 16),
                                    color: DriverHomePalette.textSecondary,
                                  ),
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _AgentSearchBody(
                  loading: _loading,
                  query: query,
                  queryTooShort: queryTooShort,
                  searched: _searched,
                  results: _results,
                  alreadyAddedIds: widget.alreadyAddedIds,
                  blockedActiveTeamHint: widget.blockedActiveTeamHint,
                  onSelectAgent: _selectAgent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentSearchBody extends StatelessWidget {
  final bool loading;
  final String query;
  final bool queryTooShort;
  final bool searched;
  final List<TeamAgent> results;
  final Set<String> alreadyAddedIds;
  final String Function(TeamAgent agent)? blockedActiveTeamHint;
  final ValueChanged<TeamAgent> onSelectAgent;

  const _AgentSearchBody({
    required this.loading,
    required this.query,
    required this.queryTooShort,
    required this.searched,
    required this.results,
    required this.alreadyAddedIds,
    required this.blockedActiveTeamHint,
    required this.onSelectAgent,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: DriverHomePalette.primary),
      );
    }

    if (query.isEmpty) {
      return const _AgentSearchEmptyState(
        icon: LucideIcons.search,
        title: 'Lancez une recherche',
        message: 'Saisissez au moins 2 caractères pour trouver un agent.',
      );
    }

    if (queryTooShort) {
      return const _AgentSearchEmptyState(
        icon: LucideIcons.keyboard,
        title: 'Encore un caractère',
        message: 'La recherche démarre à partir de 2 caractères.',
      );
    }

    if (searched && results.isEmpty) {
      return const _AgentSearchEmptyState(
        icon: LucideIcons.userX,
        title: 'Aucun agent trouvé',
        message: 'Essayez avec un autre nom ou un matricule.',
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: results.length,
      separatorBuilder: (context, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final agent = results[i];
        final alreadyAdded = alreadyAddedIds.contains(agent.id);
        return _ControlAgentResultTile(
          agent: agent,
          alreadyAdded: alreadyAdded,
          blockedActiveTeamHint: blockedActiveTeamHint,
          onAdd: agent.hasActiveTeam || alreadyAdded
              ? null
              : () => onSelectAgent(agent),
        );
      },
    );
  }
}

class _AgentSearchEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _AgentSearchEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: DriverHomePalette.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: DriverHomePalette.primary, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DriverHomePalette.textDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DriverHomePalette.textSecondary,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlAgentResultTile extends StatelessWidget {
  final TeamAgent agent;
  final bool alreadyAdded;
  final VoidCallback? onAdd;
  final String Function(TeamAgent agent)? blockedActiveTeamHint;

  const _ControlAgentResultTile({
    required this.agent,
    required this.alreadyAdded,
    required this.onAdd,
    this.blockedActiveTeamHint,
  });

  @override
  Widget build(BuildContext context) {
    final blocked = agent.hasActiveTeam;
    String? reason;
    if (alreadyAdded) {
      reason = 'Déjà dans cette équipe';
    } else if (blocked) {
      reason =
          blockedActiveTeamHint?.call(agent) ??
          'Déjà affecté à ${agent.activeTeamName ?? 'une équipe active'}';
    }

    return Opacity(
      opacity: (blocked || alreadyAdded) ? 0.55 : 1,
      child: Material(
        color: DriverHomePalette.background,
        child: InkWell(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DriverHomePalette.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DriverHomePalette.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: DriverHomePalette.softGreen,
                  child: Text(
                    agent.initials,
                    style: const TextStyle(
                      color: DriverHomePalette.darkGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DriverHomePalette.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        reason ??
                            [
                              if (agent.driverNumber != null)
                                'Mat. ${agent.driverNumber}',
                              if (agent.depotName != null) agent.depotName!,
                            ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: (blocked || alreadyAdded)
                              ? DriverHomePalette.warning
                              : DriverHomePalette.textSecondary,
                          fontSize: 12.5,
                          fontWeight: (blocked || alreadyAdded)
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (onAdd != null)
                  IconButton(
                    onPressed: onAdd,
                    icon: const Icon(LucideIcons.plus),
                    color: DriverHomePalette.primary,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: DriverHomePalette.primary.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  )
                else
                  const Icon(
                    LucideIcons.lock,
                    size: 18,
                    color: DriverHomePalette.inactiveIcon,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
