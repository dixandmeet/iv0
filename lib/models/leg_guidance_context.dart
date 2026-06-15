import '../models/gtfs.dart';

/// Contexte GTFS résolu pour guider une étape transit d'un itinéraire.
class LegGuidanceContext {
  final GtfsRoute route;
  final GtfsStop boardingStop;
  final GtfsStop alightStop;
  final String headsign;
  final int waitMinutes;
  final int nextWaitMinutes;
  final double boardingDistanceMeters;
  final List<GtfsRoute> stationRoutes;

  const LegGuidanceContext({
    required this.route,
    required this.boardingStop,
    required this.alightStop,
    required this.headsign,
    required this.waitMinutes,
    required this.nextWaitMinutes,
    this.boardingDistanceMeters = 0,
    this.stationRoutes = const [],
  });

  /// Construit un [NearbyStation]-compatible pour les widgets existants.
  NearbyStationView get boardingStation => NearbyStationView(
        stop: boardingStop,
        distanceMeters: boardingDistanceMeters,
        routes: stationRoutes.isNotEmpty ? stationRoutes : [route],
      );

  StationDepartureView get departure => StationDepartureView(
        route: route,
        headsign: headsign,
        waitMinutes: waitMinutes,
        nextWaitMinutes: nextWaitMinutes,
      );
}

/// Vue légère compatible avec les widgets de suivi véhicule.
class NearbyStationView {
  final GtfsStop stop;
  final double distanceMeters;
  final List<GtfsRoute> routes;

  const NearbyStationView({
    required this.stop,
    required this.distanceMeters,
    required this.routes,
  });
}

/// Vue légère d'un prochain départ.
class StationDepartureView {
  final GtfsRoute route;
  final String headsign;
  final int waitMinutes;
  final int nextWaitMinutes;

  const StationDepartureView({
    required this.route,
    required this.headsign,
    required this.waitMinutes,
    required this.nextWaitMinutes,
  });
}
