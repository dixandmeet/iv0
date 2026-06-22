import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/favorites_service.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/nearby_stops/line_badge.dart';
import 'line_detail_page.dart';
import 'stop_detail_page.dart';

enum _FavTab { stops, lines }

/// Favoris de l'utilisateur : arrêts et lignes enregistrés.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  _FavTab _tab = _FavTab.stops;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gtfs = context.read<GtfsService>();
      if (gtfs.cachedStops.isEmpty) gtfs.fetchStops();
      if (gtfs.cachedRoutes.isEmpty) gtfs.fetchRoutes();
    });
  }

  void _openStop(NearbyStation station, {required bool hasDistance}) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            StopDetailPage(station: station, showDistance: hasDistance),
      ),
    );
  }

  void _openLine(GtfsRoute route, LatLng? from) {
    final gtfs = context.read<GtfsService>();
    final entry = gtfs.representativeDeparture(route, from: from);
    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Ligne indisponible pour le moment.'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LineDetailPage(
          route: route,
          headsign: entry.departure.headsign,
          station: entry.station,
          departure: entry.departure,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;

    final favorites = context.watch<FavoritesService>();
    final gtfs = context.watch<GtfsService>();
    final location = context.watch<LocationService>();
    final pos = location.currentPosition;
    final from = pos != null ? LatLng(pos.latitude, pos.longitude) : null;

    // Arrêts favoris résolus en stations (ordre préservé).
    final byStopId = {for (final s in gtfs.cachedStops) s.stopId: s};
    final stations = <NearbyStation>[];
    for (final id in favorites.stopIds) {
      final stop = byStopId[id];
      if (stop == null) continue;
      final st = gtfs.nearbyStationFor(stop, from: from);
      if (st != null) stations.add(st);
    }

    // Lignes favorites résolues en routes (ordre préservé).
    final byRouteId = {for (final r in gtfs.cachedRoutes) r.routeId: r};
    final routes = <GtfsRoute>[];
    for (final id in favorites.routeIds) {
      final r = byRouteId[id];
      if (r != null) routes.add(r);
    }

    final dataReady = favorites.isLoaded && gtfs.cachedStops.isNotEmpty;

    return AuleTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(colors: c, stops: favorites.count, lines: favorites.lineCount),
              _SegmentedTabs(
                colors: c,
                tab: _tab,
                stops: favorites.count,
                lines: favorites.lineCount,
                onChanged: (t) => setState(() => _tab = t),
              ),
              Expanded(
                child: !dataReady
                    ? Center(child: CircularProgressIndicator(color: c.brand))
                    : _tab == _FavTab.stops
                        ? _StopsList(
                            stations: stations,
                            colors: c,
                            hasDistance: pos != null,
                            onTap: (s) =>
                                _openStop(s, hasDistance: pos != null),
                          )
                        : _LinesList(
                            routes: routes,
                            colors: c,
                            onTap: (r) => _openLine(r, from),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AuleColors colors;
  final int stops;
  final int lines;
  const _Header({required this.colors, required this.stops, required this.lines});

  @override
  Widget build(BuildContext context) {
    final total = stops + lines;
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Favoris',
                style: hankenGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: colors.text,
                ),
              ),
              Text(
                '$total enregistré${total > 1 ? 's' : ''}',
                style: hankenGrotesk(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final AuleColors colors;
  final _FavTab tab;
  final int stops;
  final int lines;
  final ValueChanged<_FavTab> onChanged;

  const _SegmentedTabs({
    required this.colors,
    required this.tab,
    required this.stops,
    required this.lines,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          children: [
            _SegmentButton(
              label: 'Arrêts',
              count: stops,
              selected: tab == _FavTab.stops,
              colors: colors,
              onTap: () => onChanged(_FavTab.stops),
            ),
            _SegmentButton(
              label: 'Lignes',
              count: lines,
              selected: tab == _FavTab.lines,
              colors: colors,
              onTap: () => onChanged(_FavTab.lines),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final AuleColors colors;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? colors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            '$label · $count',
            style: hankenGrotesk(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : colors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AuleColors colors;
  final IconData icon;
  final String title;
  final String hint;
  const _EmptyState({
    required this.colors,
    required this.icon,
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 44, color: colors.faint),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: hankenGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: hankenGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.muted,
          ),
        ),
      ],
    );
  }
}

class _StopsList extends StatelessWidget {
  final List<NearbyStation> stations;
  final AuleColors colors;
  final bool hasDistance;
  final ValueChanged<NearbyStation> onTap;

  const _StopsList({
    required this.stations,
    required this.colors,
    required this.hasDistance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) {
      return _EmptyState(
        colors: colors,
        icon: LucideIcons.star,
        title: 'Aucun arrêt favori',
        hint: "Touchez l'étoile sur une fiche d'arrêt pour l'ajouter ici.",
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: stations.length,
      itemBuilder: (_, i) => _StopRow(
        station: stations[i],
        colors: colors,
        hasDistance: hasDistance,
        onTap: () => onTap(stations[i]),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
    );
  }
}

class _LinesList extends StatelessWidget {
  final List<GtfsRoute> routes;
  final AuleColors colors;
  final ValueChanged<GtfsRoute> onTap;

  const _LinesList({
    required this.routes,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return _EmptyState(
        colors: colors,
        icon: LucideIcons.star,
        title: 'Aucune ligne favorite',
        hint: "Touchez l'étoile sur une fiche de ligne pour l'ajouter ici.",
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: routes.length,
      itemBuilder: (_, i) => _LineRow(
        route: routes[i],
        colors: colors,
        onTap: () => onTap(routes[i]),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
    );
  }
}

class _StopRow extends StatelessWidget {
  final NearbyStation station;
  final AuleColors colors;
  final bool hasDistance;
  final VoidCallback onTap;
  const _StopRow({
    required this.station,
    required this.colors,
    required this.hasDistance,
    required this.onTap,
  });

  String get _sub {
    final codes = station.routes
        .map((r) => r.routeShortName ?? r.routeId)
        .take(6)
        .join(' · ');
    final more =
        station.routes.length > 6 ? ' +${station.routes.length - 6}' : '';
    if (!hasDistance) return '$codes$more';
    final meters = station.distanceMeters;
    final distance = meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(1)} km';
    return '$distance · $codes$more';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.star,
                  size: 20, color: Color(0xFFF59E0B), fill: 1.0),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          station.stop.stopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: hankenGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                      ),
                      if (station.stop.isWheelchairAccessible) ...[
                        const SizedBox(width: 6),
                        Icon(LucideIcons.accessibility,
                            size: 14, color: colors.ok),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hankenGrotesk(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 18, color: colors.faint),
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  final GtfsRoute route;
  final AuleColors colors;
  final VoidCallback onTap;
  const _LineRow({
    required this.route,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = route.routeShortName ?? route.routeId;
    final lineColor = LineBadge.colorFor(label);
    final name = route.routeLongName ?? '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: lineColor,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: hankenGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                name.isEmpty ? 'Ligne $label' : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: hankenGrotesk(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: colors.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 18, color: colors.faint),
          ],
        ),
      ),
    );
  }
}
