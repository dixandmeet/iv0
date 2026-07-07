import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../theme/driver_home_palette.dart';

/// Indicateur de sélection affiché en fin de carte.
enum OnboardingSelectionStyle {
  /// Pastille ronde — pour une sélection unique (réseau, genre, profil…).
  radio,

  /// Case carrée cochée — pour une sélection multiple (habilitations).
  checkbox,
}

/// Carte premium sélectionnable réutilisée par toutes les étapes de choix de
/// l'onboarding (profil, réseau, habilitations, type d'activité, commerce…).
///
/// Coins arrondis 24 px, ombre légère, animation 200 ms, état désactivé grisé.
class OnboardingOptionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final bool isSelected;
  final bool isDisabled;
  final OnboardingSelectionStyle selectionStyle;
  final VoidCallback onTap;

  const OnboardingOptionCard({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    required this.isSelected,
    this.isDisabled = false,
    this.selectionStyle = OnboardingSelectionStyle.radio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDisabled ? 0.42 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? DriverHomePalette.lightGreen : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? DriverHomePalette.primary
                : DriverHomePalette.border,
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
            onTap: isDisabled ? null : onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? DriverHomePalette.primary.withValues(alpha: 0.12)
                          : DriverHomePalette.softGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? DriverHomePalette.primary
                                : DriverHomePalette.textDark,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: DriverHomePalette.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _SelectionIndicator(
                    isSelected: isSelected,
                    style: selectionStyle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  final bool isSelected;
  final OnboardingSelectionStyle style;

  const _SelectionIndicator({required this.isSelected, required this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: isSelected
          ? _selectedBox(key: const ValueKey('on'))
          : _emptyBox(key: const ValueKey('off')),
    );
  }

  Widget _selectedBox({required Key key}) {
    if (style == OnboardingSelectionStyle.radio) {
      return Icon(
        LucideIcons.circleCheck,
        key: key,
        color: DriverHomePalette.primary,
        size: 24,
      );
    }
    return Container(
      key: key,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: DriverHomePalette.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(LucideIcons.check, size: 15, color: Colors.white),
    );
  }

  Widget _emptyBox({required Key key}) {
    if (style == OnboardingSelectionStyle.radio) {
      return Icon(
        LucideIcons.circle,
        key: key,
        color: DriverHomePalette.border,
        size: 24,
      );
    }
    return Container(
      key: key,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        border: Border.all(color: DriverHomePalette.border, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
