import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/flow_theme.dart';
import '../flow_primitives.dart';

/// Barre de recherche fixe en haut de l'écran Accueil.
class HomeSearchBar extends StatelessWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onFavoritesTap;

  const HomeSearchBar({
    super.key,
    required this.onSearchTap,
    required this.onFavoritesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FlowTokens.margin,
        0,
        FlowTokens.margin,
        12,
      ),
      child: Row(
        children: [
          Expanded(
            child: FlowTappable(
              onTap: onSearchTap,
              pressedScale: 0.98,
              child: Container(
                height: 54,
                padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                decoration: BoxDecoration(
                  color: FlowColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: FlowTokens.soft,
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.search, color: FlowColors.ink, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Où allez-vous ?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: FlowColors.g2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FlowTappable(
            onTap: onFavoritesTap,
            pressedScale: 0.94,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: FlowColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: FlowTokens.soft,
              ),
              child: const Icon(
                LucideIcons.star,
                size: 22,
                color: FlowColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
