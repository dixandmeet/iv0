import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/gtfs.dart';
import 'driver_map_marker.dart';

/// Mini-carte "ma position" encastrée dans le suivi de ligne : montre le point
/// GPS du conducteur au milieu des arrêts de sa ligne. Contrepartie donnée en
/// échange des informations supplémentaires demandées à la prise de service
/// (le conducteur ne voyait auparavant jamais sa propre position sur carte).
///
/// MapOptions et TileLayer sont construits une seule fois (jamais partagés
/// entre instances) : réutiliser une même config entre écrans casse le rendu
/// des tuiles flutter_map sur ce projet.
class DriverPositionMap extends StatefulWidget {
  final LatLng? userPosition;
  final List<GtfsStop> stops;
  final int currentStopIndex;

  const DriverPositionMap({
    super.key,
    required this.userPosition,
    required this.stops,
    required this.currentStopIndex,
  });

  @override
  State<DriverPositionMap> createState() => _DriverPositionMapState();
}

class _DriverPositionMapState extends State<DriverPositionMap> {
  static const _fallbackCenter = LatLng(47.2184, -1.5536); // Nantes, centre

  final MapController _mapController = MapController();
  late final MapOptions _options;
  TileLayer? _tiles;
  bool _centeredOnUser = false;

  LatLng get _initialCenter =>
      widget.userPosition ??
      (widget.stops.isNotEmpty ? widget.stops.first.position : _fallbackCenter);

  @override
  void initState() {
    super.initState();
    _centeredOnUser = widget.userPosition != null;
    _options = MapOptions(
      initialCenter: _initialCenter,
      initialZoom: 15,
      minZoom: 11,
      maxZoom: 18,
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant DriverPositionMap old) {
    super.didUpdateWidget(old);
    // Centre une seule fois dès que la position GPS devient disponible ;
    // jamais de recentrage forcé ensuite (casse le rendu des tuiles).
    final pos = widget.userPosition;
    if (!_centeredOnUser && pos != null) {
      _centeredOnUser = true;
      _mapController.move(pos, _options.initialZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    _tiles ??= TileLayer(
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.aule.pro',
      retinaMode: RetinaMode.isHighDensity(context),
      maxNativeZoom: 20,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 210,
        child: FlutterMap(
          mapController: _mapController,
          options: _options,
          children: [
            _tiles!,
            if (widget.stops.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.stops.map((s) => s.position).toList(),
                    strokeWidth: 3,
                    color: const Color(0xFF1F9D55),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (var i = 0; i < widget.stops.length; i++)
                  Marker(
                    point: widget.stops[i].position,
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    child:
                        TerrainStopDot(selected: i == widget.currentStopIndex),
                  ),
              ],
            ),
            if (widget.userPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.userPosition!,
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: const TerrainUserDot(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
