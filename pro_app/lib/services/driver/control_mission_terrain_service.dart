import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../models/driver/control_mission_terrain.dart';
import '../../models/driver/control_plan_context.dart';
import '../../models/gtfs.dart';
import '../../widgets/driver/control_mission/mission_shared_widgets.dart';
import '../gtfs_service.dart';

class ControlMissionTerrainService {
  static const LatLng nantesFallbackCenter = LatLng(47.2173, -1.5534);

  MissionTerrainPlan buildPlan({
    required ControlMissionSummary mission,
    required GtfsService? gtfs,
    required LatLng? teamPosition,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final deadline = mission.scheduledEnd;
    final anchor = teamPosition ?? _sectorAnchor(mission, gtfs);
    final center = anchor ?? nantesFallbackCenter;
    final badges = <MissionTerrainBadge>[
      if (teamPosition == null)
        const MissionTerrainBadge('GPS indisponible', warning: true),
      const MissionTerrainBadge('Temps réel indisponible', warning: true),
      const MissionTerrainBadge('Horaires théoriques'),
      if (deadline != null) const MissionTerrainBadge('Retour dépôt estimé'),
    ];

    final candidates = _candidateStations(
      mission: mission,
      gtfs: gtfs,
      center: center,
      teamPosition: teamPosition,
      now: ref,
    );

    final stops =
        candidates
            .map(
              (station) => _stopPlan(
                station: station,
                mission: mission,
                gtfs: gtfs,
                teamPosition: teamPosition,
                deadline: deadline,
                now: ref,
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final linePlans = _linePlans(stops);
    final pad = _padRecommendation(stops: stops, now: ref, deadline: deadline);

    return MissionTerrainPlan(
      mapCenter: center,
      usedFallbackCenter: teamPosition == null && anchor == null,
      badges: badges,
      stops: stops,
      sectorLines: linePlans,
      padRecommendation: pad,
      returnDeadline: deadline,
    );
  }

  static int calculateScore({
    required int lineCount,
    required int nextPassagesWithin10,
    required int connectionCount,
    required int walkMinutes,
    required bool returnCompromised,
  }) {
    return lineCount * 3 +
        nextPassagesWithin10 * 4 +
        connectionCount * 2 -
        walkMinutes -
        (returnCompromised ? 12 : 0);
  }

  LatLng? _sectorAnchor(ControlMissionSummary mission, GtfsService? gtfs) {
    final route = _missionRoute(mission, gtfs);
    if (route != null) {
      for (final segment in route.shapes) {
        if (segment.isNotEmpty) return segment[segment.length ~/ 2];
      }
    }
    final zone = mission.zoneLabel?.trim();
    if (zone != null && zone.isNotEmpty && gtfs != null) {
      final stations = gtfs.searchStations(zone, limit: 1);
      if (stations.isNotEmpty) return stations.first.stop.position;
    }
    return null;
  }

  List<NearbyStation> _candidateStations({
    required ControlMissionSummary mission,
    required GtfsService? gtfs,
    required LatLng center,
    required LatLng? teamPosition,
    required DateTime now,
  }) {
    if (gtfs == null || gtfs.cachedStops.isEmpty || gtfs.cachedRoutes.isEmpty) {
      return _mockStations(center);
    }

    final route = _missionRoute(mission, gtfs);
    final from = teamPosition ?? center;
    final seen = <String>{};
    final out = <NearbyStation>[];

    void add(NearbyStation station) {
      if (!seen.add(station.stop.stopId)) return;
      out.add(station);
    }

    for (final station in gtfs.nearbyStations(
      from,
      limit: 18,
      maxMeters: 1800,
    )) {
      add(station);
    }

    if (route != null) {
      final byDistance = <NearbyStation>[];
      for (final stop in gtfs.cachedStops) {
        final station = gtfs.nearbyStationFor(stop, from: from);
        if (station == null) continue;
        final servesMissionLine = station.routes.any(
          (r) => r.routeId == route.routeId,
        );
        if (!servesMissionLine) continue;
        byDistance.add(station);
      }
      byDistance.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      for (final station in byDistance.take(18)) {
        add(station);
      }
    }

    if (out.isEmpty) return _mockStations(center);
    out.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return out.take(24).toList();
  }

  MissionTerrainStopPlan _stopPlan({
    required NearbyStation station,
    required ControlMissionSummary mission,
    required GtfsService? gtfs,
    required LatLng? teamPosition,
    required DateTime? deadline,
    required DateTime now,
  }) {
    final passages = _passagesFor(station: station, gtfs: gtfs, now: now);
    final walkMinutes = station.distanceMeters <= 0
        ? 0
        : (station.distanceMeters / 80).ceil();
    final returnCompromised = _returnCompromised(
      walkMinutes: walkMinutes,
      deadline: deadline,
      now: now,
    );
    final lineCount = station.routes.length;
    final soonPassages = passages
        .where((p) => p.waitMinutes <= 10)
        .length
        .clamp(0, 20);
    final connections = math.max(0, lineCount - 1);
    final score = calculateScore(
      lineCount: lineCount,
      nextPassagesWithin10: soonPassages,
      connectionCount: connections,
      walkMinutes: walkMinutes,
      returnCompromised: returnCompromised,
    );
    final inSector = _isInSector(station, mission, gtfs);
    final adjustedScore = score + (inSector ? 6 : 0);

    return MissionTerrainStopPlan(
      id: station.stop.stopId,
      name: station.stop.stopName,
      position: station.stop.position,
      distanceMeters: teamPosition == null ? null : station.distanceMeters,
      inSector: inSector,
      routes: station.routes,
      passages: passages,
      score: adjustedScore,
      scoreLevel: _scoreLevel(adjustedScore),
      operationalInterest: _interestLabel(
        lineCount: lineCount,
        soonPassages: soonPassages,
        inSector: inSector,
        returnCompromised: returnCompromised,
      ),
      returnCompromised: returnCompromised,
    );
  }

  List<MissionTerrainPassage> _passagesFor({
    required NearbyStation station,
    required GtfsService? gtfs,
    required DateTime now,
  }) {
    if (gtfs == null) {
      return station.routes
          .take(3)
          .map(
            (route) => MissionTerrainPassage(
              lineLabel: _lineLabel(route),
              direction: route.routeLongName ?? 'Direction principale',
              waitMinutes: _mockWait(route, station.stop),
            ),
          )
          .toList();
    }

    final groups = gtfs.stationLineGroups(station, now: now);
    if (groups.isEmpty) {
      return station.routes
          .take(3)
          .map(
            (route) => MissionTerrainPassage(
              lineLabel: _lineLabel(route),
              direction: route.routeLongName ?? 'Direction principale',
              waitMinutes: gtfs.estimateWaitMinutes(
                route,
                station.stop,
                now: now,
              ),
            ),
          )
          .toList();
    }

    return groups
        .expand(
          (group) => group.directions
              .take(1)
              .map(
                (departure) => MissionTerrainPassage(
                  lineLabel: _lineLabel(departure.route),
                  direction: departure.headsign,
                  waitMinutes: departure.waitMinutes,
                ),
              ),
        )
        .take(8)
        .toList();
  }

  List<MissionTerrainLinePlan> _linePlans(List<MissionTerrainStopPlan> stops) {
    final bestByLine = <String, MissionTerrainLinePlan>{};
    for (final stop in stops) {
      for (final passage in stop.passages) {
        final route = stop.routes.firstWhere(
          (r) => _lineLabel(r) == passage.lineLabel,
          orElse: () => stop.routes.first,
        );
        final plan = MissionTerrainLinePlan(
          route: route,
          lineLabel: passage.lineLabel,
          lineName: route.routeLongName ?? passage.lineLabel,
          advisedStopName: stop.name,
          direction: passage.direction,
          nextWaitMinutes: passage.waitMinutes,
          operationalInterest: stop.operationalInterest,
          status: _lineStatus(passage.waitMinutes),
          score: stop.score - passage.waitMinutes / 3,
        );
        final current = bestByLine[passage.lineLabel];
        if (current == null || plan.score > current.score) {
          bestByLine[passage.lineLabel] = plan;
        }
      }
    }
    final lines = bestByLine.values.toList()
      ..sort((a, b) {
        final wait = a.nextWaitMinutes.compareTo(b.nextWaitMinutes);
        if (wait != 0) return wait;
        return b.score.compareTo(a.score);
      });
    return lines.take(12).toList();
  }

  MissionTerrainPadRecommendation _padRecommendation({
    required List<MissionTerrainStopPlan> stops,
    required DateTime now,
    required DateTime? deadline,
  }) {
    final steps = <MissionTerrainPadStep>[];
    for (final stop in stops.where((s) => !s.returnCompromised).take(3)) {
      steps.add(
        MissionTerrainPadStep(
          stop: stop,
          recommendedMinutes:
              stop.scoreLevel == MissionTerrainScoreLevel.veryHigh ? 30 : 25,
          targetLines: stop.passages.map((p) => p.lineLabel).take(4).toList(),
        ),
      );
    }
    if (steps.isEmpty && stops.isNotEmpty) {
      final stop = stops.first;
      steps.add(
        MissionTerrainPadStep(
          stop: stop,
          recommendedMinutes: 20,
          targetLines: stop.passages.map((p) => p.lineLabel).take(3).toList(),
        ),
      );
    }

    final totalMinutes = steps.fold<int>(
      0,
      (sum, step) =>
          sum + step.recommendedMinutes + (step.stop.walkMinutes ?? 6),
    );
    final estimatedReturnMinutes = steps.isEmpty
        ? 18
        : (steps.last.stop.walkMinutes ?? 8) + 16;
    final estimatedArrival = now.add(
      Duration(minutes: totalMinutes + estimatedReturnMinutes),
    );
    final returnPossible =
        deadline == null || !estimatedArrival.isAfter(deadline);
    final leaveLast = deadline?.subtract(
      Duration(minutes: estimatedReturnMinutes),
    );

    return MissionTerrainPadRecommendation(
      steps: steps,
      leaveLastPointAt: leaveLast,
      estimatedDepotArrivalAt: estimatedArrival,
      returnPossible: returnPossible,
    );
  }

  bool _returnCompromised({
    required int walkMinutes,
    required DateTime? deadline,
    required DateTime now,
  }) {
    if (deadline == null) return false;
    final estimated = now.add(Duration(minutes: walkMinutes + 35));
    return estimated.isAfter(deadline);
  }

  bool _isInSector(
    NearbyStation station,
    ControlMissionSummary mission,
    GtfsService? gtfs,
  ) {
    final route = _missionRoute(mission, gtfs);
    if (route != null) {
      return station.routes.any((r) => r.routeId == route.routeId);
    }
    final sector = missionSectorLabel(mission).toLowerCase();
    return sector != '—' &&
        (station.stop.stopName.toLowerCase().contains(sector) ||
            sector.contains(station.stop.stopName.toLowerCase()));
  }

  GtfsRoute? _missionRoute(ControlMissionSummary mission, GtfsService? gtfs) {
    final id = mission.lineId?.trim();
    if (id == null || id.isEmpty || gtfs == null) return null;
    final normalized = id.toUpperCase().replaceFirst(RegExp(r'^T'), '');
    for (final route in gtfs.cachedRoutes) {
      final short = (route.routeShortName ?? '').toUpperCase();
      final routeId = route.routeId.toUpperCase();
      if (routeId == id.toUpperCase() ||
          short == id.toUpperCase() ||
          short == normalized ||
          routeId == normalized) {
        return route;
      }
    }
    return null;
  }

  MissionTerrainScoreLevel _scoreLevel(int score) {
    if (score >= 28) return MissionTerrainScoreLevel.veryHigh;
    if (score >= 18) return MissionTerrainScoreLevel.high;
    if (score >= 8) return MissionTerrainScoreLevel.medium;
    return MissionTerrainScoreLevel.low;
  }

  MissionTerrainLineStatus _lineStatus(int waitMinutes) {
    if (waitMinutes <= 5) return MissionTerrainLineStatus.immediate;
    if (waitMinutes <= 15) return MissionTerrainLineStatus.soon;
    return MissionTerrainLineStatus.longWait;
  }

  String _interestLabel({
    required int lineCount,
    required int soonPassages,
    required bool inSector,
    required bool returnCompromised,
  }) {
    if (returnCompromised) return 'Retour dépôt à surveiller';
    if (lineCount >= 4 && soonPassages >= 2) return 'Fort croisement de lignes';
    if (inSector && soonPassages > 0) return 'Bon point de contrôle secteur';
    if (lineCount >= 2) return 'Correspondances exploitables';
    return 'Point simple, utile en appoint';
  }

  List<NearbyStation> _mockStations(LatLng center) {
    final routes = [
      GtfsRoute(
        routeId: 'T1',
        routeShortName: 'T1',
        routeLongName: 'Tram T1',
        routeType: 0,
      ),
      GtfsRoute(
        routeId: 'C1',
        routeShortName: 'C1',
        routeLongName: 'Chronobus C1',
        routeType: 3,
      ),
      GtfsRoute(
        routeId: '80',
        routeShortName: '80',
        routeLongName: 'Ligne 80',
        routeType: 3,
      ),
      GtfsRoute(
        routeId: '10',
        routeShortName: '10',
        routeLongName: 'Ligne 10',
        routeType: 3,
      ),
    ];
    final stops = [
      GtfsStop(
        stopId: 'mock-haluchere',
        stopName: 'Haluchère-Batignolles',
        position: LatLng(center.latitude + 0.006, center.longitude + 0.004),
      ),
      GtfsStop(
        stopId: 'mock-dalby',
        stopName: 'Dalby',
        position: LatLng(center.latitude - 0.004, center.longitude + 0.006),
      ),
      GtfsStop(
        stopId: 'mock-commerce',
        stopName: 'Commerce',
        position: LatLng(center.latitude, center.longitude - 0.003),
      ),
    ];
    return [
      NearbyStation(
        stop: stops[0],
        distanceMeters: 520,
        routes: routes.take(3).toList(),
      ),
      NearbyStation(
        stop: stops[1],
        distanceMeters: 760,
        routes: [routes[1], routes[3]],
      ),
      NearbyStation(stop: stops[2], distanceMeters: 980, routes: routes),
    ];
  }

  int _mockWait(GtfsRoute route, GtfsStop stop) {
    return ((route.routeId.hashCode ^ stop.stopId.hashCode).abs() % 14) + 2;
  }

  String _lineLabel(GtfsRoute route) => route.routeShortName ?? route.routeId;
}
