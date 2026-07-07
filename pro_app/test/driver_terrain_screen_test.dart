// Tests responsive de l'écran « Terrain » refactoré.

import 'package:aule_pro/screens/driver/driver_terrain_screen.dart';
import 'package:aule_pro/services/auth_service.dart';
import 'package:aule_pro/services/driver/driver_service.dart';
import 'package:aule_pro/services/driver/driver_onboarding_service.dart';
import 'package:aule_pro/services/driver/driver_workspace_service.dart';
import 'package:aule_pro/services/driver/control_plan_service.dart';
import 'package:aule_pro/services/gtfs_service.dart';
import 'package:aule_pro/services/location_service.dart';
import 'package:aule_pro/services/msr/msr_mission_service.dart';
import 'package:aule_pro/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Widget harness() {
    final supabase = SupabaseService();
    final location = LocationService();
    final auth = AuthService(supabaseService: supabase);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SupabaseService>.value(value: supabase),
        ChangeNotifierProvider<LocationService>.value(value: location),
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<DriverOnboardingService>(
          create: (_) =>
              DriverOnboardingService(supabaseService: supabase)..load(),
        ),
        ChangeNotifierProvider<ControlPlanService>(
          create: (_) => ControlPlanService(supabaseService: supabase),
        ),
        ChangeNotifierProvider<MsrMissionService>(
          create: (_) => MsrMissionService(supabaseService: supabase),
        ),
        ChangeNotifierProvider<DriverWorkspaceService>(
          create: (_) => DriverWorkspaceService()..load(),
        ),
        ChangeNotifierProxyProvider<SupabaseService, GtfsService>(
          create: (_) => GtfsService(supabaseService: supabase),
          update: (_, supabase, previous) =>
              previous ?? GtfsService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider2<
          SupabaseService,
          AuthService,
          DriverService
        >(
          create: (_) => DriverService(
            supabaseService: supabase,
            authService: auth,
            locationService: location,
          ),
          update: (_, supabase, authService, previous) =>
              previous ??
              DriverService(
                supabaseService: supabase,
                authService: authService,
                locationService: location,
              ),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: DriverTerrainScreen())),
    );
  }

  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 900));
  }

  const sizes = <Size>[Size(320, 640), Size(393, 852), Size(820, 1180)];

  for (final size in sizes) {
    testWidgets(
      'Terrain : ni overflow ni exception en ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(harness());
        await pumpFrames(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Terrain'), findsOneWidget);
        expect(find.text('Véhicules autour de vous'), findsOneWidget);
        expect(find.text('Assistance'), findsWidgets);
      },
    );
  }

  testWidgets('Changer de filtre ne lève pas d\'exception', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(harness());
    await pumpFrames(tester);

    await tester.tap(find.text('Bus'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Tram'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });
}
