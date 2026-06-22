import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Pastille d'état de la géolocalisation conducteur.
class GpsStatusChip extends StatelessWidget {
  final bool active;
  final double? accuracy;

  const GpsStatusChip({super.key, required this.active, this.accuracy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? const Color(0xFF2E7D32) : theme.colorScheme.outline;
    final label = active
        ? (accuracy != null
            ? 'GPS actif · ±${accuracy!.round()} m'
            : 'GPS actif')
        : 'GPS inactif';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? LucideIcons.navigation : LucideIcons.navigationOff,
              size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
