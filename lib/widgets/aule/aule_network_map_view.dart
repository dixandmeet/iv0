import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/gtfs.dart';
import '../../services/aule_data_adapter.dart';
import '../../theme/aule_theme.dart';
import 'aule_map_tiles.dart';

/// Plan réseau plein écran — tuiles CartoDB + tracés GTFS.
class AuleNetworkMapView extends StatelessWidget {
  final LatLng center;
  final List<GtfsRoute> routes;
  final List<GtfsStop> stops;
  final String? selectedLine;
  final LatLng? userPosition;
  final void Function(GtfsStop stop)? onStopTap;

  const AuleNetworkMapView({
    super.key,
    required this.center,
    required this.routes,
    required this.stops,
    this.selectedLine,
    this.userPosition,
    this.onStopTap,
  });

  Color _routeColor(GtfsRoute route) {
    final hex = route.routeColor;
    if (hex != null && hex.isNotEmpty) {
      try {
        return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }
    return AuleLineColors.forLine(AuleDataAdapter.lineCode(route));
  }

  bool _visible(String code) =>
      selectedLine == null || selectedLine == 'Tout' || selectedLine == code;

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);

    final polylines = <Polyline>[];
    for (final route in routes) {
      final code = AuleDataAdapter.lineCode(route);
      final color = _routeColor(route);
      final opacity = _visible(code) ? 1.0 : 0.16;
      for (final segment in route.shapes) {
        if (segment.length < 2) continue;
        polylines.add(Polyline(
          points: segment,
          color: color.withValues(alpha: opacity),
          strokeWidth: 5,
          borderColor: color.withValues(alpha: opacity * 0.35),
          borderStrokeWidth: 10,
        ));
      }
    }

    final markers = <Marker>[
      for (final stop in stops)
        Marker(
          point: stop.position,
          width: onStopTap != null ? 26 : 14,
          height: onStopTap != null ? 26 : 14,
          alignment: Alignment.center,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onStopTap == null ? null : () => onStopTap!(stop),
            child: Center(
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: c.muted.withValues(alpha: 0.7), width: 2),
                ),
              ),
            ),
          ),
        ),
      if (userPosition != null)
        Marker(
          point: userPosition!,
          width: 20,
          height: 20,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: c.brand,
              shape: BoxShape.circle,
              border: Border.all(color: c.surface, width: 3),
              boxShadow: [
                BoxShadow(
                  color: c.brand.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
    ];

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.2,
        minZoom: 11,
        maxZoom: 17,
      ),
      children: [
        AuleMapTiles.layer(context, c),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }
}
