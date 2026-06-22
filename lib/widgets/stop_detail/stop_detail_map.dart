import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../theme/app_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/gtfs.dart';
import '../../services/gtfs_service.dart';
import '../../theme/aule_theme.dart';
import '../aule/aule_map_tiles.dart';
import '../aule/aule_icons.dart';
import '../nearby_stops/line_badge.dart';

/// Carte de l'arrêt avec card flottante « Arrêt le plus proche ».
class StopDetailMap extends StatefulWidget {
  final NearbyStation station;
  final LatLng userPosition;

  const StopDetailMap({
    super.key,
    required this.station,
    required this.userPosition,
  });

  @override
  State<StopDetailMap> createState() => _StopDetailMapState();
}

class _StopDetailMapState extends State<StopDetailMap> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Color _getRouteColor(GtfsRoute route) {
    final hex = route.routeColor;
    if (hex != null && hex.isNotEmpty) {
      try {
        return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }
    final label = route.routeShortName ?? route.routeId;
    return LineBadge.colorFor(label);
  }

  void _recenterOnUser() {
    _mapController.move(widget.userPosition, 16.2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;
    final borderCol = isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);
    final fabBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryText = isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedText = isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);

    final gtfs = context.watch<GtfsService>();
    final stop = widget.station.stop;
    final lines = widget.station.routes
        .map((r) => r.routeShortName ?? r.routeId)
        .toList();
    final distance = widget.station.distanceMeters.round();
    final walkMin = (widget.station.distanceMeters / 75).ceil();

    final polylines = <Polyline>[];
    for (final route in widget.station.routes) {
      final shapes = gtfs.displayShapes(route);
      final color = _getRouteColor(route);
      for (final pts in shapes) {
        if (pts.length >= 2) {
          polylines.add(
            Polyline(
              points: pts,
              color: color.withValues(alpha: 0.85),
              strokeWidth: 4,
            ),
          );
        }
      }
    }

    final markers = <Marker>[
      // Halo arrêt sélectionné
      Marker(
        point: stop.position,
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF1B66F5).withValues(alpha: 0.35),
                width: 3,
              ),
            ),
          ),
        ),
      ),
      // Label arrêt
      Marker(
        point: stop.position,
        width: 100,
        height: 36,
        alignment: const Alignment(0, -1.8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            stop.stopName,
            style: hankenGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: primaryText,
            ),
          ),
        ),
      ),
      // Position utilisateur
      Marker(
        point: widget.userPosition,
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF1B66F5).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF1B66F5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ],
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: stop.position,
                  initialZoom: 16.0,
                  maxZoom: 18.0,
                  minZoom: 13.0,
                  backgroundColor: c.mapBg,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  AuleMapTiles.layer(context, c),
                  PolylineLayer(polylines: polylines),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),

            // Card flottante arrêt le plus proche
            Positioned(
              left: 12,
              bottom: 12,
              right: 64,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Arrêt le plus proche',
                      style: hankenGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stop.stopName,
                      style: hankenGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AuleIcons.walk(size: 13, color: mutedText),
                        const SizedBox(width: 4),
                        Text(
                          '$distance m • $walkMin min à pied',
                          style: hankenGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: mutedText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${lines.length} lignes disponibles',
                          style: hankenGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: mutedText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: lines
                                .take(5)
                                .map((l) => LineBadge(label: l, height: 18, fontSize: 9))
                                .toList(),
                          ),
                        ),
                        Icon(LucideIcons.chevronRight, size: 16, color: mutedText),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // FAB navigation
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: _recenterOnUser,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: fabBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderCol),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    LucideIcons.navigation,
                    color: Color(0xFF1B66F5),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
