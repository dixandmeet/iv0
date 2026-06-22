import 'package:latlong2/latlong.dart';

class GtfsRoute {
  final String routeId;
  final String? routeShortName;
  final String? routeLongName;
  final int routeType; // 0: Tram, 3: Bus, 4: Navibus
  final String? routeColor;

  /// Type de transport pré-calculé ('tram', 'busway', 'navibus', 'bus').
  /// Renseigné lors du chargement depuis les assets TAN ; sinon dérivé.
  final String? _transportTypeOverride;

  /// Tracés de la ligne (un ou plusieurs segments, ex. aller/retour).
  final List<List<LatLng>> shapes;

  GtfsRoute({
    required this.routeId,
    this.routeShortName,
    this.routeLongName,
    required this.routeType,
    this.routeColor,
    String? transportTypeOverride,
    this.shapes = const [],
  }) : _transportTypeOverride = transportTypeOverride;

  factory GtfsRoute.fromJson(Map<String, dynamic> json) {
    return GtfsRoute(
      routeId: json['route_id'] as String,
      routeShortName: json['route_short_name'] as String?,
      routeLongName: json['route_long_name'] as String?,
      routeType: json['route_type'] as int,
      routeColor: json['route_color'] as String?,
    );
  }

  /// Construit une ligne depuis l'asset TAN compact
  /// ({i,s,l,t,c,g}) embarqué dans l'application.
  factory GtfsRoute.fromAsset(Map<String, dynamic> json) {
    final segments = <List<LatLng>>[];
    final rawShapes = json['g'] as List? ?? const [];
    for (final seg in rawShapes) {
      final pts = <LatLng>[];
      for (final p in (seg as List)) {
        pts.add(LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()));
      }
      if (pts.isNotEmpty) segments.add(pts);
    }

    const typeToCode = {'tram': 0, 'busway': 3, 'navibus': 4, 'bus': 3};
    final tType = json['t'] as String? ?? 'bus';

    return GtfsRoute(
      routeId: json['i'] as String,
      routeShortName: json['s'] as String?,
      routeLongName: json['l'] as String?,
      routeType: typeToCode[tType] ?? 3,
      routeColor: json['c'] as String?,
      transportTypeOverride: tType,
      shapes: segments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'route_short_name': routeShortName,
      'route_long_name': routeLongName,
      'route_type': routeType,
      'route_color': routeColor,
    };
  }

  // Helper to verify transport type string
  String get transportType {
    if (_transportTypeOverride != null) return _transportTypeOverride!;
    if (routeId == '1' || routeId == '2' || routeId == '3') return 'tram';
    if (routeId == '4' || routeId == '5' || routeId == 'C4') return 'busway';
    if (routeId.startsWith('N')) return 'navibus';
    return 'bus';
  }
}

class GtfsStop {
  final String stopId;
  final String stopName;
  final LatLng position;

  /// Clé station voyageur (référence tan_stations.json `i`).
  final String? stationId;

  /// Accessibilité PMR (GTFS wheelchair_boarding) :
  /// 0 inconnu, 1 accessible, 2 non accessible.
  final int wheelchairBoarding;

  GtfsStop({
    required this.stopId,
    required this.stopName,
    required this.position,
    this.stationId,
    this.wheelchairBoarding = 0,
  });

  bool get isWheelchairAccessible => wheelchairBoarding == 1;

  /// Accessibilité PMR explicitement signalée comme impossible (valeur 2).
  bool get isWheelchairInaccessible => wheelchairBoarding == 2;

  /// Libellé d'accessibilité PMR couvrant les 3 états GTFS.
  String get accessibilityLabel {
    switch (wheelchairBoarding) {
      case 1:
        return 'Accès PMR';
      case 2:
        return 'Non accessible PMR';
      default:
        return 'Accessibilité non renseignée';
    }
  }

