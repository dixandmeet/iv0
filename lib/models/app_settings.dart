class AppSettings {
  final String id;
  final String deviceId;
  final bool passiveTrackingEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppSettings({
    required this.id,
    required this.deviceId,
    required this.passiveTrackingEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      passiveTrackingEnabled: json['passive_tracking_enabled'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'passive_tracking_enabled': passiveTrackingEnabled,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
