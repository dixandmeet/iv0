import 'package:flutter/material.dart';

import '../../../../theme/driver_home_palette.dart';

/// Champ de saisie premium aligné sur le design system (coins arrondis,
/// fond blanc, bordure verte au focus).
class OnboardingTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool optional;
  final TextInputType keyboardType;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const OnboardingTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.onChanged,
    this.optional = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: DriverHomePalette.textDark,
              ),
            ),
            if (optional) ...[
              const SizedBox(width: 6),
              const Text(
                'optionnel',
                style: TextStyle(
                  fontSize: 12,
                  color: DriverHomePalette.textSecondary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: DriverHomePalette.textDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: DriverHomePalette.textSecondary.withValues(alpha: 0.7),
            ),
            prefixIcon: Icon(icon, size: 20, color: DriverHomePalette.primary),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: DriverHomePalette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide:
                  const BorderSide(color: DriverHomePalette.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
