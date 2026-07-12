import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';
import '../models/fleet_vehicle.dart';
import '../models/line.dart';
import '../models/naolib_feed.dart';
import '../models/route_data.dart';
import '../models/transport_mode.dart';
import '../utils/geo_utils.dart';

class TransportDataException implements Exception {
  final String message;
  const TransportDataException(this.message);

  @override
  String toString() => message;
}

abstract class TransportDataSource {
  NaolibFeedInfo? get feedInfo;
  Future<NaolibFeedInfo> fetchFeedInfo();
  Future<List<BusLine>> fetchLines({bool refresh = false});
  Future<RouteJourney> fetchJourney(BusLine line, LineDirection direction);
  Future<List<FleetVehicle>> fetchFleet();
}

class TransportRepository implements TransportDataSource {
  TransportRepository({SupabaseClient? client, http.Client? httpClient})
    : _client = client ?? Supabase.instance.client,
      _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _http;

  NaolibFeedInfo? _feedInfo;
  List<BusLine>? _lines;

  @override
  NaolibFeedInfo? get feedInfo => _feedInfo;

  @override
  Future<NaolibFeedInfo> fetchFeedInfo() async {
    final response = await _http
        .get(Uri.parse(BackendConfig.naolibCatalogUrl))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw TransportDataException(
        'Catalogue Naolib indisponible (${response.statusCode}).',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final results = payload['results'] as List? ?? const [];
    if (results.isEmpty) {
      throw const TransportDataException('Aucun flux GTFS Naolib publié.');
    }
    final record = results.first as Map<String, dynamic>;
    final file = record['fichier'] as Map<String, dynamic>?;
    if (file == null || file['url'] == null) {
      throw const TransportDataException('Fichier GTFS Naolib introuvable.');
    }
    return _feedInfo = NaolibFeedInfo(
      validFrom: DateTime.parse(record['debut_de_validite'] as String),
      validUntil: DateTime.parse(record['fin_de_validite'] as String),
      downloadUrl: Uri.parse(file['url'] as String),
      filename: file['filename'] as String? ?? 'naolib-gtfs.zip',
    );
  }

  @override
  Future<List<BusLine>> fetchLines({bool refresh = false}) async {
    if (!refresh && _lines != null) return _lines!;
    // Le catalogue est consulté à chaque rafraîchissement : il garantit que
    // les tables interrogées correspondent encore à une période GTFS publiée.
    final feed = await fetchFeedInfo();
    if (!feed.isCurrentlyValid) {
      throw TransportDataException(
        'Le flux GTFS Naolib publié n’est pas valide à la date du jour.',
      );
    }
    final rows = await _client
        .from('gtfs_routes')
        .select(
          'route_id,route_short_name,route_long_name,route_type,route_color',
        )
        .order('route_short_name');
    final lines = (rows as List)
        .map((row) => _lineFromRow(row as Map<String, dynamic>))
        .toList();
    if (lines.isEmpty) {
      throw const TransportDataException(
        'Aucune ligne GTFS disponible dans Supabase.',
      );
    }
    lines.sort(_compareLines);
    return _lines = lines;
  }

  BusLine _lineFromRow(Map<String, dynamic> row) {
    final id = row['route_id'] as String;
    final shortName = row['route_short_name'] as String? ?? id;
    final longName = row['route_long_name'] as String? ?? '';
    final endpoints = _endpoints(longName);
    return BusLine(
      key: id,
      mode: _modeFromGtfs((row['route_type'] as num?)?.toInt() ?? 3, shortName),
      label: shortName,
      desc: longName.isEmpty ? 'Réseau Naolib' : longName,
      colorHex: row['route_color'] as String?,
      directions: [
        LineDirection(key: '0', label: '→ ${endpoints.$1}'),
        LineDirection(key: '1', label: '→ ${endpoints.$2}'),
      ],
    );
  }

  (String, String) _endpoints(String longName) {
    final parts = longName.split(RegExp(r'\s+-\s+'));
    if (parts.length >= 2) return (parts.first.trim(), parts.last.trim());
    return (longName.isEmpty ? 'Direction 1' : longName, 'Direction opposée');
  }

  int _compareLines(BusLine a, BusLine b) {
    final mode = a.mode.index.compareTo(b.mode.index);
    if (mode != 0) return mode;
    final an = int.tryParse(a.label);
    final bn = int.tryParse(b.label);
    if (an != null && bn != null) return an.compareTo(bn);
    if (an != null) return -1;
    if (bn != null) return 1;
    return a.label.compareTo(b.label);
  }

  @override
  Future<RouteJourney> fetchJourney(
    BusLine line,
    LineDirection direction,
  ) async {
    final directionId = int.tryParse(direction.key) ?? 0;
    final tripsRaw = await _client
        .from('gtfs_trips')
        .select('trip_id,shape_id,direction_id')
        .eq('route_id', line.key)
        .eq('direction_id', directionId)
        .limit(40);
    final trips = (tripsRaw as List).cast<Map<String, dynamic>>();
    if (trips.isEmpty) {
      throw TransportDataException(
        'Aucun circuit trouvé pour la ligne ${line.label}.',
      );
    }

    final tripIds = trips.map((t) => t['trip_id'] as String).toList();
    final timesRaw = await _client
        .from('gtfs_stop_times')
        .select(
          'trip_id,stop_sequence,gtfs_stops(stop_id,stop_name,geom)',
        )
        .inFilter('trip_id', tripIds)
        .order('stop_sequence')
        .limit(5000);
    final byTrip = <String, List<Map<String, dynamic>>>{};
    for (final value in timesRaw as List) {
      final row = value as Map<String, dynamic>;
      (byTrip[row['trip_id'] as String] ??= []).add(row);
    }
    final candidates = trips.where(
      (trip) => (byTrip[trip['trip_id']]?.length ?? 0) >= 2,
    );
    if (candidates.isEmpty) {
      throw TransportDataException(
        'Aucun horaire trouvé pour la ligne ${line.label}.',
      );
    }
    // Les variantes partielles existent dans le GTFS. La plus longue donne au
    // conducteur le circuit complet et tous ses arrêts réels.
    final trip = candidates.reduce((a, b) {
      final aLength = byTrip[a['trip_id']]!.length;
      final bLength = byTrip[b['trip_id']]!.length;
      return bLength > aLength ? b : a;
    });
    final timeRows = byTrip[trip['trip_id']]!;
    // Arrêts dans l'ordre de desserte (stop_sequence est fiable).
    final rawStops = timeRows.map((row) {
      final stop = row['gtfs_stops'] as Map<String, dynamic>;
      return (
        id: stop['stop_id'] as String? ?? '',
        name: stop['stop_name'] as String,
        position: _pointFromGeometry(stop['geom']),
      );
    }).toList();

    // Tracé : shape GTFS, sinon la suite des positions d'arrêts.
    final shapeId = trip['shape_id'] as String?;
    var points = <LatLng>[];
    if (shapeId != null) {
      final shapesRaw = await _client
          .from('gtfs_shapes')
          .select('shape_pt_sequence,geom')
          .eq('shape_id', shapeId)
          .order('shape_pt_sequence')
          .limit(5000);
      points = (shapesRaw as List)
          .map(
            (row) => _pointFromGeometry((row as Map<String, dynamic>)['geom']),
          )
          .whereType<LatLng>()
          .toList();
    }
    if (points.length < 2) {
      points = rawStops.map((s) => s.position).whereType<LatLng>().toList();
    }
    if (points.length < 2) {
      throw const TransportDataException('Tracé GTFS inexploitable.');
    }

    // Les horaires GTFS de ce jeu de données sont incohérents (temps mélangés
    // et non monotones d'un arrêt à l'autre) : on ignore les temps absolus.
    // La progression de chaque arrêt est calée sur la géométrie du tracé et les
    // durées estimées à vitesse commerciale — robuste et monotone.
    final totalMeters = _routeLength(points);
    const avgMetersPerMinute = 285.0; // ~17 km/h en milieu urbain
    final totalMinutes = math.max(1, (totalMeters / avgMetersPerMinute).round());

    // `stop_sequence` de ce jeu de données est un compteur « premier vu » peu
    // fiable (arrêts de plusieurs trajets fusionnés) : on ordonne le plan par
    // la géométrie du tracé, robuste et cohérent avec la progression du bus.
    final stops = <RouteStop>[];
    for (var i = 0; i < rawStops.length; i++) {
      final rs = rawStops[i];
      final pos = rs.position != null
          ? projectOnRoute(points, rs.position!).t
          : (rawStops.length <= 1 ? 0.0 : i / (rawStops.length - 1));
      stops.add(
        RouteStop(
          id: rs.id,
          name: rs.name,
          pos: pos,
          scheduledMinutes: (pos * totalMinutes).round(),
          position: rs.position,
        ),
      );
    }
    stops.sort((a, b) => a.pos.compareTo(b.pos));

    return RouteJourney(
      tripId: trip['trip_id'] as String,
      shapeId: shapeId,
      points: points,
      stops: stops,
      totalMinutes: totalMinutes,
      totalMeters: totalMeters,
    );
  }

  @override
  Future<List<FleetVehicle>> fetchFleet() async {
    final rows = await _client.rpc(
      'immersive_fleet_positions',
      params: {'p_max_age_seconds': 300},
    );
    final now = DateTime.now();
    return (rows as List).map((value) {
      final row = value as Map<String, dynamic>;
      final recordedAt = DateTime.parse(row['recorded_at'] as String).toLocal();
      final mode = _modeFromName(row['vehicle_type'] as String?);
      return FleetVehicle(
        id: row['public_id'].toString(),
        mode: mode,
        line: row['route_id'] as String? ?? '',
        destination: row['destination'] as String? ?? 'Destination inconnue',
        stop: 'Position certifiée Aule',
        etaSeconds: 0,
        angleDeg: (row['heading'] as num?)?.toDouble() ?? 0,
        ageSeconds: math.max(0, now.difference(recordedAt).inSeconds),
        isRealtime: true,
        position: LatLng(
          (row['latitude'] as num).toDouble(),
          (row['longitude'] as num).toDouble(),
        ),
      );
    }).toList();
  }

  LatLng? _pointFromGeometry(dynamic geometry) {
    if (geometry is! Map) return null;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    return LatLng(
      (coordinates[1] as num).toDouble(),
      (coordinates[0] as num).toDouble(),
    );
  }

  double _routeLength(List<LatLng> points) {
    const distance = Distance();
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return meters;
  }

  TransportMode _modeFromGtfs(int type, String route) {
    if (type == 0) return TransportMode.tram;
    if (type == 4 || route.toUpperCase().startsWith('N')) {
      return TransportMode.boat;
    }
    return TransportMode.bus;
  }

  TransportMode _modeFromName(String? value) => switch (value) {
    'tram' => TransportMode.tram,
    'navibus' || 'boat' => TransportMode.boat,
    _ => TransportMode.bus,
  };
}
