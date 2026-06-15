import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user_role.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';
import 'driver/driver_shell.dart';

/// Routeur post-auth : passager vs conducteur / agent MSR.
class ModeGate extends StatelessWidget {
  const ModeGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (auth.role) {
      case AppUserRole.driver:
        return const DriverShell();
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
