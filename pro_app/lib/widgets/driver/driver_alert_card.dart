import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/driver_home_palette.dart';

/// Niveau de gravité d'un message important affiché sur l'accueil.
enum DriverAlertLevel { danger, warning, info }

/// Une alerte / message important (déviation, incident…).
class DriverAlert {
  final String title;
  final String subtitle;
  final String time;
  final DriverAlertLevel level;

  const DriverAlert({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.level,
  });

  Color get color => switch (level) {
        DriverAlertLevel.danger => DriverHomePalette.danger,
        DriverAlertLevel.warning => DriverHomePalette.warning,
        DriverAlertLevel.info => DriverHomePalette.blue,
      };
}

/// Une ligne d'alerte : icône colorée à gauche, titre + sous-titre, heure à
/// droite. Conçue pour être empilée dans une carte blanche.
class DriverAlertCard extends StatelessWidget {
  final DriverAlert alert;
  final VoidCallback? onTap;

  const DriverAlertCard({super.key, required this.alert, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: alert.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(LucideIcons.triangleAlert, size: 19, color: alert.color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DriverHomePalette.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DriverHomePalette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              alert.time,
              style: const TextStyle(
                color: DriverHomePalette.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
