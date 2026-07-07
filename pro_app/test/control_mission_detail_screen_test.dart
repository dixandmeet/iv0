import 'package:aule_pro/models/driver/control_plan_context.dart';
import 'package:aule_pro/models/driver/mission_models.dart';
import 'package:aule_pro/screens/driver/control_mission_detail_screen.dart';
import 'package:aule_pro/services/driver/control_plan_service.dart';
import 'package:aule_pro/services/supabase_service.dart';
import 'package:aule_pro/widgets/driver/control_mission/mission_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

ControlMissionSummary _mission({bool fullAccess = false}) {
  return ControlMissionSummary(
    id: 'mission-1',
    planName: 'Mission Test',
    teamId: 'team-1',
    teamName: 'Équipe A',
    scheduledStart: DateTime(2026, 6, 1, 8),
    scheduledEnd: DateTime(2026, 6, 1, 12),
    creatorName: 'Chef',
    fullAccess: fullAccess,
    zoneLabel: fullAccess ? 'Zone X' : null,
    lineId: fullAccess ? 'T1' : null,
    instructions: fullAccess ? const ['Consigne terrain'] : const [],
    missionDisplayNumber: 248,
  );
}

Widget _harness(Widget child) {
  return MaterialApp(
    home: ChangeNotifierProvider(
      create: (_) => ControlPlanService(supabaseService: SupabaseService()),
      child: child,
    ),
  );
}

void main() {
  testWidgets('délègue au workspace avec onglets mission', (tester) async {
    await tester.pumpWidget(
      _harness(
        ControlMissionDetailScreen(
          mission: _mission(fullAccess: true),
          canViewFull: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Service de contrôle'), findsOneWidget);
    expect(find.text('Service'), findsWidgets);
    expect(find.text('Équipe'), findsOneWidget);
    expect(find.text('Terrain'), findsOneWidget);
    expect(find.text('Discussion'), findsOneWidget);
  });

  testWidgets('affiche le bandeau avec numéro terrain', (tester) async {
    await tester.pumpWidget(
      _harness(
        ControlMissionDetailScreen(
          mission: _mission(fullAccess: true),
          canViewFull: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Service #248'), findsWidgets);
  });

  testWidgets('une checklist incomplète bloque explicitement le démarrage', (
    tester,
  ) async {
    const readiness = TeamReadiness(
      items: [
        ReadinessItem(key: 'pad', label: 'PAD désigné', done: true),
        ReadinessItem(key: 'chef', label: 'Chef désigné', done: false),
        ReadinessItem(key: 'tpe', label: 'TPE désigné', done: true),
        ReadinessItem(
          key: 'all_joined',
          label: 'Tous les agents ont accepté',
          done: false,
        ),
        ReadinessItem(
          key: 'all_present',
          label: 'Tous les agents sont présents',
          done: false,
          blocking: 'Kevin Tshibangu n\'est pas encore arrivé',
        ),
      ],
      ready: false,
      blockingLabel: 'Kevin Tshibangu n\'est pas encore arrivé',
      joinedCount: 2,
      joinedTotal: 2,
      presentCount: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: PreparationChecklist(readiness: readiness),
          ),
        ),
      ),
    );

    expect(
      find.text('Kevin Tshibangu n\'est pas encore arrivé'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Le service ne peut pas démarrer'),
      findsOneWidget,
    );
  });
}
