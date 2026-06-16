import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/aule/aule_network_map_view.dart';
import 'stop_detail_page.dart';

/// Plan du réseau plein écran : lignes, arrêts et position de l'utilisateur.
class NetworkMapPage extends StatefulWidget {
  const NetworkMapPage({super.key});

  @override
  State<NetworkMapPage> createState() => _NetworkMapPageState();
}

class _NetworkMapPageState extends State<NetworkMapPage> {
  static const _nantesCenter = LatLng(47.2184, -1.5536);
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gtfs = context.read<GtfsService>();
      if (gtfs.cachedRoutes.isEmpty || gtfs.cachedStops.isEmpty) {
        setState(() => _loading = true);
        if (gtfs.cachedRoutes.isEmpty) await gtfs.fetchRoutes();
        if (gtfs.cachedStops.isEmpty) await gtfs.fetchStops();
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  void _openStop(GtfsStop stop, LatLng? from) {
    final gtfs = context.read<GtfsService>();
    final station = gtfs.nearbyStationFor(stop, from: from);
    if (station == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            StopDetailPage(station: station, showDistance: from != null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;

    final gtfs = context.watch<GtfsService>();
    final location = context.watch<LocationService>();
    final pos = location.currentPosition;
    final userPos = pos != null ? LatLng(pos.latitude, pos.longitude) : null;

    return AuleTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            if (_loading || gtfs.cachedRoutes.isEmpty)
              Center(child: CircularProgressIndicator(color: c.brand))
            else
              Positioned.fill(
                child: AuleNetworkMapView(
                  center: userPos ?? _nantesCenter,
                  routes: gtfs.cachedRoutes,
                  stops: gtfs.cachedStops,
                  userPosition: userPos,
                  onStopTap: (stop) => _openStop(stop, userPos),
                ),
              ),
            // Bouton retour + titre flottants.
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _CircleButton(
                    icon: LucideIcons.arrowLeft,
                    colors: c,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.line),
                      boxShadow: AuleTokens.cardShadow(c.shadow),
                    ),
                    child: Text(
                      'Plan du réseau',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final AuleColors colors;
  final VoidCallback onTap;
  const _CircleButton(
      {required this.icon, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.line),
          boxShadow: AuleTokens.cardShadow(colors.shadow),
        ),
        child: Icon(icon, size: 20, color: colors.text),
      ),
    );
  }
}