  factory GtfsStop.fromJson(Map<String, dynamic> json) {
    // GeoJSON point or coordinate fields from PostgreSQL
    double lat = 0.0;
    double lon = 0.0;

    if (json['geom'] != null && json['geom'] is Map) {
      final coordinates = json['geom']['coordinates'] as List;
      lon = (coordinates[0] as num).toDouble();
      lat = (coordinates[1] as num).toDouble();
    } else if (json['latitude'] != null && json['longitude'] != null) {
      lat = (json['latitude'] as num).toDouble();
      lon = (json['longitude'] as num).toDouble();
    }

    return GtfsStop(
      stopId: json['stop_id'] as String,
      stopName: json['stop_name'] as String,
      position: LatLng(lat, lon),
      wheelchairBoarding: (json['wheelchair_boarding'] as num?)?.toInt() ?? 0,
    );
  }

  /// Construit un arrêt depuis l'asset TAN compact ({i,n,la,lo,lt,w,sid?}).
  factory GtfsStop.fromAsset(Map<String, dynamic> json) {
    return GtfsStop(
      stopId: json['i'] as String,
      stopName: json['n'] as String,
      position: LatLng(
        (json['la'] as num).toDouble(),
        (json['lo'] as num).toDouble(),
      ),
      stationId: json['sid'] as String?,
      wheelchairBoarding: (json['w'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Lieu voyageur (station) depuis tan_stations.json ({i,n,la,lo}).
class GtfsStation {
  final String stationId;
  final String name;
  final LatLng position;

  GtfsStation({
    required this.stationId,
    required this.name,
    required this.position,
  });

  factory GtfsStation.fromAsset(Map<String, dynamic> json) {
    return GtfsStation(
      stationId: json['i'] as String,
      name: json['n'] as String,
      position: LatLng(
        (json['la'] as num).toDouble(),
        (json['lo'] as num).toDouble(),
      ),
    );
  }

  GtfsStop toMapStop() => GtfsStop(
        stopId: stationId,
        stopName: name,
        position: position,
        stationId: stationId,
      );
}

class GtfsShape {
  final String shapeId;
  final int sequence;
  final LatLng position;

  GtfsShape({
    required this.shapeId,
    required this.sequence,
    required this.position,
  });

  factory GtfsShape.fromJson(Map<String, dynamic> json) {
    double lat = 0.0;
    double lon = 0.0;

    if (json['geom'] != null && json['geom'] is Map) {
      final coordinates = json['geom']['coordinates'] as List;
      lon = (coordinates[0] as num).toDouble();
      lat = (coordinates[1] as num).toDouble();
    }

    return GtfsShape(
      shapeId: json['shape_id'] as String,
      sequence: json['shape_pt_sequence'] as int,
      position: LatLng(lat, lon),
    );
  }
}

class GtfsTrip {
  final String tripId;
  final String routeId;
  final String serviceId;
  final String? shapeId;
  final int? directionId;

  GtfsTrip({
    required this.tripId,
    required this.routeId,
    required this.serviceId,
    this.shapeId,
    this.directionId,
  });

  factory GtfsTrip.fromJson(Map<String, dynamic> json) {
    return GtfsTrip(
      tripId: json['trip_id'] as String,
      routeId: json['route_id'] as String,
      serviceId: json['service_id'] as String,
      shapeId: json['shape_id'] as String?,
      directionId: json['direction_id'] as int?,
    );
  }
}

class GtfsStopTime {
  final String tripId;
  final String stopId;
  final String arrivalTime;
  final String departureTime;
  final int stopSequence;

  GtfsStopTime({
    required this.tripId,
    required this.stopId,
    required this.arrivalTime,
    required this.departureTime,
    required this.stopSequence,
  });

  factory GtfsStopTime.fromJson(Map<String, dynamic> json) {
    return GtfsStopTime(
      tripId: json['trip_id'] as String,
      stopId: json['stop_id'] as String,
      arrivalTime: json['arrival_time'] as String,
      departureTime: json['departure_time'] as String,
      stopSequence: json['stop_sequence'] as int,
    );
  }
}
