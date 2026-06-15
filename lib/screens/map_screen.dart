import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/community_vehicle.dart';
import '../models/gtfs.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../services/gtfs_service.dart';
import '../services/operator_realtime_service.dart';
import '../services/vehicle_detection_service.dart';
import '../services/report_service.dart';
import '../services/map_service.dart';
import '../theme/aule_theme.dart';
import '../theme/flow_theme.dart';
import '../widgets/aule/aule_map_tiles.dart';
import '../widgets/flow_primitives.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/line_plan_sheet.dart';
import '../widgets/nearby_station_card.dart';
import '../models/track_request.dart';
import 'search_route_screen.dart';
import 'station_search_screen.dart';
import 'widgets/station_details_bottom_sheet.dart';
import 'widgets/vehicle_details_bottom_sheet.dart';
import 'widgets/report_incident_bottom_sheet.dart';
import 'widgets/tracked_vehicle_sheet.dart';

class MapScreen extends StatefulWidget {
  final TrackRequest? initialTrack;
  final VoidCallback? onTrackConsumed;

  const MapScreen({
    super.key,
    this.initialTrack,
    this.onTrackConsumed,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final OperatorRealtimeService _operator = OperatorRealtimeService();
  final LatLng _nantesCenter = const LatLng(47.218371, -1.553621); // Commerce

  bool _showStops = true;
  bool _showShapes = true;

  // --- Suivi d'un véhicule après tap sur une ligne ---
  _TrackedLine? _tracked;
  /// Vrai tant que la caméra suit le véhicule ; un geste utilisateur libère
  /// la caméra sans interrompre le suivi (bandeau + plan de ligne restent).
  bool _followVehicle = true;
  Timer? _trackTicker;
  LatLng? _trackedPosition;
  int _trackedWaitSeconds = 0;
  TrackedSource _trackedSource = TrackedSource.estimated;

  /// Vue 3D de suivi : carte inclinée (perspective) et orientée selon le
  /// cap du véhicule. Uniquement disponible pendant un suivi.
  bool _view3D = false;
  double _headingDeg = 0;
  /// Faux tant qu'aucun cap fiable n'a été calculé : le premier cap est
  /// appliqué sans lissage pour orienter la caméra dès l'activation.
  bool _hasHeading = false;
  Duration? _operatorWait;
  DateTime? _operatorFetchedAt;
  bool _operatorFetching = false;

  // Suivi caméra pour adapter l'affichage au niveau de zoom.
  double _currentZoom = 14.0;
  LatLngBounds? _visibleBounds;

  /// En-dessous de ce zoom, les arrêts sont masqués : les lignes
  /// suffisent pour la vue d'ensemble (comportement type Google Maps).
  static const double _stopsMinZoom = 14.5;
  /// Au-delà, les arrêts passent en taille pleine.
  static const double _stopsFullZoom = 16.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialTrack());
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTrack != null &&
        widget.initialTrack != oldWidget.initialTrack) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialTrack());
    }
  }

  void _applyInitialTrack() {
    final track = widget.initialTrack;
    if (track == null) return;
    _startLineTracking(track.route, track.station, track.departure);
    widget.onTrackConsumed?.call();
  }

  @override
  void dispose() {
    _trackTicker?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  void _onPositionChanged(MapCamera position, bool hasGesture) {
    // Un geste utilisateur reprend la main sur la caméra, mais le suivi
    // (bandeau, plan de ligne, capsule) reste actif.
    if (hasGesture && _tracked != null && _followVehicle) {
      setState(() => _followVehicle = false);
    }

    final zoom = position.zoom;
    final bounds = position.visibleBounds;
    final bool stopsWereVisible = _currentZoom >= _stopsMinZoom;
    final bool stopsNowVisible = zoom >= _stopsMinZoom;
    final bool crossedFullZoom =
        (_currentZoom >= _stopsFullZoom) != (zoom >= _stopsFullZoom);

    // Franchissement du seuil d'estompage / masquage des lignes de bus.
    final bool crossedShapesZoom =
        _showShapes && (_currentZoom < 13.0) != (zoom < 13.0);
    final bool crossedHideBus =
        _showShapes && (_currentZoom < 12.5) != (zoom < 12.5);

    // On ne rebuild que si l'affichage change : franchissement d'un seuil
    // de zoom, ou déplacement alors que des arrêts sont visibles
    // (le culling viewport doit suivre la caméra).
    final bool needsRebuild = crossedShapesZoom ||
        crossedHideBus ||
        (_showStops &&
            (stopsWereVisible != stopsNowVisible ||
                crossedFullZoom ||
                (stopsNowVisible && bounds != _visibleBounds)));

    _currentZoom = zoom;
    _visibleBounds = bounds;
    if (needsRebuild) setState(() {});
  }

  /// Vrai si le point est dans le viewport (avec une marge pour éviter
  /// que les markers "popent" en bord d'écran pendant un déplacement).
  bool _isInView(LatLng point) {
    final b = _visibleBounds;
    if (b == null) return true;
    const pad = 0.006; // ~600 m
    return point.latitude >= b.south - pad &&
        point.latitude <= b.north + pad &&
        point.longitude >= b.west - pad &&
        point.longitude <= b.east + pad;
  }

  // ------------------------------------------------------------------
  // Suivi du véhicule d'une ligne (tap sur une direction dans le sheet)
  // ------------------------------------------------------------------

  void _startLineTracking(
      GtfsRoute route, NearbyStation station, StationDeparture departure) {
    _trackTicker?.cancel();
    setState(() {
      _tracked = _TrackedLine(route, station, departure);
      _followVehicle = true;
      _trackedPosition = null;
      _hasHeading = false;
      _operatorWait = null;
      _operatorFetchedAt = null;
    });

    // Replie le sheet pour dégager la carte.
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.16,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }

    _trackTicker = Timer.periodic(
        const Duration(seconds: 1), (_) => _updateTracking());
    _updateTracking(initialZoom: 16.0);
  }

  void _stopLineTracking() {
    _trackTicker?.cancel();
    _trackTicker = null;
    if (_tracked == null) return;
    setState(() {
      _tracked = null;
      _trackedPosition = null;
      _view3D = false;
      _headingDeg = 0;
      _hasHeading = false;
    });
    // Restaure une carte orientée nord.
    _mapController.rotate(0);
  }

  /// Bascule la vue 3D de suivi (perspective + cap du véhicule vers le haut).
  void _toggle3DView() {
    if (_tracked == null) return;
    setState(() {
      _view3D = !_view3D;
      _followVehicle = true;
    });
    if (!_view3D) _mapController.rotate(0);
    _updateTracking();
  }

  /// Fiche d'informations du véhicule suivi (tap sur sa capsule).
  void _openTrackedVehicleSheet() {
    final tracked = _tracked;
    if (tracked == null) return;
    final mapHelper = Provider.of<MapService>(context, listen: false);
    showFlowSheet(
      context,
      builder: (_) => TrackedVehicleSheet(
        route: tracked.route,
        headsign: tracked.departure.headsign,
        stationName: tracked.station.stop.stopName,
        waitSeconds: _trackedWaitSeconds,
        sourceLabel: _trackedSource.label,
        sourceIcon: _trackedSource.icon,
        lineColor: mapHelper.getTransportColor(
          tracked.route.transportType,
          routeColorHex: tracked.route.routeColor,
        ),
        view3D: _view3D,
        onToggle3D: _toggle3DView,
      ),
    );
  }

  /// Démarre le suivi d'une ligne depuis un véhicule communautaire (bouton
  /// « Suivre ce bus » de sa fiche), puis active la vue 3D.
  void _startTrackingFromVehicle(CommunityVehicle vehicle) {
    final gtfs = Provider.of<GtfsService>(context, listen: false);

    GtfsRoute? route;
    for (final r in gtfs.cachedRoutes) {
      if (r.routeId == vehicle.routeId || r.routeShortName == vehicle.routeId) {
        route = r;
        break;
      }
    }
    if (route == null) {
      showFlowToast(context, 'Ligne ${vehicle.routeId} introuvable.',
          icon: LucideIcons.mapPinOff);
      return;
    }
    final resolved = route;

    // Station de référence : la plus proche de l'utilisateur (sinon du
    // véhicule) desservie par cette ligne.
    final location = Provider.of<LocationService>(context, listen: false);
    final userPos = location.currentPosition;
    final center = userPos != null
        ? LatLng(userPos.latitude, userPos.longitude)
        : vehicle.position;
    NearbyStation? station;
    for (final s in gtfs.nearbyStations(center, limit: 40, maxMeters: 3000)) {
      if (s.routes.any((r) => r.routeId == resolved.routeId)) {
        station = s;
        break;
      }
    }
    if (station == null) {
      showFlowToast(context, 'Aucune station de la ligne à proximité.',
          icon: LucideIcons.mapPinOff);
      return;
    }

    // Direction : le départ le plus imminent de cette ligne à la station.
    StationDeparture? departure;
    for (final dep in gtfs.stationDepartures(station)) {
      if (dep.route.routeId != resolved.routeId) continue;
      if (departure == null || dep.waitMinutes < departure.waitMinutes) {
        departure = dep;
      }
    }
    if (departure == null) {
      showFlowToast(context, 'Aucun départ trouvé pour cette ligne.',
          icon: LucideIcons.mapPinOff);
      return;
    }

    setState(() => _view3D = true);
    _startLineTracking(resolved, station, departure);
  }

  /// Rafraîchit le prochain passage annoncé par l'opérateur (Naolib).
  Future<void> _refreshOperatorWait() async {
    final tracked = _tracked;
    if (tracked == null || _operatorFetching) return;
    _operatorFetching = true;
    try {
      final gtfs = Provider.of<GtfsService>(context, listen: false);
      final wait = await _operator.nextWait(
        stopCode: tracked.station.stop.stopId,
        lineCode: tracked.route.routeShortName ?? tracked.route.routeId,
        headsign: tracked.departure.headsign,
        gtfsStopId: gtfs.gtfsQuayFor(
            tracked.route, tracked.station.stop, tracked.departure.headsign),
        gtfsRouteId: gtfs.gtfsRouteId(tracked.route),
      );
      if (!mounted || !identical(_tracked, tracked)) return;
      _operatorWait = wait;
      _operatorFetchedAt = DateTime.now();
    } finally {
      _operatorFetching = false;
    }
  }

  /// Met à jour la position suivie : véhicule communautaire (position réelle)
  /// en priorité, sinon attente opérateur, sinon estimation locale — les deux
  /// dernières étant projetées sur le tracé de la ligne.
  void _updateTracking({double? initialZoom}) {
    final tracked = _tracked;
    if (tracked == null) return;
    final detection =
        Provider.of<VehicleDetectionService>(context, listen: false);
    final gtfs = Provider.of<GtfsService>(context, listen: false);
    const distance = Distance();

    LatLng? pos;
    // Points du tracé juste en aval / en amont de la position estimée :
    // donnent le cap de circulation immédiatement (sans attendre deux
    // ticks de suivi). L'amont sert quand le véhicule est déjà à l'arrêt
    // (l'aval coïncide alors avec sa position).
    LatLng? aheadPos;
    LatLng? behindPos;
    TrackedSource source;
    double waitSeconds;

    // 1. Véhicule communautaire de la ligne (le plus récemment vu).
    CommunityVehicle? community;
    for (final v in detection.detectedVehicles) {
      final matches = v.routeId == tracked.route.routeId ||
          v.routeId == tracked.route.routeShortName;
      if (!matches) continue;
      if (community == null || v.lastSeenAt.isAfter(community.lastSeenAt)) {
        community = v;
      }
    }

    if (community != null) {
      pos = community.position;
      source = TrackedSource.community;
      final meters = distance.as(
          LengthUnit.Meter, pos, tracked.station.stop.position);
      waitSeconds =
          meters / GtfsService.avgSpeedMps(tracked.route.transportType);
    } else {
      final fetchedAt = _operatorFetchedAt;
      final operatorRemaining = (_operatorWait != null && fetchedAt != null)
          ? _operatorWait! - DateTime.now().difference(fetchedAt)
          : null;

      if (operatorRemaining != null && operatorRemaining.inSeconds > 0) {
        waitSeconds = operatorRemaining.inSeconds.toDouble();
        source = TrackedSource.operator_;
      } else {
        waitSeconds = gtfs
            .estimateWaitSeconds(tracked.route, tracked.station.stop,
                direction: tracked.departure.headsign)
            .toDouble();
        source = TrackedSource.estimated;
      }

      // Données opérateur : premier fetch immédiat puis toutes les ~30 s.
      if (fetchedAt == null ||
          DateTime.now().difference(fetchedAt) > const Duration(seconds: 30)) {
        _refreshOperatorWait();
      }

      pos = gtfs.projectVehicleOnRoute(tracked.route, tracked.station.stop,
          tracked.departure.headsign, waitSeconds);
      aheadPos = gtfs.projectVehicleOnRoute(tracked.route, tracked.station.stop,
          tracked.departure.headsign, waitSeconds > 8 ? waitSeconds - 8 : 0);
      behindPos = gtfs.projectVehicleOnRoute(tracked.route, tracked.station.stop,
          tracked.departure.headsign, waitSeconds + 8);
    }

    if (pos == null) {
      _stopLineTracking();
      showFlowToast(context, 'Tracé indisponible pour cette ligne.',
          icon: LucideIcons.mapPinOff);
      return;
    }

    // Cap du véhicule (pour orienter la caméra en vue 3D) : tangente du
    // tracé en priorité (disponible dès le premier tick), sinon direction
    // entre deux positions successives. Premier cap appliqué tel quel,
    // ensuite lissé pour éviter les à-coups de la position estimée.
    final previous = _trackedPosition;
    double? targetHeading;
    if (aheadPos != null && distance.as(LengthUnit.Meter, pos, aheadPos) > 1.5) {
      targetHeading = distance.bearing(pos, aheadPos);
    } else if (behindPos != null &&
        distance.as(LengthUnit.Meter, behindPos, pos) > 1.5) {
      targetHeading = distance.bearing(behindPos, pos);
    } else if (previous != null &&
        distance.as(LengthUnit.Meter, previous, pos) > 1.5) {
      targetHeading = distance.bearing(previous, pos);
    }
    if (targetHeading != null) {
      _headingDeg = _hasHeading
          ? _lerpAngleDeg(_headingDeg, targetHeading, 0.35)
          : targetHeading;
      _hasHeading = true;
    }

    setState(() {
      _trackedPosition = pos;
      _trackedWaitSeconds = waitSeconds.round();
      _trackedSource = source;
    });

    // La caméra suit le véhicule, sauf si l'utilisateur a repris la main.
    if (_followVehicle) {
      if (_view3D) {
        // Vue rapprochée, direction de circulation vers le haut.
        final zoom = initialZoom ?? (_currentZoom < 16.2 ? 16.8 : _currentZoom);
        _mapController.moveAndRotate(pos, zoom, -_headingDeg);
      } else {
        final zoom = initialZoom ?? (_currentZoom < 15.0 ? 15.5 : _currentZoom);
        _mapController.move(pos, zoom);
      }
    }
  }

  /// Interpolation d'angles en degrés via le plus court chemin angulaire.
  static double _lerpAngleDeg(double from, double to, double t) {
    var delta = (to - from) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return from + delta * t;
  }

  /// Recentre la caméra sur le véhicule suivi et reprend le suivi.
  void _resumeFollow() {
    if (_tracked == null) return;
    setState(() => _followVehicle = true);
    _updateTracking();
  }

  void _centerOnUser() {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final pos = locationService.currentPosition;
    if (pos != null) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);
    } else {
      showFlowToast(context, 'Position GPS indisponible. Vérifiez vos autorisations.',
          icon: LucideIcons.locateOff);
    }
  }

  void _openSearch() {
    Navigator.push(context, FlowPageRoute(page: const SearchRouteScreen()));
  }

  void _openStationSearch() {
    Navigator.push(context, FlowPageRoute(page: const StationSearchScreen()));
  }

  void _openReport() {
    showFlowSheet(context, builder: (_) => const ReportIncidentBottomSheet());
  }

  void _openStopSheet(GtfsStop stop) {
    final gtfs = Provider.of<GtfsService>(context, listen: false);
    final mapHelper = Provider.of<MapService>(context, listen: false);
    final location = Provider.of<LocationService>(context, listen: false);
    final userPos = location.currentPosition;
    final LatLng? from =
        userPos != null ? LatLng(userPos.latitude, userPos.longitude) : null;
    final station = gtfs.nearbyStationFor(stop, from: from);
    if (station == null) {
      showFlowToast(context, 'Aucune ligne ne dessert cet arrêt.',
          icon: LucideIcons.mapPinOff);
      return;
    }
    showFlowSheet(
      context,
      builder: (_) => StationDetailsBottomSheet(
        station: station,
        gtfs: gtfs,
        mapHelper: mapHelper,
        showDistance: from != null,
        onCenterMap: () => _mapController.move(stop.position, 17.0),
        onDirectionTap: _startLineTracking,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Provider.of<SupabaseService>(context);
    final location = Provider.of<LocationService>(context);
    final gtfs = Provider.of<GtfsService>(context);
    final detection = Provider.of<VehicleDetectionService>(context);
    final reportService = Provider.of<ReportService>(context);
    final mapHelper = Provider.of<MapService>(context);

    final String? trackedRouteId = _tracked?.route.routeId;

    final List<Polyline> polylines = [];
    if (_showShapes) {
      final List<Polyline> busLines = [];
      final List<Polyline> structuringLines = [];
      final List<Polyline> trackedLines = [];
      // En vue dézoomée, les bus sont masqués : seuls tram/busway/navibus
      // restent visibles (comme sur la carte Naolib).
      final bool zoomedOut = _currentZoom < 13.0;
      final bool hideBus = _currentZoom < 12.5;
      // Épaisseur des traits légèrement adaptée au zoom (style Naolib).
      final zoomFactor = (_currentZoom / 14.0).clamp(0.7, 1.3);

      // Trams et busways au-dessus des bus : ordre de dessin croissant.
      final routes = List<GtfsRoute>.from(gtfs.cachedRoutes)
        ..sort((a, b) {
          int rank(GtfsRoute r) => switch (r.transportType) {
                'tram' => 0,
                'busway' => 1,
                'navibus' => 2,
                _ => 3,
              };
          final ra = rank(a), rb = rank(b);
          if (ra != rb) return ra - rb;
          return (a.routeShortName ?? a.routeId)
              .compareTo(b.routeShortName ?? b.routeId);
        });

      for (final route in routes) {
        final bool structuring = route.transportType != 'bus';
        if (!structuring && hideBus) continue;
        final bool isTracked = route.routeId == trackedRouteId;
        if (trackedRouteId != null && !isTracked) continue;

        final color = mapHelper.getTransportColor(
          route.transportType,
          routeColorHex: route.routeColor,
        );
        final double alpha = isTracked
            ? 0.95
            : (structuring ? 1.0 : (zoomedOut ? 0.35 : 0.55));

        // Vue d'ensemble : branches dédupliquées (sans double sens).
        // Suivi : une seule variante orientée vers la direction suivie.
        final Iterable<List<LatLng>> segmentsToDraw = isTracked && _tracked != null
            ? [gtfs.shapeToward(route, _tracked!.departure.headsign)]
            : gtfs.displayShapes(route);

        for (final segment in segmentsToDraw) {
          if (segment.length < 2) continue;
          // Trait fin + halo blanc : lisibilité sur fond clair (style Naolib).
          final double core = (isTracked
                  ? 4.0
                  : structuring
                      ? (zoomedOut ? 2.8 : 3.2)
                      : (zoomedOut ? 1.8 : 2.4)) *
              zoomFactor;
          final double border = (isTracked ? 2.0 : structuring ? 1.6 : 1.2) *
              zoomFactor;
          final line = Polyline(
            points: segment,
            strokeWidth: core,
            borderStrokeWidth: border,
            borderColor: Colors.white.withValues(alpha: 0.92),
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
            color: color.withValues(alpha: alpha),
          );
          (isTracked
                  ? trackedLines
                  : structuring
                      ? structuringLines
                      : busLines)
              .add(line);
        }
      }
      polylines
        ..addAll(busLines)
        ..addAll(structuringLines)
        ..addAll(trackedLines);
    }

    final List<Marker> markers = [];

    // A. Position de l'utilisateur (point bleu + halo)
    final userPos = location.currentPosition;
    if (userPos != null) {
      markers.add(
        Marker(
          point: LatLng(userPos.latitude, userPos.longitude),
          width: 30,
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: FlowColors.blue.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: FlowColors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: FlowColors.blue.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // B bis. Pendant un suivi : uniquement les arrêts de la ligne suivie,
    // dans le sens de circulation, avec l'arrêt de l'utilisateur en évidence.
    if (_tracked != null) {
      final lineColor = mapHelper.getTransportColor(
        _tracked!.route.transportType,
        routeColorHex: _tracked!.route.routeColor,
      );
      final lineStops =
          gtfs.stopsToward(_tracked!.route, _tracked!.departure.headsign);
      final targetName = _tracked!.station.stop.stopName;
      for (final stop in lineStops) {
        // Position collée au tracé de la ligne : les coordonnées GTFS des
        // quais sont souvent à quelques dizaines de mètres de la voie.
        final snapped = gtfs.snapToRouteShape(
          _tracked!.route,
          stop,
          headsign: _tracked!.departure.headsign,
        );
        if (!_isInView(snapped)) continue;
        final bool isTarget = stop.stopName == targetName;
        final double dotSize = isTarget ? 18 : 11;
        markers.add(
          Marker(
            point: snapped,
            width: dotSize,
            height: dotSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showFlowToast(
                  context,
                  isTarget
                      ? 'Votre arrêt : ${stop.stopName}'
                      : 'Arrêt : ${stop.stopName}',
                  icon: LucideIcons.mapPin,
                  duration: const Duration(seconds: 1)),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isTarget ? FlowColors.blue : lineColor,
                    width: isTarget ? 4.5 : 2.5,
                  ),
                  boxShadow: isTarget
                      ? [
                          BoxShadow(
                            color: FlowColors.blue.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        );
      }
    }

    // B. Arrêts (icône du mode principal) — uniquement à un zoom proche,
    // et seulement ceux du viewport, sinon la carte devient illisible.
    if (_tracked == null && _showStops && _currentZoom >= _stopsMinZoom) {
      gtfs.ensureNetworkGraph();
      final bool fullSize = _currentZoom >= _stopsFullZoom;
      final double markerSize = fullSize ? 24.0 : 18.0;
      for (final stop in gtfs.cachedStops) {
        if (!_isInView(stop.position)) continue;
        final transportType =
            gtfs.primaryTransportTypeForStation(stop.stopId) ?? 'bus';
        final color = mapHelper.getTransportColor(transportType);
        markers.add(
          Marker(
            point: stop.position,
            width: markerSize,
            height: markerSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openStopSheet(stop),
              child: StopMapIcon(
                transportType: transportType,
                size: markerSize,
                color: color,
              ),
            ),
          ),
        );
      }
    }

    // C. Capsules véhicule détectées (masquées pendant un suivi : seul le
    // véhicule suivi reste affiché, cf. E).
    for (final vehicle in detection.detectedVehicles) {
      if (_tracked != null) break;
      final status = vehicleStatus(vehicle);
      markers.add(
        Marker(
          point: vehicle.position,
          width: 96,
          height: 70,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {
              showFlowSheet(
                context,
                builder: (_) => VehicleDetailsBottomSheet(
                  vehicle: vehicle,
                  onFollow: () => _startTrackingFromVehicle(vehicle),
                ),
              );
            },
            child: VehicleCapsule(
              code: vehicle.routeId,
              transportType: vehicle.transportType,
              statusText: status.text,
              statusColor: status.color,
            ),
          ),
        ),
      );
    }

    // D. Signalements récents (masqués pendant un suivi)
    for (final report in reportService.activeReports) {
      if (_tracked != null) break;
      // Les perturbations officielles n'ont pas de position précise : elles
      // apparaissent dans les alertes/état réseau, pas en épingle sur la carte.
      if (report.isOfficial) continue;
      markers.add(
        Marker(
          point: report.position,
          width: 34,
          height: 34,
          child: GestureDetector(
            onTap: () => _showReportDialog(report.typeLabel, report.routeId,
                report.description, report.timestamp),
            child: Container(
              decoration: BoxDecoration(
                color: FlowColors.white,
                shape: BoxShape.circle,
                boxShadow: FlowTokens.capsule,
              ),
              child: const Icon(LucideIcons.triangleAlert, color: FlowColors.orange, size: 20),
            ),
          ),
        ),
      );
    }

    // E. Véhicule suivi (tap sur une ligne du sheet). Un tap sur la capsule
    // ouvre la fiche du véhicule (infos + bascule de la vue 3D).
    if (_tracked != null && _trackedPosition != null) {
      final minutes = (_trackedWaitSeconds / 60).ceil();
      markers.add(
        Marker(
          point: _trackedPosition!,
          width: 116,
          height: 74,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: _openTrackedVehicleSheet,
            child: VehicleCapsule(
              code: _tracked!.route.routeShortName ?? _tracked!.route.routeId,
              transportType: _tracked!.route.transportType,
              statusText: minutes <= 1 ? 'arrive' : 'arrive · $minutes min',
              statusColor: flowWaitColor(minutes),
              me: true,
            ),
          ),
        ),
      );
    }

    final topPad = MediaQuery.of(context).padding.top;
    final bool showInfoBanner = supabase.isOfflineMode || userPos == null;

    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final double bodyHeight = constraints.maxHeight;
        final Widget mapWidget = FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _nantesCenter,
            initialZoom: 14.0,
            minZoom: 10.0,
            maxZoom: 18.0,
            onPositionChanged: _onPositionChanged,
          ),
          children: [
            AuleMapTiles.layer(context, AuleColors.light),
            PolylineLayer(polylines: polylines),
            // rotate: true — les marqueurs (capsules, points) restent droits
            // et lisibles quand la carte est orientée en vue 3D.
            MarkerLayer(markers: markers, rotate: true),
          ],
        );
        return Stack(
        children: [
          // 1. Fond de carte monochrome (CartoDB Positron, façon Uber).
          // En vue 3D, la carte est rendue plus grande que l'écran
          // (OverflowBox) puis inclinée par une transformation en
          // perspective, façon caméra de navigation.
          // IMPORTANT : la structure de l'arbre (Transform + OverflowBox)
          // reste identique en 2D et en 3D pour ne jamais démonter/recréer
          // FlutterMap (sinon la carte disparaît au basculement) ; seule
          // l'amplitude de l'effet est animée.
          Positioned.fill(
            child: ClipRect(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _view3D ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: mapWidget,
                // Inclinaison 0.65 rad (~37°) avec perspective 0.001 : le bas
                // de l'écran (premier plan) consomme le plus de carte
                // (compression ~1.48×), d'où les facteurs d'agrandissement.
                // Garde-fou : le haut de la carte agrandie doit rester devant
                // la caméra (w > 0), soit demi-hauteur < 1 / (0.001·sin 0.65)
                // ≈ 1650 px logiques — large marge avec ces facteurs.
                builder: (context, t, child) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001 * t)
                    ..rotateX(0.65 * t),
                  child: OverflowBox(
                    alignment: Alignment.center,
                    minWidth: constraints.maxWidth * (1 + 0.5 * t),
                    maxWidth: constraints.maxWidth * (1 + 0.5 * t),
                    minHeight: bodyHeight * (1 + 0.95 * t),
                    maxHeight: bodyHeight * (1 + 0.95 * t),
                    child: child,
                  ),
                ),
              ),
            ),
          ),

          // 2. Pill de recherche flottante
          Positioned(
            top: topPad + 12,
            left: FlowTokens.margin,
            right: FlowTokens.margin,
            child: _SearchPill(onTap: _openSearch),
          ),

          // 3. Bandeau Hors-ligne / GPS
          if (supabase.isOfflineMode)
            Positioned(
              top: topPad + 76,
              left: FlowTokens.margin,
              right: FlowTokens.margin,
              child: const _InfoBanner(
                icon: LucideIcons.cloudOff,
                text: 'Hors-ligne · réseau TAN affiché, véhicules temps réel indisponibles',
                color: FlowColors.orange,
                background: FlowColors.orangeSoft,
              ),
            )
          else if (userPos == null)
            Positioned(
              top: topPad + 76,
              left: FlowTokens.margin,
              right: FlowTokens.margin,
              child: const _InfoBanner(
                icon: LucideIcons.locateOff,
                text: 'Position indisponible — réactivez le GPS',
                color: FlowColors.red,
                background: FlowColors.redSoft,
              ),
            ),

          // 3 bis. Bandeau de suivi du véhicule
          if (_tracked != null)
            Positioned(
              top: topPad + 76 + (showInfoBanner ? 52 : 0),
              left: FlowTokens.margin,
              right: FlowTokens.margin,
              child: _TrackingBanner(
                route: _tracked!.route,
                headsign: _tracked!.departure.headsign,
                waitSeconds: _trackedWaitSeconds,
                source: _trackedSource,
                lineColor: mapHelper.getTransportColor(
                  _tracked!.route.transportType,
                  routeColorHex: _tracked!.route.routeColor,
                ),
                following: _followVehicle,
                view3D: _view3D,
                onToggle3D: _toggle3DView,
                onFollow: _resumeFollow,
                onClose: _stopLineTracking,
              ),
            ),

          // 4. Contrôles carte (toggles + recentrer + Signaler), positionnés
          // juste au-dessus du bord du bottom sheet.
          ListenableBuilder(
            listenable: _sheetController,
            builder: (context, _) {
              final double extent = _sheetController.isAttached
                  ? _sheetController.size
                  : 0.34;
              final double bottom =
                  extent.clamp(0.16, 0.45) * bodyHeight + 14;
              return Positioned(
                right: FlowTokens.margin,
                bottom: bottom,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Recherche d'une station par son nom (horaires).
                    FlowRoundButton(
                        icon: LucideIcons.search, onTap: _openStationSearch),
                    const SizedBox(height: 10),
                    _MiniToggle(
                      active: _showShapes,
                      icon: LucideIcons.route,
                      onTap: () => setState(() => _showShapes = !_showShapes),
                    ),
                    const SizedBox(height: 8),
                    _MiniToggle(
                      active: _showStops,
                      icon: LucideIcons.mapPin,
                      onTap: () => setState(() => _showStops = !_showStops),
                    ),
                    const SizedBox(height: 10),
                    FlowRoundButton(
                        icon: LucideIcons.locateFixed, onTap: _centerOnUser),
                    // FAB Signaler : uniquement à bord d'un transport.
                    if (location.isInTransit) ...[
                      const SizedBox(height: 12),
                      _ReportFab(onTap: _openReport),
                    ],
                  ],
                ),
              );
            },
          ),

          // 5. Bottom sheet déployable : stations à proximité, ou plan de
          // ligne (arrêts restants) pendant le suivi d'un véhicule.
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.34,
            minChildSize: 0.16,
            maxChildSize: 0.72,
            snap: true,
            snapSizes: const [0.34, 0.72],
            builder: (context, scrollController) => _tracked != null
                ? LinePlanSheet(
                    route: _tracked!.route,
                    headsign: _tracked!.departure.headsign,
                    station: _tracked!.station,
                    waitSeconds: _trackedWaitSeconds,
                    lineColor: mapHelper.getTransportColor(
                      _tracked!.route.transportType,
                      routeColorHex: _tracked!.route.routeColor,
                    ),
                    gtfs: gtfs,
                    scrollController: scrollController,
                  )
                : _NearbyStationsSheet(
                    gtfs: gtfs,
                    mapHelper: mapHelper,
                    userPosition: userPos != null
                        ? LatLng(userPos.latitude, userPos.longitude)
                        : null,
                    fallbackCenter: _nantesCenter,
                    scrollController: scrollController,
                    onStationTap: (pos) => _mapController.move(pos, 16.5),
                    onDirectionTap: _startLineTracking,
                  ),
          ),
        ],
        );
      }),
    );
  }

  void _showReportDialog(String label, String routeId, String? desc, DateTime ts) {
    showFlowDialog(
      context,
      builder: (_) => FlowDialogCard(
        title: Row(
          children: [
            const Icon(LucideIcons.triangleAlert, size: 20, color: FlowColors.orange),
            const SizedBox(width: 10),
            Text(label, style: FlowText.h3),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ligne : $routeId', style: FlowText.rowTitle),
            const SizedBox(height: 8),
            Text(desc ?? 'Aucune description fournie.', style: FlowText.rowSub),
            const SizedBox(height: 12),
            Text('Il y a ${DateTime.now().difference(ts).inMinutes} min',
                style: const TextStyle(fontSize: 12, color: FlowColors.gWeak)),
          ],
        ),
      ),
    );
  }
}

