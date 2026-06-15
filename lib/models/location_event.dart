import 'package:latlong2/latlong.dart';

class LocationEvent {
  final int? id;
  final String deviceId;
  final LatLng position;
  final double speed; // m/s
  final double heading; // degrees
  final double accuracy; // meters
  final DateTime timestamp;
  final String estimatedState; // 'walking', 'waiting', 'transit_probable'

  LocationEvent({
    this.id,
    required this.deviceId,
    required this.position,
    required this.speed,
    required this.heading,
    required this.accuracy,
    required this.timestamp,
    required this.estimatedState,
  });

  factory LocationEvent.fromJson(Map<String, dynamic> json) {
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

    return LocationEvent(
      id: json['id'] as int?,
      deviceId: json['device_id'] as String,
      position: LatLng(lat, lon),
      speed: (json['speed'] as num? ?? 0.0).toDouble(),
      heading: (json['heading'] as num? ?? 0.0).toDouble(),
      accuracy: (json['accuracy'] as num? ?? 0.0).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      estimatedState: json['estimated_state'] as String? ?? 'walking',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'device_id': deviceId,
      // For Supabase PostGIS point creation, we can use a helper or pass it directly in the service
      'latitude': position.latitude,
      'longitude': position.longitude,
      'speed': speed,
      'heading': heading,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'estimated_state': estimatedState,
    };
  }
}
