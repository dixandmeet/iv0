import 'package:flutter/material.dart';

import 'driver_onboarding_data.dart';
import 'driver_workspace_mode.dart';

/// Style du marqueur de position utilisateur sur la carte Terrain.
enum TerrainUserMarkerStyle {
  blueDot,
  driverHomme,
  controllerHomme,
  controllerFemme,
  onMissionStub,
  controllerNeutralStub,
}

extension TerrainUserMarkerStyleX on TerrainUserMarkerStyle {
  bool get isPersonalIcon =>
      this == TerrainUserMarkerStyle.driverHomme ||
      this == TerrainUserMarkerStyle.controllerHomme ||
      this == TerrainUserMarkerStyle.controllerFemme;

  double get markerWidth => isPersonalIcon ? 72.0 : 56.0;

  double get markerHeight => isPersonalIcon ? 84.0 : 56.0;

  /// Point d'ancrage carte : pieds du personnage, pas le badge « Vous ».
  Alignment get markerAlignment =>
      isPersonalIcon ? const Alignment(0, -0.18) : Alignment.center;
}

/// Détermine le marqueur à afficher selon le mode workspace, la mission et le genre.
TerrainUserMarkerStyle resolveUserMarkerStyle({
  required DriverWorkspaceMode workspace,
  required DriverGender? gender,
  required bool hasActiveMission,
}) {
  if (workspace == DriverWorkspaceMode.conduite) {
    return switch (gender) {
      DriverGender.homme => TerrainUserMarkerStyle.driverHomme,
      _ => TerrainUserMarkerStyle.blueDot,
    };
  }
  if (hasActiveMission) {
    return TerrainUserMarkerStyle.onMissionStub;
  }
  return switch (gender) {
    DriverGender.homme => TerrainUserMarkerStyle.controllerHomme,
    DriverGender.femme => TerrainUserMarkerStyle.controllerFemme,
    DriverGender.autre => TerrainUserMarkerStyle.controllerNeutralStub,
    null => TerrainUserMarkerStyle.blueDot,
  };
}

/// Cap GPS utilisable pour l'orientation du marqueur (0 = nord).
double resolveUserHeadingDeg(double? heading) {
  if (heading == null || heading < 0 || heading.isNaN) return 0;
  return heading;
}
