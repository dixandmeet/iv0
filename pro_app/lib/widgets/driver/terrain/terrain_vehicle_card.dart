import 'package:flutter/material.dart';

import '../../../services/driver/terrain_nearby_service.dart';
import '../../../theme/driver_home_palette.dart';
import '../driver_map_marker.dart';

/// Carte véhicule dans la liste radar (niveau 2).
class TerrainVehicleCard extends StatelessWidget {
  final TerrainNearbyVehicle item;
  final bool selected;
  final VoidCallback onTap;

  const TerrainVehicleCard({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = item.marker;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? DriverHomePalette.lightGreen : DriverHomePalette.card,
        borderRadius: BorderRadius.circular(20),
        elevation: selected ? 0 : 1,
        shadowColor: const Color(0x0F10251D),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? DriverHomePalette.primary.withValues(alpha: 0.4)
                    : DriverHomePalette.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: m.type.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(m.type.icon, color: m.type.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: DriverHomePalette.textDark,
                              ),
                            ),
                          ),
                          Text(
                            item.statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _statusColor(item.statusLabel),
                            ),
                          ),
                        ],
                      ),
                      if (m.direction != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          m.direction!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DriverHomePalette.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${TerrainNearbyService.formatDistance(item.distanceMeters)}'
                        '${item.delayLabel.isNotEmpty ? ' · ${item.delayLabel}' : ''}',
                        style: const TextStyle(
                          color: DriverHomePalette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String label) {
    if (label.contains('service') && !label.contains('Hors')) {
      return DriverHomePalette.primary;
    }
    if (label.contains('GPS') || label.contains('Hors')) {
      return DriverHomePalette.warning;
    }
    if (label.contains('Incident')) return DriverHomePalette.danger;
    return DriverHomePalette.textSecondary;
  }
}
