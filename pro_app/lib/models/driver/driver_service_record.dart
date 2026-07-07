/// Prise de service (table `driver_services`) : le créneau planifié d'un
/// conducteur, puis sa réalisation (heures réelles, statut).
class DriverServiceRecord {
  final String id;
  final String driverId;
  final String? vehicleId;
  final String? lineId; // route_id GTFS
  final String? trainNumber; // position dans la flotte en ligne (ex. « 1-12 »)
  final String? serviceCode; // n° de service de roulement (ex. « 01TD-3 »)
  final String? dayCode; // code du roulement journalier (ex. « 38B-4 »)
  final String? parkingSlot; // emplacement au dépôt (ex. « H13-1 »)
  final int? directionId; // 0 / 1
  final String? headsign; // destination (sens)
  final DateTime? startTimePlanned;
  final DateTime? endTimePlanned;
  final DateTime? startTimeReal;
  final DateTime? endTimeReal;
  final String status; // planned, active, paused, completed, cancelled
  final DateTime? createdAt;

  const DriverServiceRecord({
    required this.id,
    required this.driverId,
    this.vehicleId,
    this.lineId,
    this.trainNumber,
    this.serviceCode,
    this.dayCode,
    this.parkingSlot,
    this.directionId,
    this.headsign,
    this.startTimePlanned,
    this.endTimePlanned,
    this.startTimeReal,
    this.endTimeReal,
    required this.status,
    this.createdAt,
  });

  factory DriverServiceRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String key) => json[key] != null
        ? DateTime.tryParse(json[key] as String)?.toLocal()
        : null;

    return DriverServiceRecord(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      vehicleId: json['vehicle_id'] as String?,
      lineId: json['line_id'] as String?,
      trainNumber: json['train_number'] as String?,
      serviceCode: json['service_code'] as String?,
      dayCode: json['day_code'] as String?,
      parkingSlot: json['parking_slot'] as String?,
      directionId: (json['direction_id'] as num?)?.toInt(),
      headsign: json['headsign'] as String?,
      startTimePlanned: parse('start_time_planned'),
      endTimePlanned: parse('end_time_planned'),
      startTimeReal: parse('start_time_real'),
      endTimeReal: parse('end_time_real'),
      status: json['status'] as String? ?? 'planned',
      createdAt: parse('created_at'),
    );
  }

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';
  bool get isRunning => isActive || isPaused;

  String get lineLabel => lineId != null ? 'Ligne $lineId' : 'Ligne —';

  String get directionLabel {
    if (headsign != null && headsign!.trim().isNotEmpty) {
      return '→ ${headsign!.trim()}';
    }
    if (directionId != null) return 'Sens $directionId';
    return 'Sens —';
  }

  /// Durée du service réalisé, si commencé.
  Duration? get realDuration {
    if (startTimeReal == null) return null;
    final end = endTimeReal ?? DateTime.now();
    return end.difference(startTimeReal!);
  }

  DriverServiceRecord copyWith({
    String? status,
    DateTime? startTimeReal,
    DateTime? endTimeReal,
    String? vehicleId,
    String? lineId,
    String? trainNumber,
    String? serviceCode,
    String? dayCode,
    String? parkingSlot,
    int? directionId,
    String? headsign,
  }) {
    return DriverServiceRecord(
      id: id,
      driverId: driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      lineId: lineId ?? this.lineId,
      trainNumber: trainNumber ?? this.trainNumber,
      serviceCode: serviceCode ?? this.serviceCode,
      dayCode: dayCode ?? this.dayCode,
      parkingSlot: parkingSlot ?? this.parkingSlot,
      directionId: directionId ?? this.directionId,
      headsign: headsign ?? this.headsign,
      startTimePlanned: startTimePlanned,
      endTimePlanned: endTimePlanned,
      startTimeReal: startTimeReal ?? this.startTimeReal,
      endTimeReal: endTimeReal ?? this.endTimeReal,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
