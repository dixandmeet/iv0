import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_fonts.dart';
import '../../theme/aule_theme.dart';

/// Composants partagés de « fiche horaire » (grille des passages théoriques),
/// utilisés par la fiche arrêt (StopScheduleGridPage) ET la fiche ligne
/// (LineSchedulePage). Centralise le rendu pour éviter la divergence.

/// Buckets de type de jour : 'd' (Lun–Ven), 's' (Sam), 'u' (Dim/fériés).
class ScheduleDay {
  ScheduleDay._();

  static String bucketOf(int weekday) =>
      weekday <= 5 ? 'd' : (weekday == 6 ? 's' : 'u');

  /// Prochaine date (aujourd'hui compris) dont le type de jour correspond au
  /// [bucket] : affiche la bonne grille et permet de surligner le prochain
  /// passage quand c'est aujourd'hui.
  static DateTime refDateFor(String bucket) {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 7; i++) {
      if (bucketOf(d.weekday) == bucket) return d;
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  static const options = [
    ('d', 'Lun–Ven'),
    ('s', 'Sam'),
    ('u', 'Dim'),
  ];
}

/// Sélecteur de type de jour (segmented control).
class ScheduleDaySelector extends StatelessWidget {
  final String selected;
  final AuleColors colors;
  final ValueChanged<String> onSelect;

  const ScheduleDaySelector({
    super.key,
    required this.selected,
    required this.colors,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          children: [
            for (final o in ScheduleDay.options)
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(o.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          selected == o.$1 ? colors.brand : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      o.$2,
                      style: hankenGrotesk(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: selected == o.$1 ? Colors.white : colors.muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sélecteur de direction (terminus) défilable.
class ScheduleDirectionSelector extends StatelessWidget {
  final List<String> headsigns;
  final int selected;
  final Color lineColor;
  final AuleColors colors;
  final ValueChanged<int> onSelect;

  const ScheduleDirectionSelector({
    super.key,
    required this.headsigns,
    required this.selected,
    required this.lineColor,
    required this.colors,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        itemCount: headsigns.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isSel = i == selected;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    isSel ? lineColor.withValues(alpha: 0.14) : colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSel ? lineColor : colors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.arrowRight,
                      size: 14, color: isSel ? lineColor : colors.muted),
                  const SizedBox(width: 6),
                  Text(
                    headsigns[i],
                    style: hankenGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSel ? lineColor : colors.muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Rail des heures (saut rapide vers un bloc horaire).
class ScheduleHourRail extends StatelessWidget {
  final List<int> hours;
  final AuleColors colors;
  final ValueChanged<int> onTap;

  /// Heure mise en avant (ex. heure du prochain passage / « partir à »).
  final int? highlightHour;

  const ScheduleHourRail({
    super.key,
    required this.hours,
    required this.colors,
    required this.onTap,
    this.highlightHour,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: hours.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final h = hours[i];
          final hot = h == highlightHour;
          return GestureDetector(
            onTap: () => onTap(h),
            child: Container(
              width: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hot ? colors.brand : colors.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: hot ? colors.brand : colors.line),
              ),
              child: Text(
                h.toString().padLeft(2, '0'),
                style: hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: hot ? Colors.white : colors.text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bloc d'une heure : libellé heure + chips de minutes.
class ScheduleHourBlock extends StatelessWidget {
  final int hour;
  final List<DateTime> times;
  final Color lineColor;
  final DateTime? nextTime;
  final DateTime? now;
  final AuleColors colors;

  const ScheduleHourBlock({
    super.key,
    required this.hour,
    required this.times,
    required this.lineColor,
    required this.nextTime,
    required this.now,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lineColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${hour.toString().padLeft(2, '0')}h',
              style: hankenGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: lineColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final t in times) _minuteChip(t),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _minuteChip(DateTime t) {
    final isNext = nextTime != null && t.isAtSameMomentAs(nextTime!);
    final isPast = now != null && t.isBefore(now!);

    final Color bg;
    final Color fg;
    if (isNext) {
      bg = lineColor;
      fg = Colors.white;
    } else if (isPast) {
      bg = colors.surface;
      fg = colors.faint;
    } else {
      bg = colors.surface;
      fg = colors.text;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isNext ? lineColor : colors.line,
        ),
      ),
      child: Text(
        t.minute.toString().padLeft(2, '0'),
        style: hankenGrotesk(
          fontSize: 14,
          fontWeight: isNext ? FontWeight.w800 : FontWeight.w700,
          color: fg,
          decoration: isPast ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

/// État vide d'une grille horaire.
class ScheduleEmpty extends StatelessWidget {
  final AuleColors colors;
  final String title;
  final String? subtitle;

  const ScheduleEmpty({
    super.key,
    required this.colors,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendarOff, size: 40, color: colors.faint),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: hankenGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Regroupe une liste de passages par heure, en ordre « service » (la nuit,
/// après minuit, vient après 23h). Retourne (heures triées, map heure→passages).
({List<int> hours, Map<int, List<DateTime>> byHour}) groupTimesByHour(
    List<DateTime> times) {
  final byHour = <int, List<DateTime>>{};
  for (final t in times) {
    byHour.putIfAbsent(t.hour, () => []).add(t);
  }
  int orderKey(int h) => h < 4 ? h + 24 : h;
  final hours = byHour.keys.toList()
    ..sort((a, b) => orderKey(a).compareTo(orderKey(b)));
  for (final list in byHour.values) {
    list.sort();
  }
  return (hours: hours, byHour: byHour);
}
