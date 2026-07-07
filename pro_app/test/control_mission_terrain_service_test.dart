import 'package:aule_pro/models/driver/control_plan_context.dart';
import 'package:aule_pro/models/driver/control_mission_terrain.dart';
import 'package:aule_pro/services/driver/control_mission_terrain_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ControlMissionTerrainService scoring', () {
    test('priorise lignes, passages proches et correspondances', () {
      final strong = ControlMissionTerrainService.calculateScore(
        lineCount: 4,
        nextPassagesWithin10: 3,
        connectionCount: 3,
        walkMinutes: 6,
        returnCompromised: false,
      );
      final weak = ControlMissionTerrainService.calculateScore(
        lineCount: 1,
        nextPassagesWithin10: 0,
        connectionCount: 0,
        walkMinutes: 12,
        returnCompromised: false,
      );

      expect(strong, greaterThan(weak));
    });

    test('pénalise un retour dépôt compromis', () {
      final ok = ControlMissionTerrainService.calculateScore(
        lineCount: 3,
        nextPassagesWithin10: 2,
        connectionCount: 2,
        walkMinutes: 7,
        returnCompromised: false,
      );
      final compromised = ControlMissionTerrainService.calculateScore(
        lineCount: 3,
        nextPassagesWithin10: 2,
        connectionCount: 2,
        walkMinutes: 7,
        returnCompromised: true,
      );

      expect(ok - compromised, 12);
    });
  });

  group('ControlMissionTerrainService fallback', () {
    test('retourne un plan exploitable sans GTFS ni GPS', () {
      final service = ControlMissionTerrainService();
      final plan = service.buildPlan(
        mission: ControlMissionSummary(
          id: 'mission-1',
          planName: 'Mission Test',
          teamName: 'Équipe',
          scheduledEnd: DateTime(2026, 6, 1, 12),
          zoneLabel: 'Zone X',
        ),
        gtfs: null,
        teamPosition: null,
        now: DateTime(2026, 6, 1, 8),
      );

      expect(plan.usedFallbackCenter, isTrue);
      expect(plan.badges.map((b) => b.label), contains('GPS indisponible'));
      expect(plan.badges.map((b) => b.label), contains('Horaires théoriques'));
      expect(plan.badges.map((b) => b.label), contains('Retour dépôt estimé'));
      expect(plan.recommendedStop, isNotNull);
      expect(plan.padRecommendation.steps, isNotEmpty);
      expect(plan.recommendedStop!.scoreLevel, isA<MissionTerrainScoreLevel>());
    });
  });
}
