import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/driver/terrain_map_layers.dart';
import '../../../models/driver/terrain_marker.dart';
import '../../../models/driver/terrain_user_marker_style.dart';
import '../../../models/gtfs.dart';
import '../../../services/driver/terrain_cluster_engine.dart';
import '../../../services/driver/terrain_feed.dart';
import '../../../services/driver/terrain_live_engine.dart';
import '../../../services/driver/terrain_selection_controller.dart';
import '../../../utils/map_path_utils.dart';
import '../../../widgets/driver/driver_map_marker.dart';

/// Carte Terrain temps réel avec clustering progressif et mode Live.
class TerrainMap extends StatefulWidget {
  final LatLng? userPosition;
  final double? userAccuracyMeters;
  final TerrainUserMarkerStyle userMarkerStyle;
  final double userHeadingDeg;
  final TerrainSelectionController controller;
  final SupabaseClient? supabaseClient;
  final List<GtfsStation> stations;
  final List<Polyline> linePolylines;
  final List<LatLng>? walkingRoute;

  /// Tracés GTFS par libellé de ligne (« C6 », « 1 »…) : la couche d'ambiance
  /// simulée fait suivre aux véhicules l'itinéraire de leur ligne.
  final Map<String, List<LatLng>> routePaths;
  final ValueChanged<TerrainMarker> onMarkerTapped;

  const TerrainMap({
    super.key,
    required this.userPosition,
    this.userAccuracyMeters,
    this.userMarkerStyle = TerrainUserMarkerStyle.blueDot,
    this.userHeadingDeg = 0,
    required this.controller,
    required this.supabaseClient,
    this.stations = const [],
    this.linePolylines = const [],
    this.walkingRoute,
    this.routePaths = const {},
    required this.onMarkerTapped,
  });

  @override
  State<TerrainMap> createState() => TerrainMapState();
}

