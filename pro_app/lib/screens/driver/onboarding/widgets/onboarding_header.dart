import 'package:flutter/material.dart';

import '../../../../theme/driver_home_palette.dart';

/// Titre + sous-titre standard d'une étape d'onboarding.
///
/// Animé à l'entrée (fondu + léger glissement) pour des transitions fluides.
class OnboardingHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const OnboardingHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: DriverHomePalette.textDark,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            color: DriverHomePalette.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
