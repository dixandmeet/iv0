import 'package:flutter/material.dart';

import '../../../models/driver/terrain_display_mode.dart';
import '../../../services/driver/terrain_selection_controller.dart';
import '../../../theme/driver_home_palette.dart';

/// Panneau Filtres : mode d'affichage + couches cartographiques.
class TerrainLayersPanel extends StatelessWidget {
  final TerrainSelectionController controller;

  const TerrainLayersPanel({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    TerrainSelectionController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TerrainLayersPanel(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        // Réécoute le contrôleur : sans ça, basculer un switch ne déplace pas
        // visuellement le toggle (la modale ne se reconstruirait jamais).
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final mode = controller.displayMode;
            final layers = controller.layers;
            return Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 16),
                const Text(
                  'Mode d\'affichage',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: DriverHomePalette.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TerrainDisplayMode.values.map((m) {
                    final selected = mode == m;
                    return ChoiceChip(
                      label: Text(m.label),
                      selected: selected,
                      onSelected: (_) {
                        controller.setDisplayMode(m);
                      },
                      selectedColor: DriverHomePalette.lightGreen,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? DriverHomePalette.primary
                            : DriverHomePalette.textSecondary,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Couches cartographiques',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: DriverHomePalette.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                _layerSwitch('Véhicules', 'vehicles', layers.vehicles),
                _layerSwitch('Stations', 'stations', layers.stations),
                _layerSwitch('Incidents', 'incidents', layers.incidents),
                _layerSwitch('Lignes', 'lines', layers.lines),
                _layerSwitch('Relèves', 'releves', layers.releves),
                _layerSwitch('Contrôle', 'controle', layers.controle),
                _layerSwitch('MSR', 'msr', layers.msr),
                _layerSwitch('Zones', 'zones', layers.zones),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Mode Live',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Animations fluides des véhicules',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: controller.liveEnabled,
                  activeTrackColor: DriverHomePalette.primary.withValues(
                    alpha: 0.35,
                  ),
                  activeThumbColor: DriverHomePalette.primary,
                  onChanged: controller.setLiveEnabled,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _layerSwitch(String label, String key, bool value) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      activeTrackColor: DriverHomePalette.primary.withValues(alpha: 0.35),
      activeThumbColor: DriverHomePalette.primary,
      onChanged: (v) => controller.toggleLayer(key, v),
    );
  }
}
