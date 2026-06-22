/// Fiche conducteur (table `drivers`). Sa simple présence (par e-mail) fait
/// basculer l'utilisateur dans l'espace conducteur.
class DriverProfile {
  final String id;
  final String? userId;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? driverNumber;
  final String? depotId;
  final String status; // off, available, on_service, paused
  final DateTime? createdAt;

  const DriverProfile({
    required this.id,
    this.userId,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.driverNumber,
    this.depotId,
    required this.status,
    this.createdAt,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      email: json['email'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      driverNumber: json['driver_number'] as String?,
      depotId: json['depot_id'] as String?,
      status: json['status'] as String? ?? 'off',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Prénom si présent, sinon partie locale de l'e-mail.
  String get firstNameOrFallback {
    if (firstName != null && firstName!.trim().isNotEmpty) {
      return firstName!.trim();
    }
    if (email.contains('@')) return email.split('@').first;
    return 'Conducteur';
  }

  String get fullName {
    final parts = [firstName, lastName]
        .where((p) => p != null && p.trim().isNotEmpty)
        .map((p) => p!.trim());
    final joined = parts.join(' ');
    return joined.isNotEmpty ? joined : firstNameOrFallback;
  }

  String get statusLabel {
    switch (status) {
      case 'available':
        return 'Disponible';
      case 'on_service':
        return 'En service';
      case 'paused':
        return 'En pause';
      default:
        return 'Hors service';
    }
  }
}
