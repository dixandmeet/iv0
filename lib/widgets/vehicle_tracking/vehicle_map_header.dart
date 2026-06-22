import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../theme/app_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/gtfs.dart';
import '../../services/gtfs_service.dart';
import '../../services/walking_route_service.dart';
import '../../theme/aule_theme.dart';
import '../../utils/map_path_utils.dart';
import '../aule/aule_map_tiles.dart';

/// Header immersif (~35 % écran) — carte temps réel avec dégradé fondu.
class VehicleMapHeader extends StatefulWidget {
  final GtfsRoute route;
  final String headsign;
  final GtfsStop stop;
  final LatLng userPosition;
  final LatLng? vehiclePosition;
  final Color lineColor;
  final IconData vehicleIcon;
  final bool isApproaching;
  final bool isFavorite;
  /// Affiche un tracé marche utilisateur → arrêt et atténue la ligne TC.
  final bool walkingPath;
  /// Limite le tracé TC à ±[lineContextMeters] autour de l'arrêt cible.
  final double? lineContextMeters;
  /// Borne le tracé TC entre deux positions (ex. montée → descente).
  final LatLng? lineClipStart;
  final LatLng? lineClipEnd;
  /// Fraction de la hauteur écran (défaut 0,35).
  final double? heightFraction;
  final VoidCallback onBack;
  final VoidCallback onFavoriteToggle;

  const VehicleMapHeader({
    super.key,
    required this.route,
    required this.headsign,
    required this.stop,
    required this.userPosition,
    required this.vehiclePosition,
    required this.lineColor,
    required this.vehicleIcon,
    this.isApproaching = false,
    this.isFavorite = false,
    this.walkingPath = false,
    this.lineContextMeters,
    this.lineClipStart,
    this.lineClipEnd,
    this.heightFraction,
    required this.onBack,
    required this.onFavoriteToggle,
  });

  @override
  State<VehicleMapHeader> createState() => _VehicleMapHeaderState();
}

