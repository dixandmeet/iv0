import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../models/fleet_vehicle.dart';
import '../models/route_data.dart';
import '../models/transport_mode.dart';
import '../services/transport_repository.dart';
import '../services/map_weather_service.dart';
import '../theme/app_theme.dart';
import '../utils/geo_utils.dart';
import '../widgets/floating_top_bar.dart';
import '../widgets/map_weather_layer.dart';
import '../widgets/maplibre_weather_style.dart';

class RadarScreen extends StatefulWidget {
  final VoidCallback onBack;
  final TransportDataSource repository;
  const RadarScreen({
    super.key,
    required this.onBack,
    required this.repository,
  });

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  List<FleetVehicle> _fleet = const [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  ml.MapLibreMapController? _mapController;
  final _sheetController = DraggableScrollableController();
  final _projectedVehicles = ValueNotifier<Map<String, Offset>>(const {});
  final _projectedUser = ValueNotifier<Offset?>(null);
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _userPosition;
  bool _mapReady = false;
  bool _hasCenteredOnUser = false;
  bool _locating = true;
  String? _locationMessage;
  bool _locationSettingsAction = false;
  late final MapWeatherController _weather;
  String? _appliedWeatherSignature;
  bool _mapStyleReady = false;
  int _projectionRequest = 0;
  final _searchController = TextEditingController();
  String _search = '';
  String _filter = 'tous';
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _weather = MapWeatherController()
      ..addListener(_onWeatherChanged)
      ..start(kRadarCenter);
    _loadFleet();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadFleet(silent: true),
    );
    _initLocation();
  }

  LatLng get _referencePosition => _userPosition ?? kRadarCenter;

  void _onWeatherChanged() {
    if (mounted) setState(() {});
    final controller = _mapController;
    final signature = _weather.value.signature;
    if (controller == null || signature == _appliedWeatherSignature) return;
    _appliedWeatherSignature = signature;
    _mapStyleReady = false;
    unawaited(controller.setStyle(_weather.value.baseMapStyleUrl));
  }

  Future<void> _initLocation() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (mounted) {
      setState(() {
        _locating = true;
        _locationMessage = null;
        _locationSettingsAction = false;
      });
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() {
          _locating = false;
          _locationMessage = 'Activez la localisation du téléphone';
          _locationSettingsAction = true;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locating = false;
          _locationMessage = 'Autorisez la position dans les réglages';
          _locationSettingsAction = true;
        });
        return;
      }
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _locating = false;
          _locationMessage = 'Position non autorisée · Réessayer';
        });
        return;
      }

      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) _onPosition(lastPosition);

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen(
            _onPosition,
            onError: (_) {
              if (!mounted || _userPosition != null) return;
              setState(() {
                _locating = false;
                _locationMessage = 'Position indisponible · Réessayer';
              });
            },
          );

      // Force une première mesure : certains appareils Android ne publient
      // rien sur le stream tant que le terminal ne s'est pas déplacé.
      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      _onPosition(currentPosition);
    } on TimeoutException {
      if (!mounted || _userPosition != null) return;
      setState(() {
        _locating = false;
        _locationMessage = 'Signal GPS faible · Réessayer';
      });
    } catch (_) {
      if (!mounted || _userPosition != null) return;
      setState(() {
        _locating = false;
        _locationMessage = 'Position indisponible · Réessayer';
      });
    }
  }

  void _onPosition(Position position) {
    if (!mounted) return;
    final point = LatLng(position.latitude, position.longitude);
    setState(() {
      _userPosition = point;
      _locating = false;
      _locationMessage = null;
      _locationSettingsAction = false;
    });
    _weather.updateLocation(point);
    if (_mapReady && !_hasCenteredOnUser) {
      _hasCenteredOnUser = true;
      _moveCamera(point);
    }
    unawaited(_projectMarkers());
  }

  void _onMapCreated(ml.MapLibreMapController controller) {
    _mapController = controller;
    _mapReady = true;
    _appliedWeatherSignature = _weather.value.signature;
    final position = _userPosition;
    if (position != null && !_hasCenteredOnUser) {
      _hasCenteredOnUser = true;
      _moveCamera(position);
    }
  }

  Future<void> _configureMapStyle() async {
    final controller = _mapController;
    if (controller == null || _mapStyleReady) return;
    await addWeatherBuildings(
      controller: controller,
      weather: _weather.value,
      layerId: 'radar-3d-buildings',
    );
    _mapStyleReady = true;
    await _projectMarkers();
  }

  ml.LatLng _toMapLatLng(LatLng point) =>
      ml.LatLng(point.latitude, point.longitude);

  Future<void> _moveCamera(LatLng point) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(target: _toMapLatLng(point), zoom: 15.1, tilt: 55),
      ),
    );
  }

  List<FleetVehicle> get _filteredFleet => _fleet
      .where((vehicle) => _matchFilter(vehicle) && _matchQuery(vehicle))
      .toList();

  Future<void> _projectMarkers() async {
    final controller = _mapController;
    if (controller == null || !mounted) return;
    final request = ++_projectionRequest;
    final vehicles = _filteredFleet;
    final user = _userPosition;
    final coordinates = <ml.LatLng>[
      if (user != null) _toMapLatLng(user),
      ...vehicles.map((vehicle) => _toMapLatLng(vehicle.position)),
    ];
    if (coordinates.isEmpty) {
      _projectedUser.value = null;
      _projectedVehicles.value = const {};
      return;
    }
    try {
      final points = await controller.toScreenLocationBatch(coordinates);
      if (!mounted || request != _projectionRequest) return;
      final dpr = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? MediaQuery.devicePixelRatioOf(context)
          : 1.0;
      var index = 0;
      if (user != null) {
        final point = points[index++];
        _projectedUser.value = Offset(point.x / dpr, point.y / dpr);
      } else {
        _projectedUser.value = null;
      }
      _projectedVehicles.value = {
        for (final vehicle in vehicles)
          vehicle.id: Offset(points[index].x / dpr, points[index++].y / dpr),
      };
    } catch (_) {
      // Le style peut se recharger pendant une projection ; le prochain
      // mouvement de caméra republiera automatiquement les positions.
    }
  }

  Future<void> _handleLocationAction() async {
    if (_locationSettingsAction) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        await Geolocator.openAppSettings();
      } else {
        await Geolocator.openLocationSettings();
      }
      return;
    }
    await _initLocation();
  }

  void _recenterOnUser() {
    final position = _userPosition;
    if (position == null) {
      _initLocation();
      return;
    }
    _moveCamera(position);
  }

  Future<void> _setSheetSize(double size) async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      size,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadFleet({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final fleet = await widget.repository.fetchFleet();
      if (!mounted) return;
      setState(() {
        _fleet = fleet;
        _error = null;
        _loading = false;
      });
      unawaited(_projectMarkers());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    _sheetController.dispose();
    _searchController.dispose();
    _projectedVehicles.dispose();
    _projectedUser.dispose();
    _weather
      ..removeListener(_onWeatherChanged)
      ..dispose();
    super.dispose();
  }

  bool _matchFilter(FleetVehicle v) {
    if (_filter == 'tous') return true;
    if (_filter == 'bateau') return v.mode == TransportMode.boat;
    return v.mode.name == _filter;
  }

  bool _matchQuery(FleetVehicle v) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = '${v.mode.label} ${v.line} ${v.destination} ${v.stop}'
        .toLowerCase();
    return hay.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFleet;
    final sorted = filtered.toList()
      ..sort(
        (a, b) => a
            .distanceFrom(_referencePosition)
            .compareTo(b.distanceFrom(_referencePosition)),
      );

    final noFleet = _fleet.isEmpty;
    final hasResults = !noFleet && sorted.isNotEmpty;
    final hasSearch = _search.trim().isNotEmpty;
    final count = sorted.length;
    final resultCountLabel = hasSearch
        ? '$count ${count > 1 ? "résultats" : "résultat"}'
        : '$count ${count > 1 ? "véhicules à proximité" : "véhicule à proximité"}';

    String emptyTitle, emptyBody;
    if (noFleet) {
      emptyTitle = _loading
          ? 'Connexion à la flotte…'
          : 'Aucun véhicule à proximité';
      emptyBody =
          _error ??
          'Aucune position réelle récente n’est publiée pour le moment. Les véhicules apparaîtront automatiquement ici.';
    } else if (hasSearch) {
      emptyTitle = 'Aucun résultat';
      emptyBody =
          'Aucun véhicule ne correspond à « ${_search.trim()} ». Vérifiez la ligne ou la destination.';
    } else {
      emptyTitle = 'Aucun résultat pour ce filtre';
      emptyBody =
          'Essayez un autre filtre pour voir les véhicules à proximité.';
    }

    final weather = _weather.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_projectMarkers());
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ml.MapLibreMap(
                    styleString: weather.baseMapStyleUrl,
                    initialCameraPosition: ml.CameraPosition(
                      target: _toMapLatLng(kRadarCenter),
                      zoom: 15.1,
                      tilt: 55,
                    ),
                    minMaxZoomPreference: const ml.MinMaxZoomPreference(12, 19),
                    onMapCreated: _onMapCreated,
                    onStyleLoadedCallback: _configureMapStyle,
                    onCameraMove: (_) => unawaited(_projectMarkers()),
                    onCameraIdle: () => unawaited(_projectMarkers()),
                    compassEnabled: false,
                    logoEnabled: false,
                    annotationOrder: const [],
                  ),
                  ValueListenableBuilder<Offset?>(
                    valueListenable: _projectedUser,
                    builder: (context, position, _) {
                      if (position == null) return const SizedBox.shrink();
                      return Positioned(
                        left: position.dx - 18,
                        top: position.dy - 18,
                        child: const _UserDot(),
                      );
                    },
                  ),
                  ValueListenableBuilder<Map<String, Offset>>(
                    valueListenable: _projectedVehicles,
                    builder: (context, positions, _) => Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        for (final vehicle in filtered)
                          if (positions[vehicle.id] case final position?)
                            Positioned(
                              left: position.dx - 37,
                              top: position.dy - 15,
                              width: 74,
                              height: 30,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _selectedId = _selectedId == vehicle.id
                                      ? null
                                      : vehicle.id,
                                ),
                                child: Center(
                                  child: _RadarBadge(
                                    vehicle: vehicle,
                                    selected: _selectedId == vehicle.id,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                  MapWeatherLayer(weather: weather),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.bg.withValues(
                              alpha: weather.isDark ? 0.7 : 0.42,
                            ),
                            Colors.transparent,
                            Colors.transparent,
                            AppColors.bg.withValues(
                              alpha: weather.isDark ? 0.96 : 0.84,
                            ),
                          ],
                          stops: const [0, 0.22, 0.62, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 96,
                    right: 20,
                    child: SafeArea(
                      bottom: false,
                      child: MapWeatherBadge(weather: weather),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      bottom: false,
                      child: FloatingTopBar(
                        onBack: widget.onBack,
                        titleArea: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Radar',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Véhicules réels à proximité',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.radar_rounded,
                                size: 13,
                                color: AppColors.accent,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '1,2 km',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 96,
                    left: 20,
                    child: SafeArea(
                      bottom: false,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _userPosition != null
                            ? const SizedBox.shrink()
                            : _LocationStatusChip(
                                key: ValueKey(
                                  '${_locating}_${_locationMessage ?? ''}',
                                ),
                                loading: _locating,
                                message:
                                    _locationMessage ??
                                    'Localisation en cours…',
                                onTap: _locating ? null : _handleLocationAction,
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 154,
                    right: 20,
                    child: SafeArea(
                      bottom: false,
                      child: _MapActionButton(
                        onTap: _recenterOnUser,
                        active: _userPosition != null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.57,
              minChildSize: 0.14,
              maxChildSize: 0.9,
              snap: true,
              snapSizes: const [0.14, 0.57, 0.9],
              builder: (context, sheetScrollController) => Container(
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
                  controller: sheetScrollController,
                  child: Column(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _setSheetSize(0.9),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _search = v),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un véhicule, une ligne…',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.32),
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 17,
                              color: Colors.white38,
                            ),
                            suffixIcon: hasSearch
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 13,
                                      color: Colors.white60,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _search = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFF0D1512),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.13),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.13),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            for (final f in const [
                              ('tous', 'Tous'),
                              ('bus', 'Bus'),
                              ('tram', 'Tram'),
                              ('bateau', 'Bateau'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _FilterChip(
                                  label: f.$2,
                                  active: _filter == f.$1,
                                  onTap: () => setState(() => _filter = f.$1),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  resultCountLabel,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Tri par proximité',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      hasResults
                          ? ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                20,
                              ),
                              itemCount: sorted.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 9),
                              itemBuilder: (context, i) {
                                final v = sorted[i];
                                return _VehicleCard(
                                  vehicle: v,
                                  referencePosition: _referencePosition,
                                  selected: _selectedId == v.id,
                                  onTap: () => setState(
                                    () => _selectedId = _selectedId == v.id
                                        ? null
                                        : v.id,
                                  ),
                                );
                              },
                            )
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                20,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 34,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.search_rounded,
                                        size: 26,
                                        color: Colors.white38,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      emptyTitle,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      emptyBody,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      const SizedBox(height: 20),
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

class _LocationStatusChip extends StatelessWidget {
  final bool loading;
  final String message;
  final VoidCallback? onTap;

  const _LocationStatusChip({
    super.key,
    required this.loading,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE60A1210),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 285),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: loading
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.amber.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: AppColors.accent,
                  ),
                )
              else
                const Icon(
                  Icons.location_off_rounded,
                  size: 16,
                  color: AppColors.amber,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              if (!loading) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: Colors.white54,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool active;

  const _MapActionButton({required this.onTap, required this.active});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD90A1210),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(
            active ? Icons.my_location_rounded : Icons.location_searching,
            size: 20,
            color: active ? AppColors.accent : Colors.white54,
          ),
        ),
      ),
    );
  }
}

class _UserDot extends StatefulWidget {
  const _UserDot();
  @override
  State<_UserDot> createState() => _UserDotState();
}

class _UserDotState extends State<_UserDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final scale = 0.85 + t * 0.5;
        final opacity = (1 - t) * 0.6;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: opacity),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.16),
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.65),
                    blurRadius: 14,
                    spreadRadius: 3,
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

