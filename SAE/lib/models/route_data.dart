import 'package:latlong2/latlong.dart';

class RouteStop {
  final String id;
  final String name;
  final double pos; // fraction 0..1 le long du service
  final int scheduledMinutes;
  final LatLng? position;
  const RouteStop({
    this.id = '',
    required this.name,
    required this.pos,
    this.scheduledMinutes = 0,
    this.position,
  });
}

class RouteJourney {
  final String tripId;
  final String? shapeId;
  final List<LatLng> points;
  final List<RouteStop> stops;
  final int totalMinutes;
  final double totalMeters;

  const RouteJourney({
    required this.tripId,
    this.shapeId,
    required this.points,
    required this.stops,
    required this.totalMinutes,
    required this.totalMeters,
  });
}

/// Nantes · Commerce — position simulée de l'agent pour l'écran Radar.
const kRadarCenter = LatLng(47.2181, -1.5556);
