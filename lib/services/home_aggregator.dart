import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/community_vehicle.dart';
import '../models/gtfs.dart';
import '../models/report.dart';
import 'gtfs_service.dart';

/// Départ imminent agrégé depuis plusieurs stations proches.
class ImminentDeparture {
  final GtfsRoute route;
  final String headsign;
  final int waitMinutes;
  final String stationName;
  final double distanceMeters;

  const ImminentDeparture({
    required this.route,
    required this.headsign,
    required this.waitMinutes,
    required this.stationName,
    this.distanceMeters = 0,
  });
}

/// Véhicule détecté à proximité avec distance et ETA estimés.
class NearbyVehicleInfo {
  final CommunityVehicle vehicle;
  final double distanceMeters;
  final int etaMinutes;
  final String directionLabel;

  const NearbyVehicleInfo({
    required this.vehicle,
    required this.distanceMeters,
    required this.etaMinutes,
    required this.directionLabel,
  });
}

/// Synthèse de l'état du réseau pour l'accueil.
class NetworkStatusSummary {
  final int punctualityPercent;
  final int disruptionCount;

  const NetworkStatusSummary({
    required this.punctualityPercent,
    required this.disruptionCount,
  });

  String get headline {
    if (disruptionCount > 0) {
      return '$disruptionCount perturbation${disruptionCount > 1 ? 's' : ''} en cours';
    }
    return '$punctualityPercent % des lignes fonctionnent normalement';
  }
}

/// Suggestion contextuelle affichée sur l'accueil.
sealed class SmartSuggestion {}

class RushHourSuggestion extends SmartSuggestion {
  final String timeLabel;
  final GtfsRoute route;
  final String headsign;
  final int waitMinutes;

  RushHourSuggestion({
    required this.timeLabel,
    required this.route,
    required this.headsign,
    required this.waitMinutes,
  });
}

class DisruptionSuggestion extends SmartSuggestion {
  final Report report;
  final String lineLabel;

  DisruptionSuggestion({required this.report, required this.lineLabel});
}

/// Agrège les données voyageur pour l'écran Accueil.
class HomeAggregator {
  HomeAggregator._();

  static const LatLng nantesCenter = LatLng(47.218371, -1.553621);
  static const _distance = Distance();

  static LatLng resolveCenter(LatLng? userPosition) =>
      userPosition ?? nantesCenter;

  static List<NearbyStation> nearbyStations(
    GtfsService gtfs,
    LatLng? userPosition, {
    int limit = 6,
  }) {
    return gtfs.nearbyStations(resolveCenter(userPosition), limit: limit);
  }

  static List<List<StationLineGroup>> groupsPerStation(
    GtfsService gtfs,
    List<NearbyStation> stations,
  ) {
    return [
      for (final station in stations)
        gtfs.stationLineGroups(station, now: DateTime.now()),
    ];
  }

  static List<ImminentDeparture> imminentDepartures(
    GtfsService gtfs,
    List<NearbyStation> stations, {
    int limit = 6,
  }) {
    final groups = groupsPerStation(gtfs, stations);
    return imminentFromGroups(stations, groups, limit: limit);
  }

  /// Variante de [imminentDepartures] s'appuyant sur des groupes déjà calculés
  /// (évite de relancer [GtfsService.stationLineGroups] une seconde fois quand
  /// l'appelant les a déjà sous la main — gain net sur la page Horaires).
  static List<ImminentDeparture> imminentFromGroups(
    List<NearbyStation> stations,
    List<List<StationLineGroup>> groupsPerStation, {
    int limit = 6,
  }) {
    final all = <ImminentDeparture>[];
    for (var i = 0; i < stations.length; i++) {
      final station = stations[i];
      final groups = i < groupsPerStation.length
          ? groupsPerStation[i]
          : const <StationLineGroup>[];
      for (final group in groups) {
        for (final dep in group.directions) {
          all.add(ImminentDeparture(
            route: dep.route,
            headsign: dep.headsign,
            waitMinutes: dep.waitMinutes,
            stationName: station.stop.stopName,
            distanceMeters: station.distanceMeters,
          ));
        }
      }
    }
    all.sort((a, b) {
      final byDistance = a.distanceMeters.compareTo(b.distanceMeters);
      if (byDistance != 0) return byDistance;
      return a.waitMinutes.compareTo(b.waitMinutes);
    });

    final seen = <String>{};
    final unique = <ImminentDeparture>[];
    for (final dep in all) {
      final key =
          '${dep.route.routeId}|${dep.headsign}|${dep.waitMinutes}';
      if (seen.add(key)) unique.add(dep);
      if (unique.length >= limit) break;
    }
    return unique;
  }