class _RadarBadge extends StatelessWidget {
  final FleetVehicle vehicle;
  final bool selected;
  const _RadarBadge({required this.vehicle, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = vehicle.mode.color;
    return AnimatedScale(
      scale: selected ? 1.14 : 1,
      duration: const Duration(milliseconds: 150),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 3, 9, 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: selected
                  ? color.withValues(alpha: 0.45)
                  : AppColors.bg.withValues(alpha: 0.65),
              blurRadius: 0,
              spreadRadius: selected ? 3 : 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: AppColors.bg.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                vehicle.mode.icon,
                size: 11,
                color: AppColors.accentDark,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              vehicle.line,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accentDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppColors.accent.withValues(alpha: 0.14)
          : Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final FleetVehicle vehicle;
  final LatLng referencePosition;
  final bool selected;
  final VoidCallback onTap;
  const _VehicleCard({
    required this.vehicle,
    required this.referencePosition,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = vehicle.mode.color;
    return Material(
      color: selected
          ? color.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 15, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(vehicle.mode.icon, size: 20, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            vehicle.line,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '→ ${vehicle.destination}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vehicle.mode.label} · à '
                      '${vehicle.distanceFrom(referencePosition)} m',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            vehicle.stop,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          formatDistance(
                            (vehicle.distanceFrom(referencePosition) * 0.35)
                                .clamp(40, 1 << 20)
                                .toDouble(),
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    vehicle.etaLabel,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: vehicle.arrivedAt != null
                          ? AppColors.amber
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: vehicle.isRealtime
                              ? AppColors.accent
                              : AppColors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        vehicle.isRealtime ? 'Temps réel' : 'Estimé',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: vehicle.isRealtime
                              ? AppColors.accent.withValues(alpha: 0.9)
                              : AppColors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vehicle.freshLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
