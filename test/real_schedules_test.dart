import 'package:flutter_test/flutter_test.dart';
import 'package:wazibus_nantes/services/gtfs_service.dart';
import 'package:wazibus_nantes/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GtfsService gtfs;

  setUpAll(() async {
    final supabase = SupabaseService();
    gtfs = GtfsService(supabaseService: supabase);
    await gtfs.fetchRoutes(); // déclenche aussi le chargement des horaires réels
    await gtfs.fetchStops();
    gtfs.ensureNetworkGraph();
  });

  test('les horaires réels sont chargés depuis l\'asset', () {
    expect(gtfs.hasRealSchedules, isTrue);
  });

  test('tram 1 à Commerce : horaires théoriques réels (pas une simulation)',
      () {
    final route = gtfs.cachedRoutes
        .firstWhere((r) => (r.routeShortName ?? r.routeId) == '1');
    final stop = gtfs.cachedStops.firstWhere((s) => s.stopName == 'Commerce');

    // Lundi tôt le matin : journée complète vers Beaujoire.
    final monday = DateTime(2026, 6, 15, 3, 0);
    final fullDay = gtfs.theoreticalDepartureTimes(
      route,
      stop,
      direction: 'Beaujoire',
      now: monday,
      fullDay: true,
    );

    // Réseau réel : amplitude étendue et cadence irrégulière (≠ simulation).
    expect(fullDay.length, greaterThan(100));
    final first = fullDay.first;
    // Premier passage théorique vers Beaujoire ≈ 04:23 (cf. données GTFS).
    expect(first.hour, 4);
    expect(first.minute, inInclusiveRange(20, 30));

    // Les écarts ne sont pas tous identiques (un cadencement simulé le serait).
    final gaps = <int>{};
    for (var i = 1; i < 12 && i < fullDay.length; i++) {
      gaps.add(fullDay[i].difference(fullDay[i - 1]).inMinutes);
    }
    expect(gaps.length, greaterThan(1),
        reason: 'des écarts variés prouvent des horaires réels');
  });

  test('estimateWaitMinutes utilise le prochain passage réel', () {
    final route = gtfs.cachedRoutes
        .firstWhere((r) => (r.routeShortName ?? r.routeId) == '1');
    final stop = gtfs.cachedStops.firstWhere((s) => s.stopName == 'Commerce');

    final monday = DateTime(2026, 6, 15, 12, 0);
    final next = gtfs.nextRealDeparture(route, stop,
        direction: 'Beaujoire', now: monday);
    expect(next, isNotNull);

    final wait =
        gtfs.estimateWaitMinutes(route, stop, direction: 'Beaujoire', now: monday);
    final expected = (next!.difference(monday).inSeconds / 60).ceil();
    expect(wait, expected);
    expect(wait, lessThan(60)); // un tram en journée passe sous l'heure
  });

  test(
      'rattachement ligne→station filtré par les horaires réels : '
      'Batignolles ne liste pas la 80 (qui s\'arrête à Haluchère)', () {
    final batignolles = gtfs.cachedStops
        .firstWhere((s) => s.stopName == 'Batignolles');
    final station = gtfs.nearbyStationFor(batignolles);
    expect(station, isNotNull);

    final lines = station!.routes
        .map((r) => r.routeShortName ?? r.routeId)
        .toSet();

    // La 80 passe à proximité du tracé mais s'arrête à « Haluchère - Batignolles »,
    // pas ici : l'index horaire réel ne l'y place pas.
    expect(lines, isNot(contains('80')));
    // Les lignes réellement à l'arrêt restent présentes.
    expect(lines, containsAll(<String>['C6', '75']));
  });

  test('le plan de ligne suit aussi les horaires réels : '
      'la 80 dessert Haluchère - Batignolles, pas Batignolles', () {
    final route = gtfs.cachedRoutes
        .firstWhere((r) => (r.routeShortName ?? r.routeId) == '80');
    final stops = gtfs.stopsToward(route, 'Fac de Droit');
    expect(stops, isNotEmpty);

    final names = stops.map((s) => s.stopName).toSet();
    expect(names, isNot(contains('Batignolles')));
    expect(names.any((n) => n.toLowerCase().contains('haluchere') ||
        n.toLowerCase().contains('haluchère')), isTrue);
  });

  test('pont GTFS-RT : ids GTFS résolus pour le live', () {
    final route = gtfs.cachedRoutes
        .firstWhere((r) => (r.routeShortName ?? r.routeId) == '1');
    final stop = gtfs.cachedStops.firstWhere((s) => s.stopName == 'Commerce');
    expect(gtfs.gtfsRouteId(route), 'NAOLIBORG:Line:1');
    expect(gtfs.gtfsQuayFor(route, stop, 'Beaujoire'), startsWith('FR_NAOLIB:Quay:'));
  });
}
