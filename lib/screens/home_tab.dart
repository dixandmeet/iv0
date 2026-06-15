import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/stop_data.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../widgets/nearby_stops/header_section.dart';
import '../widgets/nearby_stops/nearby_stops_section.dart';
import '../widgets/nearby_stops/stop_card.dart';
import 'stop_detail_page.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _sortBy = 'Distance';
  bool _isLoading = false;
  final LatLng _fallbackPosition = const LatLng(47.25156, -1.53026);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gtfs = Provider.of<GtfsService>(context, listen: false);
      if (gtfs.cachedStops.isEmpty || gtfs.cachedRoutes.isEmpty) {
        setState(() => _isLoading = true);
        await gtfs.fetchRoutes();
        await gtfs.fetchStops();
        gtfs.ensureNetworkGraph();
        if (mounted) setState(() => _isLoading = false);
      }
    });
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

    final rawStations =
        gtfs.nearbyStations(userPos, limit: 10, maxMeters: 500);
    final stopsList = rawStations.map(_mapStationToStopData).toList();

    if (_sortBy == 'Distance') {
      stopsList.sort((a, b) => a.distance.compareTo(b.distance));
    } else {
      stopsList.sort((a, b) => a.name.compareTo(b.name));
    }

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 6),
          const HeaderSection(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFF1B66F5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chargement des lignes TAN...',
                            style: GoogleFonts.hankenGrotesk(
                              color: primaryTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NearbyStopsSection(
                          sortBy: _sortBy,
                          onSortToggle: () {
                            setState(() {
                              _sortBy =
                                  _sortBy == 'Distance' ? 'Nom' : 'Distance';
                            });
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: stopsList.isEmpty
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 32),
                                  child: Center(
                                    child: Text(
                                      'Aucun arrêt à proximité.',
                                      style: GoogleFonts.hankenGrotesk(
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
                                        final station =
                                            rawStations.firstWhere(
                                          (s) => s.stop.stopId == stop.id,
                                        );
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => StopDetailPage(
                                              station: station,
                                              showDistance: pos != null,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
