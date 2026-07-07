import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../models/driver/terrain_display_mode.dart';
import '../../../models/driver/terrain_marker.dart';
import '../../../services/driver/terrain_nearby_service.dart';
import '../../../theme/driver_home_palette.dart';
import '../driver_map_marker.dart';

/// Fiche détail métier (radar niveau 3).
class TerrainVehicleDetail extends StatelessWidget {
  final TerrainMarker marker;
  final LatLng? userPosition;
  final TerrainDisplayMode displayMode;
  final void Function(TerrainDetailAction action) onAction;

  const TerrainVehicleDetail({
    super.key,
    required this.marker,
    required this.userPosition,
    required this.displayMode,
    required this.onAction,
  });

  static const _distance = Distance();

  @override
  Widget build(BuildContext context) {
    final m = marker;
    final now = DateTime.now();
    final dist = userPosition == null
        ? null
        : _distance.as(LengthUnit.Meter, userPosition!, m.position);
    final delay = m.delayMinutes;
    final delayText = delay == null
        ? ''
        : delay == 0
        ? ' · À l\'heure'
        : delay > 0
        ? ' · +$delay min'
        : ' · $delay min';
    // Sous-titre : direction pour un véhicule, contexte (message d'incident,
    // plan de contrôle, statut MSR…) pour les autres marqueurs.
    final subtitle = m.direction ?? (m.isVehicle ? null : m.detail);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: m.type.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(m.type.icon, color: m.type.color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: DriverHomePalette.textDark,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: DriverHomePalette.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${TerrainNearbyService.statusDot(m, now)} '
          '${TerrainNearbyService.statusLabel(m, now)}'
          '${dist != null ? ' · ${TerrainNearbyService.formatDistance(dist)}' : ''}'
          '$delayText',
          style: const TextStyle(
            color: DriverHomePalette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: DriverHomePalette.border),
        const SizedBox(height: 12),
        _actionGrid(displayMode.detailActions),
        if (m.isVehicle) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniStat('Vitesse', '${m.speedKmh.round()} km/h'),
              ),
              Expanded(
                child: _miniStat(
                  'GPS',
                  m.gpsReliability == null ? '—' : '${m.gpsReliability} %',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _actionGrid(List<TerrainDetailAction> actions) {
    final primary = actions.take(4).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: primary.map((a) {
        return SizedBox(
          width: primary.length <= 2 ? double.infinity : null,
          child: _ActionChip(action: a, onTap: () => onAction(a)),
        );
      }).toList(),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: DriverHomePalette.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: DriverHomePalette.textDark,
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final TerrainDetailAction action;
  final VoidCallback onTap;

  const _ActionChip({required this.action, required this.onTap});

  IconData get _icon => switch (action) {
    TerrainDetailAction.follow => LucideIcons.eye,
    TerrainDetailAction.viewLine => LucideIcons.route,
    TerrainDetailAction.join => LucideIcons.userPlus,
    TerrainDetailAction.share => LucideIcons.share2,
    TerrainDetailAction.alert => LucideIcons.bell,
    TerrainDetailAction.comments => LucideIcons.messageSquare,
    TerrainDetailAction.history => LucideIcons.history,
    TerrainDetailAction.contact => LucideIcons.messageCircle,
    TerrainDetailAction.route => LucideIcons.navigation,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DriverHomePalette.lightGreen,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 16, color: DriverHomePalette.primary),
              const SizedBox(width: 6),
              Text(
                action.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: DriverHomePalette.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
