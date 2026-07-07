import 'package:flutter/material.dart';

import '../../../../models/driver/driver_onboarding_data.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_info_card.dart';
import '../widgets/onboarding_option_card.dart';

/// Écran — Habilitations (parcours « Agent du réseau »).
///
/// L'interface empêche naturellement toutes les combinaisons interdites :
/// les cartes qui mèneraient à une sélection invalide sont grisées et
/// non cliquables. Aucun message d'erreur n'est affiché.
class HabilitationsStep extends StatelessWidget {
  final Set<DriverHabilitation> selected;
  final ValueChanged<Set<DriverHabilitation>> onChanged;

  const HabilitationsStep({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// Une carte est désactivée si l'ajouter à la sélection courante donnerait
  /// une combinaison interdite.
  bool _isDisabled(DriverHabilitation candidate) {
    if (selected.contains(candidate)) return false;
    return !DriverOnboardingData.isHabilitationSetValid({
      ...selected,
      candidate,
    });
  }

  void _toggle(DriverHabilitation hab) {
    final next = Set<DriverHabilitation>.from(selected);
    if (selected.contains(hab)) {
      next.remove(hab);
    } else {
      if (!DriverOnboardingData.isHabilitationSetValid({...selected, hab})) {
        return;
      }
      next.add(hab);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingHeader(
            title: 'Vos habilitations',
            subtitle:
                'Sélectionnez les habilitations correspondant à vos missions.',
          ),
          const SizedBox(height: 24),
          for (final hab in DriverHabilitation.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingOptionCard(
                emoji: hab.emoji,
                title: hab.label,
                subtitle: hab.description,
                isSelected: selected.contains(hab),
                isDisabled: _isDisabled(hab),
                selectionStyle: OnboardingSelectionStyle.checkbox,
                onTap: () => _toggle(hab),
              ),
            ),
          const SizedBox(height: 4),
          const OnboardingInfoCard(
            title: 'Règles de sélection',
            bullets: [
              'Une seule habilitation est sélectionnable par défaut.',
              'Conduite peut être associée uniquement à Contrôle ou Intervention.',
              'UMTC est exclusive.',
            ],
          ),
        ],
      ),
    );
  }
}