  static List<NearbyVehicleInfo> nearbyVehicles(
    List<CommunityVehicle> vehicles,
    LatLng? userPosition, {
    double maxMeters = 2000,
    int limit = 8,
  }) {
    if (userPosition == null) return const [];

    final result = <NearbyVehicleInfo>[];
    for (final vehicle in vehicles) {
      final meters = _distance.as(
        LengthUnit.Meter,
        userPosition,
        vehicle.position,
      );
      if (meters > maxMeters) continue;

      final speedMps = vehicle.speed > 1 ? vehicle.speed : 25 / 3.6;
      final etaMinutes = math.max(1, (meters / speedMps / 60).ceil());

      result.add(NearbyVehicleInfo(
        vehicle: vehicle,
        distanceMeters: meters,
        etaMinutes: etaMinutes,
        directionLabel: _headingLabel(vehicle.heading),
      ));
    }

    result.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return result.take(limit).toList();
  }

  static NetworkStatusSummary networkStatus(
    List<CommunityVehicle> vehicles,
    List<Report> reports,
  ) {
    final punctuality = _punctuality(vehicles);
    return NetworkStatusSummary(
      punctualityPercent: punctuality,
      disruptionCount: reports.length,
    );
  }

  static int _punctuality(List<CommunityVehicle> vehicles) {
    if (vehicles.isEmpty) return 98;
    final onTime = vehicles
        .where((v) => (v.estimatedDelaySeconds ?? 0) <= 30)
        .length;
    return ((onTime / vehicles.length) * 100).round().clamp(75, 100);
  }

  static SmartSuggestion? bestSuggestion({
    required List<NearbyStation> stations,
    required List<List<StationLineGroup>> groupsPerStation,
    required List<Report> reports,
    required GtfsService gtfs,
  }) {
    if (stations.isNotEmpty && reports.isNotEmpty) {
      final nearbyRouteIds = <String>{
        for (final station in stations)
          for (final route in station.routes) route.routeId,
      };
      for (final report in reports) {
        if (nearbyRouteIds.contains(report.routeId) ||
            report.routeId == 'Réseau') {
          return DisruptionSuggestion(
            report: report,
            lineLabel: report.routeId,
          );
        }
      }
    }

    final now = DateTime.now();
    final hour = now.hour;
    final isRush = (hour >= 7 && hour < 9) || (hour >= 17 && hour < 19);
    if (!isRush || stations.isEmpty || groupsPerStation.isEmpty) {
      return null;
    }

    final groups = groupsPerStation.first;
    if (groups.isEmpty) return null;

    StationLineGroup? bestGroup;
    int bestWait = 9999;
    StationDeparture? bestDep;
    for (final group in groups) {
      for (final dep in group.directions) {
        if (dep.waitMinutes < bestWait) {
          bestWait = dep.waitMinutes;
          bestGroup = group;
          bestDep = dep;
        }
      }
    }
    if (bestGroup == null || bestDep == null) return null;

    final timeLabel =
        '${now.hour.toString().padLeft(2, '0')}h${now.minute.toString().padLeft(2, '0')}';
    return RushHourSuggestion(
      timeLabel: timeLabel,
      route: bestGroup.route,
      headsign: bestDep.headsign,
      waitMinutes: bestDep.waitMinutes,
    );
  }

  static String _headingLabel(double heading) {
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
    final index = ((heading % 360) / 45).round() % 8;
    return labels[index];
  }
}
