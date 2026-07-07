import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/driver/terrain_display_mode.dart';
import '../../../models/driver/terrain_marker.dart';
import '../../../models/driver/terrain_sheet_level.dart';
import '../../../services/driver/terrain_nearby_service.dart';
import '../../../services/driver/terrain_selection_controller.dart';
import '../../../theme/driver_home_palette.dart';
import '../../../widgets/driver/terrain/terrain_stats_banner.dart';
import '../../../widgets/driver/terrain/terrain_vehicle_card.dart';
import '../../../widgets/driver/terrain/terrain_vehicle_detail.dart';

/// Bottom sheet radar 3 niveaux : résumé → liste → détail.
class TerrainRadarSheet extends StatelessWidget {
  final TerrainSelectionController controller;
  final List<TerrainMarker> markers;
  final LatLng? userPosition;
  final ScrollController scrollController;
  final void Function(TerrainDetailAction action) onDetailAction;

  const TerrainRadarSheet({
    super.key,
    required this.controller,
    required this.markers,
    required this.userPosition,
    required this.scrollController,
    required this.onDetailAction,
  });

  @override
  Widget build(BuildContext context) {
    final stats = TerrainNearbyService.computeStats(
      markers: markers,
      userPosition: userPosition,
    );
    final nearby = TerrainNearbyService.nearbyVehicles(
      markers: markers,
      userPosition: userPosition,
      filterType: controller.activeFilterType,
    );
    final selected = controller.selectedMarker;
    final level = controller.sheetLevel;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A101A14),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: DriverHomePalette.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (level == TerrainSheetLevel.summary) ...[
                    const Text(
                      'Véhicules autour de vous',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: DriverHomePalette.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (stats.bus > 0)
                          AnimatedStatCount(value: stats.bus, label: 'Bus'),
                        if (stats.tram > 0)
                          AnimatedStatCount(value: stats.tram, label: 'Tram'),
                        if (stats.controle > 0)
                          AnimatedStatCount(
                              value: stats.controle, label: 'Contrôle'),
                        if (stats.msr > 0)
                          AnimatedStatCount(value: stats.msr, label: 'MSR'),
                      ],
                    ),
                  ] else if (level == TerrainSheetLevel.detail &&
                      selected != null)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: TerrainVehicleDetail(
                        key: ValueKey(selected.id),
                        marker: selected,
                        userPosition: userPosition,
                        displayMode: controller.displayMode,
                        onAction: onDetailAction,
                      ),
                    )
                  else
                    const Text(
                      'À proximité',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: DriverHomePalette.textDark,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (level != TerrainSheetLevel.summary &&
              !(level == TerrainSheetLevel.detail && selected != null))
            nearby.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Aucun véhicule à proximité',
                          style: TextStyle(
                              color: DriverHomePalette.textSecondary),
                        ),
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                    sliver: SliverList.builder(
                      itemCount: nearby.length,
                      itemBuilder: (context, index) {
                        final item = nearby[index];
                        return TerrainVehicleCard(
                          item: item,
                          selected: selected?.id == item.marker.id,
                          onTap: () => controller.selectMarker(
                            item.marker,
                            expandTo: TerrainSheetLevel.detail,
                          ),
                        );
                      },
                    ),
                  )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}
