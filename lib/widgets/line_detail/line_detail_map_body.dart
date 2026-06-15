import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/gtfs.dart';
import '../../services/gtfs_service.dart';
import '../../theme/aule_theme.dart';
import '../../utils/map_path_utils.dart';
import '../aule/aule_map_tiles.dart';

/// Corps de carte réutilisable (embarquée ou plein écran).
class LineDetailMapBody extends StatefulWidget {
  final GtfsRoute route;
  final String headsign;
  final GtfsStop stop;
  final LatLng userPosition;
  final LatLng? vehiclePosition;
  final Color lineColor;
  final int waitMinutes;
  final IconData vehicleIcon;
  final bool showControls;
  final VoidCallback? onFullscreen;
  final MapController? mapController;

  const LineDetailMapBody({
    super.key,
    required this.route,
    required this.headsign,
    required this.stop,
    required this.userPosition,
    required this.vehiclePosition,
    required this.lineColor,
    required this.waitMinutes,
    this.vehicleIcon = LucideIcons.bus,
    this.showControls = true,
    this.onFullscreen,
    this.mapController,
  });

  @override
  State<LineDetailMapBody> createState() => _LineDetailMapBodyState();
}

class _LineDetailMapBodyState extends State<LineDetailMapBody> {
  late final MapController _ownController;
  bool _mapReady = false;
  // Options et fond de carte figés : recréer un MapOptions ou un TileLayer
  // à chaque build (identité/retinaMode instables) fait réinitialiser le
  // TileLayer par flutter_map à chaque rebuild — les chargements de tuiles
  // sont avortés en boucle.
  MapOptions? _mapOptions;
  TileLayer? _tileLayer;
  bool? _mapOptionsDark;

  MapController get _controller => widget.mapController ?? _ownController;

  @override
  void initState() {
    super.initState();
    _ownController = MapController();
  }

  static const _distance = Distance();

