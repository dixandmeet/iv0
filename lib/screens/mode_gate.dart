import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user_role.dart';
import '../services/auth_service.dart';
import '../services/driver/driver_service.dart';
import 'app_shell.dart';
import 'driver/driver_shell.dart';

/// Routeur post-auth : conducteur (présence dans `drivers`) vs agent MSR vs
/// passager.
class ModeGate extends StatelessWidget {
  const ModeGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final driver = context.watch<DriverService>();

    if (auth.loading || driver.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // La table `drivers` (par e-mail) fait foi pour l'espace conducteur.
    if (driver.isDriver) {
      return const DriverShell();
    }

    switch (auth.role) {
      case AppUserRole.msrAgent:
        // Phase 4 — inbox MSR agent
        return const Scaffold(
          body: Center(child: Text('Mode agent MSR — bientôt disponible')),
        );
      default:
        return const AppShell();
    }
  }
}
