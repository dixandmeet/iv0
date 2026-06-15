import 'package:latlong2/latlong.dart';

class Report {
  final String id;
  final String? deviceId;
  final String routeId;
  final String? vehicleId;
  final String reportType; // 'delay', 'crowded', 'breakdown', 'accident', 'control', 'safety', 'works', 'disruption'
  final LatLng position;
  final DateTime timestamp;
  final String? description;

  /// Vrai pour les perturbations officielles Naolib (info-trafic), par
  /// opposition aux signalements communautaires. Sert notamment à ne pas les
  /// épingler sur la carte (leur position n'est qu'approximative).
  final bool isOfficial;

  Report({
    required this.id,
    this.deviceId,
    required this.routeId,
    this.vehicleId,
    required this.reportType,
    required this.position,
    required this.timestamp,
    this.description,
    this.isOfficial = false,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
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

    return Report(
      id: json['id'] as String,
      deviceId: json['device_id'] as String?,
      routeId: json['route_id'] as String,
      vehicleId: json['vehicle_id'] as String?,
      reportType: json['report_type'] as String,
      position: LatLng(lat, lon),
      timestamp: DateTime.parse(json['timestamp'] as String),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'route_id': routeId,
      'vehicle_id': vehicleId,
      'report_type': reportType,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
    };
  }

  // Traduction française lisible des types de signalements
  String get typeLabel {
    switch (reportType) {
      case 'delay':
        return 'Retard';
      case 'crowded':
        return 'Véhicule bondé';
      case 'breakdown':
        return 'Panne';
      case 'accident':
        return 'Incident de ligne';
      case 'control':
        return 'Contrôle en cours';
      case 'safety':
        return 'Problème sécurité';
      case 'works':
        return 'Travaux';
      case 'disruption':
        return 'Perturbation';
      default:
        return 'Signalement';
    }
  }
}
