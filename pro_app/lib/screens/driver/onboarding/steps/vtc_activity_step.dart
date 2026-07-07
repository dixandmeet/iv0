import 'package:flutter/material.dart';

import '../../../../models/driver/driver_onboarding_data.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_option_card.dart';

/// Écran — Type d'activité (parcours « VTC / Taxi »).
class VtcActivityStep extends StatelessWidget {
  final VtcActivity? selected;
  final ValueChanged<VtcActivity> onSelected;

  const VtcActivityStep({
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
            title: 'Quel est votre\ntype d\'activité ?',
            subtitle: 'Sélectionnez votre statut de transport individuel.',
          ),
          const SizedBox(height: 28),
          for (final activity in VtcActivity.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingOptionCard(
                emoji: activity.emoji,
                title: activity.label,
                subtitle: activity.description,
                isSelected: selected == activity,
                onTap: () => onSelected(activity),
              ),
            ),
        ],
      ),
    );
  }
}
