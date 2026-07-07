import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/gtfs.dart';
import '../services/gtfs_service.dart';
import '../widgets/driver/driver_map_marker.dart';

bool _isTramRoute(GtfsRoute route) => route.transportType == 'tram';

bool _isBusFamilyRoute(GtfsRoute route) {
  final t = route.transportType;
  return t == 'bus' || t == 'busway' || t == 'navibus';
}

/// Lignes GTFS desservant un arrêt (nécessite routes + graphe réseau chargés).
List<GtfsRoute> servingRoutes(GtfsService gtfs, GtfsStop stop) {
  return gtfs.nearbyStationFor(stop)?.routes ?? const [];
}

/// Bus, tram, ou les deux selon les lignes desservant l'arrêt.
TerrainStopKind resolveStopKind(GtfsService gtfs, GtfsStop stop) {
  final routes = servingRoutes(gtfs, stop);
  if (routes.isEmpty) {
    final primary = gtfs.primaryTransportTypeForStation(stop.stopId);
    if (primary == 'tram') return TerrainStopKind.tram;
    return TerrainStopKind.bus;
  }
  final hasTram = routes.any(_isTramRoute);
  final hasBus = routes.any(_isBusFamilyRoute);
  if (hasTram && hasBus) return TerrainStopKind.both;
  if (hasTram) return TerrainStopKind.tram;
  return TerrainStopKind.bus;
}

String stopKindLabel(TerrainStopKind kind) => switch (kind) {
      TerrainStopKind.bus => 'Arrêt bus',
      TerrainStopKind.tram => 'Arrêt tram',
      TerrainStopKind.both => 'Arrêt bus · tram',
    };

Color routeBadgeColor(GtfsRoute route) {
  final hex = route.routeColor;
  if (hex != null && hex.isNotEmpty) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {}
  }
  return switch (route.transportType) {
    'tram' => const Color(0xFF2F80ED),
    'busway' => const Color(0xFF7B61FF),
    'navibus' => const Color(0xFF0E7490),
    _ => const Color(0xFF2F8F63),
  };
}

/// Résout un arrêt GTFS depuis l'id marqueur `stop:…`.
GtfsStop? stopForMarkerId(String markerId, List<GtfsStop> stops) {
  if (!markerId.startsWith('stop:')) return null;
  final stopId = markerId.replaceFirst('stop:', '');
  for (final s in stops) {
    if (s.stopId == stopId) return s;
  }
  return null;
}

/// Tracés GTFS des lignes desservant un arrêt. Tram = 2× l'épaisseur bus.
List<Polyline> transitLinePolylines(
  GtfsService gtfs,
  List<GtfsRoute> routes, {
  double busWidth = 2.8,
}) {
  const tramMultiplier = 2.0;
  final polylines = <Polyline>[];
  for (final route in routes) {
    final isTram = route.transportType == 'tram';
    final width = isTram ? busWidth * tramMultiplier : busWidth;
    final color = routeBadgeColor(route);
    for (final segment in gtfs.displayShapes(route)) {
      if (segment.length < 2) continue;
      polylines.add(
        Polyline(
          points: segment,
          color: color.withValues(alpha: 0.82),
          strokeWidth: width,
          borderStrokeWidth: isTram ? 1.2 : 0.8,
          borderColor: Colors.white.withValues(alpha: 0.55),
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
    }
  }
  return polylines;
}
