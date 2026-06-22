import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/gtfs.dart';
import '../../services/aule_data_adapter.dart';
import '../../theme/aule_theme.dart';
import 'aule_map_tiles.dart';

/// Plan réseau plein écran — tuiles CartoDB + tracés GTFS.
///
/// Inspiré de l'app officielle Naolib : les arrêts sont regroupés en
/// pastilles à comptage quand on dézoome, puis éclatés en arrêts unitaires
/// quand on zoome. Un appui sur une grappe zoome dessus.
class AuleNetworkMapView extends StatefulWidget {
  final LatLng center;
  final List<GtfsRoute> routes;
  final List<GtfsStop> stops;
  final String? selectedLine;

  /// Modes de transport visibles. `null` => tous.
  final Set<AuleLineMode>? activeModes;
  final LatLng? userPosition;
  final void Function(GtfsStop stop)? onStopTap;
  final MapController? controller;

  const AuleNetworkMapView({
    super.key,
    required this.center,
    required this.routes,
    required this.stops,
    this.selectedLine,
    this.activeModes,
    this.userPosition,
    this.onStopTap,
    this.controller,
  });

  @override
  State<AuleNetworkMapView> createState() => _AuleNetworkMapViewState();
}

class _AuleNetworkMapViewState extends State<AuleNetworkMapView> {
  static const _initialZoom = 13.2;

  late final MapController _controller = widget.controller ?? MapController();
  double _zoom = _initialZoom;

  Color _routeColor(GtfsRoute route) {
    final hex = route.routeColor;
    if (hex != null && hex.isNotEmpty) {
      try {
        return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }
    return AuleLineColors.forLine(AuleDataAdapter.lineCode(route));
  }

  bool _lineVisible(String code) =>
      widget.selectedLine == null ||
      widget.selectedLine == 'Tout' ||
      widget.selectedLine == code;

  bool _modeVisible(GtfsRoute route) {
    final modes = widget.activeModes;
    if (modes == null || modes.isEmpty) return true;
    return modes.contains(AuleDataAdapter.modeFrom(route.transportType));
  }

  void _onMapEvent(MapEvent event) {
    final z = event.camera.zoom;
    if ((z - _zoom).abs() > 0.04) setState(() => _zoom = z);
  }

  /// Taille d'une cellule de regroupement (en degrés de longitude) telle
  /// qu'elle corresponde à ~`_clusterPx` pixels au zoom courant.
  static const _clusterPx = 64.0;
  double _cellSize(double zoom) =>
      _clusterPx * 360.0 / (256.0 * math.pow(2, zoom));

  /// Regroupe les arrêts dans une grille adaptée au zoom.
  List<_Cluster> _buildClusters(double zoom) {
    final cell = _cellSize(zoom);
    final buckets = <int, _Cluster>{};
    for (final stop in widget.stops) {
      final gx = (stop.position.longitude / cell).floor();
      final gy = (stop.position.latitude / cell).floor();
      // Clé de grille combinée (les coordonnées tiennent largement sur 32 bits).
      final key = gx * 100000 + gy;
      (buckets[key] ??= _Cluster()).add(stop);
    }
    return buckets.values.toList(growable: false);
  }

  void _zoomOn(LatLng target) {
    final next = (_zoom + 2).clamp(11.0, 17.0).toDouble();
    _controller.move(target, next);
  }

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);

    final polylines = <Polyline>[];
    for (final route in widget.routes) {
      final code = AuleDataAdapter.lineCode(route);
      final color = _routeColor(route);
      final shown = _lineVisible(code) && _modeVisible(route);
      final opacity = shown ? 1.0 : 0.12;
      for (final segment in route.shapes) {
        if (segment.length < 2) continue;
        polylines.add(Polyline(
          points: segment,
          color: color.withValues(alpha: opacity),
          strokeWidth: 2.5,
          borderColor: color.withValues(alpha: opacity * 0.3),
          borderStrokeWidth: 4,
        ));
      }
    }

    final clusters = _buildClusters(_zoom);
    final markers = <Marker>[];
    for (final cluster in clusters) {
      if (cluster.count == 1) {
        final stop = cluster.stops.first;
        markers.add(Marker(
          point: stop.position,
          width: 26,
          height: 26,
          alignment: Alignment.center,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onStopTap == null
                ? null
                : () => widget.onStopTap!(stop),
            child: const Center(child: _StopDot()),
          ),
        ));
      } else {
        markers.add(Marker(
          point: cluster.center,
          width: 46,
          height: 46,
          alignment: Alignment.center,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _zoomOn(cluster.center),
            child: _ClusterBadge(count: cluster.count, colors: c),
          ),
        ));
      }
    }

    if (widget.userPosition != null) {
      markers.add(Marker(
        point: widget.userPosition!,
        width: 22,
        height: 22,
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
      ));
    }

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: _initialZoom,
        minZoom: 11,
        maxZoom: 17,
        onMapEvent: _onMapEvent,
      ),
      children: [
        AuleMapTiles.layer(context, c),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

/// Accumulateur de regroupement d'arrêts.
class _Cluster {
  final List<GtfsStop> stops = [];
  double _sumLat = 0;
  double _sumLng = 0;

  void add(GtfsStop stop) {
    stops.add(stop);
    _sumLat += stop.position.latitude;
    _sumLng += stop.position.longitude;
  }

  int get count => stops.length;
  LatLng get center => LatLng(_sumLat / count, _sumLng / count);
}

/// Pastille blanche d'un arrêt unitaire.
class _StopDot extends StatelessWidget {
  const _StopDot();

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: c.surface,
        shape: BoxShape.circle,
        border: Border.all(color: c.muted.withValues(alpha: 0.7), width: 2),
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: 0.18), blurRadius: 3),
        ],
      ),
    );
  }
}

/// Grappe d'arrêts façon Naolib : disque blanc + comptage.
class _ClusterBadge extends StatelessWidget {
  final int count;
  final AuleColors colors;
  const _ClusterBadge({required this.count, required this.colors});

  @override
  Widget build(BuildContext context) {
    // Disque qui grossit légèrement avec le nombre d'arrêts.
    final size = (38.0 + math.min(count, 40) * 0.18).clamp(38.0, 46.0);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colors.line, width: 1.5),
        boxShadow: AuleTokens.cardShadow(colors.shadow),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: count > 99 ? 12 : 14,
          fontWeight: FontWeight.w800,
          color: colors.text,
        ),
      ),
    );
  }
}
