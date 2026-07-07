import 'service_exchange_post.dart';

/// Onglet de la bourse d'échanges.
enum ServiceExchangeTab {
  available('available'),
  mine('mine'),
  receivedContacts('received_contacts');

  final String dbValue;
  const ServiceExchangeTab(this.dbValue);

  String get label => switch (this) {
        ServiceExchangeTab.available => 'Disponibles',
        ServiceExchangeTab.mine => 'Mes annonces',
        ServiceExchangeTab.receivedContacts => 'Réponses reçues',
      };
}

/// Sous-filtre de l'onglet « Mes annonces ».
enum ServiceExchangeMineFilter {
  active('active'),
  done('done'),
  cancelled('cancelled');

  final String dbValue;
  const ServiceExchangeMineFilter(this.dbValue);

  String get label => switch (this) {
        ServiceExchangeMineFilter.active => 'En cours',
        ServiceExchangeMineFilter.done => 'Réalisés',
        ServiceExchangeMineFilter.cancelled => 'Annulés',
      };
}

/// Filtres de recherche du feed « Disponibles ».
class ServiceExchangeFilters {
  final String? search;
  final ServiceExchangeServiceType? serviceType;
  final DateTime? serviceDate;
  final ServiceExchangePostKind? postKind;

  const ServiceExchangeFilters({
    this.search,
    this.serviceType,
    this.serviceDate,
    this.postKind,
  });

  bool get hasActiveFilters =>
      (search != null && search!.trim().isNotEmpty) ||
      serviceType != null ||
      serviceDate != null ||
      postKind != null;

  ServiceExchangeFilters copyWith({
    String? search,
    ServiceExchangeServiceType? serviceType,
    DateTime? serviceDate,
    ServiceExchangePostKind? postKind,
    bool clearServiceType = false,
    bool clearServiceDate = false,
    bool clearPostKind = false,
    bool clearSearch = false,
  }) {
    return ServiceExchangeFilters(
      search: clearSearch ? null : (search ?? this.search),
      serviceType: clearServiceType ? null : (serviceType ?? this.serviceType),
      serviceDate: clearServiceDate ? null : (serviceDate ?? this.serviceDate),
      postKind: clearPostKind ? null : (postKind ?? this.postKind),
    );
  }
}
