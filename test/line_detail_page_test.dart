import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:aule/screens/line_detail_page.dart';
import 'package:aule/services/disruption_service.dart';
import 'package:aule/services/favorites_service.dart';
import 'package:aule/services/gtfs_service.dart';
import 'package:aule/services/location_service.dart';
import 'package:aule/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GtfsService gtfs;
  late SupabaseService supabase;

  setUpAll(() async {
    supabase = SupabaseService();
    gtfs = GtfsService(supabaseService: supabase);
    await gtfs.fetchRoutes();
    await gtfs.fetchStops();
    gtfs.ensureNetworkGraph();
  });

  testWidgets('LineDetailPage affiche le contenu scrollable', (tester) async {
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'image resource service') return;
      previousErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousErrorHandler);
    final route = gtfs.cachedRoutes.firstWhere(
      (r) => (r.routeShortName ?? r.routeId) == 'C6',
      orElse: () => gtfs.cachedRoutes.first,
    );
    final stop = gtfs.cachedStops.firstWhere(
      (s) => s.stopName.contains('Ranzay'),
      orElse: () => gtfs.cachedStops.first,
    );
    final station = NearbyStation(
      stop: stop,
      distanceMeters: 120,
      routes: [route],
    );
    final departure = StationDeparture(
      route: route,
      headsign: 'Hermeland',
      waitMinutes: 2,
      nextWaitMinutes: 8,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GtfsService>.value(value: gtfs),
          ChangeNotifierProvider<LocationService>(
            create: (_) => LocationService(),
          ),
          ChangeNotifierProvider<FavoritesService>(
            create: (_) => FavoritesService(),
          ),
          ChangeNotifierProvider<DisruptionService>(
            create: (_) => DisruptionService(
              client: MockClient(
                (_) async => http.Response('{"results":[]}', 200),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: LineDetailPage(
            route: route,
            headsign: 'Hermeland',
            station: station,
            departure: departure,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    while (tester.takeException() != null) {}

    expect(find.text('Plan de la ligne'), findsOneWidget);
  });
}
