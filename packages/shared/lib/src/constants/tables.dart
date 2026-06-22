/// Noms des tables/vues Supabase, centralisés pour éviter la dispersion de
/// chaînes magiques dans les deux apps.
class Tables {
  const Tables._();

  // Réseau / référentiel GTFS
  static const String gtfsRoutes = 'gtfs_routes';
  static const String gtfsStops = 'gtfs_stops';
  static const String gtfsStopTimes = 'gtfs_stop_times';
  static const String stations = 'stations';
  static const String stops = 'stops';

  // Voyageur
  static const String travelerComments = 'traveler_comments';
  static const String reports = 'reports';
  static const String anonymousDevices = 'anonymous_devices';
  static const String userProfiles = 'user_profiles';
  static const String userFavorites = 'user_favorites';
  static const String liveFleetPositions = 'live_fleet_positions';

  // Conducteur
  static const String drivers = 'drivers';
  static const String driverSessions = 'driver_sessions';

  // MSR
  static const String msrMissions = 'msr_missions';
  static const String msrTeams = 'msr_teams';
  static const String msrZones = 'msr_zones';
}
