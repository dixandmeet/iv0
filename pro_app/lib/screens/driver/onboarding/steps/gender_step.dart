import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../models/driver/driver_onboarding_data.dart';
import '../../../../theme/driver_home_palette.dart';
import '../widgets/onboarding_header.dart';

/// Écran — Genre. Trois cartes ; la sélection devient verte avec une coche.
class GenderStep extends StatelessWidget {
  final DriverGender? selected;
  final ValueChanged<DriverGender> onSelected;

  const GenderStep({
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
            title: 'Quel est votre genre ?',
            subtitle:
                'Cette information permet uniquement de personnaliser votre expérience.',
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, gender) in DriverGender.values.indexed)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i < DriverGender.values.length - 1 ? 10 : 0,
                    ),
                    child: _GenderCard(
                      gender: gender,
                      isSelected: selected == gender,
                      onTap: () => onSelected(gender),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final DriverGender gender;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.gender,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: 148,
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
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(gender.emoji, style: const TextStyle(fontSize: 40)),
                    if (isSelected)
                      Positioned(
                        top: -4,
                        right: -8,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: DriverHomePalette.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  gender.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? DriverHomePalette.primary
                        : DriverHomePalette.textDark,
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
