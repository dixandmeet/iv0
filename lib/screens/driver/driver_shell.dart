import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user_role.dart';
import '../../services/auth_service.dart';
import '../../services/driver_session_service.dart';
import 'driver_active_session_screen.dart';
import 'driver_home_screen.dart';
import 'driver_session_summary_screen.dart';

class DriverShell extends StatelessWidget {
  const DriverShell({super.key});

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverSessionService>();

    Widget body;
    switch (driver.phase) {
      case DriverSessionPhase.ended:
        body = const DriverSessionSummaryScreen();
      case DriverSessionPhase.idle:
        body = const DriverHomeScreen();
      default:
        body = const DriverActiveSessionScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode conducteur'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final driverService = context.read<DriverSessionService>();
              final authService = context.read<AuthService>();
              await driverService.endService();
              driverService.resetToIdle();
              await authService.signOut();
            },
          ),
        ],
      ),
      body: body,
    );
  }
}
