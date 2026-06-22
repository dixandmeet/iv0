import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/driver_report.dart';
import '../../services/driver/driver_service.dart';
import '../../services/driver/driver_report_service.dart';
import '../../services/location_service.dart';

/// Formulaire de signalement terrain.
class DriverReportScreen extends StatefulWidget {
  const DriverReportScreen({super.key});

  @override
  State<DriverReportScreen> createState() => _DriverReportScreenState();
}

class _DriverReportScreenState extends State<DriverReportScreen> {
  final _messageController = TextEditingController();
  DriverReportType? _type;
  DriverReportUrgency _urgency = DriverReportUrgency.medium;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final driverService = context.read<DriverService>();
    final reportService = context.read<DriverReportService>();
    final location = context.read<LocationService>();
    final driver = driverService.driver;
    final type = _type;

    if (driver == null || type == null) return;

    // Position GPS automatique : position du service si actif, sinon dernière connue.
    final pos = driverService.lastPosition ??
        location.currentPosition ??
        await location.updateCurrentPosition();

    final ok = await reportService.submitReport(
      driverId: driver.id,
      type: type,
      urgency: _urgency,
      message: _messageController.text,
      driverServiceId: driverService.currentService?.id,
      vehicleId: driverService.currentService?.vehicleId,
      latitude: pos?.latitude,
      longitude: pos?.longitude,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signalement envoyé')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(reportService.errorMessage ?? 'Échec de l\'envoi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitting = context.watch<DriverReportService>().submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Signalement')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Type de signalement',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: DriverReportType.values.map((t) {
              final selected = _type == t;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _type = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(t.icon,
                          size: 18,
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.label,
                            style: theme.textTheme.labelLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          Text('Niveau d\'urgence',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: DriverReportUrgency.values.map((u) {
              final selected = _urgency == u;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _urgency = u),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? u.color.withValues(alpha: 0.15)
                            : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? u.color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(u.label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: selected
                                ? u.color
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          Text('Commentaire',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Décrivez la situation (optionnel)',
            ),
          ),
          const SizedBox(height: 16),

          // Photo (plomberie prête ; capture non incluse dans le MVP)
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Ajout de photo bientôt disponible')),
              );
            },
            icon: const Icon(LucideIcons.camera),
            label: const Text('Ajouter une photo (optionnel)'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(LucideIcons.mapPin,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('Position GPS jointe automatiquement',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: (_type != null && !submitting) ? _submit : null,
            icon: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.send),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child:
                  Text('Envoyer le signalement', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
