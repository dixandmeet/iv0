import 'package:flutter/material.dart';

import '../../../../models/driver/driver_onboarding_data.dart';
import '../../../../theme/driver_home_palette.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_option_card.dart';

/// Écran — Dépôt de rattachement (parcours « Agent du réseau »).
///
/// Le dépôt sert au rapprochement des demandes de changement / remplacement
/// de service : on persiste son code métier (BLX / TTX / SHX).
class DepotStep extends StatelessWidget {
  final DriverDepot? selected;
  final ValueChanged<DriverDepot> onSelected;

  const DepotStep({
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
            title: 'À quel dépôt\nêtes-vous rattaché ?',
            subtitle:
                'Votre dépôt facilite le rapprochement lors des demandes de '
                'changement ou de remplacement de service.',
          ),
          const SizedBox(height: 28),
          for (final depot in DriverDepot.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingOptionCard(
                emoji: '🏠',
                title: depot.label,
                subtitle: depot.description,
                isSelected: selected == depot,
                onTap: () => onSelected(depot),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "D'autres dépôts seront disponibles prochainement.",
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
