import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track_request.dart';
import '../services/gtfs_service.dart';
import '../services/report_service.dart';
import '../services/vehicle_detection_service.dart';
import '../widgets/flow_widgets.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

/// Shell principal avec navigation par onglets (Accueil · Map · Profil).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  TrackRequest? _pendingTrack;

  void switchToMapWithTracking(TrackRequest request) {
    setState(() {
      _pendingTrack = request;
      _index = 1;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gtfs = Provider.of<GtfsService>(context, listen: false);
      Provider.of<VehicleDetectionService>(context, listen: false)
          .startMonitoring();
      Provider.of<ReportService>(context, listen: false).fetchRecentReports();
      await gtfs.fetchRoutes();
      await gtfs.fetchStops();
      gtfs.ensureNetworkGraph();
    });
  }

  @override
  void dispose() {
    Provider.of<VehicleDetectionService>(context, listen: false)
        .stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onTrackLine: switchToMapWithTracking),
          MapScreen(
            initialTrack: _pendingTrack,
            onTrackConsumed: () => setState(() => _pendingTrack = null),
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: FlowBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
