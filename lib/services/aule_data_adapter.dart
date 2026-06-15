import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/aule_models.dart';
import '../models/gtfs.dart';
import '../models/report.dart';
import '../services/gtfs_service.dart';
import '../services/home_aggregator.dart';
import '../theme/aule_theme.dart';

/// Convertit les données GTFS / temps réel du projet en modèles Aule.
class AuleDataAdapter {
  AuleDataAdapter._();

  static const _distance = Distance();

  static const _headwayMinutes = {
    'tram': 6,
    'busway': 8,
    'navibus': 20,
    'bus': 12,
  };

  static AuleLineMode modeFrom(String transportType) {
    switch (transportType.toLowerCase()) {
      case 'tram':
        return AuleLineMode.tram;
      case 'busway':
        return AuleLineMode.busway;
      default:
        return AuleLineMode.bus;
    }
  }

  static String modeLabel(String transportType) {
    switch (transportType.toLowerCase()) {
      case 'tram':
        return 'Tramway';
      case 'busway':
        return 'Chronobus';
      case 'navibus':
        return 'Navibus';
      default:
        return 'Bus';
    }
  }

  static String lineCode(GtfsRoute route) =>
      route.routeShortName ?? route.routeId;

  static Color? routeColor(GtfsRoute route) {
    final hex = route.routeColor;
    if (hex == null || hex.isEmpty) {
      return AuleLineColors.forLine(lineCode(route));
    }
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AuleLineColors.forLine(lineCode(route));
    }
  }

  static GtfsRoute? findRoute(GtfsService gtfs, String routeId) {
    for (final route in gtfs.cachedRoutes) {
      if (route.routeId == routeId) return route;
    }
    return null;
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String formatWalkTime(double meters) {
    final walk = (meters / 75).ceil().clamp(1, 99);
    return '$walk min à pied';
  }

  static String frequencyLabel(GtfsRoute route) {
    final headway = _headwayMinutes[route.transportType] ?? 12;
    return 'toutes les $headway min';
  }

  static String terminusLabel(GtfsRoute route) {
    final long = route.routeLongName;
    if (long != null && long.isNotEmpty) return long.replaceAll(' - ', ' ↔ ');
    return route.routeShortName ?? route.routeId;
  }

  static AuleLineDeparture fromStationDeparture({
    required StationDeparture departure,
    required NearbyStation station,
    required GtfsService gtfs,
    required DateTime now,
  }) {
    final waitSeconds = gtfs.estimateWaitSeconds(
      departure.route,
      station.stop,
      direction: departure.headsign,
      now: now,
    );
    return AuleLineDeparture(
      label: lineCode(departure.route),
      destination: departure.headsign,
      modeLabel: modeLabel(departure.route.transportType),
      mode: modeFrom(departure.route.transportType),
      arrivalAt: now.add(Duration(seconds: waitSeconds)),
      lineColor: routeColor(departure.route),
    );
  }

  static AuleLineDeparture fromImminentDeparture(
    ImminentDeparture departure,
    DateTime now,
  ) {
    return AuleLineDeparture(
      label: lineCode(departure.route),
      destination: departure.headsign,
      modeLabel: modeLabel(departure.route.transportType),
      mode: modeFrom(departure.route.transportType),
      arrivalAt: now.add(Duration(minutes: departure.waitMinutes)),
      lineColor: routeColor(departure.route),
    );
  }

  static AuleStopData fromNearbyStation({
    required NearbyStation station,
    required List<StationLineGroup> groups,
    required GtfsService gtfs,
    required DateTime now,
  }) {
    final lines = <AuleLineDeparture>[];
    for (final group in groups) {
      if (group.directions.isEmpty) continue;
      lines.add(fromStationDeparture(
        departure: group.directions.first,
        station: station,
        gtfs: gtfs,
        now: now,
      ));
    }

    return AuleStopData(
      name: station.stop.stopName,
      distance: formatDistance(station.distanceMeters),
      walkTime: formatWalkTime(station.distanceMeters),
      accessible: station.stop.isWheelchairAccessible,
      lines: lines,
    );
  }

  static AuleVehicleData? fromNearbyVehicle({
    required NearbyVehicleInfo info,
    required GtfsService gtfs,
    required DateTime now,
  }) {
    final route = findRoute(gtfs, info.vehicle.routeId);
    final label = route != null ? lineCode(route) : info.vehicle.routeId;
    final mode = modeFrom(
      route?.transportType ?? info.vehicle.transportType,
    );

    final speedMps =
        info.vehicle.speed > 1 ? info.vehicle.speed : 25 / 3.6;
    final etaSeconds =
        math.max(1, (info.distanceMeters / speedMps).ceil());

    return AuleVehicleData(
      label: label,
      mode: mode,
      position: info.vehicle.position,
      lineColor: route != null ? routeColor(route) : null,
      arrivalAt: now.add(Duration(seconds: etaSeconds)),
    );
  }

  static AuleAlertData fromReport(Report report, GtfsService gtfs) {
    final route = findRoute(gtfs, report.routeId);
    final line = route != null ? lineCode(route) : report.routeId;
    final mode = modeFrom(route?.transportType ?? 'bus');

    return AuleAlertData(
      line: line,
      mode: mode,
      type: report.typeLabel.toUpperCase(),
      text: report.description?.trim().isNotEmpty == true
          ? report.description!.trim()
          : '${report.typeLabel} signalé sur la ligne $line',
    );
  }

  static AuleSuggestionView? fromSmartSuggestion(
    SmartSuggestion? suggestion,
    DateTime now,
  ) {
    switch (suggestion) {
      case RushHourSuggestion s:
        return AuleSuggestionView(
          timeLabel: s.timeLabel,
          line: lineCode(s.route),
          title: 'Votre Ligne ${lineCode(s.route)} vers ${s.headsign}',
          arrivalAt: now.add(Duration(minutes: s.waitMinutes)),
        );
      case DisruptionSuggestion s:
        return AuleSuggestionView(
          timeLabel:
              '${now.hour.toString().padLeft(2, '0')}h${now.minute.toString().padLeft(2, '0')}',
          line: s.lineLabel,
          title:
              'Perturbation · ${s.report.typeLabel} sur la ligne ${s.lineLabel}',
          arrivalAt: null,
        );
      case null:
        return null;
    }
  }

  static AuleHomeSnapshot buildHomeSnapshot({
    required GtfsService gtfs,
    required LatLng? userPosition,
    required List<NearbyVehicleInfo> vehicles,
    required List<Report> reports,
    required bool isOffline,
    required DateTime now,
  }) {
    final hasGps = userPosition != null;
    final stations = HomeAggregator.nearbyStations(
      gtfs,
      userPosition,
      limit: 4,
    );
    final groupsPerStation = HomeAggregator.groupsPerStation(gtfs, stations);

    final stops = <AuleStopData>[];
    for (var i = 0; i < stations.length; i++) {
      final groups = i < groupsPerStation.length
          ? groupsPerStation[i]
          : <StationLineGroup>[];
      if (groups.isEmpty) continue;
      stops.add(fromNearbyStation(
        station: stations[i],
        groups: groups,
        gtfs: gtfs,
        now: now,
      ));
    }

    final imminent = HomeAggregator.imminentDepartures(gtfs, stations, limit: 6)
        .map((d) => fromImminentDeparture(d, now))
        .toList()
      ..sort((a, b) =>
          a.arrivalAt.compareTo(b.arrivalAt));

    final radarVehicles = <AuleVehicleData>[];
    for (final v in vehicles.take(3)) {
      final puck = fromNearbyVehicle(info: v, gtfs: gtfs, now: now);
      if (puck != null) radarVehicles.add(puck);
    }

    final network = HomeAggregator.networkStatus(
      vehicles.map((v) => v.vehicle).toList(),
      reports,
    );

    final suggestion = fromSmartSuggestion(
      HomeAggregator.bestSuggestion(
        stations: stations,
        groupsPerStation: groupsPerStation,
        reports: reports,
        gtfs: gtfs,
      ),
      now,
    );

    return AuleHomeSnapshot(
      stops: stops,
      departures: imminent,
      vehicles: radarVehicles,
      alerts: reports.take(5).map((r) => fromReport(r, gtfs)).toList(),
      suggestion: suggestion,
      networkHealthPercent: network.punctualityPercent,
      networkDisruptions: network.disruptionCount,
      hasGps: hasGps,
      isOffline: isOffline,
    );
  }

  /// Lignes structurantes affichées sur la carte réseau (tram, chronobus…).
  static List<GtfsRoute> mapRoutes(GtfsService gtfs) {
    final routes = [...gtfs.cachedRoutes];
    routes.sort((a, b) {
      int priority(String t) => switch (t) {
            'tram' => 0,
            'busway' => 1,
            'navibus' => 2,
            _ => 3,
          };
      final pa = priority(a.transportType);
      final pb = priority(b.transportType);
      if (pa != pb) return pa.compareTo(pb);
      return lineCode(a).compareTo(lineCode(b));
    });

    final featured = routes.where((r) {
      if (r.transportType == 'tram' || r.transportType == 'busway') {
        return true;
      }
      final code = lineCode(r);
      return code.length <= 3 && int.tryParse(code) != null;
    }).toList();

    return featured.isNotEmpty ? featured : routes.take(12).toList();
  }

  static List<String> mapFilterChips(GtfsService gtfs) {
    return ['Tout', ...mapRoutes(gtfs).map(lineCode)];
  }

  static List<AuleNetworkLine> networkLines(
    GtfsService gtfs,
    List<Report> reports,
  ) {
    final disruptedIds = reports.map((r) => r.routeId).toSet();
    return mapRoutes(gtfs).map((route) {
      return AuleNetworkLine(
        code: lineCode(route),
        terminus: terminusLabel(route),
        modeLabel: modeLabel(route.transportType),
        mode: modeFrom(route.transportType),
        frequency: frequencyLabel(route),
        disrupted: disruptedIds.contains(route.routeId),
      );
    }).toList();
  }

  static List<GtfsStop> mapStopsNear(LatLng center, GtfsService gtfs,
      {double maxMeters = 2500}) {
    final stops = <GtfsStop>[];
    for (final stop in gtfs.cachedStops) {
      final d = _distance.as(LengthUnit.Meter, center, stop.position);
      if (d <= maxMeters) stops.add(stop);
    }
    stops.sort((a, b) {
      final da = _distance.as(LengthUnit.Meter, center, a.position);
      final db = _distance.as(LengthUnit.Meter, center, b.position);
      return da.compareTo(db);
    });
    return stops.take(80).toList();
  }
}
