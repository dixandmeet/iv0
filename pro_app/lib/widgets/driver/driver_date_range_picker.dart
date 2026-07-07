import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/driver_home_palette.dart';

const _weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Affiche un sélecteur de période aux couleurs de l'espace conducteur.
Future<DateTimeRange?> showDriverDateRangePicker({
  required BuildContext context,
  required DateTimeRange initialDateRange,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Période du plan',
  String confirmLabel = 'Valider',
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: DriverHomePalette.textDark.withValues(alpha: 0.35),
    builder: (ctx) => _DriverDateRangePickerSheet(
      initialDateRange: initialDateRange,
      firstDate: DateUtils.dateOnly(firstDate),
      lastDate: DateUtils.dateOnly(lastDate),
      title: title,
      confirmLabel: confirmLabel,
    ),
  );
}

class _DriverDateRangePickerSheet extends StatefulWidget {
  final DateTimeRange initialDateRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String confirmLabel;

  const _DriverDateRangePickerSheet({
    required this.initialDateRange,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.confirmLabel,
  });

  @override
  State<_DriverDateRangePickerSheet> createState() =>
      _DriverDateRangePickerSheetState();
}

class _DriverDateRangePickerSheetState
    extends State<_DriverDateRangePickerSheet> {
  late DateTime _start;
  DateTime? _end;
  late final ScrollController _monthScrollController;
  late final List<DateTime> _months;

  @override
  void initState() {
    super.initState();
    _start = DateUtils.dateOnly(widget.initialDateRange.start);
    _end = DateUtils.dateOnly(widget.initialDateRange.end);
    _months = _buildMonthList();
    _monthScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInitialMonth());
  }

  @override
  void dispose() {
    _monthScrollController.dispose();
    super.dispose();
  }

  List<DateTime> _buildMonthList() {
    final months = <DateTime>[];
    var cursor = DateTime(widget.firstDate.year, widget.firstDate.month);
    final last = DateTime(widget.lastDate.year, widget.lastDate.month);
    while (!cursor.isAfter(last)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return months;
  }

  void _scrollToInitialMonth() {
    if (!_monthScrollController.hasClients) return;
    final index = _months.indexWhere(
      (month) =>
          month.year == _start.year && month.month == _start.month,
    );
    if (index <= 0) return;
    const monthExtent = 312.0;
    final offset = (index * monthExtent).clamp(
      0.0,
      _monthScrollController.position.maxScrollExtent,
    );
    _monthScrollController.jumpTo(offset);
  }

  bool get _singleDay =>
      _end != null && DateUtils.isSameDay(_start, _end!);

  int get _durationDays {
    final end = _end ?? _start;
    return end.difference(_start).inDays + 1;
  }

  String _formatRangeHeader() {
    final end = _end ?? _start;
    if (DateUtils.isSameDay(_start, end)) {
      return _capitalize(DateFormat('d MMMM yyyy', 'fr_FR').format(_start));
    }
    final sameYear = _start.year == end.year;
    final sameMonth = sameYear && _start.month == end.month;
    if (sameMonth) {
      return '${_start.day} – ${end.day} '
          '${DateFormat('MMMM yyyy', 'fr_FR').format(_start)}';
    }
    if (sameYear) {
      return '${DateFormat('d MMM', 'fr_FR').format(_start)} – '
          '${DateFormat('d MMM yyyy', 'fr_FR').format(end)}';
    }
    return '${DateFormat('d MMM yyyy', 'fr_FR').format(_start)} – '
        '${DateFormat('d MMM yyyy', 'fr_FR').format(end)}';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  void _onDayTap(DateTime day) {
    if (day.isBefore(widget.firstDate) || day.isAfter(widget.lastDate)) {
      return;
    }
    setState(() {
      if (_end != null) {
        _start = day;
        _end = null;
        return;
      }
      if (day.isBefore(_start)) {
        _end = _start;
        _start = day;
        return;
      }
      _end = day;
    });
  }

  void _confirm() {
    final end = _end ?? _start;
    Navigator.of(context).pop(DateTimeRange(start: _start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
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
                        LucideIcons.calendarDays,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _capitalize(_formatRangeHeader()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _HeaderChip(
                            icon: LucideIcons.calendar,
                            label: _singleDay
                                ? 'Une journée'
                                : '$_durationDays jours',
                          ),
                          if (_end == null) ...[
                            const SizedBox(width: 8),
                            _HeaderChip(
                              icon: LucideIcons.mousePointerClick,
                              label: 'Choisir la fin',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: _weekdayLabels
                      .map(
                        (label) => Expanded(
                          child: Center(
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: DriverHomePalette.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: DriverHomePalette.border),
              Flexible(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: DriverHomePalette.background,
                  ),
                  child: ListView.builder(
                    controller: _monthScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: _months.length,
                    itemBuilder: (context, index) => _MonthGrid(
                      month: _months[index],
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      start: _start,
                      end: _end,
                      onDayTap: _onDayTap,
                    ),
                  ),
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
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime start;
  final DateTime? end;
  final ValueChanged<DateTime> onDayTap;

  const _MonthGrid({
    required this.month,
    required this.firstDate,
    required this.lastDate,
    required this.start,
    required this.end,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR').format(month);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday =
        DateTime(month.year, month.month, 1).weekday; // 1 = Mon
    final leadingBlanks = firstWeekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Text(
              _capitalize(monthLabel),
              style: const TextStyle(
                color: DriverHomePalette.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (var row = 0; row < rowCount; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _buildDayCell(
                      row: row,
                      col: col,
                      leadingBlanks: leadingBlanks,
                      daysInMonth: daysInMonth,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDayCell({
    required int row,
    required int col,
    required int leadingBlanks,
    required int daysInMonth,
  }) {
    final cellIndex = row * 7 + col;
    if (cellIndex < leadingBlanks || cellIndex >= leadingBlanks + daysInMonth) {
      return const SizedBox(height: 44);
    }
    final day = cellIndex - leadingBlanks + 1;
    final date = DateUtils.dateOnly(DateTime(month.year, month.month, day));
    final enabled = !date.isBefore(firstDate) && !date.isAfter(lastDate);
    final effectiveEnd = end ?? start;
    final isStart = DateUtils.isSameDay(date, start);
    final isEnd = DateUtils.isSameDay(date, effectiveEnd);
    final inRange = !date.isBefore(start) && !date.isAfter(effectiveEnd);
    final isToday = DateUtils.isSameDay(date, DateTime.now());

    return _DayCell(
      day: day,
      enabled: enabled,
      isStart: isStart,
      isEnd: isEnd,
      inRange: inRange && !isStart && !isEnd,
      isToday: isToday,
      onTap: enabled ? () => onDayTap(date) : null,
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool enabled;
  final bool isStart;
  final bool isEnd;
  final bool inRange;
  final bool isToday;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.enabled,
    required this.isStart,
    required this.isEnd,
    required this.inRange,
    required this.isToday,
    required this.onTap,
  });

  bool get _isEndpoint => isStart || isEnd;
  bool get _showRangeBar => inRange && !(isStart && isEnd);

  @override
  Widget build(BuildContext context) {
    final textColor = !enabled
        ? DriverHomePalette.inactiveIcon.withValues(alpha: 0.45)
        : _isEndpoint
            ? Colors.white
            : inRange
                ? DriverHomePalette.primary
                : DriverHomePalette.textDark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_showRangeBar)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isStart ? 22 : 0,
                    right: isEnd ? 22 : 0,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DriverHomePalette.lightGreen,
                      borderRadius: BorderRadius.horizontal(
                        left: isStart
                            ? const Radius.circular(22)
                            : Radius.zero,
                        right:
                            isEnd ? const Radius.circular(22) : Radius.zero,
                      ),
                    ),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _isEndpoint
                    ? DriverHomePalette.primary
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !_isEndpoint
                    ? Border.all(
                        color: DriverHomePalette.primary.withValues(alpha: 0.55),
                        width: 1.5,
                      )
                    : null,
                boxShadow: _isEndpoint
                    ? [
                        BoxShadow(
                          color: DriverHomePalette.primary
                              .withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14.5,
                  fontWeight:
                      _isEndpoint || isToday ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formate une période de mission pour l'affichage dans les formulaires.
String formatMissionPeriodLabel({
  required DateTime start,
  required DateTime end,
}) {
  final singleDay = DateUtils.isSameDay(start, end);
  if (singleDay) {
    final label = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(start);
    return _capitalizePeriodLabel(label);
  }
  final sameYear = start.year == end.year;
  if (sameYear && start.month == end.month) {
    final monthYear = DateFormat('MMMM yyyy', 'fr_FR').format(start);
    return 'Du ${start.day} au ${end.day} ${_capitalizePeriodLabel(monthYear)}';
  }
  if (sameYear) {
    return 'Du ${DateFormat('d MMM', 'fr_FR').format(start)} au '
        '${DateFormat('d MMM yyyy', 'fr_FR').format(end)}';
  }
  return 'Du ${DateFormat('d MMM yyyy', 'fr_FR').format(start)} au '
      '${DateFormat('d MMM yyyy', 'fr_FR').format(end)}';
}

String missionPeriodDurationLabel({
  required DateTime start,
  required DateTime end,
}) {
  final days = end.difference(start).inDays + 1;
  return days == 1 ? '1 jour' : '$days jours';
}

String _capitalizePeriodLabel(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