  @override
  void didUpdateWidget(LineDetailMapBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refit seulement sur changement significatif : un fitCamera programmé
    // casse le chargement des tuiles (flutter_map ne les recharge qu'au
    // prochain geste), donc pas question d'en émettre à chaque jitter GPS
    // ni à chaque déplacement du véhicule (déjà couvert par le cadrage).
    final movedFar = _distance.as(
          LengthUnit.Meter,
          oldWidget.userPosition,
          widget.userPosition,
        ) >
        50;
    if (movedFar || oldWidget.headsign != widget.headsign) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitOverview());
    }
  }

  @override
  void dispose() {
    if (widget.mapController == null) {
      _ownController.dispose();
    }
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
  }

  /// Cadrage d'ensemble : utilisateur + arrêt + véhicule + tracé.
  /// Appliqué via [MapOptions.initialCameraFit] — un fitCamera après coup
  /// (post-frame / onMapReady) désynchronisait le TileLayer de la caméra :
  /// les tuiles du zoom initial restaient peintes en miniature.
  CameraFit? _overviewFit(List<LatLng> shape, LatLng snappedStop) {
    final points = <LatLng>[
      widget.userPosition,
      snappedStop,
      if (widget.vehiclePosition != null) widget.vehiclePosition!,
      ...shape,
    ];
    if (points.length < 2) return null;
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.all(56),
    );
  }

  void _recenterOnUser() {
    if (!_mapReady) return;
    _controller.move(widget.userPosition, 16.2);
  }

  void _fitOverview() {
    if (!mounted || !_mapReady) return;
    final gtfs = context.read<GtfsService>();
    final shape = MapPathUtils.densify(
      gtfs.shapeToward(widget.route, widget.headsign, via: widget.stop),
    );
    final snappedStop = gtfs.snapToRouteShape(
      widget.route,
      widget.stop,
      headsign: widget.headsign,
    );
    final fit = _overviewFit(shape, snappedStop);
    if (fit == null) return;
    _controller.fitCamera(fit);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);
    final fabBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryText =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);

    final gtfs = context.watch<GtfsService>();
    final rawShape =
        gtfs.shapeToward(widget.route, widget.headsign, via: widget.stop);
    final shape = MapPathUtils.densify(rawShape);
    final snappedStop = gtfs.snapToRouteShape(
      widget.route,
      widget.stop,
      headsign: widget.headsign,
    );
    final vehicle = widget.vehiclePosition;
    final walkPath = MapPathUtils.walkingPath(
      widget.userPosition,
      snappedStop,
    );

    final polylines = <Polyline>[];

    if (shape.length >= 2) {
      final vehicleIdx = vehicle != null
          ? MapPathUtils.nearestIndex(shape, vehicle)
          : MapPathUtils.nearestIndex(shape, snappedStop);

      final passed = MapPathUtils.slice(shape, 0, vehicleIdx);
      final ahead = MapPathUtils.slice(shape, vehicleIdx, shape.length - 1);

      if (passed.length >= 2) {
        polylines.add(
          Polyline(
            points: passed,
            color: widget.lineColor.withValues(alpha: 0.28),
            strokeWidth: 5,
          ),
        );
      }
      if (ahead.length >= 2) {
        polylines.add(
          Polyline(
            points: ahead,
            color: widget.lineColor.withValues(alpha: 0.22),
            strokeWidth: 9,
          ),
        );
        polylines.add(
          Polyline(
            points: ahead,
            color: widget.lineColor.withValues(alpha: 0.95),
            strokeWidth: 5.5,
          ),
        );
      }
    }

    if (walkPath.length >= 2) {
      polylines.add(
        Polyline(
          points: walkPath,
          color: const Color(0xFF1B66F5).withValues(alpha: 0.35),
          strokeWidth: 4,
          borderStrokeWidth: 1.5,
          borderColor: Colors.white.withValues(alpha: 0.85),
        ),
      );
      polylines.add(
        Polyline(
          points: walkPath,
          color: const Color(0xFF1B66F5).withValues(alpha: 0.75),
          strokeWidth: 2.5,
        ),
      );
    }

    final markers = <Marker>[
      if (vehicle != null)
        Marker(
          point: vehicle,
          width: 36,
          height: 36,
          child: Container(
            decoration: BoxDecoration(
              color: widget.lineColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: widget.lineColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(widget.vehicleIcon, color: Colors.white, size: 16),
          ),
        ),
      Marker(
        point: snappedStop,
        width: 20,
        height: 20,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: widget.lineColor, width: 3),
          ),
        ),
      ),
      Marker(
        point: widget.userPosition,
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
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
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ],
        ),
      ),
    ];

    if (_mapOptions == null || _mapOptionsDark != isDark) {
      final overviewFit = _overviewFit(shape, snappedStop);
      _mapOptionsDark = isDark;
      _tileLayer = AuleMapTiles.layer(context, c);
      _mapOptions = overviewFit != null
          ? MapOptions(
              initialCameraFit: overviewFit,
              maxZoom: 18.0,
              minZoom: 12.0,
              backgroundColor: c.mapBg,
              onMapReady: _onMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            )
          : MapOptions(
              initialCenter: snappedStop,
              initialZoom: 15.5,
              maxZoom: 18.0,
              minZoom: 12.0,
              backgroundColor: c.mapBg,
              onMapReady: _onMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _controller,
            options: _mapOptions!,
            children: [
              _tileLayer!,
              PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
        if (widget.showControls)
          Positioned(
            right: 12,
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onFullscreen != null) ...[
                  _CircleFab(
                    icon: LucideIcons.maximize2,
                    onTap: widget.onFullscreen!,
                    bg: fabBg,
                    border: borderCol,
                    iconColor: primaryText,
                    tooltip: 'Plein écran',
                  ),
                  const SizedBox(width: 8),
                ],
                _CircleFab(
                  icon: LucideIcons.crosshair,
                  onTap: _recenterOnUser,
                  bg: fabBg,
                  border: borderCol,
                  iconColor: primaryText,
                  tooltip: 'Recentrer',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CircleFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color bg;
  final Color border;
  final Color iconColor;
  final String? tooltip;

  const _CircleFab({
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.border,
    required this.iconColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
        ),
      ),
    );
  }
}
