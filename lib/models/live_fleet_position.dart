import 'package:latlong2/latlong.dart';

/// Position unifiée depuis `live_fleet_positions` (conducteur, communauté, opérateur).
class LiveFleetPosition {
  final String id;
  final String routeId;
  final String? tripId;
  final String transportType;
  final LatLng position;
  final double speed;
  final double heading;
  final String source; // driver | community | operator
  final int? sourceConfidence;
  final int reliabilityScore;
  final int freshnessSeconds;
  final int? coherenceScore;
  final String? driverSessionId;
  final String? communityVehicleId;
  final int? activeUserCount;
  final int? estimatedDelaySeconds;
  final DateTime lastSeenAt;

  LiveFleetPosition({
    required this.id,
    required this.routeId,
    this.tripId,
    required this.transportType,
    required this.position,
    required this.speed,
    required this.heading,
    required this.source,
    this.sourceConfidence,
    required this.reliabilityScore,
    required this.freshnessSeconds,
    this.coherenceScore,
    this.driverSessionId,
    this.communityVehicleId,
    this.activeUserCount,
    this.estimatedDelaySeconds,
    required this.lastSeenAt,
  });

  factory LiveFleetPosition.fromJson(Map<String, dynamic> json) {
    double lat = 0.0;
    double lon = 0.0;

    if (json['geom'] != null && json['geom'] is Map) {
      final coordinates = json['geom']['coordinates'] as List;
      lon = (coordinates[0] as num).toDouble();
      lat = (coordinates[1] as num).toDouble();
    }

    return LiveFleetPosition(
      id: json['id'] as String,
      routeId: json['route_id'] as String,
      tripId: json['trip_id'] as String?,
      transportType: json['transport_type'] as String? ?? 'bus',
      position: LatLng(lat, lon),
      speed: (json['speed'] as num? ?? 0.0).toDouble(),
      heading: (json['heading'] as num? ?? 0.0).toDouble(),
      source: json['source'] as String? ?? 'community',
      sourceConfidence: json['source_confidence'] as int?,
      reliabilityScore: json['reliability_score'] as int? ?? 0,
      freshnessSeconds: json['freshness_seconds'] as int? ?? 0,
      coherenceScore: json['coherence_score'] as int?,
      driverSessionId: json['driver_session_id'] as String?,
      communityVehicleId: json['community_vehicle_id'] as String?,
      activeUserCount: json['active_user_count'] as int?,
      estimatedDelaySeconds: json['estimated_delay_seconds'] as int?,
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
    );
  }

  String get reliabilityLevel {
    if (reliabilityScore >= 80) return 'fort';
    if (reliabilityScore >= 50) return 'moyen';
    return 'faible';
  }

  String get sourceLabel {
    switch (source) {
      case 'driver':
        return 'Conducteur certifié';
      case 'operator':
        return 'Opérateur';
      case 'community':
        return 'Communauté';
      default:
        return 'Temps réel';
    }
  }
}
