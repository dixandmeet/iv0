import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'supabase_service.dart';
import '../models/gtfs.dart';
import '../models/leg_guidance_context.dart';

class RouteStep {
  final String instruction;
  final String lineShortName;
  final String lineType;
  final String departureStop;
  final String arrivalStop;
  final int durationMinutes;

  /// Heures théoriques réelles de ce tronçon (montée / descente), issues des
  /// horaires Naolib. Null quand seule une estimation géométrique existe.
  final DateTime? departureTime;
  final DateTime? arrivalTime;

  RouteStep({
    required this.instruction,
    required this.lineShortName,
    required this.lineType,
    required this.departureStop,
    required this.arrivalStop,
    required this.durationMinutes,
    this.departureTime,
    this.arrivalTime,
  });
}

class TransitItinerary {
  final List<RouteStep> steps;
  final int totalDurationMinutes;
  final double estimatedCost;

  /// Heures de départ / d'arrivée porte-à-porte, calées sur le prochain
  /// passage théorique réel. Null si aucun horaire réel n'a pu être utilisé
  /// (l'UI retombe alors sur « maintenant + durée estimée »).
  final DateTime? departureTime;
  final DateTime? arrivalTime;

  /// true si au moins le premier tronçon a été daté sur un horaire réel.
  final bool realTiming;

  /// true si une ligne *connue des horaires* ne circule pas avant un long
  /// moment (service de nuit) : l'itinéraire reste affiché mais déclassé.
  final bool serviceLater;

  TransitItinerary({
    required this.steps,
    required this.totalDurationMinutes,
    this.estimatedCost = 1.80, // Prix ticket unitaire Naolib (GTFS fare_attributes, juin 2026)
    this.departureTime,
    this.arrivalTime,
    this.realTiming = false,
    this.serviceLater = false,
  });
}

/// Station proche de l'utilisateur, avec les lignes qui la desservent.
class NearbyStation {
  final GtfsStop stop;
  final double distanceMeters;
  final List<GtfsRoute> routes;

  NearbyStation({
    required this.stop,
    required this.distanceMeters,
    required this.routes,
  });
}

/// Prochain passage estimé d'une ligne à une station, dans une direction.
class StationDeparture {
  final GtfsRoute route;

  /// Terminus de la direction (« → Beaujoire »).
  final String headsign;
  final int waitMinutes;

  /// Passage suivant (pour afficher « 3 min puis 9 min »).
  final int nextWaitMinutes;

  StationDeparture({
    required this.route,
    required this.headsign,
    required this.waitMinutes,
    required this.nextWaitMinutes,
  });
}

/// Tous les départs d'une même ligne à une station, regroupés par direction.
/// Permet de n'afficher qu'une seule fois le badge de ligne (Citymapper-like).
class StationLineGroup {
  final GtfsRoute route;

  /// Directions desservies, triées par prochain passage le plus proche.
  final List<StationDeparture> directions;

  StationLineGroup({required this.route, required this.directions});

  /// Prochain passage le plus proche, toutes directions confondues.
  int get soonestWait =>
      directions.map((d) => d.waitMinutes).reduce((a, b) => a < b ? a : b);
}

class GtfsService with ChangeNotifier {
  final SupabaseService _supabaseService;

  // Cache local des lignes, arrêts et tracés
  List<GtfsRoute> _cachedRoutes = [];
  List<GtfsStop> _cachedStops = []; // dédupliqués par nom (pour la carte)
  List<GtfsStop> _allStops = []; // tous les arrêts physiques (pour le routage)
  final Map<String, List<LatLng>> _cachedShapes = {}; // shape_id -> Points

  List<GtfsRoute> get cachedRoutes => _cachedRoutes;
  List<GtfsStop> get cachedStops => _cachedStops;
  Map<String, List<LatLng>> get cachedShapes => _cachedShapes;

  // --- Graphe d'adjacence approché (routage hors-ligne, sans horaires GTFS) ---
  // Construit par proximité spatiale entre arrêts et tracés de lignes.
  // On raisonne au niveau STATION (groupe de quais voisins de même nom)
  // pour fusionner les quais sans confondre les homonymes éloignés.
  static const Distance _distance = Distance();
  bool _graphBuilt = false;
  final Map<String, List<GtfsRoute>> _routesByStationId = {};
  final Map<String, List<_RouteStopHit>> _servedStopsByRouteId = {};
  // Quai physique (stopId) -> station agrégée affichée sur la carte.
  final Map<String, GtfsStop> _stationOfStopId = {};

  // Cache des tracés carte (dédupliqués, style Naolib).
  final Map<String, List<List<LatLng>>> _displayShapesCache = {};

  // --- Horaires théoriques réels (GTFS stop_times précompilés) ---------------
  // Index compact produit par tool/build_schedules.py :
  //   sched[routeShort][stopNorm][terminusNorm] = {q, d:[min], s:[min], u:[min]}
  // (d=semaine, s=samedi, u=dimanche/férié ; minutes depuis minuit, >1440 = nuit)
  bool _schedulesLoaded = false;
  Map<String, dynamic>? _sched;
  Map<String, String> _gtfsRouteIdByShort = {};

  GtfsService({required SupabaseService supabaseService})
      : _supabaseService = supabaseService;

  // Charger les lignes Naolib.
  // Toujours depuis les assets embarqués : la table Supabase gtfs_routes ne
  // porte pas les tracés (shapes), indispensables à la carte et au routage.
  // Supabase reste la source de la couche communautaire (véhicules, reports).
  Future<List<GtfsRoute>> fetchRoutes() async {
    if (_cachedRoutes.isNotEmpty) return _cachedRoutes;

    try {
      final raw = await rootBundle.loadString('assets/data/tan_routes.json');
      final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
      _cachedRoutes = data
          .map((x) => GtfsRoute.fromAsset(x as Map<String, dynamic>))
          .toList();
      // Pré-remplit le cache des tracés (premier segment par ligne).
      for (final route in _cachedRoutes) {
        if (route.shapes.isNotEmpty) {
          _cachedShapes[route.routeId] = route.shapes.first;
        }
      }
      _displayShapesCache.clear();
      debugPrint('Wazibus: ${_cachedRoutes.length} lignes TAN chargées (assets).');
    } catch (e) {
      debugPrint('Wazibus: Error loading TAN routes asset ($e)');
      _cachedRoutes = [];
    }
    await _loadSchedules();
    notifyListeners();
    return _cachedRoutes;
  }

