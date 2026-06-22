import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/stop_data.dart';
import '../services/disruption_service.dart';
import '../services/favorites_service.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/nearby_stops/header_section.dart';
import '../widgets/nearby_stops/line_badge.dart';
import '../widgets/nearby_stops/nearby_stops_section.dart';
import '../widgets/nearby_stops/stop_card.dart';
import 'disruptions_page.dart';
import 'line_detail_page.dart';
import 'stop_detail_page.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'Distance';
  bool _isLoading = false;
  bool _isLocating = false;
  final LatLng _fallbackPosition = const LatLng(47.25156, -1.53026);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gtfs = Provider.of<GtfsService>(context, listen: false);
      if (gtfs.cachedStops.isEmpty || gtfs.cachedRoutes.isEmpty) {
        setState(() => _isLoading = true);
        await gtfs.fetchRoutes();
        await gtfs.fetchStops();
        gtfs.ensureNetworkGraph();
        if (mounted) setState(() => _isLoading = false);
      }
      if (mounted) context.read<DisruptionService>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _openStopDetail(NearbyStation station, {required bool hasDistance}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StopDetailPage(
          station: station,
          showDistance: hasDistance,
        ),
      ),
    );
  }

  StopData _mapStationToStopData(NearbyStation station) {
    final lines =
        station.routes.map((r) => r.routeShortName ?? r.routeId).toList();
    return StopData(
      id: station.stop.stopId,
      name: station.stop.stopName,
      distance: station.distanceMeters.round(),
      walkTime: (station.distanceMeters / 75).ceil(),
      lines: lines,
      position: station.stop.position,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final primaryTextColor =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);

    final location = context.watch<LocationService>();
    final gtfs = context.watch<GtfsService>();

    final pos = location.currentPosition;
    final LatLng userPos =
        pos != null ? LatLng(pos.latitude, pos.longitude) : _fallbackPosition;

    final query = _searchController.text.trim();
    final isSearching = query.isNotEmpty;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 6),
          const HeaderSection(),
          _buildSearchBar(isDark, cardBg),
          Expanded(
            child: _isLoading
                ? _buildLoader(cardBg, primaryTextColor)
                : isSearching
                    ? _buildSearchResults(
                        gtfs, query, pos != null ? userPos : null, primaryTextColor)
                    : _buildNearbyContent(
                        gtfs, userPos, pos != null, primaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader(Color cardBg, Color primaryTextColor) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1B66F5)),
            const SizedBox(height: 16),
            Text(
              'Chargement des lignes TAN...',
              style: hankenGrotesk(
                color: primaryTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barre de recherche inline : saisie d'un arrêt + bouton GPS pour
  /// recentrer sur la position de l'utilisateur.
  Widget _buildSearchBar(bool isDark, Color cardBg) {
    final mutedTextColor =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);
    final primaryTextColor =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(LucideIcons.search, color: mutedTextColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  cursorColor: const Color(0xFF1B66F5),
                  style: hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Rechercher un arrêt...',
                    hintStyle: hankenGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: mutedTextColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _searchController.clear,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(LucideIcons.x, color: mutedTextColor, size: 20),
                  ),
                )
              else
                GestureDetector(
                  onTap: _isLocating ? null : _locateNearby,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B66F5),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            LucideIcons.navigation,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Résultats de recherche d'arrêts ; un tap ouvre les temps de passage.
  Widget _buildSearchResults(
    GtfsService gtfs,
    String query,
    LatLng? from,
    Color primaryTextColor,
  ) {
    final results = gtfs.searchStations(query, from: from);
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Aucun arrêt trouvé pour « $query ».',
            style: hankenGrotesk(
              color: primaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final station = results[i];
        return _StationResultRow(
          station: station,
          showDistance: from != null,
          onTap: () => _openStopDetail(station, hasDistance: from != null),
        );
      },
    );
  }

  Widget _buildNearbyContent(
    GtfsService gtfs,
    LatLng userPos,
    bool hasGps,
    Color primaryTextColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;
    final disruptions = context.watch<DisruptionService>();
    final favorites = context.watch<FavoritesService>();
    final from = hasGps ? userPos : null;

    final rawStations = gtfs.nearbyStations(userPos, limit: 10, maxMeters: 500);
    final stopsList = rawStations.map(_mapStationToStopData).toList();

    if (_sortBy == 'Distance') {
      stopsList.sort((a, b) => a.distance.compareTo(b.distance));
    } else {
      stopsList.sort((a, b) => a.name.compareTo(b.name));
    }

    // Favorite stops resolved to NearbyStation with departures.
    final byStopId = {for (final s in gtfs.cachedStops) s.stopId: s};
    final favStations = <NearbyStation>[];
    for (final id in favorites.stopIds) {
      final stop = byStopId[id];
      if (stop == null) continue;
      final st = gtfs.nearbyStationFor(stop, from: from);
      if (st != null) favStations.add(st);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (disruptions.cached.isNotEmpty)
            _DisruptionBanner(
              count: disruptions.cached.length,
              colors: c,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DisruptionsPage(),
                ),
              ),
            ),
          if (favStations.isNotEmpty) ...[
            _FavoritesSectionHeader(colors: c),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < favStations.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _FavoriteStopCard(
                      station: favStations[i],
                      gtfs: gtfs,
                      colors: c,
                      onTapStop: () =>
                          _openStopDetail(favStations[i], hasDistance: hasGps),
                      onTapDeparture: (dep) => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => LineDetailPage(
                            route: dep.route,
                            headsign: dep.headsign,
                            station: favStations[i],
                            departure: dep,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          NearbyStopsSection(
            sortBy: _sortBy,
            onSortToggle: () {
              setState(() {
                _sortBy = _sortBy == 'Distance' ? 'Nom' : 'Distance';
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: stopsList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Aucun arrêt à proximité.',
                        style: hankenGrotesk(
                          color: primaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: stopsList.map((stop) {
                      return StopCard(
                        stop: stop,
                        isSelected: false,
                        onTap: () {
                          final station = rawStations.firstWhere(
                            (s) => s.stop.stopId == stop.id,
                          );
                          _openStopDetail(station, hasDistance: hasGps);
                        },
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Bandeau d'alerte perturbations affiché en haut de l'accueil quand le réseau
/// est perturbé. Tap → page Perturbations.
class _DisruptionBanner extends StatelessWidget {
  final int count;
  final AuleColors colors;
  final VoidCallback onTap;

  const _DisruptionBanner({
    required this.count,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Material(
        color: amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.triangleAlert,
                      size: 17, color: amber),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count perturbation${count > 1 ? 's' : ''} en cours',
                        style: hankenGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: amber,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Voir les lignes impactées',
                        style: hankenGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: amber.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight,
                    size: 18, color: amber.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// En-tête « Mes favoris » avec étoile.
class _FavoritesSectionHeader extends StatelessWidget {
  final AuleColors colors;
  const _FavoritesSectionHeader({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Icon(LucideIcons.star, size: 17, color: colors.brand, fill: 1.0),
          const SizedBox(width: 8),
          Text(
            'Mes favoris',
            style: hankenGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'un arrêt favori avec les 2 prochains départs (la plus imminente par
/// ligne). Un tap sur la carte ouvre la fiche arrêt ; un tap sur un départ
/// ouvre la fiche ligne.
class _FavoriteStopCard extends StatelessWidget {
  final NearbyStation station;
  final GtfsService gtfs;
  final AuleColors colors;
  final VoidCallback onTapStop;
  final ValueChanged<StationDeparture> onTapDeparture;

  const _FavoriteStopCard({
    required this.station,
    required this.gtfs,
    required this.colors,
    required this.onTapStop,
    required this.onTapDeparture,
  });

  @override
  Widget build(BuildContext context) {
    final departures = gtfs.stationDepartures(station)
      ..sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
    final top = departures.where((d) => d.waitMinutes <= 60).take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: stop name + chevron
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTapStop,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 10, 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.star,
                          size: 16, color: Color(0xFFF59E0B), fill: 1.0),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        station.stop.stopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hankenGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colors.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Icon(LucideIcons.chevronRight,
                        size: 17, color: colors.faint),
                  ],
                ),
              ),
            ),
          ),
          if (top.isNotEmpty)
            Divider(height: 1, color: colors.line, thickness: 1),
          for (final dep in top)
            _FavDepartureRow(
              departure: dep,
              colors: colors,
              onTap: () => onTapDeparture(dep),
            ),
        ],
      ),
    );
  }
}

/// Ligne de départ dans une carte favori : badge ligne, destination, temps
/// d'attente color-codé.
class _FavDepartureRow extends StatelessWidget {
  final StationDeparture departure;
  final AuleColors colors;
  final VoidCallback onTap;

  const _FavDepartureRow({
    required this.departure,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = departure.route.routeShortName ?? departure.route.routeId;
    final lineColor = LineBadge.colorFor(label);
    final wait = departure.waitMinutes;

    final waitColor = wait < 1
        ? const Color(0xFFEF4444)
        : wait < 5
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);

    final waitText = wait < 1 ? "À l'approche" : '$wait min';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: waitColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  waitText,
                  style: hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: waitColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne de résultat de recherche : nom de l'arrêt, distance éventuelle et
/// codes des lignes desservies.
class _StationResultRow extends StatelessWidget {
  final NearbyStation station;
  final bool showDistance;
  final VoidCallback onTap;

  const _StationResultRow({
    required this.station,
    required this.showDistance,
    required this.onTap,
  });

  String get _sub {
    final codes = station.routes
        .map((r) => r.routeShortName ?? r.routeId)
        .take(6)
        .join(' · ');
    final more =
        station.routes.length > 6 ? ' +${station.routes.length - 6}' : '';
    if (!showDistance) return '$codes$more';
    final meters = station.distanceMeters;
    final distance = meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(1)} km';
    return '$distance · $codes$more';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final primaryTextColor =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedTextColor =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);
    final busIconBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFEAF1FE);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: busIconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.mapPin,
                      size: 20, color: Color(0xFF1B66F5)),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              station.stop.stopName,
                              style: hankenGrotesk(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (station.stop.isWheelchairAccessible) ...[
                            const SizedBox(width: 6),
                            const Icon(LucideIcons.accessibility,
                                size: 14, color: Color(0xFF16A34A)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _sub,
                        style: hankenGrotesk(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronRight, size: 18, color: mutedTextColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
