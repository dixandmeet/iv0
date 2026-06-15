import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/flow_theme.dart';
import '../../../widgets/flow_primitives.dart';
import '../../../widgets/home/home_section_header.dart';
import '../../search_route_screen.dart';

/// Section Favoris (stub phase 1 — pas de persistance).
class FavoritesSection extends StatelessWidget {
  const FavoritesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('favorites_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(emoji: '⭐', title: 'Favoris'),
        Row(
          children: [
            _FavChip(
              icon: LucideIcons.house,
              label: 'Maison',
              onTap: () => _openRoute(context, 'Commerce'),
            ),
            const SizedBox(width: 8),
            _FavChip(
              icon: LucideIcons.briefcase,
              label: 'Travail',
              onTap: () => _openRoute(context, 'Cité des Congrès'),
            ),
            const SizedBox(width: 8),
            _FavChip(
              icon: LucideIcons.plus,
              label: 'Ajouter',
              ghost: true,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  void _openRoute(BuildContext context, String destination) {
    Navigator.push(
      context,
      FlowPageRoute(page: const SearchRouteScreen()),
    );
  }
}

class _FavChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ghost;
  final VoidCallback onTap;

  const _FavChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.ghost = false,
  });

  @override
  Widget build(BuildContext context) {
    return FlowTappable(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ghost ? FlowColors.fill : FlowColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ghost ? FlowColors.line : FlowColors.line,
          ),
          boxShadow: ghost ? null : FlowTokens.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: FlowColors.ink),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FlowColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
