import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

import '../../models/aule_models.dart';
import '../../theme/aule_theme.dart';
import 'aule_icons.dart';
import 'departure_row.dart';

/// Carte riche pour un arrêt à proximité.
class StopCard extends StatelessWidget {
  final AuleStopData stop;
  final DateTime now;

  const StopCard({
    super.key,
    required this.stop,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(AuleTokens.rCard),
        boxShadow: AuleTokens.cardShadow(c.shadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: hankenGrotesk(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: c.text,
                  ),
                ),
              ),
              if (stop.accessible) ...[
                const SizedBox(width: 9),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: c.brandWeak,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: AuleIcons.accessibility(
                    size: 14,
                    color: c.brand,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AuleIcons.walk(size: 13, color: c.muted),
                const SizedBox(width: 5),
                Text(
                  '${stop.distance} · ${stop.walkTime}',
                  style: hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...stop.lines.map(
            (l) => StopDepartureRow(departure: l, now: now),
          ),
        ],
      ),
    );
  }
}
