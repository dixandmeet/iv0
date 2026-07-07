import 'package:flutter/material.dart';

import '../../../../models/driver/driver_onboarding_data.dart';
import '../../../../theme/driver_home_palette.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_option_card.dart';

/// Écran — Zone d'activité (parcours « VTC / Taxi »).
///
/// Pensé pour s'étendre facilement à plusieurs villes / régions.
class ZoneStep extends StatelessWidget {
  final ActivityZone? selected;
  final ValueChanged<ActivityZone> onSelected;

  const ZoneStep({
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
            title: 'Votre zone\nd\'activité',
            subtitle: 'Sélectionnez la zone où vous exercez principalement.',
          ),
          const SizedBox(height: 28),
          for (final zone in ActivityZone.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingOptionCard(
                emoji: '📍',
                title: zone.label,
                subtitle: zone.description,
                isSelected: selected == zone,
                onTap: () => onSelected(zone),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "De nouvelles villes et régions arrivent bientôt.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: DriverHomePalette.textSecondary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
