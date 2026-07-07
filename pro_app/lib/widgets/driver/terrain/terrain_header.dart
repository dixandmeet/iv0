import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/driver_home_palette.dart';

/// En-tête compact de la page Terrain.
class TerrainHeader extends StatelessWidget {
  final VoidCallback onFilters;

  const TerrainHeader({super.key, required this.onFilters});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Terrain',
              style: TextStyle(
                color: DriverHomePalette.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onFilters,
            icon: const Icon(
              LucideIcons.slidersHorizontal,
              size: 18,
              color: DriverHomePalette.textDark,
            ),
            label: const Text(
              'Filtres',
              style: TextStyle(
                color: DriverHomePalette.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