class _VehicleMapHeaderState extends State<VehicleMapHeader>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  List<LatLng> _walkPath = const [];
  int _walkRequestId = 0;
  bool _mapReady = false;
  // Options et fond de carte figés : recréer un MapOptions ou un TileLayer
  // à chaque build fait réinitialiser le TileLayer (chargements de tuiles
  // avortés en boucle).
  MapOptions? _mapOptions;
  TileLayer? _tileLayer;
  bool? _mapOptionsDark;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshWalkPath());
  }

  @override
  void didUpdateWidget(VehicleMapHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved = oldWidget.userPosition != widget.userPosition ||
        oldWidget.stop.stopId != widget.stop.stopId;
    if (moved || oldWidget.walkingPath != widget.walkingPath) {
      _refreshWalkPath();
    }
    // Pas de refit sur le déplacement du véhicule : il suit le tracé déjà
    // couvert, et refit en boucle empêche les tuiles de se charger.
    if (moved ||
        oldWidget.lineClipStart != widget.lineClipStart ||
        oldWidget.lineClipEnd != widget.lineClipEnd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitOverview());
    }
  }

  void _refreshWalkPath() {
    if (!widget.walkingPath) {
      _walkPath = const [];
      return;
    }

    final gtfs = context.read<GtfsService>();
    final snappedStop = gtfs.snapToRouteShape(
      widget.route,
      widget.stop,
      headsign: widget.headsign,
    );
    final from = widget.userPosition;
    final requestId = ++_walkRequestId;

    _walkPath = WalkingRouteService.immediate(from, snappedStop);
    WalkingRouteService.resolve(from, snappedStop).then((path) {
      if (!mounted || requestId != _walkRequestId) return;
      setState(() => _walkPath = path);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitOverview());
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
  }

  /// Points à cadrer (marche : chemin piéton ; sinon ligne complète).
  List<LatLng> _overviewPoints(GtfsService gtfs, LatLng snappedStop) {
    if (widget.walkingPath) {
      return [..._walkPath, widget.userPosition, snappedStop];
    }
    final shape = MapPathUtils.densify(
      gtfs.shapeToward(widget.route, widget.headsign, via: widget.stop),
    );
    return [
      widget.userPosition,
      snappedStop,
      if (widget.vehiclePosition != null) widget.vehiclePosition!,
      ...shape,
    ];
  }

  EdgeInsets get _fitPadding => EdgeInsets.fromLTRB(
        48,
        72,
        48,
        widget.walkingPath ? 72 : 96,
      );

  void _fitOverview() {
    if (!mounted || !_mapReady) return;

    final gtfs = context.read<GtfsService>();
    final snappedStop = gtfs.snapToRouteShape(
      widget.route,
      widget.stop,
      headsign: widget.headsign,
    );
    final points = _overviewPoints(gtfs, snappedStop);
    if (points.length < 2) return;

    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: _fitPadding,
        ),
      );
    } catch (_) {
      _mapController.move(snappedStop, 15.8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final headerH = screenH * (widget.heightFraction ?? 0.35);
    final c = AuleTheme.of(context);
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

    final polylines = <Polyline>[];
    if (widget.walkingPath) {
      polylines.addAll(
        MapPathUtils.walkGuidancePolylines(
          walkPath: _walkPath,
          transitShape: shape,
          stopOnLine: snappedStop,
          lineColor: widget.lineColor,
        ),
      );
    } else {
      polylines.addAll(
        MapPathUtils.transitGuidancePolylines(
          shape: shape,
          focusStop: snappedStop,
          lineColor: widget.lineColor,
          vehicle: vehicle,
          clipStart: widget.lineClipStart,
          clipEnd: widget.lineClipEnd,
          contextMeters: widget.lineClipStart == null && widget.lineClipEnd == null
              ? widget.lineContextMeters
              : null,
        ),
      );
    }

    if (_mapOptions == null || _mapOptionsDark != c.isDark) {
      final overviewPoints = _overviewPoints(gtfs, snappedStop);
      _mapOptionsDark = c.isDark;
      _tileLayer = AuleMapTiles.layer(context, c);
      _mapOptions = overviewPoints.length >= 2
          ? MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(overviewPoints),
                padding: _fitPadding,
              ),
              maxZoom: 18,
              minZoom: 12,
              backgroundColor: c.mapBg,
              onMapReady: _onMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            )
          : MapOptions(
              initialCenter: snappedStop,
              initialZoom: 15.8,
              maxZoom: 18,
              minZoom: 12,
              backgroundColor: c.mapBg,
              onMapReady: _onMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            );
    }

    return SizedBox(
      height: headerH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ClipRect(
              child: FlutterMap(
                mapController: _mapController,
                options: _mapOptions!,
                children: [
                  _tileLayer!,
                  PolylineLayer(polylines: polylines),
                  MarkerLayer(
                    markers: [
                      if (vehicle != null)
                        Marker(
                          point: vehicle,
                          width: 52,
                          height: 52,
                          child: _AnimatedVehicleMarker(
                            controller: _pulseController,
                            color: widget.lineColor,
                            icon: widget.vehicleIcon,
                            isApproaching: widget.isApproaching,
                          ),
                        ),
                      Marker(
                        point: snappedStop,
                        width: 80,
                        height: 56,
                        alignment: Alignment.bottomCenter,
                        child: _StopPin(
                          label: widget.stop.stopName,
                          color: widget.lineColor,
                        ),
                      ),
                      Marker(
                        point: widget.userPosition,
                        width: 48,
                        height: 48,
                        child: _UserLocationDot(controller: _pulseController),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Fondu léger vers le bas pour laisser la carte visible.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.walkingPath
                        ? [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.25),
                            Colors.white.withValues(alpha: 0.72),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0.82),
                          ],
                    stops: const [0.0, 0.5, 0.82, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _HeaderFab(
                    icon: LucideIcons.arrowLeft,
                    onTap: widget.onBack,
                  ),
                  const Spacer(),
                  _HeaderFab(
                    icon: widget.isFavorite
                        ? LucideIcons.star
                        : LucideIcons.star,
                    filled: widget.isFavorite,
                    onTap: widget.onFavoriteToggle,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _HeaderFab({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: filled ? const Color(0xFFF59E0B) : const Color(0xFF0B1220),
            fill: filled ? 1.0 : 0.0,
          ),
        ),
      ),
    );
  }
}

class _UserLocationDot extends StatelessWidget {
  final AnimationController controller;

  const _UserLocationDot({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 28 + t * 14,
              height: 28 + t * 14,
              decoration: BoxDecoration(
                color: const Color(0xFF1B66F5).withValues(alpha: 0.12 - t * 0.06),
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
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B66F5).withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedVehicleMarker extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final IconData icon;
  final bool isApproaching;

  const _AnimatedVehicleMarker({
    required this.controller,
    required this.color,
    required this.icon,
    required this.isApproaching,
  });

  @override
  Widget build(BuildContext context) {
    final haloColor =
        isApproaching ? const Color(0xFFF59E0B) : color;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            if (isApproaching)
              Container(
                width: 44 + t * 16,
                height: 44 + t * 16,
                decoration: BoxDecoration(
                  color: haloColor.withValues(alpha: 0.18 - t * 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
          ],
        );
      },
    );
  }
}

class _StopPin extends StatelessWidget {
  final String label;
  final Color color;

  const _StopPin({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: hankenGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0B1220),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Icon(
          LucideIcons.mapPin,
          size: 28,
          color: color,
          fill: 1.0,
        ),
      ],
    );
  }
}
