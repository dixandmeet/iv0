import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/track_request.dart';
import '../services/gtfs_service.dart';
import '../services/home_aggregator.dart';
import '../services/location_service.dart';
import '../services/report_service.dart';
import '../services/supabase_service.dart';
import '../services/vehicle_detection_service.dart';
import '../theme/flow_theme.dart';
import '../widgets/home/home_map_header.dart';
import '../widgets/home/home_search_bar.dart';
import '../widgets/nearby_station_card.dart';
import 'unified_search_screen.dart';
import 'widgets/home/favorites_section.dart';
import 'widgets/home/imminent_departures_section.dart';
import 'widgets/home/nearby_stations_section.dart';
import 'widgets/home/nearby_vehicles_section.dart';
import 'widgets/home/network_status_section.dart';
import 'widgets/home/smart_suggestions_section.dart';
import 'widgets/home/traffic_alerts_section.dart';

class HomeScreen extends StatefulWidget {
  final void Function(TrackRequest request) onTrackLine;

  const HomeScreen({super.key, required this.onTrackLine});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _favoritesKey = GlobalKey();
  Timer? _refreshTimer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UnifiedSearchScreen()),
    );
  }

  void _scrollToFavorites() {
    final ctx = _favoritesKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force rebuild every 30 s for refreshed departures.
    final _ = _tick;

    final location = Provider.of<LocationService>(context);
    final gtfs = Provider.of<GtfsService>(context);
    final detection = Provider.of<VehicleDetectionService>(context);
    final reports = Provider.of<ReportService>(context);
    final supabase = Provider.of<SupabaseService>(context);

    final pos = location.currentPosition;
    final LatLng? userPos =
        pos != null ? LatLng(pos.latitude, pos.longitude) : null;
    final center = HomeAggregator.resolveCenter(userPos);

    final stations = HomeAggregator.nearbyStations(gtfs, userPos);
    final groups = HomeAggregator.groupsPerStation(gtfs, stations);
    final badges = assignRelevance(stations, groups);
    final departures = HomeAggregator.imminentDepartures(gtfs, stations);
    final vehicles =
        HomeAggregator.nearbyVehicles(detection.detectedVehicles, userPos);
    final network =
        HomeAggregator.networkStatus(detection.detectedVehicles, reports.activeReports);
    final suggestion = HomeAggregator.bestSuggestion(
      stations: stations,
      groupsPerStation: groups,
      reports: reports.activeReports,
      gtfs: gtfs,
    );

    return Scaffold(
      backgroundColor: FlowColors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: HomeMapHeader(center: center),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                HomeSearchBar(
                  onSearchTap: _openSearch,
                  onFavoritesTap: _scrollToFavorites,
                ),
                if (supabase.isOfflineMode)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _InfoStrip(
                      text:
                          'Hors-ligne · véhicules temps réel indisponibles',
                    ),
                  )
                else if (userPos == null)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _InfoStrip(
                      text: 'Position indisponible — réactivez le GPS',
                    ),
                  ),
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            NearbyStationsSection(
                              stations: stations,
                              groupsPerStation: groups,
                              badges: badges,
                              userPosition: userPos,
                              onTrackLine: widget.onTrackLine,
                            ),
                            const SizedBox(height: 24),
                            ImminentDeparturesSection(departures: departures),
                            const SizedBox(height: 24),
                            NearbyVehiclesSection(vehicles: vehicles),
                            const SizedBox(height: 24),
                            NetworkStatusSection(status: network),
                            const SizedBox(height: 24),
                            TrafficAlertsSection(reports: reports.activeReports),
                            const SizedBox(height: 24),
                            FavoritesSection(key: _favoritesKey),
                            const SizedBox(height: 24),
                            SmartSuggestionsSection(suggestion: suggestion),
                          ]),
                        ),
                      ),
                    ],
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

class _InfoStrip extends StatelessWidget {
  final String text;
  const _InfoStrip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FlowColors.orangeSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: FlowColors.orange,
        ),
      ),
    );
  }
}
