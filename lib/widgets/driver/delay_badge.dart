import 'package:flutter/material.dart';

/// Indicateur d'avance / retard.
/// 0 = à l'heure · +N = N min de retard · -N = N min d'avance.
class DelayBadge extends StatelessWidget {
  final int minutes;
  final bool large;

  const DelayBadge({super.key, required this.minutes, this.large = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color color;
    final String label;
    if (minutes == 0) {
      color = const Color(0xFF2E7D32); // vert : à l'heure
      label = 'À l\'heure';
    } else if (minutes > 0) {
      color = const Color(0xFFC62828); // rouge : retard
      label = '+$minutes min · retard';
    } else {
      color = const Color(0xFF1565C0); // bleu : avance
      label = '$minutes min · avance';
    }

    final sign = minutes > 0 ? '+$minutes' : '$minutes';
    final display = minutes == 0 ? '0' : sign;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 12,
        vertical: large ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            display,
            style: (large
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.titleMedium)
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
