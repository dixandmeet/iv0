import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'services/supabase_service.dart';
import 'services/location_service.dart';
import 'services/gtfs_service.dart';
import 'services/auth_service.dart';
import 'services/driver/driver_service.dart';
import 'services/driver/driver_report_service.dart';
import 'services/driver/driver_message_service.dart';
import 'screens/pro_root.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  final supabaseService = SupabaseService();
  await supabaseService.initialize();

  final locationService = LocationService();
  try {
    await locationService.initialize();
  } catch (e) {
    debugPrint('Aule Pro: Location init failed ($e). Continuing without GPS.');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: supabaseService),
        ChangeNotifierProvider.value(value: locationService),
        ChangeNotifierProxyProvider<SupabaseService, GtfsService>(
          create: (context) => GtfsService(supabaseService: supabaseService),
          update: (context, supabase, previous) =>
              previous ?? GtfsService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider<SupabaseService, AuthService>(
          create: (context) => AuthService(
            supabaseService: context.read<SupabaseService>(),
          ),
          update: (context, supabase, previous) =>
              previous ?? AuthService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider2<SupabaseService, AuthService,
            DriverService>(
          create: (context) => DriverService(
            supabaseService: context.read<SupabaseService>(),
            authService: context.read<AuthService>(),
            locationService: context.read<LocationService>(),
          ),
          update: (context, supabase, auth, previous) {
            final service = previous ??
                DriverService(
                  supabaseService: supabase,
                  authService: auth,
                  locationService: context.read<LocationService>(),
                );
            service.syncWithAuth(auth);
            return service;
          },
        ),
        ChangeNotifierProxyProvider<SupabaseService, DriverReportService>(
          create: (context) =>
              DriverReportService(supabaseService: supabaseService),
          update: (context, supabase, previous) =>
              previous ?? DriverReportService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider<SupabaseService, DriverMessageService>(
          create: (context) =>
              DriverMessageService(supabaseService: supabaseService),
          update: (context, supabase, previous) =>
              previous ?? DriverMessageService(supabaseService: supabase),
        ),
      ],
      child: const AuleProApp(),
    ),
  );
}

class AuleProApp extends StatelessWidget {
  const AuleProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aule Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B66F5)),
        useMaterial3: true,
      ),
      home: const ProRoot(),
    );
  }
}
