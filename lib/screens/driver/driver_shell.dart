import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/driver/driver_service.dart';
import 'driver_home_screen.dart';
import 'driver_line_tracking_screen.dart';
import 'driver_messages_screen.dart';
import 'driver_summary_screen.dart';

/// Conteneur du mode conducteur : navigation Accueil / Suivi / Messages,
/// bascule vers le résumé en fin de service.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverService>();

    // Fin de service : on présente le résumé en plein écran.
    if (driver.completedService != null) {
      return const DriverSummaryScreen();
    }

    final tracking =
        context.select<DriverService, bool>((d) => d.hasActiveService);

    const pages = [
      DriverHomeScreen(),
      DriverLineTrackingScreen(),
      DriverMessagesScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace conducteur'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(LucideIcons.logOut),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(LucideIcons.house),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(tracking
                ? LucideIcons.navigation
                : LucideIcons.navigationOff),
            label: 'Suivi',
          ),
          const NavigationDestination(
            icon: Icon(LucideIcons.messageCircle),
            label: 'Messages',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final driver = context.read<DriverService>();
    final auth = context.read<AuthService>();

    if (driver.hasActiveService) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Service en cours'),
          content: const Text(
              'Un service est actif. Terminez-le avant de vous déconnecter, '
              'ou déconnectez-vous quand même (le GPS sera coupé).'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Se déconnecter')),
          ],
        ),
      );
      if (ok != true) return;
    }

    await auth.signOut();
  }
}
