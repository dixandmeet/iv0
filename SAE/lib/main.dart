import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell.dart';
import 'config/backend_config.dart';
import 'services/transport_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  await Supabase.initialize(
    url: BackendConfig.supabaseUrl,
    publishableKey: BackendConfig.supabasePublishableKey,
  );
  runApp(SaeApp(repository: TransportRepository()));
}

class SaeApp extends StatelessWidget {
  final TransportDataSource repository;
  const SaeApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aule Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: AppShell(repository: repository),
    );
  }
}
