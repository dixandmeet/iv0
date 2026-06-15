import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/report_service.dart';
import '../services/vehicle_detection_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/nearby_stops/bottom_nav_bar.dart';
import 'home_tab.dart';
import 'horaires_page.dart';
import 'itinerary_page.dart';
import 'menu_page.dart';

/// Shell principal — Accueil · Itinéraire · Horaires · Menu.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static void switchTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_AppShellState>()?.setTab(index);
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // Onglets déjà activés : seuls ceux-ci sont réellement construits, les
  // autres restent des SizedBox. Évite un arbre trop profond au premier build
  // (stack overflow DDC en debug web) tout en conservant l'état après visite.
  final List<bool> _visited = [true, false, false, false];

  // Montage en deux temps : la toute première frame ne monte qu'un placeholder
  // trivial, le vrai shell se monte ensuite via un post-frame callback. Ça sort
  // le montage profond de la passe synchrone de attachRootWidget — sans quoi DDC
  // (debug web) déborde la pile au premier build. Sans effet en profile/release.
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _booted = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<VehicleDetectionService>(context, listen: false)
          .startMonitoring();
      Provider.of<ReportService>(context, listen: false).fetchRecentReports();
    });
  }

  @override
  void dispose() {
    Provider.of<VehicleDetectionService>(context, listen: false).stopMonitoring();
    super.dispose();
  }

  void setTab(int index) {
    if (_index == index) return;
    setState(() {
      _index = index;
      _visited[index] = true;
    });
  }

  Widget _tab(int index, Widget Function() builder) {
    return _visited[index] ? builder() : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = isDark ? AuleColors.dark : AuleColors.light;
    final scaffoldBg =
        isDark ? const Color(0xFF0A0D13) : const Color(0xFFF6F7FB);

    if (!_booted) {
      // Première frame : arbre minimal, profondeur quasi nulle.
      return ColoredBox(color: scaffoldBg, child: const SizedBox.expand());
    }

    return AuleTheme(
      colors: colors,
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: IndexedStack(
          index: _index,
          children: [
            _tab(0, () => const HomeTab()),
            _tab(1, () => const ItineraryPage()),
            _tab(2, () => const HorairesPage()),
            _tab(
              3,
              () => MenuPage(
                onOpenHoraires: () => setTab(2),
                onOpenItinerary: () => setTab(1),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _index,
          onTap: setTab,
        ),
      ),
    );
  }
}
