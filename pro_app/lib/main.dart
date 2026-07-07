import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'services/supabase_service.dart';
import 'services/location_service.dart';
import 'services/gtfs_service.dart';
import 'services/auth_service.dart';
import 'services/driver/driver_service.dart';
import 'services/driver/driver_onboarding_service.dart';
import 'services/driver/driver_settings_service.dart';
import 'services/driver/driver_workspace_service.dart';
import 'services/driver/driver_report_service.dart';
import 'services/platform/discussion_service.dart';
import 'services/platform/conversation_context_service.dart';
import 'services/platform/hub_engine.dart';
import 'services/platform/local_notification_service.dart';
import 'services/platform/resource_service.dart';
import 'services/driver/feed_service.dart';
import 'services/driver/control_team_service.dart';
import 'services/driver/control_plan_service.dart';
import 'services/driver/mission_event_bus.dart';
import 'services/driver/mission_notification_service.dart';
import 'services/driver/control_presence_service.dart';
import 'services/driver/service_exchange_service.dart';
import 'services/msr/msr_mission_service.dart';
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

  final localNotificationService = LocalNotificationService();
  try {
    await localNotificationService.init();
  } catch (e) {
    debugPrint('Aule Pro: notifications init failed ($e).');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: supabaseService),
        ChangeNotifierProvider.value(value: locationService),
        Provider<LocalNotificationService>.value(
          value: localNotificationService,
        ),
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
        ChangeNotifierProvider(
          create: (context) => DriverOnboardingService(
            supabaseService: context.read<SupabaseService>(),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => DriverSettingsService()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => DriverWorkspaceService()..load(),
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
        ChangeNotifierProxyProvider<SupabaseService, DiscussionService>(
          create: (context) =>
              DiscussionService(supabaseService: supabaseService),
          update: (context, supabase, previous) =>
              previous ?? DiscussionService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider<SupabaseService,
            ConversationContextService>(
          create: (context) =>
              ConversationContextService(supabaseService: supabaseService),
          update: (context, supabase, previous) =>
              previous ??
              ConversationContextService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider<SupabaseService, ServiceExchangeService>(
          create: (context) =>
              ServiceExchangeService(supabaseService: supabaseService),
          update: (context, supabase, previous) =>
              previous ?? ServiceExchangeService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider<SupabaseService, HubEngine>(
          create: (context) => HubEngine(supabaseService: supabaseService),
          update: (context, supabase, previous) =>
              previous ?? HubEngine(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider<SupabaseService, ResourceService>(
          create: (context) =>
              ResourceService(supabaseService: supabaseService),
          update: (context, supabase, previous) =>
              previous ?? ResourceService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider<SupabaseService, FeedService>(
          create: (context) => FeedService(supabaseService: supabaseService),
          update: (context, supabase, previous) =>
              previous ?? FeedService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider<SupabaseService, ControlTeamService>(
          create: (context) =>
              ControlTeamService(supabaseService: supabaseService),
          update: (context, supabase, previous) =>
              previous ?? ControlTeamService(supabaseService: supabase),
        ),
        ChangeNotifierProvider(create: (_) => MissionEventBus()),
        ChangeNotifierProxyProvider2<SupabaseService, MissionEventBus,
            ControlPlanService>(
          create: (context) => ControlPlanService(
            supabaseService: context.read<SupabaseService>(),
            eventBus: context.read<MissionEventBus>(),
          ),
          update: (context, supabase, bus, previous) =>
              previous ??
              ControlPlanService(
                supabaseService: supabase,
                eventBus: bus,
              ),
        ),
        Provider<MissionNotificationService>(
          create: (context) => MissionNotificationService(
            bus: context.read<MissionEventBus>(),
          ),
          dispose: (_, service) => service.dispose(),
        ),
        ProxyProvider2<ControlPlanService, LocationService,
            ControlPresenceService>(
          update: (context, plan, location, previous) =>
              previous ??
              ControlPresenceService(
                planService: plan,
                locationService: location,
              ),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProxyProvider<SupabaseService, MsrMissionService>(
          create: (context) =>
              MsrMissionService(supabaseService: supabaseService),
          update: (context, supabase, previous) =>
              previous ?? MsrMissionService(supabaseService: supabase),
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
      locale: const Locale('fr', 'FR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        // Primary de la charte officielle Aule Pro (docs/brand/README.md)
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E8D82)),
        useMaterial3: true,
      ),
      home: const ProRoot(),
    );
  }
}
