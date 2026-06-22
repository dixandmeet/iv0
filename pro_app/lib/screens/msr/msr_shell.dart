import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import 'msr_missions_screen.dart';
import 'msr_profile_screen.dart';

/// Conteneur de l'espace agent MSR : navigation Missions / Profil.
/// Scaffold de la séparation des apps — la logique métier (prise/fin de
/// mission, zones, équipes, contrôle terrain) sera branchée au lot MSR.
class MsrShell extends StatefulWidget {
  const MsrShell({super.key});

  @override
  State<MsrShell> createState() => _MsrShellState();
}

class _MsrShellState extends State<MsrShell> {
  int _index = 0;

  static const _pages = [
    MsrMissionsScreen(),
    MsrProfileScreen(),
  ];

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthService>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aule Pro · MSR'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(LucideIcons.logOut),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.clipboardList),
            label: 'Missions',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.userRound),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
