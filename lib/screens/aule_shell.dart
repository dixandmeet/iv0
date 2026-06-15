import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/aule_theme_service.dart';
import '../services/gtfs_service.dart';
import '../services/report_service.dart';
import '../services/vehicle_detection_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/aule/bottom_nav.dart';
import 'aule_home_screen.dart';
import 'aule_map_screen.dart';
import 'aule_profile_screen.dart';

/// Shell Aule — navigation Accueil · Map · Profil avec thème et horloge temps réel.
class AuleShell extends StatefulWidget {
  const AuleShell({super.key});

  @override
  State<AuleShell> createState() => _AuleShellState();
}

class _AuleShellState extends State<AuleShell> {
  int _index = 0;

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
    context.watch<AuleClock>();
    final themeService = context.watch<AuleThemeService>();
    final isDark = themeService.isDark(context);
    final colors = isDark ? AuleColors.dark : AuleColors.light;

    return AuleTheme(
        colors: colors,
        child: Scaffold(
          backgroundColor: colors.bg,
          body: IndexedStack(
            index: _index,
            children: const [
              AuleHomeScreen(),
              AuleMapScreen(),
              AuleProfileScreen(),
            ],
          ),
          bottomNavigationBar: BottomNav(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
          ),
        ),
    );
  }
}
