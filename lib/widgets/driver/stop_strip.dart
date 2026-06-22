import 'package:flutter/material.dart';

import '../../models/gtfs.dart';

/// Frise horizontale des arrêts d'une ligne. L'arrêt courant ([currentIndex])
/// et ceux déjà passés sont distingués des arrêts à venir.
class StopStrip extends StatelessWidget {
  final List<GtfsStop> stops;
  final int currentIndex;

  const StopStrip({
    super.key,
    required this.stops,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (stops.isEmpty) {
      return Container(
        height: 96,
        alignment: Alignment.center,
        child: Text(
          'Tracé d\'arrêts indisponible pour cette ligne',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: stops.length,
        itemBuilder: (context, i) {
          final passed = i < currentIndex;
          final isCurrent = i == currentIndex;
          final color = isCurrent
              ? theme.colorScheme.primary
              : passed
                  ? theme.colorScheme.outlineVariant
                  : theme.colorScheme.onSurfaceVariant;

          return SizedBox(
            width: 92,
            child: Column(
              children: [
                // Ligne + pastille
                SizedBox(
                  height: 24,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 3,
                          color: i == 0
                              ? Colors.transparent
                              : (passed || isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant),
                        ),
                      ),
                      Container(
                        width: isCurrent ? 16 : 11,
                        height: isCurrent ? 16 : 11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : passed
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.5)
                                  : theme.colorScheme.surface,
                          border: Border.all(
                            color: passed || isCurrent
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                            width: 2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 3,
                          color: i == stops.length - 1
                              ? Colors.transparent
                              : (passed
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    stops[i].stopName,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
