import 'package:latlong2/latlong.dart';

import '../gtfs.dart';

enum MissionTerrainScoreLevel {
  low('faible'),
  medium('moyen'),
  high('élevé'),
  veryHigh('très élevé');

  final String label;

  const MissionTerrainScoreLevel(this.label);
}

enum MissionTerrainLineStatus {
  immediate('immédiat'),
  soon('bientôt'),
  longWait('attente longue');

  final String label;

  const MissionTerrainLineStatus(this.label);
}

class MissionTerrainBadge {
  final String label;
  final bool warning;

  const MissionTerrainBadge(this.label, {this.warning = false});
}

class MissionTerrainPassage {
  final String lineLabel;
  final String direction;
  final int waitMinutes;
  final bool theoretical;

  const MissionTerrainPassage({
    required this.lineLabel,
    required this.direction,
    required this.waitMinutes,
    this.theoretical = true,
  });
}

class MissionTerrainLinePlan {
  final GtfsRoute? route;
  final String lineLabel;
  final String lineName;
  final String advisedStopName;
  final String direction;
  final int nextWaitMinutes;
  final String operationalInterest;
  final MissionTerrainLineStatus status;
  final double score;

  const MissionTerrainLinePlan({
    required this.route,
    required this.lineLabel,
    required this.lineName,
    required this.advisedStopName,
    required this.direction,
    required this.nextWaitMinutes,
    required this.operationalInterest,
    required this.status,
    required this.score,
  });
}

class MissionTerrainStopPlan {
  final String id;
  final String name;
  final LatLng position;
  final double? distanceMeters;
  final bool inSector;
  final List<GtfsRoute> routes;
  final List<MissionTerrainPassage> passages;
  final int score;
  final MissionTerrainScoreLevel scoreLevel;
  final String operationalInterest;
  final bool returnCompromised;

  const MissionTerrainStopPlan({
    required this.id,
    required this.name,
    required this.position,
    required this.distanceMeters,
    required this.inSector,
    required this.routes,
    required this.passages,
    required this.score,
    required this.scoreLevel,
    required this.operationalInterest,
    required this.returnCompromised,
  });

  int get lineCount => routes.length;

  int? get soonestWaitMinutes {
    if (passages.isEmpty) return null;
    return passages.map((p) => p.waitMinutes).reduce((a, b) => a < b ? a : b);
  }

  int? get walkMinutes {
    final d = distanceMeters;
    if (d == null) return null;
    return (d / 80).ceil().clamp(1, 90);
  }
}

class MissionTerrainPadStep {
  final MissionTerrainStopPlan stop;
  final int recommendedMinutes;
  final List<String> targetLines;

  const MissionTerrainPadStep({
    required this.stop,
    required this.recommendedMinutes,
    required this.targetLines,
  });
}

class MissionTerrainPadRecommendation {
  final List<MissionTerrainPadStep> steps;
  final DateTime? leaveLastPointAt;
  final DateTime? estimatedDepotArrivalAt;
  final bool returnPossible;

  const MissionTerrainPadRecommendation({
    required this.steps,
    required this.leaveLastPointAt,
    required this.estimatedDepotArrivalAt,
    required this.returnPossible,
  });
}

class MissionTerrainPlan {
  final LatLng mapCenter;
  final bool usedFallbackCenter;
  final List<MissionTerrainBadge> badges;
  final List<MissionTerrainStopPlan> stops;
  final List<MissionTerrainLinePlan> sectorLines;
  final MissionTerrainPadRecommendation padRecommendation;
  final DateTime? returnDeadline;
  final bool loadingFromGtfs;

  const MissionTerrainPlan({
    required this.mapCenter,
    required this.usedFallbackCenter,
    required this.badges,
    required this.stops,
    required this.sectorLines,
    required this.padRecommendation,
    required this.returnDeadline,
    this.loadingFromGtfs = false,
  });

  MissionTerrainStopPlan? get recommendedStop =>
      stops.isEmpty ? null : stops.first;
}
