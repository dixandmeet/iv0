import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../models/line.dart';
import '../services/map_weather_service.dart';
import '../theme/app_theme.dart';
import '../utils/geo_utils.dart';
import '../widgets/floating_top_bar.dart';
import '../widgets/map_weather_layer.dart';
import '../widgets/maplibre_weather_style.dart';

const _kShowOffRouteAlert =
    false; // réglage de démo (banner « hors itinéraire »)

class GuidageScreen extends StatefulWidget {
  final ActiveService service;
  final VoidCallback onHome;
  final VoidCallback onEnd;

  const GuidageScreen({
    super.key,
    required this.service,
    required this.onHome,
    required this.onEnd,
  });

  @override
  State<GuidageScreen> createState() => _GuidageScreenState();
}

class _GuidageScreenState extends State<GuidageScreen>
    with SingleTickerProviderStateMixin {
  final _sheetController = DraggableScrollableController();
  ml.MapLibreMapController? _mapController;
  bool _mapStyleReady = false;
  late final MapWeatherController _weather;
  String? _appliedWeatherSignature;

  late final ValueNotifier<List<LatLng>> _traveled;

  Ticker? _ticker;
  double _bearing = 0;
  bool _bearingInit = false;
  Duration _lastMapSync = Duration.zero;
  Duration _lastCameraSync = Duration.zero;
  Duration _lastUiSync = Duration.zero;
  double? _appliedInsetSheet;

  // Le véhicule est dessiné à cette fraction de la bande de carte visible
  // (au-dessus du panneau). La caméra est calée pour que la position réelle du
  // bus se projette exactement à cet endroit → le pointeur reste sur le tracé.
  static const _kPuckAnchor = 0.67;

  // Position. Par défaut simulation (temps écoulé), remplacée par le GPS réel
  // du terminal dès qu'il est disponible et autorisé.
  StreamSubscription<Position>? _posSub;
  bool _gpsActive = false;
  LatLng? _gpsPos;
  double? _gpsHeading;
  double _t = 0; // progression 0..1 le long du tracé (GPS projeté ou simulée)
  double _snappedBearing = 0;

  // Caméra : suit la position (nav) ou libre après un geste de l'utilisateur.
  bool _following = true;
  final ValueNotifier<Offset?> _freePuck = ValueNotifier<Offset?>(null);

  bool _planExpanded = false;
  bool _confirmingEnd = false;
  int _progressPct = 0;

  @override
  void initState() {
    super.initState();
    _traveled = ValueNotifier<List<LatLng>>([
      widget.service.journey.points.first,
    ]);
    _t = _computeT();
    final start = pointOnRoute(widget.service.journey.points, _t);
    _weather = MapWeatherController()
      ..addListener(_onWeatherChanged)
      ..start(start.position);
    _appliedWeatherSignature = _weather.value.signature;
    _bearing = start.bearing;
    _snappedBearing = start.bearing;
    _bearingInit = true;
    _ticker = createTicker(_onTick)..start();
    _initGps();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _ticker?.dispose();
    _sheetController.dispose();
    _traveled.dispose();
    _freePuck.dispose();
    _weather
      ..removeListener(_onWeatherChanged)
      ..dispose();
    super.dispose();
  }

  /// Bascule sur le GPS réel du terminal si le service et l'autorisation le
  /// permettent ; sinon on conserve la position simulée.
  Future<void> _initGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) _onPosition(last);
      } catch (_) {}
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        ),
      ).listen(_onPosition, onError: (_) {});
    } catch (_) {
      // Toute erreur (plateforme sans GPS, permission refusée…) : simulation.
    }
  }

  void _onPosition(Position p) {
    if (!mounted) return;
    final ll = LatLng(p.latitude, p.longitude);
    final match = projectOnRoute(widget.service.journey.points, ll);
    _gpsPos = ll;
    _weather.updateLocation(ll);
    _t = match.t;
    _snappedBearing = match.bearing;
    // Le cap GPS n'est fiable qu'en mouvement ; sinon on garde le cap du tracé.
    _gpsHeading = (p.heading >= 0 && p.speed > 0.7) ? p.heading : null;
    if (!_gpsActive) setState(() => _gpsActive = true);
  }

  void _onWeatherChanged() {
    if (mounted) setState(() {});
    final controller = _mapController;
    final signature = _weather.value.signature;
    if (controller == null || signature == _appliedWeatherSignature) return;
    _appliedWeatherSignature = signature;
    _mapStyleReady = false;
    unawaited(controller.setStyle(_weather.value.baseMapStyleUrl));
  }

  Future<void> _setSheetSize(double size) async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      size,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  double _computeT() {
    final elapsed = DateTime.now().difference(widget.service.startedAt);
    final duration = Duration(minutes: widget.service.journey.totalMinutes);
    return (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
  }

  /// Position affichée du bus : GPS réel si disponible, sinon simulation.
  LatLng _displayPosition() => _gpsActive && _gpsPos != null
      ? _gpsPos!
      : pointOnRoute(widget.service.journey.points, _t).position;

  void _onTick(Duration elapsed) {
    final points = widget.service.journey.points;
    // En simulation, la progression avance avec le temps ; en GPS, elle est
    // pilotée par _onPosition.
    if (!_gpsActive) _t = _computeT();
    final displayPos = _displayPosition();
    final targetBearing = _gpsActive
        ? (_gpsHeading ?? _snappedBearing)
        : pointOnRoute(points, _t).bearing;
    if (!_bearingInit) {
      _bearing = targetBearing;
      _bearingInit = true;
    } else {
      _bearing = lerpAngle(_bearing, targetBearing, 0.09);
    }

    if (_following) {
      if (elapsed - _lastCameraSync > const Duration(milliseconds: 100)) {
        _lastCameraSync = elapsed;
        _syncCamera(displayPos);
      }
    } else {
      // Caméra libre : on projette le pointeur à sa vraie position écran.
      if (elapsed - _lastCameraSync > const Duration(milliseconds: 66)) {
        _lastCameraSync = elapsed;
        _projectFreePuck(displayPos);
      }
    }

    if (elapsed - _lastMapSync > const Duration(milliseconds: 200)) {
      _lastMapSync = elapsed;
      _traveled.value = traveledCoords(points, _t);
      if (_mapStyleReady) {
        _mapController?.setGeoJsonSource(
          'guide-traveled',
          _lineGeoJson(_traveled.value),
        );
      }
    }
    if (elapsed - _lastUiSync > const Duration(milliseconds: 900)) {
      _lastUiSync = elapsed;
      final pct = (_t * 100).round();
      if (pct != _progressPct) setState(() => _progressPct = pct);
    }
  }

  /// Projette la position sur l'écran (mode caméra libre). Sur Android,
  /// `toScreenLocation` renvoie des pixels physiques → division par le ratio.
  Future<void> _projectFreePuck(LatLng p) async {
    final controller = _mapController;
    if (controller == null || !mounted) return;
    try {
      final pt = await controller.toScreenLocation(_toMapLatLng(p));
      if (!mounted) return;
      var x = pt.x.toDouble();
      var y = pt.y.toDouble();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        x /= dpr;
        y /= dpr;
      }
      _freePuck.value = Offset(x, y);
    } catch (_) {}
  }

  void _enterFreeMode() {
    if (!_following) return;
    setState(() => _following = false);
    _projectFreePuck(_displayPosition());
  }

  void _recenter() {
    setState(() {
      _following = true;
      _freePuck.value = null;
    });
    _appliedInsetSheet = null; // force la réapplication des insets
    _syncCamera(_displayPosition());
  }

  ml.LatLng _toMapLatLng(LatLng point) =>
      ml.LatLng(point.latitude, point.longitude);

  double _sheetSize() =>
      _sheetController.isAttached ? _sheetController.size : 0.62;

  /// Insets caméra pour que la cible (position du bus) se projette à
  /// [_kPuckAnchor] × bande visible, c.-à-d. pile sous le pointeur.
  EdgeInsets _cameraInsets(double sheetSize, double height) {
    final strip = height * (1 - sheetSize);
    return EdgeInsets.only(
      top: (2 * _kPuckAnchor - 1) * strip,
      bottom: height * sheetSize,
    );
  }

  /// Centre la caméra sur la position réelle du bus ; le pointeur (dessiné à
  /// une position fixe à l'écran) tombe alors exactement sur le tracé.
  Future<void> _syncCamera(LatLng vehicle) async {
    final controller = _mapController;
    if (controller == null || !mounted) return;
    final height = MediaQuery.sizeOf(context).height;
    final sheetSize = _sheetSize();
    if (_appliedInsetSheet == null ||
        (sheetSize - _appliedInsetSheet!).abs() > 0.003) {
      _appliedInsetSheet = sheetSize;
      await controller.updateContentInsets(_cameraInsets(sheetSize, height));
      if (!mounted) return;
    }
    await controller.moveCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: _toMapLatLng(vehicle),
          zoom: 17.15,
          tilt: 67,
          bearing: _bearing,
        ),
      ),
    );
  }

  Map<String, dynamic> _lineGeoJson(List<LatLng> points) => {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'properties': <String, dynamic>{},
        'geometry': {
          'type': 'LineString',
          'coordinates': points
              .map((point) => [point.longitude, point.latitude])
              .toList(),
        },
      },
    ],
  };

  Future<void> _configureMapStyle() async {
    final controller = _mapController;
    if (controller == null || _mapStyleReady) return;

    await addWeatherBuildings(
      controller: controller,
      weather: _weather.value,
      layerId: 'guide-3d-buildings',
    );

    await controller.addGeoJsonSource(
      'guide-route',
      _lineGeoJson(widget.service.journey.points),
    );
    await controller.addLineLayer(
      'guide-route',
      'guide-route-shadow',
      ml.LineLayerProperties(
        lineColor: _weather.value.isDark ? '#07110f' : '#F5F0DF',
        lineWidth: 13,
        lineOpacity: 0.9,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      enableInteraction: false,
    );
    await controller.addLineLayer(
      'guide-route',
      'guide-route-active',
      const ml.LineLayerProperties(
        lineColor: '#19D3AE',
        lineWidth: 7,
        lineOpacity: 1,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      enableInteraction: false,
    );
    await controller.addGeoJsonSource(
      'guide-traveled',
      _lineGeoJson(_traveled.value),
    );
    await controller.addLineLayer(
      'guide-traveled',
      'guide-route-traveled',
      const ml.LineLayerProperties(
        lineColor: '#62736E',
        lineWidth: 7,
        lineOpacity: 1,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      enableInteraction: false,
    );

    // Cale la projection dès le premier rendu pour éviter un saut du pointeur.
    if (mounted) {
      final height = MediaQuery.sizeOf(context).height;
      final sheetSize = _sheetSize();
      _appliedInsetSheet = sheetSize;
      await controller.updateContentInsets(_cameraInsets(sheetSize, height));
    }
    _mapStyleReady = true;
  }

  @override
  Widget build(BuildContext context) {
    final tG = _progressPct.clamp(0, 100) / 100;
    final journey = widget.service.journey;
    final stops = journey.stops;
    var nextIdx = stops.indexWhere((s) => s.pos > tG + 0.004);
    if (nextIdx == -1) nextIdx = stops.length - 1;
    final lastStop = stops.last;
    int minsTo(double pos) =>
        ((pos - tG) * journey.totalMinutes).round().clamp(0, 1 << 30);
    double distTo(double pos) => ((pos - tG) * journey.totalMeters)
        .clamp(0, journey.totalMeters)
        .toDouble();

    final nextStop = stops[nextIdx];
    final nextIsTerminus = nextIdx == stops.length - 1;
    final nextMin = minsTo(nextStop.pos);
    final nextArrived = nextMin <= 0;
    final followingLine = nextIsTerminus
        ? 'Terminus de la ligne'
        : 'puis ${stops[nextIdx + 1].name}';
    final remMin = minsTo(lastStop.pos);

    final fullPlan = List.generate(stops.length, (i) {
      final s = stops[i];
      final status = i < nextIdx
          ? 'done'
          : i == nextIdx
          ? 'next'
          : 'up';
      return _PlanEntry(
        idx: i,
        name: s.name,
        status: status,
        isTerm: i == stops.length - 1,
        minutes: minsTo(s.pos),
      );
    });
    final visiblePlan = _planExpanded
        ? fullPlan
        : fullPlan.where((x) => x.idx >= nextIdx).take(3).toList();

    final initialTarget = pointOnRoute(journey.points, _computeT());
    final weather = _weather.value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_confirmingEnd) {
          setState(() => _confirmingEnd = false);
        } else {
          widget.onHome();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Un geste sur la carte passe en caméra libre (le suivi
                  // automatique cesse jusqu'au recentrage).
                  Listener(
                    onPointerDown: (_) => _enterFreeMode(),
                    child: ml.MapLibreMap(
                      styleString: weather.baseMapStyleUrl,
                      initialCameraPosition: ml.CameraPosition(
                        target: _toMapLatLng(initialTarget.position),
                        zoom: 17.15,
                        tilt: 67,
                        bearing: initialTarget.bearing,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _appliedWeatherSignature = weather.signature;
                      },
                      onStyleLoadedCallback: _configureMapStyle,
                      compassEnabled: false,
                      logoEnabled: false,
                      annotationOrder: const [],
                    ),
                  ),
                  MapWeatherLayer(weather: weather),
                  // Vignette pour lisibilité.
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.bg.withValues(
                              alpha: weather.isDark ? 0.65 : 0.38,
                            ),
                            Colors.transparent,
                            Colors.transparent,
                            AppColors.bg.withValues(
                              alpha: weather.isDark ? 0.95 : 0.84,
                            ),
                          ],
                          stops: const [0, 0.2, 0.6, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 72,
                    left: 16,
                    child: SafeArea(
                      bottom: false,
                      child: MapWeatherBadge(weather: weather),
                    ),
                  ),
                  // Pointeur véhicule. En suivi, il est ancré et descend avec
                  // le panneau (la caméra le cale sur le tracé) ; en caméra
                  // libre, il est projeté à sa vraie position à l'écran.
                  if (_following)
                    AnimatedBuilder(
                      animation: _sheetController,
                      builder: (context, _) {
                        final height = MediaQuery.sizeOf(context).height;
                        final centerY =
                            _kPuckAnchor * height * (1 - _sheetSize());
                        return Positioned(
                          top: centerY - 23,
                          left: 0,
                          right: 0,
                          child: const Center(child: _VehiclePuck()),
                        );
                      },
                    )
                  else
                    ValueListenableBuilder<Offset?>(
                      valueListenable: _freePuck,
                      builder: (context, screen, _) {
                        if (screen == null) return const SizedBox.shrink();
                        return Positioned(
                          left: screen.dx - 23,
                          top: screen.dy - 23,
                          child: const _VehiclePuck(),
                        );
                      },
                    ),
                  // Bouton recentrer (visible uniquement en caméra libre).
                  if (!_following)
                    Positioned(
                      top: 8,
                      right: 16,
                      child: SafeArea(
                        bottom: false,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: _RecenterButton(onTap: _recenter),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      bottom: false,
                      child: FloatingTopBar(
                        onBack: widget.onHome,
                        titleArea: Text(
                          widget.service.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: const LiveBadge(),
                      ),
                    ),
                  ),
                  if (_kShowOffRouteAlert)
                    Positioned(
                      top: 66,
                      left: 16,
                      right: 16,
                      child: SafeArea(
                        bottom: false,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: AppColors.red.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 19,
                                color: AppColors.red,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Hors itinéraire',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Écart de plus de 80 m depuis 15 s. Rejoignez le tracé.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.62,
              minChildSize: 0.105,
              maxChildSize: 0.90,
              snap: true,
              snapSizes: const [0.105, 0.62, 0.90],
              builder: (context, scrollController) => Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 30,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 42,
                        child: Row(
                          children: [
                            const SizedBox(width: 36),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _setSheetSize(0.90),
                                child: Center(
                                  child: Container(
                                    width: 44,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.28,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _setSheetSize(0.105),
                              tooltip: 'Fermer le panneau',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragEnd: (details) {
                          if ((details.primaryVelocity ?? 0) < -250) {
                            _setSheetSize(0.90);
                          }
                        },
                        onTap: () => _setSheetSize(0.90),
                        child: Semantics(
                          button: true,
                          label: 'Agrandir le panneau',
                          child: const SizedBox(
                            width: double.infinity,
                            height: 1,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Position transmise',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                                Text(
                                  ' · ~5 s',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 13,
                                  color: Colors.white38,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${lastStop.name} · ${remMin <= 0 ? "arrivée" : "$remMin min"}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.accent.withValues(alpha: 0.13),
                              AppColors.accent.withValues(alpha: 0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.26),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PROCHAIN ARRÊT',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    nextStop.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    followingLine,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  nextArrived ? 'à quai' : '$nextMin min',
                                  style: TextStyle(
                                    fontSize: nextArrived ? 16 : 23,
                                    fontWeight: FontWeight.w700,
                                    color: nextArrived
                                        ? AppColors.amber
                                        : AppColors.accent,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  nextArrived
                                      ? "à l'approche"
                                      : formatDistance(distTo(nextStop.pos)),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white.withValues(alpha: 0.45),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PLAN DE LIGNE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _planExpanded = !_planExpanded),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _planExpanded
                                      ? 'Réduire'
                                      : 'Voir tout · ${stops.length} arrêts',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                AnimatedRotation(
                                  turns: _planExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: _planExpanded ? 220 : double.infinity,
                        ),
                        child: _planExpanded
                            ? SingleChildScrollView(
                                child: _PlanList(
                                  entries: visiblePlan,
                                  nextIdx: nextIdx,
                                ),
                              )
                            : _PlanList(entries: visiblePlan, nextIdx: nextIdx),
                      ),
                      const SizedBox(height: 6),
                      if (_confirmingEnd)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    setState(() => _confirmingEnd = false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: Text(
                                  'Annuler',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: widget.onEnd,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.red,
                                  foregroundColor: const Color(0xFF2A0805),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Confirmer la fin',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _confirmingEnd = true),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.red.withValues(
                                alpha: 0.1,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(
                                color: AppColors.red.withValues(alpha: 0.35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Terminer le service',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.red,
                              ),
                            ),
                          ),
                        ),
                    ],
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

class _VehiclePuck extends StatelessWidget {
  const _VehiclePuck();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
              ),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.55),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.navigation_rounded,
              size: 17,
              color: AppColors.accentDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
          ),
          child: const Icon(
            Icons.my_location_rounded,
            size: 22,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}

class _PlanEntry {
  final int idx;
  final String name;
  final String status; // done | next | up
  final bool isTerm;
  final int minutes;
  const _PlanEntry({
    required this.idx,
    required this.name,
    required this.status,
    required this.isTerm,
    required this.minutes,
  });
}

class _PlanList extends StatelessWidget {
  final List<_PlanEntry> entries;
  final int nextIdx;
  const _PlanList({required this.entries, required this.nextIdx});

  static const _dim = Color(0x24FFFFFF);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(entries.length, (vi) {
        final x = entries[vi];
        final first = vi == 0;
        final last = vi == entries.length - 1;
        final topAccent = x.idx <= nextIdx;
        final botAccent = x.idx < nextIdx;

        Widget dot;
        if (x.isTerm) {
          final reached = x.status != 'up';
          dot = Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: reached ? AppColors.accent : AppColors.bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: reached ? AppColors.accent : _dim,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.flag_rounded,
              size: 10,
              color: reached ? AppColors.accentDark : Colors.white38,
            ),
          );
        } else if (x.status == 'done') {
          dot = Container(
            width: 11,
            height: 11,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          );
        } else if (x.status == 'next') {
          dot = Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: AppColors.bg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 3),
            ),
          );
        } else {
          dot = Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: AppColors.bg,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
          );
        }

        final nameColor = x.status == 'done'
            ? Colors.white.withValues(alpha: 0.4)
            : x.status == 'next'
            ? Colors.white
            : Colors.white.withValues(alpha: 0.72);

        String etaLabel;
        Color etaColor;
        FontWeight etaWeight;
        double etaSize;
        if (x.status == 'done') {
          etaLabel = 'Desservi';
          etaColor = Colors.white.withValues(alpha: 0.3);
          etaWeight = FontWeight.w500;
          etaSize = 11.5;
        } else if (x.status == 'next') {
          etaLabel = x.minutes <= 0 ? 'à quai' : '${x.minutes} min';
          etaColor = x.minutes <= 0 ? AppColors.amber : AppColors.accent;
          etaWeight = FontWeight.w700;
          etaSize = 13.5;
        } else {
          etaLabel = '${x.minutes} min';
          etaColor = Colors.white.withValues(alpha: 0.5);
          etaWeight = FontWeight.w600;
          etaSize = 12.5;
        }

        return SizedBox(
          height: 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 18,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: 2,
                        color: first
                            ? Colors.transparent
                            : (topAccent ? AppColors.accent : _dim),
                      ),
                    ),
                    dot,
                    Expanded(
                      child: Container(
                        width: 2,
                        color: last
                            ? Colors.transparent
                            : (botAccent ? AppColors.accent : _dim),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            x.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: x.status == 'next' ? 15.5 : 14,
                              fontWeight: x.status == 'next'
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: nameColor,
                            ),
                          ),
                          if (x.status == 'next')
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Text(
                                'DESSERTE EN COURS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      etaLabel,
                      style: TextStyle(
                        fontSize: etaSize,
                        fontWeight: etaWeight,
                        color: etaColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
