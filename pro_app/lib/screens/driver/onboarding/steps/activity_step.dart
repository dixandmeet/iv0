import 'package:flutter/material.dart';

import '../../../../models/driver/driver_onboarding_data.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_option_card.dart';

/// Écran 2 — Votre activité.
///
/// Le choix du profil détermine automatiquement la suite du parcours.
class ActivityStep extends StatelessWidget {
  final ProProfile? selected;
  final ValueChanged<ProProfile> onSelected;

  const ActivityStep({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingHeader(
            title: 'Quelle est votre\nactivité ?',
            subtitle:
                'Sélectionnez le profil qui correspond à votre activité principale.',
          ),
          const SizedBox(height: 28),
          for (final profile in ProProfile.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingOptionCard(
                emoji: profile.emoji,
                title: profile.label,
                subtitle: profile.description,
                isSelected: selected == profile,
                onTap: () => onSelected(profile),
              ),
            ),
        ],
      ),
    );
  }
}
