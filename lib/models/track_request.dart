import '../models/gtfs.dart';
import '../services/gtfs_service.dart';

/// Demande de suivi d'une ligne depuis l'écran Accueil vers la carte.
class TrackRequest {
  final GtfsRoute route;
  final NearbyStation station;
  final StationDeparture departure;

  const TrackRequest({
    required this.route,
    required this.station,
    required this.departure,
  });
}
