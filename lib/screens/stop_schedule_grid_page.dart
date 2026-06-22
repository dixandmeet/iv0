import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/gtfs_service.dart';
import '../theme/app_fonts.dart';
import '../theme/aule_theme.dart';
import '../widgets/nearby_stops/line_badge.dart';
import '../widgets/schedule/schedule_grid.dart';

/// Grille horaire complète d'un arrêt (« fiche horaire » TAN) : sélection
/// ligne › direction › type de jour, puis tous les passages théoriques de la
/// journée groupés par heure. Le prochain passage est mis en évidence quand le
/// jour affiché est aujourd'hui.
class StopScheduleGridPage extends StatefulWidget {
  final NearbyStation station;
  final GtfsRoute? initialRoute;

  const StopScheduleGridPage({
    super.key,
    required this.station,
    this.initialRoute,
  });

  @override
  State<StopScheduleGridPage> createState() => _StopScheduleGridPageState();
}

class _StopScheduleGridPageState extends State<StopScheduleGridPage> {
  String? _routeId;
  int _dirIndex = 0;
  late String _dayType; // 'd' (Lun–Ven), 's' (Sam), 'u' (Dim/fériés)

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _routeId = widget.initialRoute?.routeId;
    _dayType = ScheduleDay.bucketOf(DateTime.now().weekday);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;
    final gtfs = context.watch<GtfsService>();

    final groups = gtfs.stationLineGroups(widget.station);

    return AuleTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: groups.isEmpty
              ? Column(
                  children: [
                    _Header(colors: c, stopName: widget.station.stop.stopName),
                    Expanded(
                      child: ScheduleEmpty(
                        colors: c,
                        title: 'Aucune ligne à cet arrêt',
                      ),
                    ),
                  ],
                )
              : _buildContent(gtfs, groups, c),
        ),
      ),
    );
  }

  Widget _buildContent(
      GtfsService gtfs, List<StationLineGroup> groups, AuleColors c) {
    // Ligne sélectionnée (défaut : première du groupe).
    final group = groups.firstWhere(
      (g) => g.route.routeId == _routeId,
      orElse: () => groups.first,
    );
    _routeId = group.route.routeId;

    final refDate = ScheduleDay.refDateFor(_dayType);

    // Sens groupés par quai (fiches complètes) ; repli sur l'ancien découpage
    // par terminus si l'index réel ne couvre pas ce couple.
    final scheds = gtfs.stopDirectionSchedules(
        group.route, widget.station.stop, day: refDate);
    final dirLabels = scheds.isNotEmpty
        ? [for (final s in scheds) s.label]
        : [for (final d in group.directions) d.headsign];
    final dirIndex =
        dirLabels.isEmpty ? 0 : _dirIndex.clamp(0, dirLabels.length - 1);
    final headsign = dirLabels.isEmpty ? '' : dirLabels[dirIndex];

    final List<DateTime> times = scheds.isNotEmpty
        ? [for (final p in scheds[dirIndex].passages) p.time]
        : gtfs.theoreticalDepartureTimes(
            group.route,
            widget.station.stop,
            direction: headsign,
            now: refDate,
            fullDay: true,
          );

    final isToday = _dayType == ScheduleDay.bucketOf(DateTime.now().weekday);
    final now = DateTime.now();
    DateTime? nextTime;
    if (isToday) {
      for (final t in times) {
        if (!t.isBefore(now)) {
          nextTime = t;
          break;
        }
      }
    }

    final grouped = groupTimesByHour(times);
    final hours = grouped.hours;
    final byHour = grouped.byHour;

    final lineColor =
        LineBadge.colorFor(group.route.routeShortName ?? group.route.routeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(colors: c, stopName: widget.station.stop.stopName),
        _LineSelector(
          groups: groups,
          selectedId: group.route.routeId,
          colors: c,
          onSelect: (id) => setState(() {
            _routeId = id;
            _dirIndex = 0;
          }),
        ),
        if (dirLabels.length > 1)
          ScheduleDirectionSelector(
            headsigns: dirLabels,
            selected: dirIndex,
            lineColor: lineColor,
            colors: c,
            onSelect: (i) => setState(() => _dirIndex = i),
          )
        else if (dirLabels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Icon(LucideIcons.arrowRight, size: 15, color: c.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    headsign,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hankenGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ScheduleDaySelector(
          selected: _dayType,
          colors: c,
          onSelect: (d) => setState(() => _dayType = d),
        ),
        const SizedBox(height: 4),
        if (hours.isNotEmpty)
          ScheduleHourRail(
            hours: hours,
            colors: c,
            highlightHour: nextTime?.hour,
            onTap: _scrollToHour,
          ),
        Expanded(
          child: times.isEmpty
              ? ScheduleEmpty(
                  colors: c,
                  title: 'Aucun passage ce jour',
                  subtitle: 'Essayez un autre jour ou une autre direction.',
                )
              : SingleChildScrollView(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final h in hours)
                        ScheduleHourBlock(
                          key: _hourKeys[h] ??= GlobalKey(),
                          hour: h,
                          times: byHour[h]!,
                          lineColor: lineColor,
                          nextTime: nextTime,
                          now: isToday ? now : null,
                          colors: c,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  final Map<int, GlobalKey> _hourKeys = {};

  void _scrollToHour(int hour) {
    final key = _hourKeys[hour];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
  }
}

class _Header extends StatelessWidget {
  final AuleColors colors;
  final String stopName;
  const _Header({required this.colors, required this.stopName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.line),
              ),
              child: Icon(LucideIcons.arrowLeft, size: 20, color: colors.text),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Horaires',
                  style: hankenGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: colors.text,
                  ),
                ),
                Text(
                  stopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: hankenGrotesk(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.muted,
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

class _LineSelector extends StatelessWidget {
  final List<StationLineGroup> groups;
  final String selectedId;
  final AuleColors colors;
  final ValueChanged<String> onSelect;

  const _LineSelector({
    required this.groups,
    required this.selectedId,
    required this.colors,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final route = groups[i].route;
          final code = route.routeShortName ?? route.routeId;
          final color = LineBadge.colorFor(code);
          final selected = route.routeId == selectedId;
          return GestureDetector(
            onTap: () => onSelect(route.routeId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? color : colors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selected ? color : color.withValues(alpha: 0.4),
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                code,
                style: hankenGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
