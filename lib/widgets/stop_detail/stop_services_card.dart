import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/aule_data_adapter.dart';
import '../../services/gtfs_service.dart';
import '../../theme/aule_theme.dart';

/// Carte « Accès & services » de la fiche d'arrêt.
///
/// N'affiche que des informations adossées aux données réelles : accessibilité
/// PMR (3 états GTFS `wheelchair_boarding`) et modes de transport desservis.
class StopServicesCard extends StatelessWidget {
  final NearbyStation station;
  final AuleColors colors;

  const StopServicesCard({
    super.key,
    required this.station,
    required this.colors,
  });

  ({IconData icon, Color color, Color bg}) _pmrVisuals() {
    final stop = station.stop;
    if (stop.isWheelchairAccessible) {
      return (icon: LucideIcons.accessibility, color: colors.ok, bg: colors.okBg);
    }
    if (stop.isWheelchairInaccessible) {
      final red =
          colors.isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
      return (
        icon: LucideIcons.circleSlash,
        color: red,
        bg: red.withValues(alpha: 0.12),
      );
    }
    return (
      icon: LucideIcons.circleHelp,
      color: colors.muted,
      bg: colors.surface2,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Modes desservis, dédoublonnés en conservant l'ordre (structurants
    // d'abord, tel que trié dans NearbyStation.routes).
    final modes = <String>[];
    for (final route in station.routes) {
      final label = AuleDataAdapter.modeLabel(route.transportType);
      if (!modes.contains(label)) modes.add(label);
    }

    final pmr = _pmrVisuals();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accès & services',
            style: hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 12),
          // Accessibilité PMR (3 états).
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: pmr.bg,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(pmr.icon, size: 18, color: pmr.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  station.stop.accessibilityLabel,
                  style: hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
            ],
          ),
          if (modes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Modes desservis',
              style: hankenGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in modes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.brandWeak,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      mode,
                      style: hankenGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.brand,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
