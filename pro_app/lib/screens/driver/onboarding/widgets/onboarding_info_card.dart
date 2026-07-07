import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../theme/driver_home_palette.dart';

/// Carte d'information douce (fond vert clair) servant à expliquer une règle
/// ou à rassurer l'utilisateur. Évite qu'une étape ne paraisse vide.
class OnboardingInfoCard extends StatelessWidget {
  final String title;
  final List<String> bullets;
  final IconData icon;

  const OnboardingInfoCard({
    super.key,
    required this.title,
    this.bullets = const [],
    this.icon = LucideIcons.info,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverHomePalette.softGreen.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: DriverHomePalette.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: DriverHomePalette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: DriverHomePalette.primary,
                  ),
                ),
              ),
            ],
          ),
          if (bullets.isNotEmpty) const SizedBox(height: 10),
          for (final bullet in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Text(
                      '•  ',
                      style: TextStyle(
                        color: DriverHomePalette.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(
                        fontSize: 13,
                        color: DriverHomePalette.textSecondary,
                        height: 1.4,
                      ),
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
