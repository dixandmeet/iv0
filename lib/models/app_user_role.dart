enum AppUserRole {
  passenger,
  driver,
  msrAgent,
  msrSupervisor,
  regulator,
  admin,
}

extension AppUserRoleX on AppUserRole {
  static AppUserRole fromDb(String value) {
    switch (value) {
      case 'driver':
        return AppUserRole.driver;
      case 'msr_agent':
        return AppUserRole.msrAgent;
      case 'msr_supervisor':
        return AppUserRole.msrSupervisor;
      case 'regulator':
        return AppUserRole.regulator;
      case 'admin':
        return AppUserRole.admin;
      default:
        return AppUserRole.passenger;
    }
  }

  bool get isMobileStaff => this == AppUserRole.driver || this == AppUserRole.msrAgent;
}
