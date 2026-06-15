import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/gtfs_service.dart';
import '../services/home_aggregator.dart';
import '../services/location_service.dart';
import '../widgets/nearby_stops/line_badge.dart';
import '../widgets/nearby_stops/search_section.dart';
import '../widgets/nearby_stops/tab_page_header.dart';
import 'station_search_screen.dart';
import 'stop_detail_page.dart';

/// Onglet Horaires — prochains passages des arrêts à proximité.
class HorairesPage extends StatefulWidget {
  const HorairesPage({super.key});

  @override
  State<HorairesPage> createState() => _HorairesPageState();
}

class _HorairesPageState extends State<HorairesPage> {
  Timer? _ticker;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLocation());
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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _openStationSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StationSearchScreen()),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final primaryTextColor =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedTextColor =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);

    final location = context.watch<LocationService>();
    final gtfs = context.watch<GtfsService>();

    final pos = location.currentPosition;
    final LatLng? userPos =
        pos != null ? LatLng(pos.latitude, pos.longitude) : null;
    final stations = HomeAggregator.nearbyStations(
      gtfs,
      userPos,
      limit: 10,
    );
    final departures =
        HomeAggregator.imminentDepartures(gtfs, stations, limit: 8);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabPageHeader(
            title: 'Horaires',
            subtitle: userPos != null
                ? 'Arrêts autour de vous'
                : 'Prochains passages à proximité',
          ),
          SearchSection(
            onSearchTap: _openStationSearch,
            onLocateTap: _isLocating ? null : _locateNearby,
          ),
          if (userPos == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _InfoBanner(
                text: 'Position indisponible — horaires basés sur le centre-ville',
                cardBg: cardBg,
                borderCol: borderCol,
                mutedTextColor: mutedTextColor,
              ),
            ),
          Expanded(
            child: stations.isEmpty && departures.isEmpty
                ? _EmptyState(
                    primaryTextColor: primaryTextColor,
                    mutedTextColor: mutedTextColor,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (stations.isNotEmpty) ...[
                        _SectionLabel(
                          label: userPos != null
                              ? 'Arrêts à proximité'
                              : 'Arrêts autour du centre-ville',
                          mutedColor: mutedTextColor,
                        ),
                        const SizedBox(height: 10),
                        ...stations.map(
                          (station) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _StationScheduleCard(
                              station: station,
                              groups: gtfs.stationLineGroups(station),
                              showDistance: userPos != null,
                              cardBg: cardBg,
                              borderCol: borderCol,
                              primaryTextColor: primaryTextColor,
                              mutedTextColor: mutedTextColor,
                              onTap: () => _openStopDetail(station,
                                  hasDistance: userPos != null),
                            ),
                          ),
                        ),
                        if (departures.isNotEmpty) const SizedBox(height: 20),
                      ],
                      if (departures.isNotEmpty) ...[
                        _SectionLabel(
                          label: 'Prochains départs',
                          mutedColor: mutedTextColor,
                        ),
                        const SizedBox(height: 10),
                        ...departures.map(
                          (dep) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DepartureTile(
                              departure: dep,
                              showDistance: userPos != null,
                              cardBg: cardBg,
                              borderCol: borderCol,
                              primaryTextColor: primaryTextColor,
                              mutedTextColor: mutedTextColor,
                              onTap: () {
                                final station = stations.firstWhere(
                                  (s) => s.stop.stopName == dep.stationName,
                                  orElse: () => stations.first,
                                );
                                _openStopDetail(station,
                                    hasDistance: userPos != null);
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color mutedColor;

  const _SectionLabel({required this.label, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.hankenGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: mutedColor,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final Color cardBg;
  final Color borderCol;
  final Color mutedTextColor;

  const _InfoBanner({
    required this.text,
    required this.cardBg,
    required this.borderCol,
    required this.mutedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 16, color: mutedTextColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: mutedTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color primaryTextColor;
  final Color mutedTextColor;

  const _EmptyState({
    required this.primaryTextColor,
    required this.mutedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.clock, size: 40, color: mutedTextColor),
            const SizedBox(height: 16),
            Text(
              'Aucun horaire disponible',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Rapprochez-vous d\'un arrêt ou recherchez une station.',
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: mutedTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartureTile extends StatelessWidget {
  final ImminentDeparture departure;
  final bool showDistance;
  final Color cardBg;
  final Color borderCol;
  final Color primaryTextColor;
  final Color mutedTextColor;
  final VoidCallback onTap;

  const _DepartureTile({
    required this.departure,
    required this.showDistance,
    required this.cardBg,
    required this.borderCol,
    required this.primaryTextColor,
    required this.mutedTextColor,
    required this.onTap,
  });

  Color _waitColor(int minutes) {
    if (minutes <= 3) return const Color(0xFF16A34A);
    if (minutes <= 8) return const Color(0xFFF59E0B);
    return mutedTextColor;
  }

  @override
  Widget build(BuildContext context) {
    final lineLabel =
        departure.route.routeShortName ?? departure.route.routeId;
    final lineColor = LineBadge.colorFor(lineLabel);
    final wait = departure.waitMinutes;
    final waitLabel = wait <= 1 ? 'Arrive' : '$wait min';

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderCol),
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
                  lineLabel,
                  style: GoogleFonts.hankenGrotesk(
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
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    Text(
                      showDistance
                          ? '${departure.stationName} · ${departure.distanceMeters.round()} m'
                          : departure.stationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                waitLabel,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _waitColor(wait),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationScheduleCard extends StatelessWidget {
  final NearbyStation station;
  final List<StationLineGroup> groups;
  final bool showDistance;
  final Color cardBg;
  final Color borderCol;
  final Color primaryTextColor;
  final Color mutedTextColor;
  final VoidCallback onTap;

  const _StationScheduleCard({
    required this.station,
    required this.groups,
    required this.showDistance,
    required this.cardBg,
    required this.borderCol,
    required this.primaryTextColor,
    required this.mutedTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final distance = station.distanceMeters.round();
    final walkMin = (station.distanceMeters / 75).ceil();
    final previews = <StationDeparture>[];
    for (final group in groups) {
      for (final dep in group.directions) {
        previews.add(dep);
        if (previews.length >= 3) break;
      }
      if (previews.length >= 3) break;
    }

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderCol),
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
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  if (showDistance) ...[
                    Text(
                      '$distance m · $walkMin min',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(LucideIcons.chevronRight, size: 18, color: mutedTextColor),
                ],
              ),
              if (previews.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Aucun départ imminent',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mutedTextColor,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                ...previews.map(
                  (dep) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: LineBadge.colorFor(
                              dep.route.routeShortName ?? dep.route.routeId,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dep.route.routeShortName ?? dep.route.routeId,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            dep.headsign,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                        Text(
                          '${dep.waitMinutes} min',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
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
