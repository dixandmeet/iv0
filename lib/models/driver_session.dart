class DriverSession {
  final String id;
  final String? routeId;
  final int? directionId;
  final String? tripId;
  final String? headsign;
  final String detectionMode;
  final int? detectionConfidence;
  final String status;
  final DateTime startedAt;
  final DateTime? confirmedAt;
  final DateTime? endedAt;

  DriverSession({
    required this.id,
    this.routeId,
    this.directionId,
    this.tripId,
    this.headsign,
    required this.detectionMode,
    this.detectionConfidence,
    required this.status,
    required this.startedAt,
    this.confirmedAt,
    this.endedAt,
  });

  factory DriverSession.fromJson(Map<String, dynamic> json) {
    return DriverSession(
      id: json['id'] as String,
      routeId: json['route_id'] as String?,
      directionId: json['direction_id'] as int?,
      tripId: json['trip_id'] as String?,
      headsign: json['headsign'] as String?,
      detectionMode: json['detection_mode'] as String? ?? 'auto',
      detectionConfidence: json['detection_confidence'] as int?,
      status: json['status'] as String? ?? 'detecting',
      startedAt: DateTime.parse(json['started_at'] as String),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
    );
  }

  String get lineLabel {
    if (routeId == null) return 'Détection…';
    final dir = headsign != null ? ' → $headsign' : '';
    return 'Ligne $routeId$dir';
  }
}
