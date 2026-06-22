import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

import '../../models/aule_models.dart';
import '../../theme/aule_theme.dart';
import 'line_badge.dart';

/// Carte d'alerte trafic avec bord gauche coloré.
class AlertCard extends StatelessWidget {
  final AuleAlertData alert;

  const AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    final color = AuleLineColors.forLine(alert.line);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 22,
            offset: const Offset(0, 8),
            spreadRadius: -18,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 52,
            margin: const EdgeInsets.only(right: 13),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          LineBadge.small(label: alert.line, mode: alert.mode),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.type.toUpperCase(),
                  style: hankenGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.text,
                  style: hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: c.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
