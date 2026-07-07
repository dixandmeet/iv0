import 'package:aule_pro/models/driver/control_plan_context.dart';
import 'package:aule_pro/widgets/driver/control_mission/mission_terrain_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MissionTerrainTab affiche les blocs principaux en fallback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionTerrainTab(
            mission: ControlMissionSummary(
              id: 'mission-1',
              planName: 'Mission Test',
              teamName: 'Équipe A',
              scheduledStart: DateTime(2026, 6, 1, 8),
              scheduledEnd: DateTime(2026, 6, 1, 12),
              zoneLabel: 'Zone X',
              lineId: 'T1',
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Point conseillé maintenant'), findsOneWidget);
    expect(find.text('GPS indisponible'), findsOneWidget);
    expect(find.text('Temps réel indisponible'), findsOneWidget);
    expect(find.text('Horaires théoriques'), findsOneWidget);
    expect(find.text('Retour dépôt estimé'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Lignes du secteur'), 350);
    expect(find.text('Lignes du secteur'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Assistant PAD'), 350);
    expect(find.text('Assistant PAD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MissionTerrainTab ouvre le détail arrêt sans donnée externe', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionTerrainTab(
            mission: ControlMissionSummary(
              id: 'mission-1',
              planName: 'Mission Test',
              teamName: 'Équipe A',
              scheduledEnd: DateTime(2026, 6, 1, 12),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Voir détails'));
    await tester.tap(find.text('Voir détails'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Prochains passages'), findsOneWidget);
    expect(find.text('Intérêt opérationnel'), findsOneWidget);
    expect(find.text('S’y rendre'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
