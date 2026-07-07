import 'package:aule_pro/models/driver/driver_onboarding_data.dart';
import 'package:aule_pro/models/driver/driver_workspace_mode.dart';
import 'package:aule_pro/models/driver/terrain_user_marker_style.dart';
import 'package:aule_pro/widgets/driver/driver_map_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  group('resolveUserMarkerStyle', () {
    test('conduite, homme → icône conducteur', () {
      expect(
        resolveUserMarkerStyle(
          workspace: DriverWorkspaceMode.conduite,
          gender: DriverGender.homme,
          hasActiveMission: false,
        ),
        TerrainUserMarkerStyle.driverHomme,
      );
    });

    test('conduite, femme → point bleu', () {
      expect(
        resolveUserMarkerStyle(
          workspace: DriverWorkspaceMode.conduite,
          gender: DriverGender.femme,
          hasActiveMission: false,
        ),
        TerrainUserMarkerStyle.blueDot,
      );
    });

    test('MSR sans mission, homme → icône H', () {
      expect(
        resolveUserMarkerStyle(
          workspace: DriverWorkspaceMode.controle,
          gender: DriverGender.homme,
          hasActiveMission: false,
        ),
        TerrainUserMarkerStyle.controllerHomme,
      );
    });

    test('MSR sans mission, femme → icône F', () {
      expect(
        resolveUserMarkerStyle(
          workspace: DriverWorkspaceMode.intervention,
          gender: DriverGender.femme,
          hasActiveMission: false,
        ),
        TerrainUserMarkerStyle.controllerFemme,
      );
    });

    test('MSR sans mission, autre → stub neutre', () {
      expect(
        resolveUserMarkerStyle(
          workspace: DriverWorkspaceMode.controle,
          gender: DriverGender.autre,
          hasActiveMission: false,
        ),
        TerrainUserMarkerStyle.controllerNeutralStub,
      );
    });

    test('MSR en mission → stub mission', () {
      expect(
        resolveUserMarkerStyle(
          workspace: DriverWorkspaceMode.controle,
          gender: DriverGender.homme,
          hasActiveMission: true,
        ),
        TerrainUserMarkerStyle.onMissionStub,
      );
    });
  });

  group('resolveUserHeadingDeg', () {
    test('heading invalide → 0', () {
      expect(resolveUserHeadingDeg(null), 0);
      expect(resolveUserHeadingDeg(-1), 0);
      expect(resolveUserHeadingDeg(double.nan), 0);
    });

    test('heading valide conservé', () {
      expect(resolveUserHeadingDeg(90), 90);
    });
  });

  // Le marqueur anime en boucle (_micro) → on utilise pump() à durée fixe,
  // jamais pumpAndSettle() qui tournerait à l'infini.

  testWidgets('bus : bus vu du dessus + badge ligne, sans exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const TerrainMapMarker(
          type: TerrainMarkerType.bus,
          headingDeg: 45,
          lineLabel: 'C6',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('B C6'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tram : badge préfixé T', (tester) async {
    await tester.pumpWidget(
      host(
        const TerrainMapMarker(
          type: TerrainMarkerType.tram,
          headingDeg: 0,
          lineLabel: 'L1',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('T L1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incident : pastille ronde, aucun badge ligne', (tester) async {
    await tester.pumpWidget(
      host(const TerrainMapMarker(type: TerrainMarkerType.incident)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('B '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contrôle : véhicule vu du dessus + badge, sans exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const TerrainMapMarker(
          type: TerrainMarkerType.controle,
          headingDeg: 20,
          lineLabel: 'C2',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('C C2'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conducteur homme : monte sans exception', (tester) async {
    await tester.pumpWidget(
      host(
        const TerrainUserMarker(
          style: TerrainUserMarkerStyle.driverHomme,
          headingDeg: 45,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(TerrainControllerIcon), findsOneWidget);
    expect(find.text('Vous'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contrôleur homme : monte sans exception', (tester) async {
    await tester.pumpWidget(
      host(
        const TerrainUserMarker(
          style: TerrainUserMarkerStyle.controllerHomme,
          headingDeg: 30,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(TerrainControllerIcon), findsOneWidget);
    expect(find.text('Vous'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contrôleur femme : monte sans exception', (tester) async {
    await tester.pumpWidget(
      host(
        const TerrainUserMarker(
          style: TerrainUserMarkerStyle.controllerFemme,
          headingDeg: 15,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(TerrainControllerIcon), findsOneWidget);
    expect(find.text('Vous'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
