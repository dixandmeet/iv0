class PlatformResourceEvent {
  final String id;
  final String resourceId;
  final String? channelId;
  final String eventType;
  final String? actorId;
  final Map<String, dynamic> payload;
  final String priority;
  final DateTime createdAt;
  final String? resourceName;
  final String? resourceType;

  PlatformResourceEvent({
    required this.id,
    required this.resourceId,
    this.channelId,
    required this.eventType,
    this.actorId,
    this.payload = const {},
    this.priority = 'normal',
    required this.createdAt,
    this.resourceName,
    this.resourceType,
  });

  String get preview =>
      payload['body_preview'] as String? ??
      payload['name'] as String? ??
      eventType;

  factory PlatformResourceEvent.fromJson(Map<String, dynamic> json) {
    return PlatformResourceEvent(
      id: json['id'] as String,
      resourceId: json['resource_id'] as String,
      channelId: json['channel_id'] as String?,
      eventType: json['event_type'] as String,
      actorId: json['actor_id'] as String?,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      priority: json['priority'] as String? ?? 'normal',
      createdAt: DateTime.parse(json['created_at'] as String),
      resourceName: json['resource_name'] as String?,
      resourceType: json['resource_type'] as String?,
    );
  }
}
