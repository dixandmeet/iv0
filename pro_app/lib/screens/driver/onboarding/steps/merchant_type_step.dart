import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../models/driver/driver_onboarding_data.dart';
import '../../../../theme/driver_home_palette.dart';
import '../widgets/onboarding_header.dart';

/// Écran — Type de commerce (parcours « Commerçant »).
///
/// Grille de cartes premium ; une seule sélection.
class MerchantTypeStep extends StatelessWidget {
  final MerchantType? selected;
  final ValueChanged<MerchantType> onSelected;

  const MerchantTypeStep({
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
            title: 'Quel est votre\ntype de commerce ?',
            subtitle: 'Sélectionnez la catégorie de votre établissement.',
          ),
          const SizedBox(height: 28),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              for (final type in MerchantType.values)
                _MerchantTypeCard(
                  type: type,
                  isSelected: selected == type,
                  onTap: () => onSelected(type),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MerchantTypeCard extends StatelessWidget {
  final MerchantType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _MerchantTypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? DriverHomePalette.lightGreen : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isSelected ? DriverHomePalette.primary : DriverHomePalette.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? DriverHomePalette.primary.withValues(alpha: 0.14)
                : DriverHomePalette.cardShadow,
            blurRadius: isSelected ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(height: 10),
                    Text(
                      type.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: isSelected
                            ? DriverHomePalette.primary
                            : DriverHomePalette.textDark,
                      ),
                    ),
                  ],
                ),
                if (isSelected)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      LucideIcons.circleCheck,
                      color: DriverHomePalette.primary,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
