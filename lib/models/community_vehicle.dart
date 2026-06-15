import 'package:latlong2/latlong.dart';

import 'live_fleet_position.dart';

class CommunityVehicle {
  final String id;
  final String routeId;
  final String? tripId;
  final String transportType; // 'bus', 'tram', 'busway', 'navibus'
  final LatLng position;
  final double speed;
  final double heading;
  final int confidenceScore; // 0 to 100 (fiabilité composite en mode live fleet)
  final int activeUserCount;
  final DateTime lastSeenAt;
  final int? estimatedDelaySeconds;
  /// Source de la donnée : driver | community | operator (couche live fleet).
  final String? dataSource;
  final int? freshnessSeconds;

  CommunityVehicle({
    required this.id,
    required this.routeId,
    this.tripId,
    required this.transportType,
    required this.position,
    required this.speed,
    required this.heading,
    required this.confidenceScore,
    required this.activeUserCount,
    required this.lastSeenAt,
    this.estimatedDelaySeconds,
    this.dataSource,
    this.freshnessSeconds,
  });

  factory CommunityVehicle.fromJson(Map<String, dynamic> json) {
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

    return CommunityVehicle(
      id: json['id'] as String,
      routeId: json['route_id'] as String,
      tripId: json['trip_id'] as String?,
      transportType: json['transport_type'] as String? ?? 'bus',
      position: LatLng(lat, lon),
      speed: (json['speed'] as num? ?? 0.0).toDouble(),
      heading: (json['heading'] as num? ?? 0.0).toDouble(),
      confidenceScore: json['confidence_score'] as int? ?? 0,
      activeUserCount: json['active_user_count'] as int? ?? 1,
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
      estimatedDelaySeconds: json['estimated_delay_seconds'] as int?,
      dataSource: json['data_source'] as String?,
      freshnessSeconds: json['freshness_seconds'] as int?,
    );
  }

  factory CommunityVehicle.fromLiveFleet(LiveFleetPosition live) {
    return CommunityVehicle(
      id: live.id,
      routeId: live.routeId,
      tripId: live.tripId,
      transportType: live.transportType,
      position: live.position,
      speed: live.speed,
      heading: live.heading,
      confidenceScore: live.reliabilityScore,
      activeUserCount: live.activeUserCount ?? (live.source == 'driver' ? 1 : 1),
      lastSeenAt: live.lastSeenAt,
      estimatedDelaySeconds: live.estimatedDelaySeconds,
      dataSource: live.source,
      freshnessSeconds: live.freshnessSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_id': routeId,
      'trip_id': tripId,
      'transport_type': transportType,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'speed': speed,
      'heading': heading,
      'confidence_score': confidenceScore,
      'active_user_count': activeUserCount,
      'last_seen_at': lastSeenAt.toIso8601String(),
      'estimated_delay_seconds': estimatedDelaySeconds,
    };
  }

  // Fiabilité calculée pour affichage de badges
  String get reliabilityLevel {
    if (confidenceScore >= 80) return 'fort';
    if (confidenceScore >= 50) return 'moyen';
    return 'faible';
  }

  String get dataSourceLabel {
    switch (dataSource) {
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
