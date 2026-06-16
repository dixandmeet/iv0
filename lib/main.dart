import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'services/location_service.dart';
import 'services/passive_tracking_service.dart';
import 'services/gtfs_service.dart';
import 'services/vehicle_detection_service.dart';
import 'services/report_service.dart';
import 'services/map_service.dart';
import 'services/aule_theme_service.dart';
import 'services/auth_service.dart';
import 'services/favorites_service.dart';
import 'services/driver_session_service.dart';
import 'theme/aule_theme.dart';
import 'screens/mode_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation des services Core
  final supabaseService = SupabaseService();
  await supabaseService.initialize();

  final locationService = LocationService();
  try {
    await locationService.initialize();
  } catch (e) {
    debugPrint('Wazibus: Location init failed ($e). Continuing without GPS.');
  }

  final passiveTrackingService = PassiveTrackingService(
    supabaseService: supabaseService,
    locationService: locationService,
  );

  // Si l'utilisateur a déjà donné son accord, on relance le suivi passif automatiquement au démarrage
  if (supabaseService.consentBackground) {
    await passiveTrackingService.startTracking();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: supabaseService),
        ChangeNotifierProvider.value(value: locationService),
        ChangeNotifierProvider.value(value: passiveTrackingService),
        ChangeNotifierProxyProvider<SupabaseService, GtfsService>(
          create: (context) => GtfsService(supabaseService: supabaseService),
          update: (context, supabase, previous) => GtfsService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider<SupabaseService, VehicleDetectionService>(
          create: (context) => VehicleDetectionService(supabaseService: supabaseService),
          update: (context, supabase, previous) => VehicleDetectionService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider<SupabaseService, ReportService>(
          create: (context) => ReportService(supabaseService: supabaseService),
          update: (context, supabase, previous) => ReportService(supabaseService: supabase),
        ),
        ChangeNotifierProvider(create: (_) => MapService()),
        ChangeNotifierProvider(create: (_) => AuleThemeService()),
        ChangeNotifierProvider(create: (_) => FavoritesService()..load()),
        ChangeNotifierProvider(create: (_) => AuleClock()),
        ChangeNotifierProxyProvider<SupabaseService, AuthService>(
          create: (context) => AuthService(
            supabaseService: context.read<SupabaseService>(),
          ),
          update: (context, supabase, previous) =>
              previous ?? AuthService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider2<SupabaseService, AuthService,
            DriverSessionService>(
          create: (context) => DriverSessionService(
            supabaseService: context.read<SupabaseService>(),
            authService: context.read<AuthService>(),
            locationService: context.read<LocationService>(),
          ),
          update: (context, supabase, auth, previous) =>
              previous ??
              DriverSessionService(
                supabaseService: supabase,
                authService: auth,
                locationService: context.read<LocationService>(),
              ),
        ),
      ],
      child: const WazibusApp(),
    ),
  );
}

class WazibusApp extends StatelessWidget {
  const WazibusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuleThemeService>(
      builder: (context, themeService, _) {
        return MaterialApp(
          title: 'Aule',
          debugShowCheckedModeBanner: false,
          theme: buildAuleTheme(isDark: false),
          darkTheme: buildAuleTheme(isDark: true),
          themeMode: themeService.mode,
          home: const ModeGate(),
        );
      },
    );
  }
}