class TerrainMapState extends State<TerrainMap>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final MapOptions _options;
  TileLayer? _tiles;
  late final TerrainFeed _feed;
  final TerrainLiveEngine _liveEngine = TerrainLiveEngine();
  final ValueNotifier<int> _repaint = ValueNotifier(0);
  // Bump uniquement quand la carte bouge (pan/zoom) — pilote le calque arrêts
  // sans le coupler aux 60 fps de l'animation véhicules.
  final ValueNotifier<int> _mapEpoch = ValueNotifier(0);

  /// En dessous de ce zoom, les arrêts sont masqués (sinon le réseau entier —
  /// >1000 arrêts — serait rendu d'un coup au dézoom → saturation/crash).
  static const _stationMinZoom = 14.0;
  static const _stationMaxRender = 220;

  Ticker? _ticker;
  Duration _last = Duration.zero;
  double _zoom = 14.6;
  bool _centeredOnUser = false;
  int _visibleMarkerCount = 0;
  double _repaintAccum = 0;

  @override
  void initState() {
    super.initState();
    final center = widget.userPosition ?? kTerrainDefaultCenter;
    _centeredOnUser = widget.userPosition != null;
    _options = MapOptions(
      initialCenter: center,
      initialZoom: _zoom,
      minZoom: 11,
      maxZoom: 18,
      backgroundColor: const Color(0xFFEDF2EE),
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
      onMapEvent: _onMapEvent,
    );
    _feed = TerrainFeed(client: widget.supabaseClient)..seed(center);
    _feed.applyRoutePaths(widget.routePaths);
    _feed.startRealtime(() {
      if (mounted) _repaint.value++;
    });
    _ticker = createTicker(_onTick)..start();
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    final target = widget.controller.cameraTarget;
    final zoom = widget.controller.cameraZoom;
    if (target != null) {
      _mapController.move(target, zoom ?? _zoom);
      widget.controller.clearCameraRequest();
    }
  }

  void _onMapEvent(MapEvent e) {
    // Le calque arrêts dépend du viewport (pan + zoom) mais PAS de l'animation :
    // on le rafraîchit ici, pas à chaque frame du ticker.
    _mapEpoch.value++;
    final z = e.camera.zoom;
    if ((z - _zoom).abs() > 0.05) {
      _zoom = z;
      widget.controller.setMapZoom(z);
      _repaint.value++;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final now = DateTime.now();
    _feed.advance(dt.clamp(0.0, 0.1), now);

    final markers = _visibleFeedMarkers(now);
    _liveEngine.tick(
      markers: markers,
      dt: dt,
      liveEnabled: widget.controller.liveEnabled,
    );

    _visibleMarkerCount = markers.length;
    // Throttle par temps accumulé : 60 fps en charge normale, plafonné à ~30 fps
    // au-delà de 500 marqueurs. (Tester `dt` brut figeait l'animation car le
    // delta par frame n'atteint jamais le seuil.)
    _repaintAccum += dt;
    final interval = _visibleMarkerCount > 500 ? 0.033 : 0.0;
    if (_repaintAccum >= interval) {
      _repaintAccum = 0;
      _repaint.value++;
    }
  }

  List<TerrainMarker> _visibleFeedMarkers(DateTime now) {
    final layers = widget.controller.layers;
    final filter = widget.controller.activeFilterType;
    final list = <TerrainMarker>[];

    for (final m in _feed.snapshot(now)) {
      if (filter != null && m.type != filter) continue;
      if (!_typeVisible(m.type, layers)) continue;
      if (m.isVehicle && m.freshnessAt(now) == TerrainFreshness.hidden) {
        continue;
      }
      list.add(m);
    }
    return list;
  }

  bool _typeVisible(TerrainMarkerType type, TerrainMapLayers layers) {
    return switch (type) {
      TerrainMarkerType.bus || TerrainMarkerType.tram => layers.vehicles,
      TerrainMarkerType.controle => layers.controle,
      TerrainMarkerType.msr => layers.msr,
      TerrainMarkerType.incident => layers.incidents,
      TerrainMarkerType.assistance => layers.incidents,
      TerrainMarkerType.arret => layers.stations,
    };
  }

  ClusterViewportBounds? _viewportBounds() {
    try {
      final bounds = _mapController.camera.visibleBounds;
      return ClusterViewportBounds(
        north: bounds.north,
        south: bounds.south,
        east: bounds.east,
        west: bounds.west,
      );
    } catch (_) {
      return null;
    }
  }

  List<Marker> _buildVehicleMarkers() {
    final now = DateTime.now();
    final selectedId = widget.controller.selectedMarker?.id;
    final markers = _visibleFeedMarkers(now);

    final clusters = TerrainClusterEngine.cluster(
      markers: markers,
      zoom: _zoom,
      viewport: _viewportBounds(),
      selectedId: selectedId,
    );

    final result = <Marker>[];

    for (final item in clusters) {
      if (item.isCluster) {
        result.add(
          Marker(
            key: ValueKey(item.id),
            point: item.center,
            width: 88,
            height: 44,
            alignment: Alignment.center,
            child: SizedBox(
              width: 88,
              height: 44,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: TerrainClusterMarker(
                  count: item.count,
                  type: item.dominantType,
                  lineLabel: item.line,
                  onTap: () {
                    // expandCluster notifie le contrôleur → _onControllerChanged
                    // déplace la carte ; pas besoin d'un move() redondant ici.
                    final z = (_zoom + 2).clamp(11.0, 18.0);
                    widget.controller.expandCluster(
                      item.id,
                      item.center,
                      zoom: z,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final m = item.members.first;
      final pos = widget.controller.liveEnabled
          ? _liveEngine.positionFor(m)
          : m.position;
      final stale = m.isVehicle && m.freshnessAt(now) == TerrainFreshness.stale;
      final oos = m.isVehicle && m.speedKmh < 1 && (m.delayMinutes ?? 0) > 10;
      final lineLabel = m.line ?? _extractLine(m.code);
      // Boîte carrée généreuse : le véhicule (halo + ombre + badge) pivote
      // selon le cap sans être rogné ni redimensionné par le FittedBox. Le tram
      // est ~2× plus long que le bus → boîte dédiée plus grande.
      final boxSize = switch (m.type) {
        TerrainMarkerType.tram => 188.0,
        _ => 104.0,
      };
      result.add(
        Marker(
          key: ValueKey(m.id),
          point: pos,
          width: boxSize,
          height: boxSize,
          alignment: Alignment.center,
          child: SizedBox(
            width: boxSize,
            height: boxSize,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: TerrainMapMarker(
                type: m.type,
                selected: m.id == selectedId,
                stale: stale,
                outOfService: oos,
                headingDeg: m.headingDeg,
                lineLabel: lineLabel,
                liveOpacity: _liveEngine.opacityFor(m.id),
                onTap: () => widget.onMarkerTapped(m),
              ),
            ),
          ),
        ),
      );
    }

    return result;
  }

  String? _extractLine(String? code) {
    if (code == null) return null;
    final match = RegExp(r'(?:Ligne\s+)?(\S+)$').firstMatch(code);
    return match?.group(1);
  }

  List<Marker> _buildStationMarkers() {
    if (!widget.controller.layers.stations || widget.stations.isEmpty) {
      return const [];
    }
    // Masqués au dézoom : au-delà, le viewport couvre tout le réseau et le rendu
    // simultané de >1000 marqueurs sature le device.
    if (_zoom < _stationMinZoom) return const [];
    final bounds = _viewportBounds();
    final selectedId = widget.controller.selectedMarker?.id;
    final visible =
        (bounds == null
                ? widget.stations
                : widget.stations.where((s) {
                    final lat = s.position.latitude;
                    final lng = s.position.longitude;
                    return lat >= bounds.south &&
                        lat <= bounds.north &&
                        lng >= bounds.west &&
                        lng <= bounds.east;
                  }))
            // Plafond de sécurité : ne jamais rendre plus que ce budget de marqueurs.
            .take(_stationMaxRender);
    return visible.map((s) {
      final sid = 'station:${s.stationId}';
      // Arrêts discrets (petits, estompés) pour ne pas voler la vedette aux
      // véhicules ; pleine présence seulement quand l'arrêt est sélectionné.
      final isSel = selectedId == sid;
      return Marker(
        key: ValueKey(sid),
        point: s.position,
        width: isSel ? 22 : 15,
        height: isSel ? 22 : 15,
        alignment: Alignment.center,
        child: Opacity(
          opacity: isSel ? 1 : 0.42,
          child: FittedBox(
            child: TerrainStationMarker(
              selected: isSel,
              onTap: () => widget.onMarkerTapped(
                TerrainMarker(
                  id: sid,
                  type: TerrainMarkerType.arret,
                  position: s.position,
                  updatedAt: DateTime.now(),
                  code: s.name,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Polyline> _ghostTrails() {
    if (!widget.controller.liveEnabled) return const [];
    final polylines = <Polyline>[];
    final now = DateTime.now();
    for (final m in _visibleFeedMarkers(now)) {
      if (!m.isVehicle) continue;
      final trail = _liveEngine.trailFor(m.id);
      if (trail.isEmpty) continue;
      polylines.add(
        Polyline(
          points: [trail.first, _liveEngine.positionFor(m)],
          color: m.type.color.withValues(alpha: 0.2),
          strokeWidth: 2,
        ),
      );
    }
    return polylines;
  }

  void recenterOnUser([LatLng? position]) {
    final target = position ?? widget.userPosition ?? kTerrainDefaultCenter;
    _zoom = 15.4;
    _mapController.move(target, _zoom);
  }

  bool get hasUserPosition => widget.userPosition != null;

  Future<bool> sendAssistance() async {
    final pos = widget.userPosition;
    if (pos == null) return false;
    final ok = await _feed.sendAssistance(pos);
    if (ok && mounted) _repaint.value++;
    return ok;
  }

  List<TerrainMarker> snapshotNow() => _feed.snapshot(DateTime.now());

  void fitToPoints(List<LatLng> points) {
    if (points.length < 2) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(48, 120, 48, 200),
        ),
      );
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant TerrainMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_centeredOnUser && widget.userPosition != null) {
      _centeredOnUser = true;
      _mapController.move(widget.userPosition!, 15.0);
    }
    // Les tracés GTFS arrivent souvent après le 1er build (chargement async) :
    // on (ré)applique tant qu'ils ne l'ont pas encore été.
    if (widget.routePaths.isNotEmpty) {
      _feed.applyRoutePaths(widget.routePaths);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ticker?.dispose();
    _feed.dispose();
    _repaint.dispose();
    _mapEpoch.dispose();
    super.dispose();
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

    final showLines =
        widget.controller.layers.lines && widget.linePolylines.isNotEmpty;

    return RepaintBoundary(
      child: FlutterMap(
        mapController: _mapController,
        options: _options,
        children: [
          _tiles!,
          if (showLines) PolylineLayer(polylines: widget.linePolylines),
          // Sillages Live : recalculés à chaque repaint (et une seule fois),
          // pour qu'ils suivent l'interpolation des véhicules.
          ListenableBuilder(
            listenable: Listenable.merge([_repaint, widget.controller]),
            builder: (_, _) => PolylineLayer(polylines: _ghostTrails()),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([_mapEpoch, widget.controller]),
            builder: (_, _) => MarkerLayer(markers: _buildStationMarkers()),
          ),
          if (widget.walkingRoute != null && widget.walkingRoute!.length >= 2)
            PolylineLayer(
              polylines: MapPathUtils.walkPolylines(widget.walkingRoute!),
            ),
          ListenableBuilder(
            listenable: Listenable.merge([_repaint, widget.controller]),
            builder: (_, _) => MarkerLayer(markers: _buildVehicleMarkers()),
          ),
          if (widget.userPosition != null)
            MarkerLayer(
              markers: [
                Marker(
                  key: const ValueKey('user'),
                  point: widget.userPosition!,
                  width: widget.userMarkerStyle.markerWidth,
                  height: widget.userMarkerStyle.markerHeight,
                  alignment: widget.userMarkerStyle.markerAlignment,
                  child: TerrainUserMarker(
                    style: widget.userMarkerStyle,
                    accuracyMeters: widget.userAccuracyMeters,
                    headingDeg: widget.userHeadingDeg,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
