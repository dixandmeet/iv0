import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:wazibus_nantes/services/gtfs_service.dart';
import 'package:wazibus_nantes/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GtfsService gtfs;

  setUpAll(() async {
    gtfs = GtfsService(supabaseService: SupabaseService());
    await gtfs.fetchRoutes();
    await gtfs.fetchStops();
    gtfs.ensureNetworkGraph();
  });

  test('les 3 lignes de tram sont chargées avec leurs tracés', () {
    final trams =
        gtfs.cachedRoutes.where((r) => r.transportType == 'tram').toList();
    expect(trams.map((r) => r.routeId).toSet(), {'1', '2', '3'});
    for (final tram in trams) {
      expect(tram.shapes, isNotEmpty,
          reason: 'le tram ${tram.routeId} doit avoir un tracé');
      final points = tram.shapes.fold<int>(0, (n, s) => n + s.length);
      expect(points, greaterThan(100),
          reason: 'tracé du tram ${tram.routeId} trop pauvre');
    }
  });

  test('les stations principales sont desservies par les trams', () {
    // Commerce est le hub central : les trams 1, 2 et 3 y passent.
    final commerce = gtfs.searchStations('Commerce', limit: 5);
    expect(commerce, isNotEmpty);
    final lines = commerce.first.routes.map((r) => r.routeShortName).toSet();
    expect(lines.containsAll({'1', '2', '3'}), isTrue,
        reason: 'Commerce doit être desservi par les trams 1, 2 et 3 '
            '(lignes trouvées : $lines)');

    // Terminus de branches du tram 1.
    for (final name in ['Beaujoire', 'Jamet', 'Ranzay']) {
      final res = gtfs.searchStations(name, limit: 5);
      expect(res, isNotEmpty, reason: '$name doit exister');
      expect(
          res.any((s) =>
              s.routes.any((r) => r.routeShortName == '1')),
          isTrue,
          reason: '$name doit être desservi par le tram 1');
    }
  });

  test('displayShapes déduplique les sens opposés (style carte Naolib)', () {
    // Tracés OSM : une variante par direction/branche (les deux sens sont
    // conservés pour le routage), dédupliquées par couple de terminus.
    final route = gtfs.cachedRoutes.firstWhere((r) => r.routeId == '1');
    expect(route.shapes.length, greaterThanOrEqualTo(4),
        reason: 'le tram 1 doit garder ses variantes de branches');
    final display = gtfs.displayShapes(route);
    expect(display.length, lessThan(route.shapes.length));
    expect(display.length, inInclusiveRange(2, 4));

    // Ligne sans branche : aller + retour fusionnés en un seul tracé.
    final tram2 = gtfs.cachedRoutes.firstWhere((r) => r.routeId == '2');
    expect(gtfs.displayShapes(tram2).length, 1);
  });

  test('shapeToward sélectionne une branche unique vers le terminus', () {
    final route = gtfs.cachedRoutes.firstWhere((r) => r.routeId == '1');
    final towardFm = gtfs.shapeToward(route, 'François Mitterrand');
    expect(towardFm.length, greaterThan(50));
    // Le terminus visé doit être proche de la fin du tracé orienté.
    final endName = gtfs.searchStations('François Mitterrand', limit: 1).first.stop;
    final endDist = const Distance()
        .as(LengthUnit.Meter, towardFm.last, endName.position);
    expect(endDist, lessThan(300));

    // Le plan de ligne ne doit pas mélanger les branches (ex. Jamet au milieu
    // d'un trajet vers François Mitterrand).
    final stops = gtfs.stopsToward(route, 'François Mitterrand');
    expect(stops, isNotEmpty);
    expect(stops.any((s) => s.stopName.contains('Jamet')), isFalse);
  });

  test('itinéraire direct Commerce -> Beaujoire via le tram 1', () async {
    // Heure de référence en pleine journée : le datage horaire ne doit pas
    // déclasser le tram 1 (qui circule) hors des propositions.
    final itineraries = await gtfs.searchItinerary('Commerce', 'Beaujoire',
        now: DateTime(2026, 6, 15, 12, 0));
    expect(itineraries, isNotEmpty);
    expect(
        itineraries.any((it) =>
            it.steps.length == 1 && it.steps.first.lineShortName == '1'),
        isTrue,
        reason: 'un trajet direct en tram 1 doit être proposé');
  });

  test('itinéraire avec les noms réels des suggestions', () async {
    for (final dest in [
      'Gare Nord - Jardin des Plantes',
      'Gare Sud',
      'Cité des Congrès',
      'Trentemoult',
      'Chantiers Navals',
    ]) {
      final itineraries = await gtfs.searchItinerary('Commerce', dest);
      expect(itineraries, isNotEmpty,
          reason: 'Commerce -> $dest doit trouver un itinéraire');
    }
  });

  test('résolution insensible aux accents et à la casse', () async {
    final a = await gtfs.searchItinerary('commerce', 'cite des congres');
    expect(a, isNotEmpty);
    final b = await gtfs.searchItinerary('Commerce', 'CITÉ DES CONGRÈS');
    expect(b, isNotEmpty);
  });

  test('« Ma position » se résout vers une station desservie', () async {
    final itineraries = await gtfs.searchItinerary('Ma position', 'Commerce',
        userPosition: const LatLng(47.2186, -1.5541)); // Hôtel de Ville
    expect(itineraries, isNotEmpty);
  });

  test('resolveLegGuidance résout Terray -> Congo (bus 23 + bus 59)', () async {
    final itineraries = await gtfs.searchItinerary('Terray', 'Congo');
    expect(itineraries, isNotEmpty);

    final best = itineraries.first;
    expect(best.steps.length, greaterThanOrEqualTo(1));

    for (final step in best.steps) {
      if (step.lineType == 'walk') continue;
      final ctx = await gtfs.resolveLegGuidance(step);
      expect(ctx, isNotNull, reason: 'étape ${step.lineShortName} non résolue');
      expect(ctx!.boardingStop.stopName, isNotEmpty);
      expect(ctx.alightStop.stopName, isNotEmpty);
      expect(ctx.headsign, isNotEmpty);
    }
  });
}