/// Ligne suivie sur la carte après un tap dans le sheet des stations.
class _TrackedLine {
  final GtfsRoute route;
  final NearbyStation station;
  final StationDeparture departure;
  _TrackedLine(this.route, this.station, this.departure);
}

/// Source de la position du véhicule suivi, par fiabilité décroissante.
enum TrackedSource { community, operator_, estimated }

extension on TrackedSource {
  String get label => switch (this) {
        TrackedSource.community => 'Position communautaire temps réel',
        TrackedSource.operator_ => 'Temps réel opérateur (Naolib)',
        TrackedSource.estimated => 'Position estimée (cadencement)',
      };

  IconData get icon => switch (this) {
        TrackedSource.community => LucideIcons.users,
        TrackedSource.operator_ => LucideIcons.radioTower,
        TrackedSource.estimated => LucideIcons.clock,
      };
}

/// Bandeau de suivi affiché sous la barre de recherche pendant qu'un
/// véhicule est suivi : ligne, direction, temps restant et source.
class _TrackingBanner extends StatelessWidget {
  final GtfsRoute route;
  final String headsign;
  final int waitSeconds;
  final TrackedSource source;
  final Color lineColor;
  final bool following;
  final bool view3D;
  final VoidCallback onToggle3D;
  final VoidCallback onFollow;
  final VoidCallback onClose;

