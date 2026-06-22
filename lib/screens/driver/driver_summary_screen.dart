import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../services/driver/driver_service.dart';
import '../../widgets/driver/driver_info_tile.dart';

/// Résumé présenté à la fin d'un service.
class DriverSummaryScreen extends StatelessWidget {
  const DriverSummaryScreen({super.key});

  String _fmtTime(DateTime? d) => d != null ? DateFormat('HH:mm').format(d) : '—';

  String _fmtDuration(Duration? d) {
    if (d == null) return '—';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '$m min';
  }

  @override
  Widget build(BuildContext context) {
    final driverService = context.watch<DriverService>();
    final service = driverService.completedService;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: service == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                      ),
                      child: const Icon(LucideIcons.circleCheckBig,
                          size: 48, color: Color(0xFF2E7D32)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text('Service terminé',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text('Merci, bonne fin de journée.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 32),

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
                  Row(
                    children: [
                      Expanded(
                        child: DriverInfoTile(
                          icon: LucideIcons.play,
                          label: 'Début',
                          value: _fmtTime(service.startTimeReal),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DriverInfoTile(
                          icon: LucideIcons.square,
                          label: 'Fin',
                          value: _fmtTime(service.endTimeReal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DriverInfoTile(
                    icon: LucideIcons.timer,
                    label: 'Durée du service',
                    value: _fmtDuration(service.realDuration),
                    accent: const Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 36),

                  FilledButton(
                    onPressed: () => driverService.clearCompletedSummary(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Retour à l\'accueil',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
