import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/gtfs.dart';

/// Carte informative sur l'arrêt sélectionné.
class StopInfoCard extends StatelessWidget {
  final GtfsStop stop;
  final Color lineColor;
  final List<String> connections;

  const StopInfoCard({
    super.key,
    required this.stop,
    required this.lineColor,
    this.connections = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedText =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);

    // Uniquement des informations adossées aux données réelles : accessibilité
    // PMR (3 états GTFS) et correspondances. Pas d'équipement fabriqué.
    final details = <String>[
      stop.accessibilityLabel,
      if (connections.isNotEmpty) 'Correspondances : ${connections.join(', ')}',
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderCol),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: lineColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(LucideIcons.mapPin, color: lineColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              stop.stopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: hankenGrotesk(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: primaryText,
                              ),
                            ),
                          ),
                          if (stop.isWheelchairAccessible) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF1FE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.accessibility,
                                    size: 11,
                                    color: Color(0xFF1B66F5),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Accessible',
                                    style: hankenGrotesk(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1B66F5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details,
                        style: hankenGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: mutedText,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 18, color: mutedText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