  const _TrackingBanner({
    required this.route,
    required this.headsign,
    required this.waitSeconds,
    required this.source,
    required this.lineColor,
    required this.following,
    required this.view3D,
    required this.onToggle3D,
    required this.onFollow,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = (waitSeconds / 60).ceil();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
      decoration: BoxDecoration(
        color: FlowColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: FlowTokens.soft,
      ),
      child: Row(
        children: [
          LineBadge(
            code: route.routeShortName ?? route.routeId,
            transportType: route.transportType,
            background: lineColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '→ $headsign',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: FlowColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(source.icon, size: 11, color: FlowColors.gWeak),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        source.label,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: FlowColors.gWeak,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            minutes <= 1 ? 'arrive' : '$minutes min',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: flowWaitColor(minutes),
            ),
          ),
          const SizedBox(width: 4),
          // Bascule de la vue 3D (perspective orientée selon le cap).
          FlowTappable(
            onTap: onToggle3D,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                LucideIcons.rotate3d,
                size: 18,
                color: view3D ? FlowColors.blue : FlowColors.g2,
              ),
            ),
          ),
          // Recentrage sur le véhicule (actif quand la caméra le suit).
          FlowTappable(
            onTap: onFollow,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                LucideIcons.locateFixed,
                size: 18,
                color: following ? FlowColors.blue : FlowColors.g2,
              ),
            ),
          ),
          FlowTappable(
            onTap: onClose,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(LucideIcons.x, size: 18, color: FlowColors.g2),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FlowTappable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        height: 54,
        padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
        decoration: BoxDecoration(
          color: FlowColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: FlowTokens.soft,
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.search, color: FlowColors.ink, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Où allez-vous ?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: FlowColors.g2),
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: FlowColors.fill,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(LucideIcons.venetianMask, size: 20, color: FlowColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final bool active;
  final IconData icon;
  final VoidCallback onTap;
  const _MiniToggle({required this.active, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FlowTappable(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active ? FlowColors.blueSoft : FlowColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: FlowColors.line),
          boxShadow: FlowTokens.soft,
        ),
        child: Icon(icon, size: 20, color: active ? FlowColors.blue : FlowColors.g2),
      ),
    );
  }
}

