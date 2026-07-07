import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/driver/driver_onboarding_service.dart';
import '../../services/driver/driver_service.dart';
import 'driver_main_shell.dart';
import 'driver_summary_screen.dart';
import 'onboarding/driver_onboarding_flow.dart';

/// Point d'entrée mode conducteur.
///
/// Ordre de priorité :
/// 1. Onboarding non complété → [DriverOnboardingFlow]
/// 2. Service terminé en attente de récapitulatif → [DriverSummaryScreen]
/// 3. Accueil principal → [DriverMainShell]
class DriverShell extends StatelessWidget {
  const DriverShell({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<DriverOnboardingService>();

    if (!onboarding.loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFEAF2EC),
      );
    }

    if (!onboarding.isComplete) {
      return const DriverOnboardingFlow();
    }

    final driver = context.watch<DriverService>();
    if (driver.completedService != null) {
      return const DriverSummaryScreen();
    }
    return const DriverMainShell();
  }
}
