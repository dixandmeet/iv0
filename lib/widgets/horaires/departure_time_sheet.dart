import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_fonts.dart';
import '../../theme/aule_theme.dart';

/// Résultat du sélecteur d'heure. [value] null signifie « Maintenant »
/// (temps réel). Un résultat null retourné par le sheet = fermé sans choix.
class DepartureTimeChoice {
  final DateTime? value;
  const DepartureTimeChoice(this.value);
}

/// Ouvre le sélecteur « partir à » et renvoie le choix, ou null si annulé.
Future<DepartureTimeChoice?> showDepartureTimeSheet(
  BuildContext context, {
  required AuleColors colors,
  DateTime? current,
}) {
  return showModalBottomSheet<DepartureTimeChoice>(
    context: context,
    backgroundColor: colors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _DepartureTimeSheet(colors: colors, current: current),
  );
}

/// Étiquette compacte de l'heure de départ choisie (pour le bouton déclencheur).
String departureTimeLabel(DateTime? value) {
  if (value == null) return 'Maintenant';
  final now = DateTime.now();
  final isTomorrow = value.day != now.day || value.month != now.month;
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '${isTomorrow ? 'Demain' : "Aujourd'hui"} $hh:$mm';
}

class _DepartureTimeSheet extends StatefulWidget {
  final AuleColors colors;
  final DateTime? current;

  const _DepartureTimeSheet({required this.colors, this.current});

  @override
  State<_DepartureTimeSheet> createState() => _DepartureTimeSheetState();
}

class _DepartureTimeSheetState extends State<_DepartureTimeSheet> {
  late bool _tomorrow;

  // Heures de service présentées (matin tôt → nuit).
  static const _hours = [
    5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 0, 1
  ];

  @override
  void initState() {
    super.initState();
    final cur = widget.current;
    final now = DateTime.now();
    _tomorrow =
        cur != null && (cur.day != now.day || cur.month != now.month);
  }

  void _pickHour(int hour) {
    final base = DateTime.now();
    var day = DateTime(base.year, base.month, base.day);
    if (_tomorrow) day = day.add(const Duration(days: 1));
    Navigator.pop(
      context,
      DepartureTimeChoice(DateTime(day.year, day.month, day.day, hour)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final curHour = widget.current?.hour;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Partir à',
              style: hankenGrotesk(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 12),
            // « Maintenant » (temps réel).
            _NowTile(
              colors: c,
              selected: widget.current == null,
              onTap: () =>
                  Navigator.pop(context, const DepartureTimeChoice(null)),
            ),
            const SizedBox(height: 14),
            // Jour.
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  _dayBtn("Aujourd'hui", !_tomorrow,
                      () => setState(() => _tomorrow = false)),
                  _dayBtn('Demain', _tomorrow,
                      () => setState(() => _tomorrow = true)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'HEURE',
              style: hankenGrotesk(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: c.faint,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in _hours)
                  _HourChip(
                    colors: c,
                    hour: h,
                    selected: !_tomorrow && curHour == h,
                    onTap: () => _pickHour(h),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayBtn(String label, bool sel, VoidCallback onTap) {
    final c = widget.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? c.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: hankenGrotesk(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: sel ? Colors.white : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _NowTile extends StatelessWidget {
  final AuleColors colors;
  final bool selected;
  final VoidCallback onTap;

  const _NowTile({
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Material(
      color: selected ? c.brandWeak : c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: selected ? c.brandLine : c.line),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.zap,
                  size: 18, color: selected ? c.brand : c.muted),
              const SizedBox(width: 10),
              Text(
                'Maintenant',
                style: hankenGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? c.brand : c.text,
                ),
              ),
              const Spacer(),
              if (selected)
                Icon(LucideIcons.check, size: 18, color: c.brand),
            ],
          ),
        ),
      ),
    );
  }
}

class _HourChip extends StatelessWidget {
  final AuleColors colors;
  final int hour;
  final bool selected;
  final VoidCallback onTap;

  const _HourChip({
    required this.colors,
    required this.hour,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.brand : c.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? c.brand : c.line),
        ),
        child: Text(
          '${hour.toString().padLeft(2, '0')}h',
          style: hankenGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : c.text,
          ),
        ),
      ),
    );
  }
}
