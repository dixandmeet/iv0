import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/driver_home_palette.dart';

/// Chip de filtre horizontal avec icône Lucide.
class TerrainFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const TerrainFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon => switch (label) {
        'Tous' => LucideIcons.radar,
        'Bus' => LucideIcons.bus,
        'Tram' => LucideIcons.trainFront,
        'Contrôle' => LucideIcons.shieldCheck,
        'Intervention' => LucideIcons.users,
        'Incidents' => LucideIcons.triangleAlert,
        'Assistance' => LucideIcons.lifeBuoy,
        _ => LucideIcons.circle,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? DriverHomePalette.primary : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? DriverHomePalette.primary
                  : DriverHomePalette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icon,
                size: 15,
                color: selected ? Colors.white : DriverHomePalette.textSecondary,
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: selected ? Colors.white : DriverHomePalette.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TerrainFilterBar extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  const TerrainFilterBar({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            for (var i = 0; i < filters.length; i++) ...[
              TerrainFilterChip(
                label: filters[i],
                selected: selected == filters[i],
                onTap: () => onSelected(filters[i]),
              ),
              if (i != filters.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}
