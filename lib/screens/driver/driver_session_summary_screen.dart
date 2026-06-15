import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/driver_session_service.dart';

class DriverSessionSummaryScreen extends StatelessWidget {
  const DriverSessionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverSessionService>();
    final session = driver.session;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.flag_circle, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Service terminé',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (session != null) ...[
            const SizedBox(height: 16),
            Text(session.lineLabel, style: theme.textTheme.titleLarge),
            Text(
              'Démarré à ${TimeOfDay.fromDateTime(session.startedAt).format(context)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const Spacer(),
          FilledButton(
            onPressed: () => context.read<DriverSessionService>().resetToIdle(),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}
