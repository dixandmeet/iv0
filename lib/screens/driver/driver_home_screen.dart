import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/driver_service_record.dart';
import '../../services/driver/driver_service.dart';
import '../../widgets/driver/driver_info_tile.dart';
import '../../widgets/driver/gps_status_chip.dart';
import 'driver_report_screen.dart';
import 'driver_take_service_screen.dart';

/// Accueil conducteur : identité, statut, service du jour, état GPS et actions.
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driverService = context.watch<DriverService>();
    final driver = driverService.driver;
    final service = driverService.currentService;
    final theme = Theme.of(context);

    if (driver == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final active = driverService.hasActiveService;

    return RefreshIndicator(
      onRefresh: driverService.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // En-tête identité + statut
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(LucideIcons.userRound,
                    color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bonjour,',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    Text(
                      driver.firstNameOrFallback,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              _StatusPill(active: active, label: driver.statusLabel),
            ],
          ),
          const SizedBox(height: 20),

          // État GPS
          Align(
            alignment: Alignment.centerLeft,
            child: GpsStatusChip(
              active: driverService.gpsActive,
              accuracy: driverService.lastPosition?.accuracy,
            ),
          ),
          const SizedBox(height: 20),

          // Service du jour
          Text('Service du jour',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (service == null)
            _EmptyServiceCard(theme: theme)
          else
            _ServiceCard(service: service, active: active),

          const SizedBox(height: 28),

          // Actions principales
          if (!active)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const DriverTakeServiceScreen()),
              ),
              icon: const Icon(LucideIcons.play),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Démarrer mon service',
                    style: TextStyle(fontSize: 16)),
              ),
            )
          else ...[
            FilledButton.tonalIcon(
              onPressed: () => _confirmEnd(context, driverService),
              icon: const Icon(LucideIcons.square),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child:
                    Text('Terminer mon service', style: TextStyle(fontSize: 16)),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DriverReportScreen()),
            ),
            icon: const Icon(LucideIcons.triangleAlert),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child:
                  Text('Signaler une anomalie', style: TextStyle(fontSize: 16)),
            ),
          ),

          if (driverService.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(driverService.errorMessage!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmEnd(
      BuildContext context, DriverService driverService) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer le service ?'),
        content: const Text(
            'La géolocalisation sera arrêtée et un résumé vous sera présenté.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Terminer')),
        ],
      ),
    );
    if (ok == true) await driverService.endService();
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;
  final String label;
  const _StatusPill({required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        active ? const Color(0xFF2E7D32) : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final DriverServiceRecord service;
  final bool active;
  const _ServiceCard({required this.service, required this.active});

  @override
  Widget build(BuildContext context) {
    final start = service.startTimeReal ?? service.startTimePlanned;
    final startLabel =
        start != null ? DateFormat('HH:mm').format(start) : '—';

    return Column(
      children: [
        DriverInfoTile(
          icon: LucideIcons.busFront,
          label: 'Ligne',
          value: service.lineLabel,
        ),
        const SizedBox(height: 10),
        DriverInfoTile(
          icon: LucideIcons.arrowRight,
          label: 'Direction',
          value: service.directionLabel,
        ),
        const SizedBox(height: 10),
        DriverInfoTile(
          icon: LucideIcons.busFront,
          label: 'Véhicule',
          value: service.vehicleId?.isNotEmpty == true
              ? service.vehicleId!
              : 'Non assigné',
        ),
        const SizedBox(height: 10),
        DriverInfoTile(
          icon: LucideIcons.clock,
          label: active ? 'Prise de service' : 'Heure prévue',
          value: startLabel,
          accent: active ? const Color(0xFF2E7D32) : null,
        ),
      ],
    );
  }
}

class _EmptyServiceCard extends StatelessWidget {
  final ThemeData theme;
  const _EmptyServiceCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.calendarClock,
              size: 36, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text('Aucun service planifié aujourd\'hui',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Vous pouvez démarrer un service manuellement ci-dessous.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
