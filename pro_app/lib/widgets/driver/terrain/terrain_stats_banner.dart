import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../services/driver/terrain_nearby_service.dart';
import '../../../theme/driver_home_palette.dart';
import '../../../models/driver/terrain_display_mode.dart';

/// Bandeau stats opérationnelles flottant sur la carte.
class TerrainStatsBanner extends StatelessWidget {
  final TerrainOperationalStats stats;
  final TerrainDisplayMode displayMode;
  final double mapZoom;

  const TerrainStatsBanner({
    super.key,
    required this.stats,
    required this.displayMode,
    this.mapZoom = 14.6,
  });

  @override
  Widget build(BuildContext context) {
    final useProximity =
        displayMode.preferProximityStats || mapZoom >= 14;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: DriverHomePalette.border.withValues(alpha: 0.6),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                useProximity ? _proximityText() : _fleetText(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DriverHomePalette.textDark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fleetText() {
    return 'Bus : ${stats.bus}  ·  Tram : ${stats.tram}  ·  '
        'Contrôle : ${stats.controle}  ·  MSR : ${stats.msr}';
  }

  String _proximityText() {
    return '🟢 ${stats.activeTotal} actifs · '
        '🟠 ${stats.nearbyCount} proches · '
        '🔴 ${stats.nearbyIncidents} incidents';
  }
}

/// Compteur animé pour le radar résumé.
class AnimatedStatCount extends StatelessWidget {
  final int value;
  final String label;

  const AnimatedStatCount({
    super.key,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(
        '$v $label',
        style: const TextStyle(
          color: DriverHomePalette.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
