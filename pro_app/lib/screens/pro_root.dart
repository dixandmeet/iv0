import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import '../services/driver/driver_service.dart';
import 'driver/driver_shell.dart';
import 'msr/msr_shell.dart';
import 'pro_login_screen.dart';

/// Racine de l'app Pro : gère la connexion puis route selon le rôle.
///
/// - non connecté → [ProLoginScreen]
/// - conducteur (présent dans `drivers`) → [DriverShell]
/// - agent MSR → espace MSR (scaffold, lot suivant)
/// - autre → accès refusé (compte non professionnel)
class ProRoot extends StatelessWidget {
  const ProRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!auth.isSignedIn) {
      return const ProLoginScreen();
    }

    final driver = context.watch<DriverService>();
    if (driver.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // La table `drivers` (par e-mail) fait foi pour l'espace conducteur.
    if (driver.isDriver) {
      return const DriverShell();
    }

    switch (auth.role) {
      case AppUserRole.msrAgent:
        return const MsrShell();
      default:
        return const _ProPlaceholder(
          title: 'Accès refusé',
          message: 'Ce compte n\'est pas autorisé sur Aule Pro.',
          showSignOut: true,
        );
    }
  }
}

class _ProPlaceholder extends StatelessWidget {
  final String title;
  final String message;
  final bool showSignOut;

  const _ProPlaceholder({
    required this.title,
    required this.message,
    this.showSignOut = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(message, textAlign: TextAlign.center),
            ),
            if (showSignOut)
              TextButton(
                onPressed: () => context.read<AuthService>().signOut(),
                child: const Text('Se déconnecter'),
              ),
          ],
        ),
      ),
    );
  }
}
