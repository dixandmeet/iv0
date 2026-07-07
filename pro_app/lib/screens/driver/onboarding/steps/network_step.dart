import 'package:flutter/material.dart';

import '../../../../models/driver/driver_onboarding_data.dart';
import '../../../../theme/driver_home_palette.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_option_card.dart';

/// Écran 3 — Réseau de transport (parcours « Agent du réseau »).
class NetworkStep extends StatelessWidget {
  final TransportNetwork? selected;
  final ValueChanged<TransportNetwork> onSelected;

  const NetworkStep({
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
            title: 'À quel réseau\nêtes-vous rattaché ?',
            subtitle: 'Sélectionnez votre réseau de transport.',
          ),
          const SizedBox(height: 28),
          for (final network in TransportNetwork.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingOptionCard(
                emoji: '🚌',
                title: network.label,
                subtitle: network.description,
                isSelected: selected == network,
                onTap: () => onSelected(network),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "D'autres réseaux seront disponibles prochainement.",
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
