import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/driver_session_service.dart';
import '../../models/app_user_role.dart';

class DriverActiveSessionScreen extends StatelessWidget {
  const DriverActiveSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverSessionService>();
    final theme = Theme.of(context);
    final session = driver.session;

    String statusLabel;
    IconData statusIcon;
    Color statusColor;

    switch (driver.phase) {
      case DriverSessionPhase.detecting:
        statusLabel = 'Détection en cours…';
        statusIcon = Icons.radar;
        statusColor = theme.colorScheme.primary;
      case DriverSessionPhase.ambiguous:
        statusLabel = 'Confirmation requise';
        statusIcon = Icons.help_outline;
        statusColor = Colors.orange;
      case DriverSessionPhase.paused:
        statusLabel = 'Service en pause';
        statusIcon = Icons.pause_circle;
        statusColor = Colors.grey;
      case DriverSessionPhase.active:
        statusLabel = 'Service actif';
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
      default:
        statusLabel = '…';
        statusIcon = Icons.info;
        statusColor = theme.colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(statusLabel, style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (session != null) ...[
            _InfoCard(
              label: 'Ligne détectée',
              value: session.lineLabel,
              sub: session.detectionConfidence != null
                  ? 'Confiance ${session.detectionConfidence} %'
                  : null,
            ),
          ] else if (driver.phase == DriverSessionPhase.ambiguous) ...[
            _InfoCard(
              label: 'Ligne probable',
              value: driver.ambiguousLineLabel ?? '—',
              sub: driver.ambiguousConfidence != null
                  ? 'Confiance ${driver.ambiguousConfidence} % — confirmer ?'
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  context.read<DriverSessionService>().confirmAmbiguousDetection(),
              child: const Text('Confirmer cette ligne'),
            ),
          ] else ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Restez sur votre ligne. La détection démarre dès que le GPS est stable.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const Spacer(),
          if (driver.phase == DriverSessionPhase.active) ...[
            OutlinedButton.icon(
              onPressed: () => context.read<DriverSessionService>().pauseService(),
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
            ),
            const SizedBox(height: 12),
          ],
          if (driver.phase == DriverSessionPhase.paused) ...[
            FilledButton.icon(
              onPressed: () => context.read<DriverSessionService>().resumeService(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Reprendre'),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: () => context.read<DriverSessionService>().endService(),
            icon: const Icon(Icons.stop),
            label: const Text('Fin de service'),
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;

  const _InfoCard({required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
