import 'package:latlong2/latlong.dart';

import 'transport_mode.dart';

class FleetVehicle {
  final String id;
  final TransportMode mode;
  final String line;
  final String destination;
  final String stop;
  final int etaSeconds;
  final double angleDeg;
  final int ageSeconds;
  final bool isRealtime;
  final LatLng position;
  final DateTime? arrivedAt;

  const FleetVehicle({
    required this.id,
    required this.mode,
    required this.line,
    required this.destination,
    required this.stop,
    required this.etaSeconds,
    required this.angleDeg,
    required this.ageSeconds,
    required this.isRealtime,
    required this.position,
    this.arrivedAt,
  });

  int distanceFrom(LatLng origin) =>
      const Distance().as(LengthUnit.Meter, origin, position).round();

  String get etaLabel => ageSeconds < 10 ? 'live' : '${ageSeconds}s';

  String get freshLabel =>
      ageSeconds < 1 ? "à l'instant" : 'il y a $ageSeconds s';
}
