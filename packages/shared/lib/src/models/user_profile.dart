import 'app_user_role.dart';

class UserProfile {
  final String id;
  final AppUserRole role;
  final String? displayName;
  final String? depotId;

  UserProfile({
    required this.id,
    required this.role,
    this.displayName,
    this.depotId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      role: AppUserRoleX.fromDb(json['role'] as String? ?? 'passenger'),
      displayName: json['display_name'] as String?,
      depotId: json['depot_id'] as String?,
    );
  }
}
