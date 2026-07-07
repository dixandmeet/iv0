import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/driver/control_team.dart';
import '../../theme/driver_home_palette.dart';

const _timePickerItemExtent = 48.0;

/// Affiche un sélecteur d'heure aux couleurs de l'espace conducteur.
Future<TimeOfDay?> showDriverTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = 'Choisir une heure',
  String confirmLabel = 'Valider',
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: DriverHomePalette.textDark.withValues(alpha: 0.35),
    builder: (ctx) => _DriverTimePickerSheet(
      initialTime: initialTime,
      title: title,
      confirmLabel: confirmLabel,
    ),
  );
}

class _DriverTimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;
  final String confirmLabel;

  const _DriverTimePickerSheet({
    required this.initialTime,
    required this.title,
    required this.confirmLabel,
  });

  @override
  State<_DriverTimePickerSheet> createState() => _DriverTimePickerSheetState();
}

class _DriverTimePickerSheetState extends State<_DriverTimePickerSheet> {
  late int _hour;
  late int _minute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  TimeOfDay get _selected => TimeOfDay(hour: _hour, minute: _minute);

  void _confirm() => Navigator.of(context).pop(_selected);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: DriverHomePalette.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: DriverHomePalette.cardShadow,
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DriverHomePalette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: DriverHomePalette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.clock,
                      size: 20,
                      color: DriverHomePalette.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: DriverHomePalette.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: 20),
                    color: DriverHomePalette.textSecondary,
                    style: IconButton.styleFrom(
                      backgroundColor: DriverHomePalette.background,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      DriverHomePalette.gradientStart,
                      DriverHomePalette.gradientEnd,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: DriverHomePalette.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      formatTimeLabel(_selected),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Format 24 h',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _timePickerItemExtent * 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: _timePickerItemExtent,
                      decoration: BoxDecoration(
                        color: DriverHomePalette.lightGreen,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: DriverHomePalette.primary.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeWheel(
                          label: 'Heures',
                          controller: _hourController,
                          itemCount: 24,
                          selectedIndex: _hour,
                          onSelected: (index) => setState(() => _hour = index),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          ':',
                          style: TextStyle(
                            color: DriverHomePalette.primary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _TimeWheel(
                          label: 'Minutes',
                          controller: _minuteController,
                          itemCount: 60,
                          selectedIndex: _minute,
                          onSelected: (index) => setState(() => _minute = index),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DriverHomePalette.textDark,
                        side: const BorderSide(color: DriverHomePalette.border),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: DriverHomePalette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        widget.confirmLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeWheel extends StatelessWidget {
  final String label;
  final FixedExtentScrollController controller;
  final int itemCount;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _TimeWheel({
    required this.label,
    required this.controller,
    required this.itemCount,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: DriverHomePalette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: _timePickerItemExtent,
            perspective: 0.002,
            diameterRatio: 1.35,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onSelected,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, index) {
                final selected = index == selectedIndex;
                return AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 120),
                  style: TextStyle(
                    color: selected
                        ? DriverHomePalette.primary
                        : DriverHomePalette.textSecondary.withValues(
                            alpha: selected ? 1 : 0.55,
                          ),
                    fontSize: selected ? 24 : 18,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                  child: Text(index.toString().padLeft(2, '0')),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
