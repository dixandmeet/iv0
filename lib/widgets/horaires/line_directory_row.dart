import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/gtfs.dart';
import '../../services/aule_data_adapter.dart';
import '../../theme/app_fonts.dart';
import '../../theme/aule_theme.dart';

/// Ligne de l'annuaire des lignes : badge coloré + terminus, étoile favori,
/// ouverture de la fiche horaire au tap.
class LineDirectoryRow extends StatelessWidget {
  final GtfsRoute route;
  final AuleColors colors;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  const LineDirectoryRow({
    super.key,
    required this.route,
    required this.colors,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final lineColor =
        AuleDataAdapter.routeColor(route) ?? const Color(0xFF6B7280);
    final code = AuleDataAdapter.lineCode(route);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 42),
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  code,
                  style: hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AuleDataAdapter.terminusLabel(route),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: isFavorite
                    ? 'Retirer la ligne des favoris'
                    : 'Ajouter la ligne aux favoris',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleFavorite,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      LucideIcons.star,
                      size: 18,
                      color: isFavorite
                          ? const Color(0xFFF59E0B)
                          : c.faint,
                      fill: isFavorite ? 1.0 : 0.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(LucideIcons.chevronRight, size: 18, color: c.faint),
            ],
          ),
        ),
      ),
    );
  }
}
