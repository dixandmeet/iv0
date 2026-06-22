import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/aule_data_adapter.dart';
import '../services/favorites_service.dart';
import '../services/gtfs_service.dart';
import '../services/home_aggregator.dart';
import '../services/location_service.dart';
import '../theme/app_fonts.dart';
import '../theme/aule_theme.dart';
import '../widgets/horaires/departure_time_sheet.dart';
import '../widgets/horaires/line_directory_row.dart';
import '../widgets/horaires/segmented_tabs.dart';
import '../widgets/live_dot.dart';
import '../widgets/nearby_stops/search_section.dart';
import '../widgets/nearby_stops/tab_page_header.dart';
import '../widgets/stop_detail/stop_filter_chips.dart';
import 'line_schedule_page.dart';
import 'station_search_screen.dart';
import 'stop_detail_page.dart';

// Codes couleur d'attente, partagés par toute la page (cohérents avec la
// fiche arrêt) : rouge « à l'approche », orange imminent, vert confortable.
const _waitRed = Color(0xFFEF4444);
const _waitOrange = Color(0xFFF59E0B);
const _waitGreen = Color(0xFF22C55E);

/// Couleur + libellé d'un temps d'attente (minutes).
({Color color, String label, bool imminent}) _waitDisplay(int minutes) {
  if (minutes < 1) {
    return (color: _waitRed, label: "À l'approche", imminent: true);
  }
  final color = minutes < 5 ? _waitOrange : _waitGreen;
  return (color: color, label: '$minutes min', imminent: false);
}

Color _lineColor(GtfsRoute route) =>
    AuleDataAdapter.routeColor(route) ?? const Color(0xFF6B7280);

/// Hub Horaires — deux sous-vues : « Autour de moi » (temps réel des arrêts
/// proches + favoris, avec sélecteur « partir à ») et « Lignes » (annuaire de
/// tout le réseau menant à la fiche horaire d'une ligne).
class HorairesPage extends StatefulWidget {
  const HorairesPage({super.key});

  @override
  State<HorairesPage> createState() => _HorairesPageState();
}

class _HorairesPageState extends State<HorairesPage> {
  Timer? _ticker;
  bool _isLocating = false;
  int _tab = 0; // 0 = autour de moi, 1 = lignes
  StopFilter _filter = StopFilter.all;