class _ReportFab extends StatelessWidget {
  final VoidCallback onTap;
  const _ReportFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FlowTappable(
      onTap: onTap,
      pressedScale: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: FlowColors.orange,
          borderRadius: BorderRadius.circular(30),
          boxShadow: FlowTokens.fab(FlowColors.orange),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.triangleAlert, color: Colors.white, size: 17),
            SizedBox(width: 8),
            Text('Signaler',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet d'accueil : les stations les plus proches, avec pour chaque
/// ligne sa direction (terminus) et le temps d'attente estimé. Déployable
/// (peek <-> 72 %) via [DraggableScrollableSheet].
class _NearbyStationsSheet extends StatefulWidget {
  final GtfsService gtfs;
  final MapService mapHelper;
  final LatLng? userPosition;
  final LatLng fallbackCenter;
  final ScrollController scrollController;
  final ValueChanged<LatLng> onStationTap;
  final DirectionTapCallback onDirectionTap;

  const _NearbyStationsSheet({
    required this.gtfs,
    required this.mapHelper,
    required this.userPosition,
    required this.fallbackCenter,
    required this.scrollController,
    required this.onStationTap,
    required this.onDirectionTap,
  });

  @override
  State<_NearbyStationsSheet> createState() => _NearbyStationsSheetState();
}

class _NearbyStationsSheetState extends State<_NearbyStationsSheet> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Les temps d'attente sont fonction de l'heure courante : on
    // rafraîchit le compte à rebours périodiquement.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.userPosition ?? widget.fallbackCenter;
    final stations = widget.gtfs.nearbyStations(center, limit: 6);

    return Container(
      decoration: const BoxDecoration(
        color: FlowColors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(FlowTokens.rSheet)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F1A1916),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          const SheetHandle(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FlowTokens.margin),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionLabel('Stations à proximité'),
                Row(
                  children: [
                    Icon(
                      widget.userPosition == null
                          ? LucideIcons.locateOff
                          : LucideIcons.clock,
                      size: 12,
                      color: FlowColors.gWeak,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.userPosition == null
                          ? 'autour du centre'
                          : 'temps estimés',
                      style: FlowText.kicker.copyWith(color: FlowColors.gWeak),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: stations.isEmpty
                ? ListView(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        FlowTokens.margin, 8, FlowTokens.margin, 24),
                    children: [
                      Text(
                        widget.gtfs.cachedStops.isEmpty
                            ? 'Chargement du réseau Naolib…'
                            : 'Aucune station à moins de 1 km.',
                        style: FlowText.rowSub,
                      ),
                    ],
                  )
                : Builder(builder: (context) {
                    final groupsPerStation = [
                      for (final s in stations)
                        widget.gtfs.stationLineGroups(s),
                    ];
                    final badges =
                        assignRelevance(stations, groupsPerStation);
                    return ListView.separated(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.fromLTRB(
                          FlowTokens.margin, 2, FlowTokens.margin, 24),
                      itemCount: stations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final station = stations[i];
                        return NearbyStationCard(
                          station: station,
                          groups: groupsPerStation[i],
                          badge: badges[i],
                          mapHelper: widget.mapHelper,
                          onTap: () =>
                              widget.onStationTap(station.stop.position),
                          onDirectionTap: widget.onDirectionTap,
                        );
                      },
                    );
                  }),
          ),
        ],
      ),
    );
  }
}

