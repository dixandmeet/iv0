import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/driver_session_service.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverSessionService>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Icon(Icons.directions_bus_filled, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Prise de service',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Appuyez pour démarrer. L\'application détectera automatiquement votre ligne et votre sens à partir du GPS.',
            style: theme.textTheme.bodyLarge,
          ),
          if (driver.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(driver.errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: () => context.read<DriverSessionService>().startTakeService(),
            icon: const Icon(Icons.play_arrow),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Prendre mon service', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
