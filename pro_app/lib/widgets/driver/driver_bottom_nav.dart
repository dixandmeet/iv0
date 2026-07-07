import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/driver_home_palette.dart';

/// Un onglet de la navigation basse conducteur.
class DriverNavDestination {
  final IconData icon;
  final String label;

  const DriverNavDestination({required this.icon, required this.label});
}

/// Navigation basse custom de l'espace conducteur : blanche, ~86 px, légère
/// ombre haute, 3 onglets (Accueil / Terrain / Menu).
///
/// État actif : icône + texte verts, pastille vert très pâle sous l'icône.
/// État inactif : icône et texte gris.
class DriverBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const destinations = <DriverNavDestination>[
    DriverNavDestination(icon: LucideIcons.house, label: 'Accueil'),
    DriverNavDestination(icon: LucideIcons.radar, label: 'Terrain'),
    DriverNavDestination(icon: Icons.menu_rounded, label: 'Menu'),
  ];

  const DriverBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DriverHomePalette.card,
        boxShadow: [
          BoxShadow(
            color: Color(0x14101A14),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SizedBox(
          height: 70,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  _NavItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final DriverNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? DriverHomePalette.primary
        : DriverHomePalette.inactiveIcon;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? DriverHomePalette.lightGreen
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(destination.icon, size: 22, color: color),
            ),
            const SizedBox(height: 5),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
