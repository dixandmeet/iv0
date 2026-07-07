import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../models/driver/terrain_marker.dart';
import '../../widgets/driver/driver_map_marker.dart';

/// Paliers de clustering progressif.
enum TerrainClusterTier {
  global,
  byLine,
  individual,
}

class TerrainClusterItem {
  final LatLng center;
  final int count;
  final TerrainMarkerType? dominantType;
  final String? line;
  final List<TerrainMarker> members;
  final String id;

  const TerrainClusterItem({
    required this.center,
    required this.count,
    required this.id,
    this.dominantType,
    this.line,
    this.members = const [],
  });

  bool get isCluster => count > 1;
}

/// Clustering progressif : global → lignes → individus.
class TerrainClusterEngine {
  static const clusterPx = 72.0;
  static const globalZoomThreshold = 13.0;
  static const lineZoomThreshold = 15.0;

  static TerrainClusterTier tierForZoom(double zoom) {
    if (zoom < globalZoomThreshold) return TerrainClusterTier.global;
    if (zoom < lineZoomThreshold) return TerrainClusterTier.byLine;
    return TerrainClusterTier.individual;
  }

  static double cellSize(double zoom, {double px = clusterPx}) =>
      px * 360.0 / (256.0 * math.pow(2, zoom));

  static List<TerrainClusterItem> cluster({
    required List<TerrainMarker> markers,
    required double zoom,
    ClusterViewportBounds? viewport,
    String? selectedId,
    double viewportPadding = 0.1,
  }) {
    final tier = tierForZoom(zoom);
    final visible = _filterViewport(markers, viewport, viewportPadding);
    if (tier == TerrainClusterTier.individual) {
      return visible
          .map((m) => TerrainClusterItem(
                center: m.position,
                count: 1,
                id: m.id,
                dominantType: m.type,
                line: m.line,
                members: [m],
              ))
          .toList();
    }

    final cell = cellSize(zoom);
    final buckets = <int, List<TerrainMarker>>{};
    final solo = <TerrainMarker>[];

    for (final m in visible) {
      if (m.id == selectedId) {
        solo.add(m);
        continue;
      }
      final gx = (m.position.longitude / cell).floor();
      final gy = (m.position.latitude / cell).floor();
      (buckets[gx * 100000 + gy] ??= []).add(m);
    }

    final items = <TerrainClusterItem>[];

    buckets.forEach((key, group) {
      if (group.length == 1) {
        solo.add(group.first);
        return;
      }

      if (tier == TerrainClusterTier.global) {
        items.add(_globalCluster(key, group));
      } else {
        items.addAll(_lineSubClusters(key, group));
      }
    });

    for (final m in solo) {
      items.add(TerrainClusterItem(
        center: m.position,
        count: 1,
        id: m.id,
        dominantType: m.type,
        line: m.line,
        members: [m],
      ));
    }

    return items;
  }

  static TerrainClusterItem _globalCluster(int key, List<TerrainMarker> group) {
    return TerrainClusterItem(
      center: _centroid(group),
      count: group.length,
      id: 'cluster:$key',
      dominantType: _dominantType(group),
      members: group,
    );
  }

  static List<TerrainClusterItem> _lineSubClusters(
    int key,
    List<TerrainMarker> group,
  ) {
    final byLine = <String, List<TerrainMarker>>{};
    for (final m in group) {
      final line = m.line ?? _shortType(m.type);
      (byLine[line] ??= []).add(m);
    }

    final sorted = byLine.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return sorted.take(4).map((e) {
      return TerrainClusterItem(
        center: _centroid(e.value),
        count: e.value.length,
        id: 'cluster:$key:${e.key}',
        dominantType: e.value.first.type,
        line: e.key,
        members: e.value,
      );
    }).toList();
  }

  static List<TerrainMarker> _filterViewport(
    List<TerrainMarker> markers,
    ClusterViewportBounds? viewport,
    double padding,
  ) {
    if (viewport == null) return markers;
    final latPad = (viewport.north - viewport.south).abs() * padding;
    final lngPad = (viewport.east - viewport.west).abs() * padding;
    return markers.where((m) {
      final lat = m.position.latitude;
      final lng = m.position.longitude;
      return lat >= viewport.south - latPad &&
          lat <= viewport.north + latPad &&
          lng >= viewport.west - lngPad &&
          lng <= viewport.east + lngPad;
    }).toList();
  }

  static String _shortType(TerrainMarkerType type) => switch (type) {
        TerrainMarkerType.bus => 'Bus',
        TerrainMarkerType.tram => 'Tram',
        TerrainMarkerType.controle => 'CTL',
        TerrainMarkerType.msr => 'MSR',
        TerrainMarkerType.incident => 'INC',
        TerrainMarkerType.assistance => 'ASS',
        TerrainMarkerType.arret => 'ARR',
      };

  static LatLng _centroid(List<TerrainMarker> group) {
    var lat = 0.0, lng = 0.0;
    for (final m in group) {
      lat += m.position.latitude;
      lng += m.position.longitude;
    }
    return LatLng(lat / group.length, lng / group.length);
  }

  static TerrainMarkerType _dominantType(List<TerrainMarker> group) {
    final counts = <TerrainMarkerType, int>{};
    for (final m in group) {
      counts[m.type] = (counts[m.type] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

class ClusterViewportBounds {
  final double north;
  final double south;
  final double east;
  final double west;

  const ClusterViewportBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });
}
