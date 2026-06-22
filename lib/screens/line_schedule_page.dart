import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/aule_data_adapter.dart';
import '../services/favorites_service.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/app_fonts.dart';
import '../theme/aule_theme.dart';
import '../widgets/schedule/schedule_grid.dart';

/// Direction d'une ligne : terminus visé + arrêts ordonnés le long du tracé.
typedef _LineDirection = ({String headsign, List<GtfsStop> stops});

/// Fiche horaire d'une ligne, indépendante d'un arrêt : on choisit
/// direction › arrêt › type de jour, puis la grille des passages théoriques.
/// Comble l'absence d'entrée « par ligne » (avant, il fallait passer par un
/// arrêt). Réutilise les composants partagés de [schedule_grid.dart].
class LineSchedulePage extends StatefulWidget {
  final GtfsRoute route;
  final String? initialHeadsign;
  final GtfsStop? initialStop;

  const LineSchedulePage({
    super.key,
    required this.route,
    this.initialHeadsign,
    this.initialStop,
  });

  @override
  State<LineSchedulePage> createState() => _LineSchedulePageState();
}

class _LineSchedulePageState extends State<LineSchedulePage> {
  int _dirIndex = 0;
  String? _stopId;
  late String _dayType;

  final ScrollController _scrollCtrl = ScrollController();
  final Map<int, GlobalKey> _hourKeys = {};

  List<_LineDirection>? _directions;

  @override
  void initState() {
    super.initState();
    _dayType = ScheduleDay.bucketOf(DateTime.now().weekday);
    _stopId = widget.initialStop?.stopId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveDirections());
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  LatLng? get _userPos {
    final pos = context.read<LocationService>().currentPosition;
    return pos == null ? null : LatLng(pos.latitude, pos.longitude);
  }

  /// Construit les directions de la ligne à partir des tracés (extrémités =
  /// terminus), avec repli sur un arrêt représentatif si les tracés manquent.
  void _resolveDirections() {
    final gtfs = context.read<GtfsService>();
    final route = widget.route;
    final dirs = <_LineDirection>[];
    final seenTerminus = <String>{};

    void addToward(String headsign) {
      if (headsign.isEmpty) return;
      final stops = gtfs.stopsToward(route, headsign);
      if (stops.length < 2) return;
      if (!seenTerminus.add(stops.last.stopId)) return;
      dirs.add((headsign: stops.last.stopName, stops: stops));
    }

    // Tracé le plus long → ses deux extrémités donnent les deux sens.
    final base = gtfs.stopsToward(route, '');
    if (base.length >= 2) {
      addToward(base.last.stopName);
      addToward(base.first.stopName);
    }

    // Repli : directions réelles vues depuis un arrêt représentatif.
    if (dirs.isEmpty) {
      final rep = gtfs.representativeDeparture(route, from: _userPos);
      if (rep != null) {
        for (final g in gtfs.stationLineGroups(rep.station)) {
          if (g.route.routeId != route.routeId) continue;
          for (final d in g.directions) {
            final stops = gtfs.stopsToward(route, d.headsign);
            dirs.add((
              headsign: stops.length >= 2 ? stops.last.stopName : d.headsign,
              stops: stops,
            ));
          }
        }
      }
    }

    // Position initiale : direction demandée, sinon première.
    var dirIndex = 0;
    final wanted = widget.initialHeadsign;
    if (wanted != null && dirs.isNotEmpty) {
      final idx = dirs.indexWhere(
          (d) => d.headsign.toLowerCase() == wanted.toLowerCase());
      if (idx >= 0) dirIndex = idx;
    }

    if (mounted) {
      setState(() {
        _directions = dirs;
        _dirIndex = dirIndex;
      });
    }
  }

  /// Arrêt sélectionné dans la direction courante (défaut : le plus proche de
  /// l'utilisateur, sinon le terminus d'origine — départs les plus complets).
  GtfsStop _selectedStop(_LineDirection dir) {
    final byId = dir.stops.where((s) => s.stopId == _stopId);
    if (byId.isNotEmpty) return byId.first;

    final user = _userPos;
    if (user != null) {
      const distance = Distance();
      GtfsStop best = dir.stops.first;
      var bestD = double.infinity;
      for (final s in dir.stops) {
        final d = distance.as(LengthUnit.Meter, user, s.position);
        if (d < bestD) {
          bestD = d;
          best = s;
        }
      }
      return best;
    }
    return dir.stops.first;
  }

  static Set<String> _tokens(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.length > 2)
      .toSet();

