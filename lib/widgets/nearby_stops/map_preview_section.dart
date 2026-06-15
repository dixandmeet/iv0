import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/gtfs.dart';
import '../../models/stop_data.dart';
import '../../services/gtfs_service.dart';
import '../../theme/aule_theme.dart';
import '../aule/aule_map_tiles.dart';
import 'line_badge.dart';

class MapPreviewSection extends StatefulWidget {
  final StopData? selectedStop;
  final LatLng userPosition;

  const MapPreviewSection({
    super.key,
    required this.selectedStop,
    required this.userPosition,
  });

  @override
  State<MapPreviewSection> createState() => _MapPreviewSectionState();
}

class _MapPreviewSectionState extends State<MapPreviewSection>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapPreviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedStop != oldWidget.selectedStop &&
        widget.selectedStop != null) {
      _animatedMapMove(widget.selectedStop!.position, 16.0);
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    _animationController?.reset();

    final Animation<double> animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.fastOutSlowIn,
    );

    _animationController!.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    _animationController!.forward();
  }

  void _recenterOnUser() {
    _animatedMapMove(widget.userPosition, 16.2);
  }

  Color _getRouteColor(GtfsRoute route) {
    final hex = route.routeColor;
    if (hex != null && hex.isNotEmpty) {
      try {
        return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }
    
    final label = route.routeShortName ?? route.routeId;
    switch (label.toUpperCase()) {
      case '1':
        return const Color(0xFF16A34A); // Green
      case 'C6':
        return const Color(0xFF8B258F); // Purple
      case '23':
        return const Color(0xFF007BC4); // Blue
      case '75':
        return const Color(0xFFF29400); // Orange
      case '80':
        return const Color(0xFFFBC02D); // Yellow
      case 'C1':
        return const Color(0xFFE30613); // Red
      case '12':
        return const Color(0xFF4FAADB); // Light Blue
      case '96':
        return const Color(0xFF8EC63F); // Light Green
      case 'C2':
        return const Color(0xFF00A650); // Dark Green
      case '30':
        return const Color(0xFFE5007D); // Pink
      case 'C20':
        return const Color(0xFF003A70); // Dark Indigo
      case 'E1':
        return const Color(0xFF009BA4); // Teal
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Fallback if AuleTheme isn't initialized above
    final c = isDark ? AuleColors.dark : AuleColors.light;

    final gtfs = context.watch<GtfsService>();
    final borderCol = isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);
    final fabBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    const fabIconColor = Color(0xFF1B66F5);

    // List of active polylines to draw
    final polylinesList = <Polyline>[];
    final markersList = <Marker>[];

    // Find the real NearbyStation corresponding to our selectedStop
    NearbyStation? selectedStation;
    if (widget.selectedStop != null) {
      for (final s in gtfs.cachedStops) {
        if (s.stopId == widget.selectedStop!.id) {
          final station = gtfs.nearbyStationFor(s, from: widget.userPosition);
          if (station != null) {
            selectedStation = station;
            break;
          }
        }
      }
    }

    // Load active routes from selected stop and map them to polylines
    if (selectedStation != null) {
      for (final route in selectedStation.routes) {
        final shapes = gtfs.displayShapes(route);
        final color = _getRouteColor(route);
        for (final pts in shapes) {
          if (pts.length >= 2) {
            polylinesList.add(
              Polyline(
                points: pts,
                color: color.withValues(alpha: 0.8),
                strokeWidth: 4,
              ),
            );
          }
        }
      }
    }

    // Load nearby stations (limit to 12) to place markers on the map
    final nearbyStations = gtfs.nearbyStations(widget.userPosition, limit: 12, maxMeters: 500);

    for (final station in nearbyStations) {
      final isSelected = widget.selectedStop?.id == station.stop.stopId;
      final hasRoutes = station.routes.isNotEmpty;
      final mainRouteName = hasRoutes ? (station.routes.first.routeShortName ?? station.routes.first.routeId) : '';

      // Draw highlighting ring for selected stop
      if (isSelected) {
        markersList.add(
          Marker(
            point: station.stop.position,
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF1B66F5).withValues(alpha: 0.4),
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Draw custom line badges on the map at stops coordinates
      if (hasRoutes && mainRouteName.isNotEmpty) {
        markersList.add(
          Marker(
            point: station.stop.position,
            width: 32,
            height: 32,
            child: Center(
              child: LineBadge(
                label: mainRouteName,
                height: 18,
                fontSize: 9,
              ),
            ),
          ),
        );
      } else {
        // Draw simple dot for stops without loaded route names
        markersList.add(
          Marker(
            point: station.stop.position,
            width: 12,
            height: 12,
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF9AA4B2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }
    }

    // Draw user position marker
    markersList.add(
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
                border: Border.all(
                  color: const Color(0xFF1B66F5).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF1B66F5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderCol, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Map Layer
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      widget.selectedStop?.position ?? widget.userPosition,
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

                  // Real Polylines for transit routes serving selected stop
                  PolylineLayer(polylines: polylinesList),

                  // Real stops & User markers
                  MarkerLayer(markers: markersList),
                ],
              ),
            ),

            // Locate GPS floating button
            Positioned(
              right: 16,
              bottom: 16,
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
                    LucideIcons.compass,
                    color: fabIconColor,
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
