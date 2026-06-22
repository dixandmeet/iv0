import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

import '../../theme/aule_theme.dart';

/// Catégories de filtre de la liste des départs d'un arrêt.
enum StopFilter { all, bus, tram, favorites }

extension StopFilterLabel on StopFilter {
  String get label {
    switch (this) {
      case StopFilter.all:
        return 'Tous';
      case StopFilter.bus:
        return 'Bus';
      case StopFilter.tram:
        return 'Tram';
      case StopFilter.favorites:
        return 'Favoris';
    }
  }
}

/// Rangée de chips (style Material 3) défilable horizontalement, sous l'en-tête.
/// Permet de filtrer les départs par mode (bus / tram) ou favoris.
class StopFilterChips extends StatelessWidget {
  final StopFilter selected;
  final ValueChanged<StopFilter> onSelected;
  final AuleColors colors;

  /// Filtres masqués faute de données (ex. aucune ligne de tram à cet arrêt).
  final Set<StopFilter> hidden;

  const StopFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.colors,
    this.hidden = const {},
  });

  @override
  Widget build(BuildContext context) {
    final visible =
        StopFilter.values.where((f) => !hidden.contains(f)).toList();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final filter = visible[i];
          return _Chip(
            label: filter.label,
            isSelected: filter == selected,
            colors: colors,
            onTap: () => onSelected(filter),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final AuleColors colors;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? colors.brand : colors.surface;
    final fg = isSelected ? Colors.white : colors.muted;
    final border = isSelected ? colors.brand : colors.line;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Text(
              label,
              style: hankenGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