  /// Charge l'index des horaires théoriques réels (une seule fois). En cas
  /// d'absence/d'erreur, l'app retombe sur l'estimation par cadencement.
  Future<void> _loadSchedules() async {
    if (_schedulesLoaded) return;
    _schedulesLoaded = true;
    try {
      final raw =
          await rootBundle.loadString('assets/data/naolib_schedules.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _sched = data['sched'] as Map<String, dynamic>?;
      final routes = data['routes'] as Map<String, dynamic>?;
      if (routes != null) {
        _gtfsRouteIdByShort = {
          for (final e in routes.entries) e.key: e.value as String,
        };
      }
      final lines = _sched?.length ?? 0;
      debugPrint('Wazibus: horaires réels chargés ($lines lignes).');
    } catch (e) {
      debugPrint('Wazibus: Error loading real schedules ($e)');
      _sched = null;
    }
  }

  bool get hasRealSchedules => _sched != null;

  /// Bucket de type de jour pour un [weekday] DateTime (1=lundi … 7=dimanche).
  static String _dayBucket(int weekday) =>
      weekday <= 5 ? 'd' : (weekday == 6 ? 's' : 'u');

  /// Cellules horaires réelles d'une ligne à un arrêt dont le terminus
  /// correspond à [direction] (matching par tokens normalisés). Renvoie la
  /// liste fusionnée et triée des minutes pour le type de jour de [day], ou
  /// null si aucune donnée réelle exploitable.
  List<int>? _realMinutes(
      GtfsRoute route, GtfsStop stop, String direction, DateTime day) {
    final sched = _sched;
    if (sched == null) return null;
    final short = route.routeShortName ?? route.routeId;
    final byStop = sched[short];
    if (byStop is! Map) return null;
    final cells = byStop[_normalizeText(stop.stopName)];
    if (cells is! Map) return null;

    final dirNorm = _normalizeText(direction);
    final dirTokens = dirNorm.split(' ').where((t) => t.length > 2).toSet();
    final bucket = _dayBucket(day.weekday);

    final merged = <int>{};
    cells.forEach((term, cell) {
      if (cell is! Map) return;
      final termNorm = term as String;
      final termTokens = termNorm.split(' ').where((t) => t.length > 2).toSet();
      final matches = termNorm == dirNorm ||
          dirNorm.isEmpty ||
          dirTokens.any(termTokens.contains) ||
          termTokens.any(dirTokens.contains);
      if (!matches) return;
      final times = cell[bucket] ?? cell['d'];
      if (times is List) {
        for (final m in times) {
          if (m is int) merged.add(m);
        }
      }
    });
    if (merged.isEmpty) return null;
    return merged.toList()..sort();
  }

  static DateTime _atDay(DateTime day, int minutes) =>
      DateTime(day.year, day.month, day.day).add(Duration(minutes: minutes));

  /// Tous les passages théoriques réels de [route] à [stop] vers [direction],
  /// chaque minute étant datée sur SON jour de service (offsets voisins de
  /// [ref], de −[dayBefore] à +[dayAfter]). Indispensable au service de nuit,
  /// encodé en minutes > 1440 (24:00) sur le jour qui l'engendre. Trié
  /// croissant ; vide si aucune donnée réelle pour ce triplet.
  List<DateTime> _realDepartureTimes(
      GtfsRoute route, GtfsStop stop, String direction, DateTime ref,
      {required int dayBefore, required int dayAfter}) {
    final base = DateTime(ref.year, ref.month, ref.day);
    final out = <DateTime>[];
    for (var offset = -dayBefore; offset <= dayAfter; offset++) {
      final serviceDay = base.add(Duration(days: offset));
      final mins = _realMinutes(route, stop, direction, serviceDay);
      if (mins == null) continue;
      for (final m in mins) {
        out.add(_atDay(serviceDay, m));
      }
    }
    out.sort();
    return out;
  }

  /// Prochain passage réel (théorique) de [route] à [stop] vers [direction] à
  /// partir de [now]. Null si aucune donnée réelle n'existe pour ce triplet.
  ///
  /// On balaie plusieurs *jours de service* voisins, pas seulement le jour
  /// calendaire : un passage de nuit est rattaché au jour de service qui l'a
  /// engendré et encodé en minutes > 1440 (24:00). Une requête à 00:09 le
  /// samedi doit donc consulter le service du **vendredi** (offset −1, dont la
  /// queue 24:00–04:00 retombe sur le samedi matin), faute de quoi tout le
  /// réseau de nuit (Luciole) reste invisible.
  DateTime? nextRealDeparture(GtfsRoute route, GtfsStop stop,
      {String direction = '', DateTime? now}) {
    final ref = now ?? DateTime.now();
    final times = _realDepartureTimes(route, stop, direction, ref,
        dayBefore: 1, dayAfter: 2);
    for (final dt in times) {
      if (!dt.isBefore(ref)) return dt;
    }
    return null;
  }

  /// Quai GTFS (ex. `FR_NAOLIB:Quay:94`) desservant [stop] sur [route] vers
  /// [direction] — pour le pont temps réel GTFS-RT. Null si inconnu.
  String? gtfsQuayFor(GtfsRoute route, GtfsStop stop, String direction) {
    final sched = _sched;
    if (sched == null) return null;
    final short = route.routeShortName ?? route.routeId;
    final byStop = sched[short];
    if (byStop is! Map) return null;
    final cells = byStop[_normalizeText(stop.stopName)];
    if (cells is! Map) return null;
    final dirNorm = _normalizeText(direction);
    final dirTokens = dirNorm.split(' ').where((t) => t.length > 2).toSet();
    String? fallback;
    for (final entry in cells.entries) {
      final cell = entry.value;
      if (cell is! Map) continue;
      final q = cell['q'] as String?;
      fallback ??= q;
      final termTokens =
          (entry.key as String).split(' ').where((t) => t.length > 2).toSet();
      if (dirTokens.any(termTokens.contains) ||
          termTokens.any(dirTokens.contains)) {
        return q;
      }
    }
    return fallback;
  }

  /// route_id GTFS (ex. `NAOLIBORG:Line:1`) d'un code de ligne, pour GTFS-RT.
  String? gtfsRouteId(GtfsRoute route) =>
      _gtfsRouteIdByShort[route.routeShortName ?? route.routeId];

  // Charger les arrêts Naolib (toujours depuis les assets, cf. fetchRoutes).
  Future<List<GtfsStop>> fetchStops() async {
    if (_cachedStops.isNotEmpty) return _cachedStops;

    try {
      final raw = await rootBundle.loadString('assets/data/tan_stops.json');
      final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
      // On conserve tous les arrêts physiques (_allStops) pour le routage,
      // et une version agrégée par station (_cachedStops) pour une carte
      // lisible (le jeu TAN sépare quais et sens de circulation).
      final all = <GtfsStop>[
        for (final x in data) GtfsStop.fromAsset(x as Map<String, dynamic>),
      ];
      _allStops = all;
      _cachedStops = _clusterStations(all);
      debugPrint('Wazibus: ${all.length} arrêts TAN '
          '(${_cachedStops.length} stations) chargés (assets).');
    } catch (e) {
      debugPrint('Wazibus: Error loading TAN stops asset ($e)');
      _cachedStops = [];
      _allStops = [];
    }
    notifyListeners();
    return _cachedStops;
  }

  /// Rayon de regroupement des quais d'une même station : dans le jeu TAN,
  /// les quais d'une station sont à moins de ~500 m les uns des autres,
  /// tandis que les homonymes (autres communes) sont à plus de 3 km.
  static const double _quayClusterMeters = 600;

  /// Agrège les arrêts physiques en stations : les quais de même nom et
  /// géographiquement voisins sont fusionnés en un marqueur placé au
  /// centroïde. Les homonymes éloignés restent des stations distinctes
  /// (l'ancienne déduplication par nom seul plaçait certains marqueurs à
  /// plusieurs kilomètres de la station réelle).
  List<GtfsStop> _clusterStations(List<GtfsStop> stops) {
    // Clé de regroupement insensible à la casse et aux espaces autour des
    // tirets : le jeu TAN contient des graphies multiples pour une même
    // station (« Foch - Cathédrale » / « Foch-Cathédrale »), qui créaient
    // des marqueurs en double.
    String nameKey(String n) => n
        .toLowerCase()
        .replaceAll(RegExp(r'\s*-\s*'), '-')
        .trim();

    final byName = <String, List<GtfsStop>>{};
    for (final s in stops) {
      byName.putIfAbsent(nameKey(s.stopName), () => []).add(s);
    }

    _stationOfStopId.clear();
    final stations = <GtfsStop>[];
    byName.forEach((name, quays) {
      // Regroupement single-linkage : un quai rejoint un groupe s'il est
      // proche d'au moins un de ses membres.
      final clusters = <List<GtfsStop>>[];
      for (final quay in quays) {
        List<GtfsStop>? home;
        for (final cluster in clusters) {
          final near = cluster.any((m) =>
              _distance.as(LengthUnit.Meter, m.position, quay.position) <=
              _quayClusterMeters);
          if (near) {
            home = cluster;
            break;
          }
        }
        if (home == null) {
          clusters.add([quay]);
        } else {
          home.add(quay);
        }
      }

      for (final cluster in clusters) {
        double lat = 0, lon = 0;
        for (final q in cluster) {
          lat += q.position.latitude;
          lon += q.position.longitude;
        }
        final station = GtfsStop(
          stopId: cluster.first.stopId,
          stopName: cluster.first.stopName,
          position: LatLng(lat / cluster.length, lon / cluster.length),
          wheelchairBoarding: cluster.any((q) => q.wheelchairBoarding == 1)
              ? 1
              : cluster.first.wheelchairBoarding,
        );
        stations.add(station);
        for (final q in cluster) {
          _stationOfStopId[q.stopId] = station;
        }
      }
    });
    return stations;
  }

  // ------------------------------------------------------------------
  // Stations à proximité (bottom sheet d'accueil)
  // ------------------------------------------------------------------

  /// Fréquences moyennes (minutes) par mode — faute de stop_times GTFS,
  /// on suppose un cadencement régulier par type de transport.
  static const Map<String, int> _headwayMinutes = {
    'tram': 6,
    'busway': 8,
    'navibus': 20,
    'bus': 12,
  };

  /// Construit le graphe station <-> lignes si nécessaire (no-op ensuite).
  void ensureNetworkGraph() => _buildNetworkGraph();

  /// Stations les plus proches de [center] desservies par au moins une
  /// ligne, triées par distance. Les lignes structurantes (tram/busway/
  /// navibus) sont listées en premier.
  List<NearbyStation> nearbyStations(LatLng center,
      {int limit = 3, double maxMeters = 1200}) {
    _buildNetworkGraph();
    final candidates = <NearbyStation>[];
    for (final stop in _cachedStops) {
      final d = _distance.as(LengthUnit.Meter, center, stop.position);
      if (d > maxMeters) continue;
      final routes = _routesByStationId[stop.stopId];
      if (routes == null || routes.isEmpty) continue;
      candidates.add(NearbyStation(
          stop: stop, distanceMeters: d, routes: _sortedRoutes(routes)));
    }
    candidates.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return candidates.take(limit).toList();
  }

  /// Mode de transport principal desservant une station (tram/busway/navibus
  /// avant bus). Null si la station n'est desservie par aucune ligne connue.
  String? primaryTransportTypeForStation(String stopId) {
    _buildNetworkGraph();
    final routes = _routesByStationId[stopId];
    if (routes == null || routes.isEmpty) return null;
    return _sortedRoutes(routes).first.transportType;
  }

  /// Résout le contexte GTFS d'une étape transit pour le guidage pas à pas.
  Future<LegGuidanceContext?> resolveLegGuidance(
    RouteStep step, {
    LatLng? near,
  }) async {
    if (_cachedRoutes.isEmpty) await fetchRoutes();
    if (_cachedStops.isEmpty) await fetchStops();
    _buildNetworkGraph();

    GtfsRoute? route;
    for (final r in _cachedRoutes) {
      final code = r.routeShortName ?? r.routeId;
      if (code == step.lineShortName) {
        route = r;
        break;
      }
    }
    if (route == null) return null;

    final boardingStop = _resolveStop(step.departureStop, near: near);
    final alightStop = _resolveStop(step.arrivalStop, near: near);
    if (boardingStop == null || alightStop == null) return null;

    final stationRoutes = _routesByStationId[boardingStop.stopId] ?? [route];
    final distance = near == null
        ? 0.0
        : _distance.as(LengthUnit.Meter, near, boardingStop.position);

    StationDeparture? bestDeparture;
    final station = NearbyStation(
      stop: boardingStop,
      distanceMeters: distance,
      routes: _sortedRoutes(stationRoutes),
    );
    for (final dep in stationDepartures(station)) {
      if (dep.route.routeId != route.routeId) continue;
      final stops = stopsToward(route, dep.headsign);
      final boardIdx =
          stops.indexWhere((s) => s.stopId == boardingStop.stopId);
      final alightIdx =
          stops.indexWhere((s) => s.stopId == alightStop.stopId);
      if (boardIdx < 0 || alightIdx <= boardIdx) continue;
      if (bestDeparture == null ||
          dep.waitMinutes < bestDeparture.waitMinutes) {
        bestDeparture = dep;
      }
    }

    final headsign = bestDeparture?.headsign ?? step.arrivalStop;
    final wait = bestDeparture?.waitMinutes ??
        estimateWaitMinutes(route, boardingStop, direction: headsign);
    final headway = _headwayMinutes[route.transportType] ?? 12;

    return LegGuidanceContext(
      route: route,
      boardingStop: boardingStop,
      alightStop: alightStop,
      headsign: headsign,
      waitMinutes: wait,
      nextWaitMinutes: bestDeparture?.nextWaitMinutes ?? wait + headway,
      boardingDistanceMeters: distance,
      stationRoutes: _sortedRoutes(stationRoutes),
    );
  }

  /// Construit une [NearbyStation] pour un arrêt carte (lignes desservantes
  /// + distance optionnelle depuis [from]).
  NearbyStation? nearbyStationFor(GtfsStop stop, {LatLng? from}) {
    _buildNetworkGraph();
    final routes = _routesByStationId[stop.stopId];
    if (routes == null || routes.isEmpty) return null;
    final distance = from == null
        ? 0.0
        : _distance.as(LengthUnit.Meter, from, stop.position);
    return NearbyStation(
      stop: stop,
      distanceMeters: distance,
      routes: _sortedRoutes(routes),
    );
  }

  /// Construit une entrée « détail ligne » représentative pour une ligne
  /// favorite ouverte sans contexte d'arrêt : choisit le premier arrêt
  /// desservi qui expose un départ, puis sa direction la plus imminente.
  ({NearbyStation station, StationDeparture departure})? representativeDeparture(
      GtfsRoute route,
      {LatLng? from}) {
    _buildNetworkGraph();
    final served = _servedStopsByRouteId[route.routeId];
    if (served == null || served.isEmpty) return null;
    for (final h in served) {
      final station = nearbyStationFor(h.stop, from: from);
      if (station == null) continue;
      for (final group in stationLineGroups(station)) {
        if (group.route.routeId == route.routeId &&
            group.directions.isNotEmpty) {
          return (station: station, departure: group.directions.first);
        }
      }
    }
    return null;
  }

  /// Lignes triées pour l'affichage : structurantes (tram/busway/navibus)
  /// d'abord, puis par code de ligne.
  List<GtfsRoute> _sortedRoutes(List<GtfsRoute> routes) {
    return List<GtfsRoute>.from(routes)
      ..sort((a, b) {
        final sa = a.transportType == 'bus' ? 1 : 0;
        final sb = b.transportType == 'bus' ? 1 : 0;
        if (sa != sb) return sa - sb;
        return (a.routeShortName ?? a.routeId)
            .compareTo(b.routeShortName ?? b.routeId);
      });
  }

  // Cache des noms de stations normalisés (recherche insensible aux accents).
  final Map<String, String> _normalizedNameCache = {};

  static String _normalizeText(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ûüù]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Recherche de stations par nom (insensible aux accents et à la casse).
  /// Seules les stations desservies par au moins une ligne sont retournées.
  /// Les correspondances par préfixe passent en premier ; à pertinence
  /// égale, tri par distance à [from] si fourni, sinon alphabétique.
  List<NearbyStation> searchStations(String query,
      {LatLng? from, int limit = 25}) {
    _buildNetworkGraph();
    final q = _normalizeText(query);
    if (q.isEmpty) return const [];

    final prefix = <NearbyStation>[];
    final contains = <NearbyStation>[];
    for (final stop in _cachedStops) {
      final name = _normalizedNameCache.putIfAbsent(
          stop.stopName, () => _normalizeText(stop.stopName));
      final bool isPrefix = name.startsWith(q);
      if (!isPrefix && !name.contains(q)) continue;
      final routes = _routesByStationId[stop.stopId];
      if (routes == null || routes.isEmpty) continue;
      final station = NearbyStation(
        stop: stop,
        distanceMeters: from == null
            ? 0
            : _distance.as(LengthUnit.Meter, from, stop.position),
        routes: _sortedRoutes(routes),
      );
      (isPrefix ? prefix : contains).add(station);
    }

    int compare(NearbyStation a, NearbyStation b) => from == null
        ? a.stop.stopName.compareTo(b.stop.stopName)
        : a.distanceMeters.compareTo(b.distanceMeters);
    prefix.sort(compare);
    contains.sort(compare);
    return [...prefix, ...contains].take(limit).toList();
  }

  /// Recherche de lignes par numéro ou nom (insensible aux accents).
  List<GtfsRoute> searchRoutes(String query, {int limit = 20}) {
    final q = _normalizeText(query);
    if (q.isEmpty) return const [];

    final prefix = <GtfsRoute>[];
    final contains = <GtfsRoute>[];
    for (final route in _cachedRoutes) {
      final short = _normalizeText(route.routeShortName ?? '');
      final long = _normalizeText(route.routeLongName ?? '');
      final id = _normalizeText(route.routeId);
      final bool isPrefix =
          short.startsWith(q) || long.startsWith(q) || id.startsWith(q);
      final bool matches =
          isPrefix || short.contains(q) || long.contains(q) || id.contains(q);
      if (!matches) continue;
      (isPrefix ? prefix : contains).add(route);
    }

    int compare(GtfsRoute a, GtfsRoute b) =>
        (a.routeShortName ?? a.routeId).compareTo(b.routeShortName ?? b.routeId);
    prefix.sort(compare);
    contains.sort(compare);
    return [...prefix, ...contains].take(limit).toList();
  }

  /// Attente estimée (minutes) avant le prochain passage de [route] à [stop]
  /// vers [direction]. Sans horaires réels, on simule un cadencement régulier
  /// décalé de façon déterministe par triplet (ligne, station, direction) :
  /// le compte à rebours reste cohérent d'un rafraîchissement à l'autre.
  int estimateWaitMinutes(GtfsRoute route, GtfsStop stop,
      {String direction = '', DateTime? now}) {
    final t = now ?? DateTime.now();
    // Horaire théorique réel (GTFS) en priorité.
    final next = nextRealDeparture(route, stop, direction: direction, now: t);
    if (next != null) {
      final secs = next.difference(t).inSeconds;
      return secs <= 0 ? 0 : (secs / 60).ceil();
    }
    // Repli : cadencement régulier simulé.
    final headway = _headwayMinutes[route.transportType] ?? 12;
    final offset = (route.routeId.hashCode ^
            stop.stopName.hashCode ^
            direction.hashCode)
        .abs() %
        headway;
    final minuteOfDay = t.hour * 60 + t.minute;
    return headway - ((minuteOfDay + offset) % headway);
  }

  /// Version « secondes » de [estimateWaitMinutes] (même décalage
  /// déterministe) pour animer la position estimée du véhicule de façon
  /// fluide et cohérente avec le compte à rebours affiché.
  int estimateWaitSeconds(GtfsRoute route, GtfsStop stop,
      {String direction = '', DateTime? now}) {
    final t = now ?? DateTime.now();
    // Horaire théorique réel (GTFS) en priorité.
    final next = nextRealDeparture(route, stop, direction: direction, now: t);
    if (next != null) {
      final secs = next.difference(t).inSeconds;
      return secs <= 0 ? 0 : secs;
    }
    // Repli : cadencement régulier simulé.
    final headway = _headwayMinutes[route.transportType] ?? 12;
    final offset = (route.routeId.hashCode ^
            stop.stopName.hashCode ^
            direction.hashCode)
        .abs() %
        headway;
    final secondOfDay = t.hour * 3600 + t.minute * 60 + t.second;
    final headwaySeconds = headway * 60;
    return headwaySeconds - ((secondOfDay + offset * 60) % headwaySeconds);
  }

  /// Cadence moyenne (minutes) d'un mode de transport.
  int headwayMinutesFor(String transportType) =>
      _headwayMinutes[transportType] ?? 12;

  static const int _serviceStartHour = 5;
  static const int _serviceEndHour = 23;
  static const int _serviceEndMinute = 30;

  int _scheduleOffsetMinutes(GtfsRoute route, GtfsStop stop, String direction) {
    final headway = headwayMinutesFor(route.transportType);
    return (route.routeId.hashCode ^
            stop.stopName.hashCode ^
            direction.hashCode)
        .abs() %
        headway;
  }

  /// Horaires théoriques de passage à [stop] pour [route] vers [direction].
  /// Générés par cadencement régulier (faute de stop_times GTFS).
  ///
  /// Avec [fullDay] à vrai, retourne tous les passages de la journée
  /// (5h00–23h30). Sinon, retourne les prochains départs à partir de [now].
  List<DateTime> theoreticalDepartureTimes(
    GtfsRoute route,
    GtfsStop stop, {
    String direction = '',
    DateTime? now,
    int maxCount = 36,
    bool fullDay = false,
  }) {
    final headway = headwayMinutesFor(route.transportType);
    final t = now ?? DateTime.now();

    // Horaires théoriques réels (GTFS) en priorité.
    if (fullDay) {
      // Grille complète d'UN jour de service (le jour de t).
      final times = _realDepartureTimes(route, stop, direction, t,
          dayBefore: 0, dayAfter: 0);
      if (times.isNotEmpty) return times;
    } else {
      // Prochains passages : on inclut la queue de nuit de la veille
      // (minutes > 24:00) et le début du lendemain pour ne pas s'arrêter à
      // minuit. Données réelles présentes ⇒ on ne mélange pas avec la
      // simulation.
      final times = _realDepartureTimes(route, stop, direction, t,
          dayBefore: 1, dayAfter: 1);
      if (times.isNotEmpty) {
        final cutoff = DateTime(t.year, t.month, t.day, t.hour, t.minute);
        final out = <DateTime>[];
        for (final dt in times) {
          if (dt.isBefore(cutoff)) continue;
          out.add(dt);
          if (out.length >= maxCount) break;
        }
        return out;
      }
    }

    // Repli : horaires simulés par cadencement régulier.
    final endOfService = DateTime(
      t.year,
      t.month,
      t.day,
      _serviceEndHour,
      _serviceEndMinute,
    );

    if (fullDay) {
      final offset = _scheduleOffsetMinutes(route, stop, direction);
      var next = DateTime(t.year, t.month, t.day, _serviceStartHour, 0)
          .add(Duration(minutes: offset));
      final times = <DateTime>[];
      while (!next.isAfter(endOfService)) {
        times.add(next);
        next = next.add(Duration(minutes: headway));
      }
      return times;
    }

    final firstWait =
        estimateWaitMinutes(route, stop, direction: direction, now: t);
    var next = DateTime(t.year, t.month, t.day, t.hour, t.minute)
        .add(Duration(minutes: firstWait));

    final times = <DateTime>[];
    while (times.length < maxCount && !next.isAfter(endOfService)) {
      times.add(next);
      next = next.add(Duration(minutes: headway));
    }
    return times;
  }

  /// Prochain passage théorique à partir de [now] dans [times].
  static DateTime? nextTheoreticalDeparture(
    List<DateTime> times, {
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final cutoff = DateTime(ref.year, ref.month, ref.day, ref.hour, ref.minute);
    for (final time in times) {
      if (!time.isBefore(cutoff)) return time;
    }
    return null;
  }

  /// Nom de la station la plus proche d'un point géographique (≤ 250 m).
  String _stopNameNear(LatLng point) {
    GtfsStop? best;
    var bestDist = double.infinity;
    for (final s in _cachedStops) {
      final d = _distance.as(LengthUnit.Meter, point, s.position);
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return bestDist <= 250 ? best!.stopName : '';
  }

  /// Score de correspondance entre un nom d'arrêt et une direction visée.
  int _headsignScore(String name, String target) {
    if (name.isEmpty || target.isEmpty) return 0;
    if (name == target) return 4;
    if (name.startsWith(target) || target.startsWith(name)) return 3;
    if (name.contains(target) || target.contains(name)) return 2;
    return 0;
  }

  /// Tracé de [route] orienté vers [headsign] : une seule polyligne
  /// continue (variante GTFS dont le terminus correspond à la direction).
  /// Indispensable pour le suivi et le plan de ligne des lignes à branches
  /// (ex. tram 1 Beaujoire / Babinière / Jamet), sans mélanger les variantes.
  ///
  /// Si [via] est fourni, la variante retenue doit desservir cet arrêt :
  /// sur une ligne à branches, la variante du terminus visé peut ne pas
  /// passer par l'arrêt de l'utilisateur (ex. Terray → François Mitterrand,
  /// desservi par la branche Babinière et non Beaujoire).
  List<LatLng> shapeToward(GtfsRoute route, String headsign, {GtfsStop? via}) {
    if (route.shapes.isEmpty) return const [];
    final target = _normalizeText(headsign);

    List<LatLng>? bestSeg;
    var bestScore = 0;
    var bestLen = 0;

    for (final segment in route.shapes) {
      if (segment.length < 2) continue;
      final startName = _normalizeText(_stopNameNear(segment.first));
      final endName = _normalizeText(_stopNameNear(segment.last));

      final endScore = _headsignScore(endName, target);
      if (endScore > 0) {
        final len = segment.length;
        if (endScore > bestScore || (endScore == bestScore && len > bestLen)) {
          bestScore = endScore;
          bestLen = len;
          bestSeg = segment;
        }
      }

      final startScore = _headsignScore(startName, target);
      if (startScore > 0) {
        final reversed = segment.reversed.toList();
        final len = reversed.length;
        if (startScore > bestScore ||
            (startScore == bestScore && len > bestLen)) {
          bestScore = startScore;
          bestLen = len;
          bestSeg = reversed;
        }
      }
    }

    final headsignSeg = bestSeg != null && bestScore > 0 ? bestSeg : null;

    if (via != null &&
        (headsignSeg == null ||
            _shapeDistanceMeters(headsignSeg, via.position) >
                _stopToShapeMeters)) {
      final viaSeg = _longestShapeServing(route, via.position);
      if (viaSeg != null) {
        // Oriente la branche de l'arrêt vers le terminus visé : l'extrémité
        // la plus proche du terminus directionnel devient la fin du tracé.
        final reference = headsignSeg?.last;
        if (reference != null &&
            _distance.as(LengthUnit.Meter, viaSeg.first, reference) <
                _distance.as(LengthUnit.Meter, viaSeg.last, reference)) {
          return viaSeg.reversed.toList();
        }
        return viaSeg;
      }
    }

    if (headsignSeg != null) return headsignSeg;
    return route.shapes.reduce((a, b) => a.length >= b.length ? a : b);
  }

  /// Distance minimale (mètres) entre [point] et les sommets de [segment].
  double _shapeDistanceMeters(List<LatLng> segment, LatLng point) {
    var best = double.infinity;
    for (final q in segment) {
      final d = _distance.as(LengthUnit.Meter, q, point);
      if (d < best) best = d;
    }
    return best;
  }

  /// Variante la plus longue de [route] passant à moins de
  /// [_stopToShapeMeters] de [point], sinon null.
  List<LatLng>? _longestShapeServing(GtfsRoute route, LatLng point) {
    List<LatLng>? best;
    for (final segment in route.shapes) {
      if (segment.length < 2) continue;
      if (_shapeDistanceMeters(segment, point) > _stopToShapeMeters) continue;
      if (best == null || segment.length > best.length) best = segment;
    }
    return best;
  }

  /// Tracés à afficher sur la carte (vue d'ensemble, style Naolib).
  ///
  /// Chaque branche n'est dessinée qu'une fois : les variantes aller et
  /// retour (A→B / B→A) sont fusionnées en ne conservant que la plus longue.
  /// Les [route.shapes] complets restent disponibles pour le routage et le
  /// suivi directionnel ([shapeToward]).
  List<List<LatLng>> displayShapes(GtfsRoute route) {
    final cached = _displayShapesCache[route.routeId];
    if (cached != null) return cached;

    final best = <String, List<LatLng>>{};
    for (final segment in route.shapes) {
      if (segment.length < 2) continue;
      final a = _normalizeText(_stopNameNear(segment.first));
      final b = _normalizeText(_stopNameNear(segment.last));
      if (a.isEmpty || b.isEmpty) continue;
      final key = a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
      final prev = best[key];
      if (prev == null || segment.length > prev.length) {
        best[key] = segment;
      }
    }

    // Troncs longs dessinés en premier (sous les raccords de branche).
    final segments = best.values.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    _displayShapesCache[route.routeId] = segments;
    return segments;
  }

  /// Position estimée du véhicule de [route] qui atteindra [stop] (direction
  /// [headsign]) dans [waitSeconds] : on remonte le tracé depuis l'arrêt sur
  /// la distance que le véhicule parcourra d'ici là. Retourne null si la
  /// ligne n'a pas de tracé exploitable.
  LatLng? projectVehicleOnRoute(
      GtfsRoute route, GtfsStop stop, String headsign, double waitSeconds) {
    final segment = shapeToward(route, headsign, via: stop);
    if (segment.length < 2) return null;

    var bestIndex = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < segment.length; i++) {
      final d = _distance.as(LengthUnit.Meter, segment[i], stop.position);
      if (d < bestDist) {
        bestDist = d;
        bestIndex = i;
      }
    }

    final speed = _avgSpeedMps[route.transportType] ?? 4.2;
    double remaining = waitSeconds * speed;

    var index = bestIndex;
    var current = segment[bestIndex];
    // Le véhicule approche depuis les index inférieurs (amont du tracé
    // orienté vers [headsign] en bout de ligne).
    while (remaining > 0 && index > 0) {
      final prev = segment[index - 1];
      final d = _distance.as(LengthUnit.Meter, prev, current);
      if (d >= remaining && d > 0) {
        final f = remaining / d;
        return LatLng(
          prev.latitude + (current.latitude - prev.latitude) * f,
          prev.longitude + (current.longitude - prev.longitude) * f,
        );
      }
      remaining -= d;
      current = prev;
      index--;
    }
    return current;
  }

  // Cache des positions d'arrêts projetées sur les tracés (par routeId).
  final Map<String, Map<String, LatLng>> _snappedStopsByRoute = {};

  /// Position de [stop] projetée orthogonalement sur le tracé de [route]
  /// (point le plus proche, projections sur les segments incluses). Sert à
  /// coller les arrêts à la polyligne pendant le suivi d'une ligne. Retourne
  /// la position d'origine si la ligne n'a pas de tracé ou si l'arrêt en est
  /// trop éloigné (probable erreur de rattachement).
  /// Si [headsign] est fourni, seule la variante orientée vers cette
  /// direction est utilisée (évite de coller à une branche parallèle).
  LatLng snapToRouteShape(GtfsRoute route, GtfsStop stop, {String? headsign}) {
    final cacheKey = headsign == null ? stop.stopId : '$headsign|${stop.stopId}';
    final cached = _snappedStopsByRoute[route.routeId]?[cacheKey];
    if (cached != null) return cached;
    if (route.shapes.isEmpty) return stop.position;

    final segments = headsign == null
        ? route.shapes
        : [shapeToward(route, headsign, via: stop)];

    final p = stop.position;
    // Repère local en mètres (équirectangulaire) centré sur l'arrêt.
    final cosLat = math.cos(p.latitude * math.pi / 180);
    const mPerDeg = 111320.0;
    double xOf(LatLng q) => (q.longitude - p.longitude) * mPerDeg * cosLat;
    double yOf(LatLng q) => (q.latitude - p.latitude) * mPerDeg;

    LatLng best = p;
    double bestD2 = double.infinity;
    for (final segment in segments) {
      for (var i = 0; i + 1 < segment.length; i++) {
        final ax = xOf(segment[i]), ay = yOf(segment[i]);
        final bx = xOf(segment[i + 1]), by = yOf(segment[i + 1]);
        final dx = bx - ax, dy = by - ay;
        final len2 = dx * dx + dy * dy;
        // Projection de l'arrêt (origine du repère) sur [a, b].
        var t = len2 == 0 ? 0.0 : (-(ax * dx) - (ay * dy)) / len2;
        t = t.clamp(0.0, 1.0);
        final px = ax + t * dx, py = ay + t * dy;
        final d2 = px * px + py * py;
        if (d2 < bestD2) {
          bestD2 = d2;
          best = LatLng(
            segment[i].latitude +
                (segment[i + 1].latitude - segment[i].latitude) * t,
            segment[i].longitude +
                (segment[i + 1].longitude - segment[i].longitude) * t,
          );
        }
      }
    }
    if (math.sqrt(bestD2) > _stopToShapeMeters * 2) best = p;
    (_snappedStopsByRoute[route.routeId] ??= {})[cacheKey] = best;
    return best;
  }

  /// Arrêts desservis par [route] dans le sens de circulation menant à
  /// [headsign] (ordre de parcours du véhicule). Liste vide si le graphe ne
  /// rattache aucun arrêt à la ligne. [via] restreint aux variantes
  /// desservant cet arrêt (lignes à branches).
  List<GtfsStop> stopsToward(GtfsRoute route, String headsign,
      {GtfsStop? via}) {
    _buildNetworkGraph();
    final segment = shapeToward(route, headsign, via: via);
    if (segment.length < 2) return const [];

    final served = _servedStopsByRouteId[route.routeId];
    if (served == null || served.isEmpty) return const [];

    final hits = <_RouteStopHit>[];
    for (final h in served) {
      var order = 0;
      var best = double.infinity;
      for (var i = 0; i < segment.length; i++) {
        final d =
            _distance.as(LengthUnit.Meter, segment[i], h.stop.position);
        if (d < best) {
          best = d;
          order = i;
        }
      }
      if (best <= _stopToShapeMeters) {
        hits.add(_RouteStopHit(h.stop, order));
      }
    }
    hits.sort((a, b) => a.order.compareTo(b.order));

    final seen = <String>{};
    final out = <GtfsStop>[];
    for (final h in hits) {
      if (seen.add(h.stop.stopId)) out.add(h.stop);
    }
    return out;
  }

  /// Terminus aux deux extrémités du sens de circulation vers [headsign].
  (String origin, String destination)? terminiToward(
      GtfsRoute route, String headsign) {
    final stops = stopsToward(route, headsign);
    if (stops.length < 2) return null;
    return (stops.first.stopName, stops.last.stopName);
  }

  /// Index, dans [stops] (sens de parcours), du premier arrêt encore devant
  /// un véhicule situé [waitSeconds] en amont de l'arrêt [targetIndex].
  int firstStopAheadIndex(List<GtfsStop> stops, int targetIndex,
      String transportType, double waitSeconds) {
    if (targetIndex <= 0) return 0;
    double remaining = waitSeconds * avgSpeedMps(transportType);
    int index = targetIndex;
    while (index > 0 && remaining > 0) {
      // Facteur de détour 1.35 : cohérent avec _estimateMinutes.
      final d = _distance.as(LengthUnit.Meter, stops[index - 1].position,
              stops[index].position) *
          1.35;
      if (d > remaining) break;
      remaining -= d;
      index--;
    }
    return index;
  }

  /// Terminus d'une ligne : premier et dernier arrêt desservis le long du
  /// tracé, sinon repli sur le nom long GTFS (« Terminus A - Terminus B »).
  (String, String)? _routeTermini(GtfsRoute route) {
    final served = _servedStopsByRouteId[route.routeId];
    if (served != null && served.length >= 2) {
      return (served.first.stop.stopName, served.last.stop.stopName);
    }
    final long = route.routeLongName;
    if (long != null && long.contains(' - ')) {
      final parts = long.split(' - ');
      return (parts.first.trim(), parts.last.trim());
    }
    return null;
  }

  /// Prochains passages estimés à une station : une entrée par couple
  /// (ligne, direction), dans l'ordre des lignes de [NearbyStation.routes].
  /// Une station terminus n'est desservie que dans un sens.
  List<StationDeparture> stationDepartures(NearbyStation station,
      {DateTime? now}) {
    final t = now ?? DateTime.now();
    final out = <StationDeparture>[];
    for (final route in station.routes) {
      final termini = _routeTermini(route);
      final headsigns = <String>[];
      if (termini == null) {
        headsigns.add(route.routeLongName ?? 'Direction inconnue');
      } else {
        if (station.stop.stopName != termini.$2) headsigns.add(termini.$2);
        if (station.stop.stopName != termini.$1) headsigns.add(termini.$1);
      }
      final headway = _headwayMinutes[route.transportType] ?? 12;
      for (final headsign in headsigns) {
        final wait = estimateWaitMinutes(route, station.stop,
            direction: headsign, now: t);
        out.add(StationDeparture(
          route: route,
          headsign: headsign,
          waitMinutes: wait,
          nextWaitMinutes: wait + headway,
        ));
      }
    }
    return out;
  }

  /// Départs regroupés par ligne (jamais deux fois la même ligne).
  /// Chaque groupe liste ses directions triées par passage le plus proche ;
  /// les groupes sont ordonnés par prochain départ le plus imminent.
  List<StationLineGroup> stationLineGroups(NearbyStation station,
      {DateTime? now}) {
    final departures = stationDepartures(station, now: now);
    final byRoute = <String, StationLineGroup>{};
    final order = <String>[];
    for (final dep in departures) {
      final id = dep.route.routeId;
      final group = byRoute.putIfAbsent(id, () {
        order.add(id);
        return StationLineGroup(route: dep.route, directions: []);
      });
      group.directions.add(dep);
    }
    final groups = [for (final id in order) byRoute[id]!];
    for (final g in groups) {
      g.directions.sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
    }
    groups.sort((a, b) {
      // Lignes structurantes (tram/busway/navibus) avant le bus.
      final sa = a.route.transportType == 'bus' ? 1 : 0;
      final sb = b.route.transportType == 'bus' ? 1 : 0;
      if (sa != sb) return sa - sb;
      return a.soonestWait.compareTo(b.soonestWait);
    });
    return groups;
  }

  /// Plus petit temps d'attente, toutes lignes/directions confondues, à une
  /// station (utilisé pour le scoring de pertinence « Le plus rapide »).
  int soonestWait(NearbyStation station, {DateTime? now}) {
    final departures = stationDepartures(station, now: now);
    if (departures.isEmpty) return 9999;
    return departures
        .map((d) => d.waitMinutes)
        .reduce((a, b) => a < b ? a : b);
  }

  // Recherche d'itinéraire simple (A -> B).
  // [userPosition] : position GPS réelle servant à résoudre « Ma position »
  // (sinon repli sur le centre-ville par défaut).
  Future<List<TransitItinerary>> searchItinerary(
      String originText, String destinationText,
      {LatLng? userPosition, DateTime? now}) async {
    // Routage hors-ligne (sans backend) — recherche textuelle simplifiée
    final String start = originText.trim().toLowerCase();
    final String dest = destinationText.trim().toLowerCase();

    if (_supabaseService.isOfflineMode) {
      return _searchItineraryLocal(start, dest,
          userPosition: userPosition, now: now);
    }

    try {
      // Pour une vraie BDD Supabase, nous exécutons une fonction SQL personnalisée (RPC)
      // qui résout la recherche A -> B. Tant qu'elle n'est pas déployée
      // (find_routes_ab absente du schéma), on retombe sur le routage local.
      final response = await _supabaseService.client!.rpc('find_routes_ab', params: {
        'origin_query': originText,
        'dest_query': destinationText,
      });

      // Mappe la réponse RPC vers notre modèle
      final itineraries = (response as List).map((it) {
        final stepsList = (it['steps'] as List).map((st) {
          return RouteStep(
            instruction: st['instruction'] as String,
            lineShortName: st['line_short_name'] as String,
            lineType: st['line_type'] as String,
            departureStop: st['departure_stop'] as String,
            arrivalStop: st['arrival_stop'] as String,
            durationMinutes: st['duration_minutes'] as int,
          );
        }).toList();
        return TransitItinerary(
          totalDurationMinutes: it['total_duration'] as int,
          steps: stepsList,
        );
      }).toList();

      if (itineraries.isNotEmpty) return itineraries;
      return _searchItineraryLocal(start, dest,
          userPosition: userPosition, now: now);
    } catch (e) {
      debugPrint('Wazibus: Error performing routing RPC ($e). Falling back to local routing.');
      return _searchItineraryLocal(start, dest,
          userPosition: userPosition, now: now);
    }
  }

  // =====================================================================
  // Routage A -> B approché (hors-ligne, sans backend)
  //
  // Faute d'horaires GTFS (trips / stop_times) dans les données fournies,
  // on construit un graphe d'adjacence par PROXIMITÉ SPATIALE entre les
  // arrêts et les tracés des lignes, puis on cherche un trajet direct ou
  // avec une correspondance. Les durées sont ESTIMÉES (distance × détour
  // / vitesse moyenne par mode), pas issues d'horaires réels.
  // =====================================================================

  // Rayon de rattachement d'un arrêt à un tracé de ligne (mètres).
  static const double _stopToShapeMeters = 130;
  // Vitesses commerciales moyennes approximatives (m/s) incluant les arrêts.
  static const Map<String, double> _avgSpeedMps = {
    'tram': 5.6, // ~20 km/h
    'busway': 5.0, // ~18 km/h
    'navibus': 3.3, // ~12 km/h
    'bus': 4.2, // ~15 km/h
  };

  /// Vitesse commerciale moyenne (m/s) d'un mode de transport.
  static double avgSpeedMps(String transportType) =>
      _avgSpeedMps[transportType] ?? 4.2;

  // Vitesse de marche piétonne (~4,8 km/h) pour la marche d'accès à l'arrêt.
  static const double _walkSpeedMps = 1.33;

  /// Minutes de marche pour [meters] ; 0 si on est quasiment à l'arrêt.
  int _walkMinutes(double meters) =>
      meters < 60 ? 0 : (meters / _walkSpeedMps / 60).ceil();

  /// true si la saisie désigne la position courante (« Ma position », vide…).
  bool _isPositionQuery(String query) {
    final q = _normalizeText(query);
    return q.isEmpty ||
        q.contains('ma position') ||
        q == 'position' ||
        q.contains('autour');
  }

  /// Arrêts candidats (montée ou descente) pour une saisie. « Ma position » →
  /// plusieurs arrêts proches avec leur marche (accès au départ / égress à
  /// l'arrivée) ; un arrêt nommé → cet arrêt seul (marche 0).
  List<({GtfsStop stop, int walkMin})> _accessCandidates(
      String query, LatLng? userPosition) {
    if (userPosition != null && _isPositionQuery(query)) {
      return nearbyStations(userPosition, limit: 4, maxMeters: 700)
          .map((n) => (stop: n.stop, walkMin: _walkMinutes(n.distanceMeters)))
          .toList();
    }
    final s = _resolveStop(query, near: userPosition);
    return s == null ? const [] : [(stop: s, walkMin: 0)];
  }

  // Marge minimale de correspondance (marche + battement) avant de chercher le
  // prochain passage réel de la ligne suivante.
  static const int _minConnectionMinutes = 4;
  // Au-delà de cette attente, une ligne connue des horaires est considérée
  // « pas en service maintenant » (typiquement la nuit) : l'itinéraire est
  // conservé mais déclassé sous les options réellement disponibles.
  static const int _maxReasonableWaitMinutes = 75;

  /// false si les horaires officiels prouvent que [route] ne dessert PAS
  /// [stop] : la ligne figure aux horaires mais cet arrêt n'apparaît pas dans
  /// sa grille → rattachement spatial fantôme (un arrêt de bus voisin collé au
  /// tracé d'un tram, p. ex.). true si l'arrêt est servi, ou si on ne peut pas
  /// trancher (ligne absente des horaires).
  bool _scheduleServesStop(GtfsRoute route, GtfsStop stop) {
    final byStop = _sched?[route.routeShortName ?? route.routeId];
    if (byStop is! Map) return true; // ligne hors horaires : on ne tranche pas
    return _scheduleKnowsStop(route, stop);
  }

  /// Temps de parcours réel en véhicule (minutes) de [board] à [alight] sur
  /// [route] vers le terminus [terminus], déduit des temps médians restants
  /// jusqu'au terminus (`'r'`, précompilés par tool/build_schedules.py) :
  /// reste[board] − reste[alight]. Null si données absentes ou incohérentes
  /// (l'appelant retombe alors sur l'estimation géométrique).
  int? _realInVehicleMinutes(
      GtfsRoute route, GtfsStop board, GtfsStop alight, String terminus) {
    if (terminus.isEmpty) return null;
    final byStop = _sched?[route.routeShortName ?? route.routeId];
    if (byStop is! Map) return null;
    final rBoard = _remainingToTerminus(byStop[_normalizeText(board.stopName)], terminus);
    final rAlight = _remainingToTerminus(byStop[_normalizeText(alight.stopName)], terminus);
    if (rBoard == null || rAlight == null) return null;
    final mins = rBoard - rAlight;
    return mins > 0 ? mins : null;
  }

  /// Temps médian restant jusqu'au terminus (`'r'`) d'une cellule horaire.
  int? _remainingToTerminus(dynamic cells, String terminus) {
    if (cells is! Map) return null;
    final cell = cells[terminus];
    if (cell is! Map) return null;
    final r = cell['r'];
    return r is int ? r : null;
  }

  /// Terminus (headsign) de [route] dans le sens [board] → [toStop], pour
  /// retrouver le bon sens dans les horaires. On ne teste que les termini qui
  /// desservent réellement [board] (clés des horaires), via le tracé orienté
  /// `stopsToward` (mis en cache). '' si indéterminé (les horaires fusionnent
  /// alors les deux sens).
  String _legHeadsign(GtfsRoute route, GtfsStop board, GtfsStop toStop) {
    final short = route.routeShortName ?? route.routeId;
    final byStop = _sched?[short];
    if (byStop is! Map) return '';
    final cells = byStop[_normalizeText(board.stopName)];
    if (cells is! Map) return '';
    for (final term in cells.keys) {
      final stops = stopsToward(route, term as String);
      final bIdx = stops.indexWhere((s) => s.stopId == board.stopId);
      final aIdx = stops.indexWhere((s) => s.stopId == toStop.stopId);
      if (bIdx >= 0 && aIdx > bIdx) return term;
    }
    return '';
  }

  /// Date chaque tronçon d'un itinéraire à partir de [now] : pour chaque leg on
  /// cherche le prochain passage théorique réel à l'arrêt de montée (en tenant
  /// compte de la marge de correspondance), puis on propage l'arrivée estimée
  /// en véhicule. Faute d'horaire réel pour un tronçon, on reste « au plus
  /// tôt ». Renvoie les heures par leg + indicateurs de fiabilité.
  _TimedItinerary _timeItinerary(List<_LegSpec> legs, DateTime now) {
    final departures = <DateTime>[];
    final arrivals = <DateTime>[];
    var realTiming = false;
    var serviceLater = false;
    var t = now;

    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final readyAt =
          i == 0 ? t : t.add(const Duration(minutes: _minConnectionMinutes));
      final dep = nextRealDeparture(leg.route, leg.board,
          direction: leg.direction, now: readyAt);

      final DateTime departure;
      if (dep != null) {
        if (i == 0) realTiming = true;
        if (dep.difference(readyAt).inMinutes > _maxReasonableWaitMinutes) {
          serviceLater = true;
        }
        departure = dep;
      } else if (_scheduleKnowsStop(leg.route, leg.board)) {
        // Ligne connue des horaires à cet arrêt mais sans aucun passage
        // exploitable (ex. bus de nuit interrogé en journée) : elle ne
        // circule pas, l'itinéraire est invalide — ne pas l'estimer « au
        // plus tôt » comme s'il partait maintenant.
        return _TimedItinerary.invalid;
      } else {
        departure = readyAt; // ligne hors horaires : estimation au plus tôt
      }
      final arrival = departure.add(Duration(minutes: leg.inVehicleMinutes));
      departures.add(departure);
      arrivals.add(arrival);
      t = arrival;
    }
    return _TimedItinerary(departures, arrivals, realTiming, serviceLater);
  }

  /// true si les horaires officiels couvrent ce couple (ligne, arrêt) — donc on
  /// peut conclure « pas de passage = pas en service » plutôt que d'estimer.
  bool _scheduleKnowsStop(GtfsRoute route, GtfsStop stop) {
    final byStop = _sched?[route.routeShortName ?? route.routeId];
    return byStop is Map && byStop.containsKey(_normalizeText(stop.stopName));
  }

  Future<List<TransitItinerary>> _searchItineraryLocal(
      String start, String dest,
      {LatLng? userPosition, DateTime? now}) async {
    if (_cachedRoutes.isEmpty) await fetchRoutes();
    if (_cachedStops.isEmpty) await fetchStops();
    _buildNetworkGraph();
    final ref = now ?? DateTime.now();

    // Arrêts candidats au départ ET à l'arrivée. Pour « Ma position », on
    // évalue plusieurs arrêts proches — Naolib marche volontiers 1-2 min vers
    // un arrêt mieux desservi (tram/Chronobus) plutôt que de se verrouiller
    // sur le plus proche —, chacun avec sa marche d'accès/égress. Pour un arrêt
    // nommé, on s'y tient (marche 0).
    final origins = _accessCandidates(start, userPosition);
    final dests = _accessCandidates(dest, userPosition);
    if (origins.isEmpty || dests.isEmpty) return [];

    final results = <TransitItinerary>[];
    for (final o in origins) {
      for (final d in dests) {
        if (o.stop.stopId == d.stop.stopId) continue;
        final core = _searchFromOrigin(
            o.stop, d.stop, ref.add(Duration(minutes: o.walkMin)));
        for (var it in core) {
          if (d.walkMin > 0) {
            it = _withEgressWalk(it, d.stop.stopName, walkMin: d.walkMin);
          }
          if (o.walkMin > 0) {
            it = _withAccessWalk(it, o.stop.stopName, walkMin: o.walkMin);
          }
          results.add(it);
        }
      }
    }

    // Tri « le plus rapide » = arrivée la plus tôt, en plaçant d'abord les
    // options réellement en service (les lignes qui ne circulent que bien plus
    // tard — service de nuit — sont déclassées). Déduplication par signature de
    // lignes (hors marche), top 4.
    results.sort(_compareItineraries);
    final seen = <String>{};
    final unique = <TransitItinerary>[];
    for (final it in results) {
      final sig = it.steps
          .where((s) => s.lineType != 'walk')
          .map((s) => s.lineShortName)
          .join('>');
      if (seen.add(sig)) unique.add(it);
      if (unique.length >= 4) break;
    }
    return unique;
  }

  /// Cœur du routage depuis UN arrêt d'origine vers [destination] à [ref]
  /// (trajets directs + une correspondance), sans déduplication ni marche
  /// d'accès. Écarte les rattachements spatiaux fantômes (cf.
  /// [_scheduleServesStop]).
  List<TransitItinerary> _searchFromOrigin(
      GtfsStop origin, GtfsStop destination, DateTime ref) {
    final originRoutes = (_routesByStationId[origin.stopId] ?? const [])
        .where((r) => _scheduleServesStop(r, origin))
        .toList();
    final destRoutes = (_routesByStationId[destination.stopId] ?? const [])
        .where((r) => _scheduleServesStop(r, destination))
        .toList();
    if (originRoutes.isEmpty || destRoutes.isEmpty) return const [];

    final results = <TransitItinerary>[];

    // 1. Trajets directs : une même ligne dessert origine ET destination.
    final destRouteIds = destRoutes.map((r) => r.routeId).toSet();
    for (final route in originRoutes) {
      if (!destRouteIds.contains(route.routeId)) continue;
      final itin = _directItinerary(route, origin, destination, ref);
      if (itin != null) results.add(itin);
    }

    // 2. Trajets avec une correspondance (si peu/pas de direct).
    if (results.length < 3) {
      results.addAll(_transferItineraries(
          origin, destination, originRoutes, destRoutes, ref, max: 3));
    }
    return results;
  }

  /// Préfixe [it] d'une marche d'accès de [walkMin] min jusqu'à
  /// [boardStopName] : on part juste à temps pour le 1er passage (heure de
  /// départ reculée d'autant).
  TransitItinerary _withAccessWalk(TransitItinerary it, String boardStopName,
      {required int walkMin}) {
    final firstDep = it.departureTime;
    final walkStart = firstDep?.subtract(Duration(minutes: walkMin));
    final walkStep = RouteStep(
      instruction: 'Marcher jusqu\'à $boardStopName',
      lineShortName: '',
      lineType: 'walk',
      departureStop: 'Ma position',
      arrivalStop: boardStopName,
      durationMinutes: walkMin,
      departureTime: walkStart,
      arrivalTime: firstDep,
    );
    final total = (walkStart != null && it.arrivalTime != null)
        ? it.arrivalTime!.difference(walkStart).inMinutes
        : it.totalDurationMinutes + walkMin;
    return TransitItinerary(
      steps: [walkStep, ...it.steps],
      totalDurationMinutes: total,
      estimatedCost: it.estimatedCost,
      departureTime: walkStart,
      arrivalTime: it.arrivalTime,
      realTiming: it.realTiming,
      serviceLater: it.serviceLater,
    );
  }

  /// Suffixe [it] d'une marche d'égress de [walkMin] min depuis
  /// [alightStopName] jusqu'à la destination (heure d'arrivée repoussée
  /// d'autant).
  TransitItinerary _withEgressWalk(TransitItinerary it, String alightStopName,
      {required int walkMin}) {
    final lastArr = it.arrivalTime;
    final walkEnd = lastArr?.add(Duration(minutes: walkMin));
    final walkStep = RouteStep(
      instruction: 'Marcher jusqu\'à destination',
      lineShortName: '',
      lineType: 'walk',
      departureStop: alightStopName,
      arrivalStop: 'Destination',
      durationMinutes: walkMin,
      departureTime: lastArr,
      arrivalTime: walkEnd,
    );
    final total = (it.departureTime != null && walkEnd != null)
        ? walkEnd.difference(it.departureTime!).inMinutes
        : it.totalDurationMinutes + walkMin;
    return TransitItinerary(
      steps: [...it.steps, walkStep],
      totalDurationMinutes: total,
      estimatedCost: it.estimatedCost,
      departureTime: it.departureTime,
      arrivalTime: walkEnd,
      realTiming: it.realTiming,
      serviceLater: it.serviceLater,
    );
  }

  TransitItinerary? _directItinerary(
      GtfsRoute route, GtfsStop origin, GtfsStop destination, DateTime now) {
    final served = _servedStopsByRouteId[route.routeId];
    if (served == null) return null;
    final oOrder = _orderOf(served, origin.stopId);
    final dOrder = _orderOf(served, destination.stopId);
    // Des ordres égaux restent possibles : deux stations d'une branche se
    // projettent parfois au même index du segment de référence. Le trajet
    // est valable, seul le décompte d'arrêts intermédiaires est inconnu.
    if (oOrder == null || dOrder == null) return null;

    final between = served
        .where((h) => h.order > (oOrder < dOrder ? oOrder : dOrder) &&
            h.order < (oOrder < dOrder ? dOrder : oOrder))
        .length;

    final headsign = _legHeadsign(route, origin, destination);
    final minutes = _realInVehicleMinutes(route, origin, destination, headsign) ??
        _estimateMinutes(origin, destination, route.transportType);
    final timed = _timeItinerary(
      [_LegSpec(route, origin, headsign, minutes)],
      now,
    );
    if (!timed.valid) return null;
    return TransitItinerary(
      totalDurationMinutes:
          timed.arrivals.last.difference(timed.departures.first).inMinutes,
      departureTime: timed.departures.first,
      arrivalTime: timed.arrivals.last,
      realTiming: timed.realTiming,
      serviceLater: timed.serviceLater,
      steps: [
        RouteStep(
          instruction:
              'Prendre ${_lineLabel(route)} vers ${destination.stopName}'
              '${between > 0 ? ' ($between arrêt${between > 1 ? 's' : ''})' : ''}',
          lineShortName: route.routeShortName ?? route.routeId,
          lineType: route.transportType,
          departureStop: origin.stopName,
          arrivalStop: destination.stopName,
          durationMinutes: minutes,
          departureTime: timed.departures.first,
          arrivalTime: timed.arrivals.first,
        ),
      ],
    );
  }

  List<TransitItinerary> _transferItineraries(
    GtfsStop origin,
    GtfsStop destination,
    List<GtfsRoute> originRoutes,
    List<GtfsRoute> destRoutes,
    DateTime now, {
    required int max,
  }) {
    final out = <TransitItinerary>[];
    // Pénalité de correspondance utilisée seulement pour départager les arrêts
    // candidats (l'attente réelle est ensuite calée sur les horaires).
    const transferPenalty = _minConnectionMinutes;

    for (final r1 in originRoutes) {
      final served1 = _servedStopsByRouteId[r1.routeId];
      if (served1 == null) continue;
      final stops1 = {for (final h in served1) h.stop.stopId: h.stop};

      for (final r2 in destRoutes) {
        if (r1.routeId == r2.routeId) continue;
        final served2 = _servedStopsByRouteId[r2.routeId];
        if (served2 == null) continue;

        // Meilleure station de correspondance : desservie par r1 et r2,
        // minimisant la durée totale estimée.
        GtfsStop? bestTransfer;
        int bestTotal = 1 << 30;
        for (final h in served2) {
          final t = stops1[h.stop.stopId];
          if (t == null) continue;
          if (t.stopId == origin.stopId || t.stopId == destination.stopId) continue;
          // Correspondance réellement desservie par les deux lignes (pas un
          // arrêt fantôme collé aux deux tracés).
          if (!_scheduleServesStop(r1, t) || !_scheduleServesStop(r2, t)) {
            continue;
          }
          final leg1 = _estimateMinutes(origin, t, r1.transportType);
          final leg2 = _estimateMinutes(t, destination, r2.transportType);
          final total = leg1 + leg2 + transferPenalty;
          if (total < bestTotal) {
            bestTotal = total;
            bestTransfer = t;
          }
        }
        if (bestTransfer == null) continue;

        final head1 = _legHeadsign(r1, origin, bestTransfer);
        final head2 = _legHeadsign(r2, bestTransfer, destination);
        final leg1 = _realInVehicleMinutes(r1, origin, bestTransfer, head1) ??
            _estimateMinutes(origin, bestTransfer, r1.transportType);
        final leg2 = _realInVehicleMinutes(r2, bestTransfer, destination, head2) ??
            _estimateMinutes(bestTransfer, destination, r2.transportType);
        final timed = _timeItinerary([
          _LegSpec(r1, origin, head1, leg1),
          _LegSpec(r2, bestTransfer, head2, leg2),
        ], now);
        if (!timed.valid) continue;
        out.add(TransitItinerary(
          totalDurationMinutes:
              timed.arrivals.last.difference(timed.departures.first).inMinutes,
          departureTime: timed.departures.first,
          arrivalTime: timed.arrivals.last,
          realTiming: timed.realTiming,
          serviceLater: timed.serviceLater,
          steps: [
            RouteStep(
              instruction: 'Prendre ${_lineLabel(r1)} vers ${bestTransfer.stopName}',
              lineShortName: r1.routeShortName ?? r1.routeId,
              lineType: r1.transportType,
              departureStop: origin.stopName,
              arrivalStop: bestTransfer.stopName,
              durationMinutes: leg1,
              departureTime: timed.departures[0],
              arrivalTime: timed.arrivals[0],
            ),
            RouteStep(
              instruction:
                  'Correspondance à ${bestTransfer.stopName}, prendre ${_lineLabel(r2)} '
                  'vers ${destination.stopName}',
              lineShortName: r2.routeShortName ?? r2.routeId,
              lineType: r2.transportType,
              departureStop: bestTransfer.stopName,
              arrivalStop: destination.stopName,
              durationMinutes: leg2,
              departureTime: timed.departures[1],
              arrivalTime: timed.arrivals[1],
            ),
          ],
        ));
      }
    }

    out.sort(_compareItineraries);
    return out.take(max).toList();
  }

  /// Ordre « le plus rapide » honnête : d'abord les itinéraires réellement
  /// disponibles, puis par heure d'arrivée réelle (à défaut, durée estimée).
  static int _compareItineraries(TransitItinerary a, TransitItinerary b) {
    if (a.serviceLater != b.serviceLater) return a.serviceLater ? 1 : -1;
    final aa = a.arrivalTime;
    final ba = b.arrivalTime;
    if (aa != null && ba != null) return aa.compareTo(ba);
    return a.totalDurationMinutes.compareTo(b.totalDurationMinutes);
  }

  int? _orderOf(List<_RouteStopHit> served, String stopId) {
    for (final h in served) {
      if (h.stop.stopId == stopId) return h.order;
    }
    return null;
  }

  int _estimateMinutes(GtfsStop a, GtfsStop b, String transportType) {
    final meters = _distance.as(LengthUnit.Meter, a.position, b.position);
    final speed = _avgSpeedMps[transportType] ?? 4.2;
    // Facteur de détour 1.35 (le réseau ne suit pas la ligne droite).
    final minutes = (meters * 1.35 / speed / 60).round();
    return minutes < 1 ? 1 : minutes;
  }

  String _lineLabel(GtfsRoute route) {
    final short = route.routeShortName ?? route.routeId;
    switch (route.transportType) {
      case 'tram':
        return 'le Tram $short';
      case 'busway':
        return 'le Busway $short';
      case 'navibus':
        return 'le Navibus $short';
      default:
        return 'le Bus $short';
    }
  }

  // Centre par défaut (Place du Commerce) pour résoudre "Ma position"
  // quand la position GPS réelle n'est pas disponible.
  static const LatLng _defaultCenter = LatLng(47.218371, -1.553621);

  /// Résout un arrêt depuis une saisie texte : "ma position" -> arrêt le plus
  /// proche de [near] (position GPS) ou du centre par défaut, sinon meilleure
  /// correspondance insensible aux accents (exact > préfixe > contient >
  /// mots en commun), départagée par la distance à [near]. Seules les
  /// stations desservies par au moins une ligne sont candidates : résoudre
  /// vers une station sans ligne garantirait un résultat vide.
  GtfsStop? _resolveStop(String query, {LatLng? near}) {
    final q = _normalizeText(query);
    if (_isPositionQuery(query)) {
      return _nearestStopTo(near ?? _defaultCenter);
    }
    final qTokens = q.split(' ').toSet();

    GtfsStop? best;
    var bestScore = 0;
    var bestDist = double.infinity;
    for (final s in _cachedStops) {
      final routes = _routesByStationId[s.stopId];
      if (routes == null || routes.isEmpty) continue;
      final name = _normalizedNameCache.putIfAbsent(
          s.stopName, () => _normalizeText(s.stopName));

      int score;
      if (name == q) {
        score = 4;
      } else if (name.startsWith(q)) {
        score = 3;
      } else if (name.contains(q)) {
        score = 2;
      } else {
        // Recherche par mots : tous les mots significatifs (> 2 lettres)
        // de la saisie présents dans le nom ("gare nantes sud" -> "Gare Sud"
        // échoue, mais "jardin plantes" -> "Gare Nord - Jardin des Plantes").
        final nTokens = name.split(' ').toSet();
        final meaningful = qTokens.where((t) => t.length > 2);
        score = meaningful.isNotEmpty && meaningful.every(nTokens.contains)
            ? 1
            : 0;
      }
      if (score == 0) continue;

      final d = near == null
          ? 0.0
          : _distance.as(LengthUnit.Meter, near, s.position);
      if (score > bestScore || (score == bestScore && d < bestDist)) {
        bestScore = score;
        bestDist = d;
        best = s;
      }
    }
    return best;
  }

  GtfsStop? _nearestStopTo(LatLng point) {
    GtfsStop? best;
    double bestDist = double.infinity;
    for (final s in _cachedStops) {
      // Une station sans ligne rattachée est inutilisable pour le routage.
      final routes = _routesByStationId[s.stopId];
      if (routes == null || routes.isEmpty) continue;
      final d = _distance.as(LengthUnit.Meter, point, s.position);
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }

  /// Construit (une seule fois) le graphe station <-> lignes par proximité
  /// spatiale entre chaque arrêt physique et les points des tracés de lignes.
  /// On utilise TOUS les arrêts (_allStops) mais on agrège par station
  /// (groupe de quais voisins) via [_stationOfStopId].
  void _buildNetworkGraph() {
    if (_graphBuilt) return;
    if (_cachedRoutes.isEmpty) return;
    final physicalStops = _allStops.isNotEmpty ? _allStops : _cachedStops;
    if (physicalStops.isEmpty) return;

    // Données chargées sans agrégation (ex. Supabase) : 1 quai = 1 station.
    if (_stationOfStopId.isEmpty) {
      for (final s in _cachedStops) {
        _stationOfStopId[s.stopId] = s;
      }
    }

    // Grille spatiale des arrêts (~110 m de côté) pour des recherches rapides.
    const double cell = 0.001;
    final Map<int, List<GtfsStop>> grid = {};
    int cellKey(double lat, double lon) {
      final gx = (lat / cell).floor();
      final gy = (lon / cell).floor();
      return gx * 100000 + gy;
    }

    for (final s in physicalStops) {
      grid.putIfAbsent(cellKey(s.position.latitude, s.position.longitude), () => [])
          .add(s);
    }

    for (final route in _cachedRoutes) {
      if (route.shapes.isEmpty) {
        _servedStopsByRouteId[route.routeId] = const [];
        continue;
      }

      // Rattachement : un arrêt appartient à la ligne s'il est proche d'un
      // point de N'IMPORTE QUEL segment (les rues à sens unique séparent les
      // deux sens). Meilleure distance par station agrégée.
      final Map<String, double> bestDist = {};
      final Map<String, GtfsStop> stationById = {};
      for (final segment in route.shapes) {
        for (final pt in segment) {
          final gx = (pt.latitude / cell).floor();
          final gy = (pt.longitude / cell).floor();
          for (int dx = -1; dx <= 1; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
              final neighbours = grid[(gx + dx) * 100000 + (gy + dy)];
              if (neighbours == null) continue;
              for (final stop in neighbours) {
                final d = _distance.as(LengthUnit.Meter, pt, stop.position);
                if (d > _stopToShapeMeters) continue;
                final station = _stationOfStopId[stop.stopId];
                if (station == null) continue;
                final prev = bestDist[station.stopId];
                if (prev == null || d < prev) {
                  bestDist[station.stopId] = d;
                  stationById[station.stopId] = station;
                }
              }
            }
          }
        }
      }

      // Ordre le long de la ligne : index du point le plus proche sur un
      // UNIQUE segment de référence (le plus long). L'ancien index global,
      // qui traversait tous les segments, mélangeait les deux sens de
      // circulation et produisait des plans de ligne incohérents.
      final refSegment = route.shapes
          .reduce((a, b) => a.length >= b.length ? a : b);
      final hits = <_RouteStopHit>[];
      stationById.forEach((id, station) {
        var order = 0;
        var best = double.infinity;
        for (var i = 0; i < refSegment.length; i++) {
          final d =
              _distance.as(LengthUnit.Meter, refSegment[i], station.position);
          if (d < best) {
            best = d;
            order = i;
          }
        }
        hits.add(_RouteStopHit(station, order));
        _routesByStationId.putIfAbsent(id, () => []).add(route);
      });
      hits.sort((a, b) => a.order.compareTo(b.order));
      _servedStopsByRouteId[route.routeId] = hits;
    }

    _graphBuilt = true;
    debugPrint('Wazibus: graphe réseau construit '
        '(${_routesByStationId.length} stations desservies).');
  }
}

/// Arrêt rattaché à une ligne, avec sa position approximative (ordre) le long
/// du tracé pour reconstituer le sens de circulation.
class _RouteStopHit {
  final GtfsStop stop;
  final int order;
  const _RouteStopHit(this.stop, this.order);
}

/// Tronçon d'itinéraire à dater : ligne, arrêt de montée, terminus visé (pour
/// retrouver le bon sens dans les horaires) et durée estimée en véhicule.
class _LegSpec {
  final GtfsRoute route;
  final GtfsStop board;
  final String direction;
  final int inVehicleMinutes;
  const _LegSpec(this.route, this.board, this.direction, this.inVehicleMinutes);
}

/// Résultat du datage d'un itinéraire : heures de départ/arrivée par tronçon
/// et indicateurs de fiabilité (horaire réel utilisé, service tardif).
class _TimedItinerary {
  final List<DateTime> departures;
  final List<DateTime> arrivals;
  final bool realTiming;
  final bool serviceLater;

  /// false quand un tronçon emprunte une ligne connue des horaires mais hors
  /// service au moment demandé → l'itinéraire entier est à écarter.
  final bool valid;

  const _TimedItinerary(
      this.departures, this.arrivals, this.realTiming, this.serviceLater)
      : valid = true;

  const _TimedItinerary._invalid()
      : departures = const [],
        arrivals = const [],
        realTiming = false,
        serviceLater = false,
        valid = false;

  static const _TimedItinerary invalid = _TimedItinerary._invalid();
}
