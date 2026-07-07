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

  // Échanges de service (bourse d'annonces)
  static const String serviceExchangePosts = 'service_exchange_posts';
  static const String serviceExchangeFavorites = 'service_exchange_favorites';
  static const String serviceExchangeViews = 'service_exchange_views';
  static const String serviceExchangeReactions = 'service_exchange_reactions';
  static const String serviceExchangeNotificationsSent =
      'service_exchange_notifications_sent';

  // Platform / Hub collaboratif
  static const String conversationContexts = 'conversation_contexts';
  static const String resources = 'resources';
  static const String resourceRelations = 'resource_relations';
  static const String resourceCapabilities = 'resource_capabilities';
  static const String resourceWatchers = 'resource_watchers';
  static const String channels = 'channels';
  static const String channelMembers = 'channel_members';
  static const String messages = 'messages';
  static const String resourceEvents = 'resource_events';
  static const String userNotifications = 'user_notifications';
  static const String channelFiles = 'channel_files';
  static const String channelTasks = 'channel_tasks';
  static const String panelLayouts = 'panel_layouts';
}