  /// Associe le sens choisi (terminus visé) à la fiche horaire de quai dont le
  /// libellé partage le plus de mots. Repli : la fiche la plus desservie.
  StopDirectionSchedule? _matchSchedule(
      List<StopDirectionSchedule> scheds, String terminusName) {
    if (scheds.isEmpty) return null;
    if (scheds.length == 1) return scheds.first;
    final target = _tokens(terminusName);
    StopDirectionSchedule? best;
    var bestScore = -1;
    for (final s in scheds) {
      final score = _tokens(s.label).where(target.contains).length;
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return best;
  }

  void _scrollToHour(int hour) {
    final ctx = _hourKeys[hour]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;
    final gtfs = context.watch<GtfsService>();
    final favorites = context.watch<FavoritesService>();

    final route = widget.route;
    final lineColor =
        AuleDataAdapter.routeColor(route) ?? const Color(0xFF16A34A);
    final code = AuleDataAdapter.lineCode(route);

    final dirs = _directions;

    return AuleTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                colors: c,
                code: code,
                lineColor: lineColor,
                modeLabel: AuleDataAdapter.modeLabel(route.transportType),
                terminus: AuleDataAdapter.terminusLabel(route),
                isFavorite: favorites.isFavoriteLine(route.routeId),
                onToggleFavorite: () => favorites.toggleLine(route.routeId),
              ),
              if (dirs == null)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (dirs.isEmpty)
                Expanded(
                  child: ScheduleEmpty(
                    colors: c,
                    title: 'Horaires indisponibles',
                    subtitle:
                        'Aucun tracé exploitable pour cette ligne.',
                  ),
                )
              else
                Expanded(child: _buildBody(gtfs, dirs, lineColor, c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    GtfsService gtfs,
    List<_LineDirection> dirs,
    Color lineColor,
    AuleColors c,
  ) {
    final dirIndex = _dirIndex.clamp(0, dirs.length - 1);
    final dir = dirs[dirIndex];
    final stop = _selectedStop(dir);

    final refDate = ScheduleDay.refDateFor(_dayType);

    // Fiche horaire groupée par sens (quai) : complète et cohérente. On choisit
    // le sens correspondant au terminus visé, avec repli sur les horaires
    // théoriques bruts si l'index réel ne couvre pas ce couple.
    final scheds = gtfs.stopDirectionSchedules(widget.route, stop, day: refDate);
    final matched = _matchSchedule(scheds, dir.headsign);
    final List<DateTime> times = matched != null
        ? [for (final p in matched.passages) p.time]
        : gtfs.theoreticalDepartureTimes(
            widget.route,
            stop,
            direction: dir.headsign,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dirs.length > 1) ...[
          const SizedBox(height: 2),
          ScheduleDirectionSelector(
            headsigns: [for (final d in dirs) d.headsign],
            selected: dirIndex,
            lineColor: lineColor,
            colors: c,
            onSelect: (i) => setState(() {
              _dirIndex = i;
              _stopId = null; // ré-ancre sur l'arrêt par défaut du nouveau sens
            }),
          ),
        ],
        _StopPicker(
          colors: c,
          lineColor: lineColor,
          stop: stop,
          stops: dir.stops,
          onSelect: (s) => setState(() => _stopId = s.stopId),
        ),
        ScheduleDaySelector(
          selected: _dayType,
          colors: c,
          onSelect: (d) => setState(() => _dayType = d),
        ),
        const SizedBox(height: 4),
        if (grouped.hours.isNotEmpty)
          ScheduleHourRail(
            hours: grouped.hours,
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
                      for (final h in grouped.hours)
                        ScheduleHourBlock(
                          key: _hourKeys[h] ??= GlobalKey(),
                          hour: h,
                          times: grouped.byHour[h]!,
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
}

class _Header extends StatelessWidget {
  final AuleColors colors;
  final String code;
  final Color lineColor;
  final String modeLabel;
  final String terminus;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _Header({
    required this.colors,
    required this.code,
    required this.lineColor,
    required this.modeLabel,
    required this.terminus,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
          Container(
            constraints: const BoxConstraints(minWidth: 46),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: lineColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              code,
              style: hankenGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modeLabel,
                  style: hankenGrotesk(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: lineColor,
                  ),
                ),
                Text(
                  terminus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: isFavorite
                ? 'Retirer la ligne des favoris'
                : 'Ajouter la ligne aux favoris',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleFavorite,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.line),
                ),
                child: Icon(
                  LucideIcons.star,
                  size: 20,
                  color: isFavorite
                      ? const Color(0xFFF59E0B)
                      : colors.muted,
                  fill: isFavorite ? 1.0 : 0.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton « arrêt courant » qui ouvre un sélecteur d'arrêt (bottom sheet).
class _StopPicker extends StatelessWidget {
  final AuleColors colors;
  final Color lineColor;
  final GtfsStop stop;
  final List<GtfsStop> stops;
  final ValueChanged<GtfsStop> onSelect;

  const _StopPicker({
    required this.colors,
    required this.lineColor,
    required this.stop,
    required this.stops,
    required this.onSelect,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<GtfsStop>(
      context: context,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _StopSheet(
        colors: colors,
        lineColor: lineColor,
        stops: stops,
        selectedId: stop.stopId,
      ),
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.line),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.mapPin, size: 18, color: lineColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arrêt',
                        style: hankenGrotesk(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: colors.faint,
                        ),
                      ),
                      Text(
                        stop.stopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hankenGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronsUpDown, size: 18, color: colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StopSheet extends StatelessWidget {
  final AuleColors colors;
  final Color lineColor;
  final List<GtfsStop> stops;
  final String selectedId;

  const _StopSheet({
    required this.colors,
    required this.lineColor,
    required this.stops,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.7;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choisir un arrêt',
                  style: hankenGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: stops.length,
                itemBuilder: (_, i) {
                  final s = stops[i];
                  final sel = s.stopId == selectedId;
                  final isTerminus = i == 0 || i == stops.length - 1;
                  return InkWell(
                    onTap: () => Navigator.pop(context, s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            isTerminus
                                ? LucideIcons.flag
                                : LucideIcons.dot,
                            size: isTerminus ? 15 : 22,
                            color: sel ? lineColor : colors.faint,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.stopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: hankenGrotesk(
                                fontSize: 14.5,
                                fontWeight:
                                    sel ? FontWeight.w800 : FontWeight.w600,
                                color: sel ? lineColor : colors.text,
                              ),
                            ),
                          ),
                          if (sel)
                            Icon(LucideIcons.check, size: 18, color: lineColor),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
