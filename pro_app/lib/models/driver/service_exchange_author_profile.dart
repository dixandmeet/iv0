/// Fiche profil résumée d'un auteur d'annonce (RPC `get_service_exchange_author_profile`).
class ServiceExchangeAuthorProfile {
  final String? displayName;
  final String? avatarUrl;
  final String roleLabel;
  final String? depotName;
  final List<String> habilitations;
  final int? memberSinceYear;
  final int exchangesDone;

  const ServiceExchangeAuthorProfile({
    this.displayName,
    this.avatarUrl,
    this.roleLabel = 'Agent',
    this.depotName,
    this.habilitations = const [],
    this.memberSinceYear,
    this.exchangesDone = 0,
  });

  String get label {
    final name = displayName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'Agent du réseau';
  }

  String get initials {
    final parts =
        label.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String habilitationLabel(String code) => switch (code) {
        'conduite' => 'Conduite',
        'controle' => 'Contrôle',
        'intervention' => 'Intervention',
        'umtc' => 'UMTC',
        _ => code,
      };

  factory ServiceExchangeAuthorProfile.fromJson(Map<String, dynamic> json) {
    return ServiceExchangeAuthorProfile(
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      roleLabel: json['role_label'] as String? ?? 'Agent',
      depotName: json['depot_name'] as String?,
      habilitations: (json['habilitations'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      memberSinceYear: (json['member_since_year'] as num?)?.toInt(),
      exchangesDone: (json['exchanges_done'] as num?)?.toInt() ?? 0,
    );
  }
}
