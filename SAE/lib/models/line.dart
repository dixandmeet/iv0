import 'transport_mode.dart';
import 'route_data.dart';

class LineDirection {
  final String key;
  final String label;
  const LineDirection({required this.key, required this.label});
}

class BusLine {
  final String key;
  final TransportMode mode;
  final String label;
  final String desc;
  final String? colorHex;
  final List<LineDirection> directions;

  const BusLine({
    required this.key,
    required this.mode,
    required this.label,
    required this.desc,
    this.colorHex,
    required this.directions,
  });
}

/// Service en cours (choisi lors de la prise de service).
class ActiveService {
  final BusLine line;
  final LineDirection direction;
  final DateTime startedAt;
  final RouteJourney journey;

  const ActiveService({
    required this.line,
    required this.direction,
    required this.startedAt,
    required this.journey,
  });

  String get label => '${line.label} · ${direction.label}';
}
