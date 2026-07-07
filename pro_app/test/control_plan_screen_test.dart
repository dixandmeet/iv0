import 'package:aule_pro/models/driver/control_plan_context.dart';
import 'package:aule_pro/models/driver/control_team.dart';
import 'package:aule_pro/screens/driver/control_plan_screen.dart';
import 'package:aule_pro/services/driver/control_plan_service.dart';
import 'package:aule_pro/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

ControlTeam _sampleTeam({
  required String id,
  required String name,
  TeamStatus status = TeamStatus.planned,
  List<TeamMember> members = const [],
}) {
  return ControlTeam(
    id: id,
    name: name,
    status: status,
    departureTime: const TimeOfDay(hour: 8, minute: 0),
    returnTime: const TimeOfDay(hour: 12, minute: 0),
    members: members,
  );
}

ControlMissionSummary _sampleMission({bool fullAccess = true}) {
  return ControlMissionSummary(
    id: 'mission-1',
    controlPlanId: 'plan-1',
    planName: 'Mission Commerce',
    teamId: 'team-1',
    teamName: 'Équipe Alpha',
    scheduledStart: DateTime(2026, 6, 1, 8),
    scheduledEnd: DateTime(2026, 6, 1, 12),
    creatorName: 'Chef Équipe',
    status: ControlMissionStatus.assigned,
    fullAccess: fullAccess,
    zoneLabel: fullAccess ? 'Zone Nord' : null,
    instructions: fullAccess ? const ['Consigne A'] : const [],
    missionDisplayNumber: 248,
  );
}

class _TestControlPlanService extends ControlPlanService {
  _TestControlPlanService(ControlPlanContext context)
      : super(supabaseService: SupabaseService()) {
    seedForTest(context);
  }

  @override
  Future<void> fetchMyContext({bool silent = false}) async {}

  @override
  Future<void> fetchHistory({int limit = 20, int offset = 0}) async {}

  @override
  Future<void> fetchUpcoming({int limit = 20, int offset = 0}) async {}
}

class _RespondTestControlPlanService extends _TestControlPlanService {
  bool responded = false;
  String? respondedTeamId;
  bool? respondedAccept;

  _RespondTestControlPlanService(super.context);

  @override
  Future<TeamInvitationResult> respondTeamInvitation({
    required String teamId,
    required bool accept,
  }) async {
    responded = true;
    respondedTeamId = teamId;
    respondedAccept = accept;
    return const TeamInvitationResult(
      success: true,
      status: 'accepted',
      message: 'Vous avez rejoint la mission',
    );
  }
}

Widget _harness(ControlPlanContext context) {
  final service = _TestControlPlanService(context);

  return MaterialApp(
    home: ChangeNotifierProvider<ControlPlanService>.value(
      value: service,
      child: const ControlPlanScreen(),
    ),
  );
}

void main() {
  test('displayMission fonctionne sans plan actif', () {
    const myTeamId = 'team-1';
    final context = ControlPlanContext(
      myTeamId: myTeamId,
      teams: [_sampleTeam(id: myTeamId, name: 'Équipe Alpha')],
      effectiveInvitationStatus: EffectiveInvitationStatus.invited,
    );

    expect(context.displayMission, isNotNull);
    expect(context.displayMission!.teamId, myTeamId);
    expect(context.displayMission!.planName, 'Équipe Alpha');
  });

  testWidgets('affiche les onglets Aujourd\'hui, À venir et Historique',
      (tester) async {
    await tester.pumpWidget(_harness(const ControlPlanContext()));
    await tester.pumpAndSettle();

    expect(find.text('Aujourd\'hui'), findsOneWidget);
    expect(find.text('À venir'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
  });

  testWidgets('empty state mission-first si aucune mission', (tester) async {
    await tester.pumpWidget(_harness(const ControlPlanContext()));
    await tester.pumpAndSettle();

    expect(find.text('Aucun service aujourd\'hui'), findsOneWidget);
    expect(find.text('Créer le service'), findsOneWidget);
  });

  testWidgets('rejoint la mission depuis la carte invitation', (tester) async {
    const myTeamId = 'team-1';
    final context = ControlPlanContext(
      myTeamId: myTeamId,
      teams: [_sampleTeam(id: myTeamId, name: 'Équipe Alpha')],
      effectiveInvitationStatus: EffectiveInvitationStatus.invited,
    );
    final service = _RespondTestControlPlanService(context);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<ControlPlanService>.value(
          value: service,
          child: const ControlPlanScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rejoindre le service'));
    await tester.pumpAndSettle();

    expect(service.responded, isTrue);
    expect(service.respondedTeamId, myTeamId);
    expect(service.respondedAccept, isTrue);
    expect(find.text('Vous avez rejoint la mission'), findsOneWidget);
  });

  testWidgets('affiche MissionStatusCard avec numéro terrain', (tester) async {
    final context = ControlPlanContext(
      plan: ControlPlanSummary(
        id: 'plan-1',
        name: 'Mission Commerce',
        status: ControlPlanStatus.active,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
        objective: 'Contrôle titres.',
      ),
      myTeamId: 'team-1',
      teams: [_sampleTeam(id: 'team-1', name: 'Équipe Alpha')],
      canViewFull: true,
      currentMission: _sampleMission(),
    );

    await tester.pumpWidget(_harness(context));
    await tester.pumpAndSettle();

    expect(find.textContaining('Service #248'), findsOneWidget);
    expect(find.text('Voir le service'), findsOneWidget);
  });
}
