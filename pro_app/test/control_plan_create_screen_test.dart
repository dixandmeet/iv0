import 'package:aule_pro/models/driver/control_plan_context.dart';
import 'package:aule_pro/models/driver/control_team.dart';
import 'package:aule_pro/screens/driver/control_mission_create_screen.dart';
import 'package:aule_pro/services/driver/control_plan_service.dart';
import 'package:aule_pro/services/driver/control_team_service.dart';
import 'package:aule_pro/services/gtfs_service.dart';
import 'package:aule_pro/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

class _TestControlPlanService extends ControlPlanService {
  _TestControlPlanService() : super(supabaseService: SupabaseService());
}

/// Service d'équipe de test : la recherche renvoie deux agents fixes plutôt
/// que d'interroger Supabase (indisponible en widget test).
class _TestControlTeamService extends ControlTeamService {
  _TestControlTeamService() : super(supabaseService: SupabaseService());

  @override
  Future<List<TeamAgent>> searchAgents(String query) async {
    return const [
      TeamAgent(id: 'a1', firstName: 'Agent', lastName: 'Un'),
      TeamAgent(id: 'a2', firstName: 'Agent', lastName: 'Deux'),
    ];
  }
}

Widget _harness({ControlPlanContext? context}) {
  final supabase = SupabaseService();
  final planService = _TestControlPlanService();
  if (context != null) {
    planService.seedForTest(context);
  }

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SupabaseService>.value(value: supabase),
      ChangeNotifierProxyProvider<SupabaseService, GtfsService>(
        create: (_) => GtfsService(supabaseService: supabase),
        update: (_, s, previous) =>
            previous ?? GtfsService(supabaseService: s),
      ),
      ChangeNotifierProvider<ControlPlanService>.value(value: planService),
      ChangeNotifierProvider<ControlTeamService>(
        create: (_) => _TestControlTeamService(),
      ),
    ],
    // Les providers doivent être au-dessus du Navigator racine : les feuilles
    // modales (showModalBottomSheet) s'insèrent dans son Overlay, en dehors
    // du sous-arbre de `home`, sinon leur contexte ne les voit pas.
    child: const MaterialApp(home: ControlMissionCreateScreen()),
  );
}

/// Ouvre la feuille de recherche d'agent, tape la requête et sélectionne le
/// premier résultat renvoyé par [_TestControlTeamService.searchAgents].
Future<void> _addAgentViaSearch(WidgetTester tester, String agentLabel) async {
  await tester.tap(find.text('Rechercher un agent (nom ou matricule)'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, 'ag');
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  await tester.tap(find.text(agentLabel));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  testWidgets('affiche le wizard 6 étapes dans le nouvel ordre', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Créer un service'), findsOneWidget);
    expect(find.text('Équipe'), findsWidgets);
    expect(find.text('Rôles'), findsOneWidget);
    expect(find.text('Consignes'), findsOneWidget);
    expect(find.text('Déplacement'), findsOneWidget);
    expect(find.text('Vacations'), findsOneWidget);
    expect(find.text('Validation'), findsOneWidget);
  });

  testWidgets('étape Équipe : état vide invite à composer l\'équipe', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Aucun agent ajouté'),
      findsOneWidget,
    );
    expect(
      find.text('Rechercher un agent (nom ou matricule)'),
      findsOneWidget,
    );
  });

  testWidgets(
    'bloque l\'étape Équipe tant que moins de 2 agents ne sont ajoutés',
    (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ajoutez au moins 2 agents à l\'équipe'),
        findsOneWidget,
      );
      // Toujours sur l'étape Équipe : pas d'attribution de rôles visible.
      expect(find.text('Attribution des rôles'), findsNothing);
    },
  );

  testWidgets('ajouter 2 agents fait avancer vers l\'étape Rôles', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await _addAgentViaSearch(tester, 'Agent Un');
    expect(find.text('Agent Un'), findsOneWidget);

    await _addAgentViaSearch(tester, 'Agent Deux');
    expect(find.text('Agent Deux'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    expect(find.text('Attribution des rôles'), findsOneWidget);
    expect(find.text('PAD, Chef et TPE pour ce service'), findsOneWidget);
  });
}
