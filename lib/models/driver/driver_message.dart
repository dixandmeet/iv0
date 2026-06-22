/// Message échangé entre le régulateur et le conducteur (table
/// `driver_messages`).
class DriverMessage {
  final String id;
  final String driverId;
  final String senderType; // 'regulator' | 'driver'
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const DriverMessage({
    required this.id,
    required this.driverId,
    required this.senderType,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  bool get isFromDriver => senderType == 'driver';
  bool get isFromRegulator => senderType == 'regulator';

  factory DriverMessage.fromJson(Map<String, dynamic> json) {
    return DriverMessage(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      senderType: json['sender_type'] as String? ?? 'regulator',
      message: json['message'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}