  /// Heure de référence des passages. null = temps réel (« Maintenant »).
  DateTime? _departAt;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLocation());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _ensureLocation() async {
    final location = context.read<LocationService>();
    if (location.currentPosition != null) return;
    await location.requestForegroundPermission();
  }

  Future<void> _locateNearby() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final location = context.read<LocationService>();
      await location.requestForegroundPermission();
      await location.updateCurrentPosition();
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const StationSearchScreen()),
    );
  }

  void _openStopDetail(NearbyStation station, {required bool hasDistance}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StopDetailPage(station: station, showDistance: hasDistance),
      ),
    );
  }

  void _openLineSchedule(GtfsRoute route) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LineSchedulePage(route: route)),
    );
  }

  Future<void> _pickDepartureTime(AuleColors c) async {
    final res = await showDepartureTimeSheet(context, colors: c, current: _departAt);
    if (res != null && mounted) setState(() => _departAt = res.value);
  }

  bool _matchesMode(StationLineGroup g) {
    switch (_filter) {
      case StopFilter.tram:
        return g.route.transportType == 'tram';
      case StopFilter.bus:
        return g.route.transportType != 'tram';
      case StopFilter.all:
      case StopFilter.favorites:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;

    final location = context.watch<LocationService>();
    context.watch<GtfsService>();
    context.watch<FavoritesService>();

    final pos = location.currentPosition;
    final LatLng? userPos =
        pos != null ? LatLng(pos.latitude, pos.longitude) : null;

    return AuleTheme(
      colors: c,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabPageHeader(
              title: 'Horaires',
              subtitle: _tab == 0
                  ? (userPos != null
                      ? 'Prochains passages autour de vous'
                      : 'Prochains passages à proximité')
                  : 'Toutes les lignes du réseau',
            ),
            SearchSection(
              onSearchTap: _openSearch,
              onLocateTap: _isLocating ? null : _locateNearby,
              hintText: 'Rechercher un arrêt ou une ligne…',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedTabs(
                colors: c,
                selected: _tab,
                onSelected: (i) => setState(() => _tab = i),
                tabs: const [
                  (icon: LucideIcons.locateFixed, label: 'Autour de moi'),
                  (icon: LucideIcons.list, label: 'Lignes'),
                ],
              ),
            ),
            Expanded(
              child: _tab == 0
                  ? _NearbyView(
                      colors: c,
                      userPos: userPos,
                      filter: _filter,
                      onFilter: (f) => setState(() => _filter = f),
                      matchesMode: _matchesMode,
                      departAt: _departAt,
                      onPickTime: () => _pickDepartureTime(c),
                      onOpenStop: _openStopDetail,
                      onOpenLine: _openLineSchedule,
                    )
                  : _LinesView(
                      colors: c,
                      onOpenLine: _openLineSchedule,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Autour de moi ──────────────────────────────

typedef _StationEntry = ({NearbyStation station, List<StationLineGroup> groups});

class _NearbyView extends StatelessWidget {
  final AuleColors colors;
  final LatLng? userPos;
  final StopFilter filter;
  final ValueChanged<StopFilter> onFilter;
  final bool Function(StationLineGroup) matchesMode;
  final DateTime? departAt;
  final VoidCallback onPickTime;
  final void Function(NearbyStation, {required bool hasDistance}) onOpenStop;
  final void Function(GtfsRoute) onOpenLine;

  const _NearbyView({
    required this.colors,
    required this.userPos,
    required this.filter,
    required this.onFilter,
    required this.matchesMode,
    required this.departAt,
    required this.onPickTime,
    required this.onOpenStop,
    required this.onOpenLine,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final gtfs = context.watch<GtfsService>();
    final favorites = context.watch<FavoritesService>();
    final planning = departAt != null;
    final effectiveNow = departAt ?? DateTime.now();
    final showDistance = userPos != null;

    // Arrêts proches + groupes calculés à l'heure de référence.
    final stations = HomeAggregator.nearbyStations(gtfs, userPos, limit: 10);
    final allGroups = [
      for (final s in stations) gtfs.stationLineGroups(s, now: effectiveNow),
    ];

    // Favoris : arrêts (résolus depuis le réseau) + lignes.
    final stopById = {for (final s in gtfs.cachedStops) s.stopId: s};
    final favStops = <_StationEntry>[];
    for (final id in favorites.stopIds) {
      final stop = stopById[id];
      if (stop == null) continue;
      final st = gtfs.nearbyStationFor(stop, from: userPos);
      if (st == null) continue;
      final groups = gtfs.stationLineGroups(st, now: effectiveNow);
      favStops.add((station: st, groups: groups));
    }
    final favStopIds = favStops.map((e) => e.station.stop.stopId).toSet();

    final favLines = <GtfsRoute>[];
    for (final id in favorites.routeIds) {
      final route = AuleDataAdapter.findRoute(gtfs, id);
      if (route != null) favLines.add(route);
    }

    // Chips de mode masqués faute de données.
    final hasTram =
        allGroups.any((gs) => gs.any((g) => g.route.transportType == 'tram'));
    final hasBus =
        allGroups.any((gs) => gs.any((g) => g.route.transportType != 'tram'));
    final hiddenFilters = <StopFilter>{
      if (!hasTram) StopFilter.tram,
      if (!hasBus) StopFilter.bus,
      StopFilter.favorites, // section Favoris dédiée → chip inutile ici
    };
    var effectiveFilter = filter;
    if (hiddenFilters.contains(effectiveFilter)) {
      effectiveFilter = StopFilter.all;
    }

    bool keep(StationLineGroup g) {
      switch (effectiveFilter) {
        case StopFilter.tram:
          return g.route.transportType == 'tram';
        case StopFilter.bus:
          return g.route.transportType != 'tram';
        case StopFilter.all:
        case StopFilter.favorites:
          return true;
      }
    }

    // Arrêts proches hors favoris (favoris affichés à part).
    final nearby = <_StationEntry>[];
    for (var i = 0; i < stations.length; i++) {
      if (favStopIds.contains(stations[i].stop.stopId)) continue;
      final groups = allGroups[i].where(keep).toList();
      if ((effectiveFilter == StopFilter.bus ||
              effectiveFilter == StopFilter.tram) &&
          groups.isEmpty) {
        continue;
      }
      nearby.add((station: stations[i], groups: groups));
    }

    final departures = HomeAggregator.imminentFromGroups(
      nearby.map((e) => e.station).toList(),
      nearby.map((e) => e.groups).toList(),
      limit: 6,
    );
    final stationByName = {for (final s in stations) s.stop.stopName: s};

    final hasAnything =
        favStops.isNotEmpty || favLines.isNotEmpty || nearby.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      physics: const BouncingScrollPhysics(),
      children: [
        _TimePill(colors: c, departAt: departAt, onTap: onPickTime),
        const SizedBox(height: 10),
        if (!hiddenFilters.containsAll([StopFilter.bus, StopFilter.tram])) ...[
          _ModeChips(
            colors: c,
            selected: effectiveFilter,
            hidden: hiddenFilters,
            onSelected: onFilter,
          ),
          const SizedBox(height: 12),
        ],
        if (!hasAnything)
          _EmptyState(colors: c)
        else ...[
          if (favLines.isNotEmpty) ...[
            _SectionLabel('Lignes favorites', colors: c),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: favLines.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final route = favLines[i];
                  final rep = gtfs.representativeDeparture(route, from: userPos);
                  return _FavLineChip(
                    colors: c,
                    route: route,
                    nextLabel: rep == null
                        ? null
                        : _waitDisplay(rep.departure.waitMinutes).label,
                    onTap: () => onOpenLine(route),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (favStops.isNotEmpty) ...[
            _SectionLabel('Arrêts favoris', colors: c),
            const SizedBox(height: 10),
            ...favStops.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StationCard(
                  colors: c,
                  entry: e,
                  showDistance: showDistance,
                  planning: planning,
                  effectiveNow: effectiveNow,
                  isFavorite: true,
                  onToggleFavorite: () =>
                      favorites.toggle(e.station.stop.stopId),
                  onTap: () =>
                      onOpenStop(e.station, hasDistance: showDistance),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (nearby.isNotEmpty) ...[
            _SectionLabel(
              showDistance ? 'Arrêts à proximité' : 'Arrêts autour du centre',
              colors: c,
            ),
            const SizedBox(height: 10),
            ...nearby.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StationCard(
                  colors: c,
                  entry: e,
                  showDistance: showDistance,
                  planning: planning,
                  effectiveNow: effectiveNow,
                  isFavorite: favorites.isFavorite(e.station.stop.stopId),
                  onToggleFavorite: () =>
                      favorites.toggle(e.station.stop.stopId),
                  onTap: () =>
                      onOpenStop(e.station, hasDistance: showDistance),
                ),
              ),
            ),
          ],
          if (departures.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionLabel(
              planning ? 'Départs à cette heure' : 'Prochains départs',
              colors: c,
            ),
            const SizedBox(height: 10),
            ...departures.map(
              (dep) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DepartureTile(
                  colors: c,
                  departure: dep,
                  showDistance: showDistance,
                  planning: planning,
                  effectiveNow: effectiveNow,
                  onTap: () {
                    final station = stationByName[dep.stationName] ??
                        (stations.isNotEmpty ? stations.first : null);
                    if (station != null) {
                      onOpenStop(station, hasDistance: showDistance);
                    }
                  },
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Bouton « Maintenant / Partir à… ».
class _TimePill extends StatelessWidget {
  final AuleColors colors;
  final DateTime? departAt;
  final VoidCallback onTap;

  const _TimePill({
    required this.colors,
    required this.departAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final planning = departAt != null;
    final accent = planning ? c.brand : c.text;
    return Material(
      color: planning ? c.brandWeak : c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: planning ? c.brandLine : c.line),
          ),
          child: Row(
            children: [
              Icon(planning ? LucideIcons.clock : LucideIcons.zap,
                  size: 18, color: planning ? c.brand : c.ok),
              const SizedBox(width: 10),
              Text(
                'Partir',
                style: hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.muted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  departureTimeLabel(departAt),
                  style: hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronDown, size: 18, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChips extends StatelessWidget {
  final AuleColors colors;
  final StopFilter selected;
  final Set<StopFilter> hidden;
  final ValueChanged<StopFilter> onSelected;

  const _ModeChips({
    required this.colors,
    required this.selected,
    required this.hidden,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Réutilise les chips de la fiche arrêt (cohérence visuelle).
    return StopFilterChips(
      selected: selected,
      hidden: hidden,
      colors: colors,
      onSelected: onSelected,
    );
  }
}

// ─────────────────────────────── Lignes ───────────────────────────────────

class _LinesView extends StatelessWidget {
  final AuleColors colors;
  final void Function(GtfsRoute) onOpenLine;

  const _LinesView({required this.colors, required this.onOpenLine});

  static const _modeOrder = ['tram', 'busway', 'navibus', 'bus'];
  static const _modeTitle = {
    'tram': 'Tramway',
    'busway': 'Chronobus',
    'navibus': 'Navibus',
    'bus': 'Bus',
  };

  /// Tri des codes ligne : numérique quand possible (2 avant 10), sinon
  /// alphabétique (C1, C6, E1…).
  static int _compareCode(GtfsRoute a, GtfsRoute b) {
    final ca = AuleDataAdapter.lineCode(a);
    final cb = AuleDataAdapter.lineCode(b);
    final na = int.tryParse(ca);
    final nb = int.tryParse(cb);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return ca.compareTo(cb);
  }

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final gtfs = context.watch<GtfsService>();
    final favorites = context.watch<FavoritesService>();
    final routes = gtfs.cachedRoutes;

    if (routes.isEmpty) {
      return _EmptyState(colors: c, lines: true);
    }

    final byMode = <String, List<GtfsRoute>>{};
    for (final r in routes) {
      byMode.putIfAbsent(r.transportType, () => []).add(r);
    }
    for (final list in byMode.values) {
      list.sort(_compareCode);
    }

    final favLines = [
      for (final id in favorites.routeIds)
        if (AuleDataAdapter.findRoute(gtfs, id) != null)
          AuleDataAdapter.findRoute(gtfs, id)!,
    ]..sort(_compareCode);

    Widget row(GtfsRoute route) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LineDirectoryRow(
            route: route,
            colors: c,
            isFavorite: favorites.isFavoriteLine(route.routeId),
            onToggleFavorite: () => favorites.toggleLine(route.routeId),
            onTap: () => onOpenLine(route),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      physics: const BouncingScrollPhysics(),
      children: [
        if (favLines.isNotEmpty) ...[
          _SectionLabel('Favoris', colors: c),
          const SizedBox(height: 10),
          ...favLines.map(row),
          const SizedBox(height: 18),
        ],
        for (final mode in _modeOrder)
          if ((byMode[mode] ?? const []).isNotEmpty) ...[
            _SectionLabel(_modeTitle[mode] ?? mode, colors: c),
            const SizedBox(height: 10),
            ...byMode[mode]!.map(row),
            const SizedBox(height: 18),
          ],
      ],
    );
  }
}

// ─────────────────────────── Composants partagés ──────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final AuleColors colors;

  const _SectionLabel(this.label, {required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: hankenGrotesk(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: colors.faint,
      ),
    );
  }
}

/// Format absolu d'un passage (heure d'arrivée) en mode planification.
String _clockOf(DateTime now, int waitMinutes) {
  final t = now.add(Duration(minutes: waitMinutes));
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Badge d'attente (live) ou heure d'arrivée (planification).
class _WaitBadge extends StatelessWidget {
  final int minutes;
  final bool planning;
  final DateTime effectiveNow;

  const _WaitBadge({
    required this.minutes,
    required this.planning,
    required this.effectiveNow,
  });

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    if (planning) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: c.line),
        ),
        child: Text(
          _clockOf(effectiveNow, minutes),
          style: hankenGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: c.text,
          ),
        ),
      );
    }

    final w = _waitDisplay(minutes);
    if (w.imminent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _waitRed.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LiveDot(size: 7),
            const SizedBox(width: 4),
            Text(
              w.label,
              style: hankenGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _waitRed,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: w.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$minutes',
              style: hankenGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: w.color,
              ),
            ),
            TextSpan(
              text: ' min',
              style: hankenGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: w.color.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'un arrêt avec un aperçu de ses prochains passages.
class _StationCard extends StatelessWidget {
  final AuleColors colors;
  final _StationEntry entry;
  final bool showDistance;
  final bool planning;
  final DateTime effectiveNow;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  const _StationCard({
    required this.colors,
    required this.entry,
    required this.showDistance,
    required this.planning,
    required this.effectiveNow,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final station = entry.station;
    final previews = <StationDeparture>[];
    for (final group in entry.groups) {
      for (final dep in group.directions) {
        previews.add(dep);
        if (previews.length >= 3) break;
      }
      if (previews.length >= 3) break;
    }

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      station.stop.stopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: hankenGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                  if (showDistance)
                    Text(
                      '${AuleDataAdapter.formatDistance(station.distanceMeters)} · ${(station.distanceMeters / 75).ceil()} min',
                      style: hankenGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.muted,
                      ),
                    ),
                  Semantics(
                    button: true,
                    label: isFavorite
                        ? 'Retirer des favoris'
                        : 'Ajouter aux favoris',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggleFavorite,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          LucideIcons.star,
                          size: 19,
                          color: isFavorite
                              ? const Color(0xFFF59E0B)
                              : c.muted.withValues(alpha: 0.5),
                          fill: isFavorite ? 1.0 : 0.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (previews.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  planning ? 'Aucun passage à cette heure' : 'Aucun départ imminent',
                  style: hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.muted,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                ...previews.map(
                  (dep) => Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 4),
                    child: _PreviewRow(
                      colors: c,
                      departure: dep,
                      planning: planning,
                      effectiveNow: effectiveNow,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne d'aperçu dans une carte arrêt (badge ligne + direction + attente).
class _PreviewRow extends StatelessWidget {
  final AuleColors colors;
  final StationDeparture departure;
  final bool planning;
  final DateTime effectiveNow;

  const _PreviewRow({
    required this.colors,
    required this.departure,
    required this.planning,
    required this.effectiveNow,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final code = AuleDataAdapter.lineCode(departure.route);
    final w = _waitDisplay(departure.waitMinutes);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: _lineColor(departure.route),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            code,
            style: hankenGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            departure.headsign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hankenGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (planning)
          Text(
            _clockOf(effectiveNow, departure.waitMinutes),
            style: hankenGrotesk(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          )
        else if (w.imminent)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LiveDot(size: 6),
              const SizedBox(width: 3),
              Text(
                w.label,
                style: hankenGrotesk(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _waitRed,
                ),
              ),
            ],
          )
        else
          Text(
            w.label,
            style: hankenGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: w.color,
            ),
          ),
      ],
    );
  }
}

/// Tuile « prochain départ » agrégée (badge ligne + direction + arrêt).
class _DepartureTile extends StatelessWidget {
  final AuleColors colors;
  final ImminentDeparture departure;
  final bool showDistance;
  final bool planning;
  final DateTime effectiveNow;
  final VoidCallback onTap;

  const _DepartureTile({
    required this.colors,
    required this.departure,
    required this.showDistance,
    required this.planning,
    required this.effectiveNow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final lineLabel = AuleDataAdapter.lineCode(departure.route);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _lineColor(departure.route),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(
                  lineLabel,
                  style: hankenGrotesk(
                    fontSize: 16,
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
                      departure.headsign,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: hankenGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    Text(
                      showDistance
                          ? '${departure.stationName} · ${departure.distanceMeters.round()} m'
                          : departure.stationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: hankenGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _WaitBadge(
                minutes: departure.waitMinutes,
                planning: planning,
                effectiveNow: effectiveNow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip d'une ligne favorite avec son prochain passage.
class _FavLineChip extends StatelessWidget {
  final AuleColors colors;
  final GtfsRoute route;
  final String? nextLabel;
  final VoidCallback onTap;

  const _FavLineChip({
    required this.colors,
    required this.route,
    required this.nextLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final color = _lineColor(route);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 30),
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AuleDataAdapter.lineCode(route),
                  style: hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                nextLabel ?? '—',
                style: hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: nextLabel == null ? c.faint : c.text,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AuleColors colors;
  final bool lines;

  const _EmptyState({required this.colors, this.lines = false});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 48, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(lines ? LucideIcons.list : LucideIcons.clock,
              size: 40, color: c.muted),
          const SizedBox(height: 16),
          Text(
            lines ? 'Réseau en cours de chargement' : 'Aucun horaire disponible',
            style: hankenGrotesk(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lines
                ? 'Les lignes apparaîtront dès le réseau chargé.'
                : "Rapprochez-vous d'un arrêt ou recherchez une station.",
            textAlign: TextAlign.center,
            style: hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.muted,
            ),
          ),
        ],
      ),
    );
  }
}
