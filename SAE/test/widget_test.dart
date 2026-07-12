import 'package:flutter_test/flutter_test.dart';

import 'package:sae/main.dart';
import 'package:sae/models/fleet_vehicle.dart';
import 'package:sae/models/line.dart';
import 'package:sae/models/naolib_feed.dart';
import 'package:sae/models/route_data.dart';
import 'package:sae/models/transport_mode.dart';
import 'package:sae/services/transport_repository.dart';
import 'package:sae/widgets/splash_overlay.dart';

class _FakeTransportDataSource implements TransportDataSource {
  static final _feed = NaolibFeedInfo(
    validFrom: DateTime(2026, 6, 22),
    validUntil: DateTime(2026, 8, 30),
    downloadUrl: Uri.parse('https://example.test/gtfs.zip'),
    filename: 'gtfs.zip',
  );

  @override
  NaolibFeedInfo? get feedInfo => _feed;

  @override
  Future<NaolibFeedInfo> fetchFeedInfo() async => _feed;

  @override
  Future<List<BusLine>> fetchLines({bool refresh = false}) async => const [
    BusLine(
      key: 'C6',
      mode: TransportMode.bus,
      label: 'C6',
      desc: 'Hermeland - Chantrerie',
      directions: [
        LineDirection(key: '0', label: '→ Hermeland'),
        LineDirection(key: '1', label: '→ Chantrerie'),
      ],
    ),
  ];

  @override
  Future<List<FleetVehicle>> fetchFleet() async => const [];

  @override
  Future<RouteJourney> fetchJourney(
    BusLine line,
    LineDirection direction,
  ) async => throw UnimplementedError();
}

void main() {
  testWidgets('affiche le splash puis le démonte automatiquement', (
    tester,
  ) async {
    await tester.pumpWidget(SaeApp(repository: _FakeTransportDataSource()));

    expect(find.text("L'app des agents de terrain"), findsOneWidget);
    expect(find.byType(SplashOverlay), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1850));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(SplashOverlay), findsNothing);
    expect(find.text('Agent Naolib'), findsOneWidget);
  });

  testWidgets('le retour système respecte les étapes de prise de service', (
    tester,
  ) async {
    await tester.pumpWidget(SaeApp(repository: _FakeTransportDataSource()));
    await tester.pump(const Duration(milliseconds: 1850));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Prendre mon service'));
    await tester.pumpAndSettle();
    expect(find.text('Quelle ligne ?'), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('C6'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Quel sens ?'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Quelle ligne ?'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Agent Naolib'), findsOneWidget);
  });
}
