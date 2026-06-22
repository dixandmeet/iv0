/// Rôles applicatifs gérés par les apps mobiles Aule.
///
/// Périmètre mobile volontairement réduit : seuls `passenger`, `driver` et
/// `msrAgent` ont des écrans. Les rôles backend supplémentaires
/// (`msr_supervisor`, `regulator`, `admin`) sont repliés vers `passenger` côté
/// mobile et seront ajoutés ici quand ils auront une interface dédiée.
enum AppUserRole {
  passenger,
  driver,
  msrAgent,
}

extension AppUserRoleX on AppUserRole {
  static AppUserRole fromDb(String value) {
    switch (value) {
      case 'driver':
        return AppUserRole.driver;
      case 'msr_agent':
        return AppUserRole.msrAgent;
      default:
        return AppUserRole.passenger;
    }
  }

  /// Vrai pour le personnel terrain géré par l'app Pro (conducteur / agent MSR).
  bool get isMobileStaff =>
      this == AppUserRole.driver || this == AppUserRole.msrAgent;
}
