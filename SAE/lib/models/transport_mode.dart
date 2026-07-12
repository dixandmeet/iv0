import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum TransportMode { bus, tram, boat }

extension TransportModeX on TransportMode {
  String get label => switch (this) {
    TransportMode.bus => 'Bus',
    TransportMode.tram => 'Tram',
    TransportMode.boat => 'Navibus',
  };

  Color get color => switch (this) {
    TransportMode.bus => AppColors.accent,
    TransportMode.tram => AppColors.blue,
    TransportMode.boat => AppColors.boat,
  };

  IconData get icon => switch (this) {
    TransportMode.bus => Icons.directions_bus_filled_rounded,
    TransportMode.tram => Icons.tram_rounded,
    TransportMode.boat => Icons.directions_boat_filled_rounded,
  };

  /// Vitesse moyenne simulée (m/s), utilisée pour dériver la distance depuis l'ETA.
  double get speedMs => switch (this) {
    TransportMode.bus => 8,
    TransportMode.tram => 11,
    TransportMode.boat => 4,
  };
}
