import 'package:flutter/material.dart';

import '../../theme/driver_home_palette.dart';

/// Chip de filtre horizontal (onglet Terrain) : vert plein quand actif, gris
/// très clair sinon.
class DriverFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const DriverFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? DriverHomePalette.primary : DriverHomePalette.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? DriverHomePalette.primary
                : DriverHomePalette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : DriverHomePalette.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
