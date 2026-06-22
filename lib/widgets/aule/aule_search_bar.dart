import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

import '../../theme/aule_theme.dart';
import 'aule_icons.dart';

/// Barre de recherche flottante chevauchant la carte.
class AuleSearchBar extends StatelessWidget {
  final String placeholder;
  final VoidCallback? onSearchTap;
  final VoidCallback? onFavoritesTap;

  const AuleSearchBar({
    super.key,
    this.placeholder = 'Où allez-vous ?',
    this.onSearchTap,
    this.onFavoritesTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onSearchTap,
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(AuleTokens.rSearch),
                  boxShadow: AuleTokens.searchShadow(c.shadow),
                ),
                child: Row(
                  children: [
                    AuleIcons.search(size: 19, color: c.muted),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        placeholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hankenGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.faint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Favoris',
            child: GestureDetector(
              onTap: onFavoritesTap,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: c.brand,
                  borderRadius: BorderRadius.circular(AuleTokens.rSearch),
                  boxShadow: [
                    BoxShadow(
                      color: c.brandShadow,
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                      spreadRadius: -10,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AuleIcons.star(size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
