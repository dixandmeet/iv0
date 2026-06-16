import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/favorites_service.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/aule_theme.dart';
import 'stop_detail_page.dart';

/// Liste des arrêts favoris de l'utilisateur.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gtfs = context.read<GtfsService>();
      if (gtfs.cachedStops.isEmpty) gtfs.fetchStops();
    });
  }

  void _open(NearbyStation station, {required bool hasDistance}) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            StopDetailPage(station: station, showDistance: hasDistance),
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

    // Résout les stopIds favoris en stations (en préservant l'ordre).
    final byId = {for (final s in gtfs.cachedStops) s.stopId: s};
    final stations = <NearbyStation>[];
    for (final id in favorites.stopIds) {
      final stop = byId[id];
      if (stop == null) continue;
      final st = gtfs.nearbyStationFor(stop, from: from);
      if (st != null) stations.add(st);
    }

    return AuleTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(colors: c, count: favorites.count),
              Expanded(
                child: !favorites.isLoaded || gtfs.cachedStops.isEmpty
                    ? Center(child: CircularProgressIndicator(color: c.brand))
                    : favorites.stopIds.isEmpty
                        ? _EmptyState(colors: c)
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: stations.length,
                            itemBuilder: (_, i) => _FavoriteRow(
                              station: stations[i],
                              colors: c,
                              hasDistance: pos != null,
                              onTap: () => _open(stations[i],
                                  hasDistance: pos != null),
                            ),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
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
  final int count;
  const _Header({required this.colors, required this.count});

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Favoris',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: colors.text,
                ),
              ),
              Text(
                '$count arrêt${count > 1 ? 's' : ''} enregistré${count > 1 ? 's' : ''}',
                style: GoogleFonts.hankenGrotesk(
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

class _EmptyState extends StatelessWidget {
  final AuleColors colors;
  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(LucideIcons.star, size: 44, color: colors.faint),
        const SizedBox(height: 16),
        Text(
          'Aucun arrêt favori',
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Touchez l'étoile sur une fiche d'arrêt pour l'ajouter ici.",
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.muted,
          ),
        ),
      ],
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  final NearbyStation station;
  final AuleColors colors;
  final bool hasDistance;
  final VoidCallback onTap;
  const _FavoriteRow({
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
                          style: GoogleFonts.hankenGrotesk(
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
                    style: GoogleFonts.hankenGrotesk(
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
