import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/gtfs_service.dart';

/// Liste des horaires théoriques groupés par heure.
class TheoreticalScheduleList extends StatelessWidget {
  final List<DateTime> times;
  final Color lineColor;
  final int headwayMinutes;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry padding;
  final DateTime? now;

  const TheoreticalScheduleList({
    super.key,
    required this.times,
    required this.lineColor,
    required this.headwayMinutes,
    this.scrollController,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    this.now,
  });

  Map<int, List<DateTime>> _groupByHour() {
    final grouped = <int, List<DateTime>>{};
    for (final time in times) {
      grouped.putIfAbsent(time.hour, () => []).add(time);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedText =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);
    final ref = now ?? DateTime.now();
    final cutoff =
        DateTime(ref.year, ref.month, ref.day, ref.hour, ref.minute);
    final nextDeparture = GtfsService.nextTheoreticalDeparture(times, now: ref);
    final timeFmt = DateFormat('HH:mm');
    final grouped = _groupByHour();
    final hours = grouped.keys.toList()..sort();

    if (times.isEmpty) {
      return Center(
        child: Text(
          'Aucun horaire disponible pour cette direction.',
          style: hankenGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: mutedText,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: padding,
      itemCount: hours.length,
      itemBuilder: (context, i) {
        final hour = hours[i];
        final hourTimes = grouped[hour]!;
        return Padding(
          padding: EdgeInsets.only(bottom: i == hours.length - 1 ? 0 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${hour.toString().padLeft(2, '0')}h',
                style: hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final time in hourTimes)
                    _TimeChip(
                      label: timeFmt.format(time),
                      isNext: time == nextDeparture,
                      isPast: time.isBefore(cutoff),
                      lineColor: lineColor,
                      primaryText: primaryText,
                      mutedText: mutedText,
                      borderCol: borderCol,
                      isDark: isDark,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bandeau d'information sur le cadencement théorique.
class TheoreticalScheduleInfoBanner extends StatelessWidget {
  final int headwayMinutes;

  const TheoreticalScheduleInfoBanner({
    super.key,
    required this.headwayMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedText =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B232F) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.info, size: 14, color: mutedText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cadencement estimé toutes les $headwayMinutes min. '
                'Horaires indicatifs, sans données GTFS officielles.',
                style: hankenGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: mutedText,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool isNext;
  final bool isPast;
  final Color lineColor;
  final Color primaryText;
  final Color mutedText;
  final Color borderCol;
  final bool isDark;

  const _TimeChip({
    required this.label,
    required this.isNext,
    required this.isPast,
    required this.lineColor,
    required this.primaryText,
    required this.mutedText,
    required this.borderCol,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isPast
        ? mutedText.withValues(alpha: 0.55)
        : (isNext ? lineColor : primaryText);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isNext
            ? lineColor.withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark ? const Color(0xFF1B232F) : const Color(0xFFF8F9FB)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNext ? lineColor.withValues(alpha: 0.5) : borderCol,
          width: isNext ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textColor,
              decoration: isPast ? TextDecoration.lineThrough : null,
              decorationColor: mutedText.withValues(alpha: 0.45),
            ),
          ),
          if (isNext)
            Text(
              'Prochain',
              style: hankenGrotesk(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: lineColor,
              ),
            ),
        ],
      ),
    );
  }
}
