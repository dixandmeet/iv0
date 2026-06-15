class AnonymousDevice {
  final String id;
  final String deviceToken;
  final bool consentBackgroundTracking;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  AnonymousDevice({
    required this.id,
    required this.deviceToken,
    required this.consentBackgroundTracking,
    required this.createdAt,
    required this.lastSeenAt,
  });

  factory AnonymousDevice.fromJson(Map<String, dynamic> json) {
    return AnonymousDevice(
      id: json['id'] as String,
      deviceToken: json['device_token'] as String,
      consentBackgroundTracking: json['consent_background_tracking'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_token': deviceToken,
      'consent_background_tracking': consentBackgroundTracking,
      'created_at': createdAt.toIso8601String(),
      'last_seen_at': lastSeenAt.toIso8601String(),
    };
  }
}
