import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

/// Profil de l'agent MSR (scaffold).
class MsrProfileScreen extends StatelessWidget {
  const MsrProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF1B66F5),
            child: const Icon(LucideIcons.userRound,
                color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            auth.displayName ?? 'Agent MSR',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (auth.email != null)
          Center(child: Text(auth.email!)),
        const SizedBox(height: 8),
        const Center(child: Chip(label: Text('Agent MSR'))),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(LucideIcons.logOut),
          title: const Text('Se déconnecter'),
          onTap: () => context.read<AuthService>().signOut(),
        ),
      ],
    );
  }
}
