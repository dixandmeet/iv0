import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Type de signalement conducteur (valeur DB ↔ libellé ↔ icône).
enum DriverReportType {
  delay('delay', 'Retard', LucideIcons.clock),
  crowded('crowded', 'Véhicule plein', LucideIcons.users),
  breakdown('breakdown', 'Panne véhicule', LucideIcons.wrench),
  accident('accident', 'Accident', LucideIcons.triangleAlert),
  traffic('traffic', 'Problème de circulation', LucideIcons.trafficCone),
  detour('detour', 'Déviation', LucideIcons.splitSquareHorizontal),
  passengerIllness('passenger_illness', 'Malaise voyageur', LucideIcons.heartPulse),
  stopSkipped('stop_skipped', 'Arrêt non desservi', LucideIcons.circleSlash),
  incivility('incivility', 'Incivilité', LucideIcons.shieldAlert),
  other('other', 'Autre', LucideIcons.ellipsis);

  final String dbValue;
  final String label;
  final IconData icon;

  const DriverReportType(this.dbValue, this.label, this.icon);

  static DriverReportType fromDb(String value) => DriverReportType.values
      .firstWhere((t) => t.dbValue == value, orElse: () => DriverReportType.other);
}

/// Niveau d'urgence d'un signalement.
enum DriverReportUrgency {
  low('low', 'Faible', Color(0xFF2E7D32)),
  medium('medium', 'Moyen', Color(0xFFE65100)),
  high('high', 'Élevé', Color(0xFFC62828));

  final String dbValue;
  final String label;
  final Color color;

  const DriverReportUrgency(this.dbValue, this.label, this.color);

  static DriverReportUrgency fromDb(String value) => DriverReportUrgency.values
      .firstWhere((u) => u.dbValue == value,
          orElse: () => DriverReportUrgency.medium);
}

/// Signalement terrain (table `driver_reports`).
class DriverReport {
  final String id;
  final String driverId;
  final String? driverServiceId;
  final String? vehicleId;
  final DriverReportType type;
  final DriverReportUrgency urgency;
  final String? message;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;
  final String status; // open, acknowledged, resolved
  final DateTime createdAt;

  const DriverReport({
    required this.id,
    required this.driverId,
    this.driverServiceId,
    this.vehicleId,
    required this.type,
    required this.urgency,
    this.message,
    this.latitude,
    this.longitude,
    this.photoUrl,
    required this.status,
    required this.createdAt,
  });

  factory DriverReport.fromJson(Map<String, dynamic> json) {
    return DriverReport(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      driverServiceId: json['driver_service_id'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      type: DriverReportType.fromDb(json['type'] as String? ?? 'other'),
      urgency: DriverReportUrgency.fromDb(json['urgency'] as String? ?? 'medium'),
      message: json['message'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      photoUrl: json['photo_url'] as String?,
      status: json['status'] as String? ?? 'open',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}
