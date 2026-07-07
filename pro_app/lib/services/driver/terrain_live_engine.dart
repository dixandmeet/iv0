import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../models/driver/terrain_marker.dart';
import '../../widgets/driver/driver_map_marker.dart';

/// État interpolé d'un véhicule pour le mode Live.
class LiveVehicleState {
  LatLng displayPosition;
  LatLng targetPosition;
  final List<LatLng> trail;
  double fadeOpacity;
  double interpolationT;

  LiveVehicleState({
    required this.displayPosition,
    required this.targetPosition,
    List<LatLng>? trail,
    this.fadeOpacity = 1.0,
    this.interpolationT = 1.0,
  }) : trail = trail ?? [];

  bool get isInterpolating => interpolationT < 1.0;
}

/// Interpolation fluide des positions véhicules (mode Live).
class TerrainLiveEngine {
  static const _lerpDurationSec = 0.8;
  static const _maxTrail = 3;

  final Map<String, LiveVehicleState> _states = {};

  Map<String, LiveVehicleState> get states => Map.unmodifiable(_states);

  /// Met à jour les positions cibles et avance l'interpolation.
  void tick({
    required List<TerrainMarker> markers,
    required double dt,
    required bool liveEnabled,
  }) {
    final ids = <String>{};
    for (final m in markers) {
      if (!m.isVehicle &&
          m.type != TerrainMarkerType.controle &&
          m.type != TerrainMarkerType.msr) {
        continue;
      }
      ids.add(m.id);
      final existing = _states[m.id];
      if (existing == null) {
        _states[m.id] = LiveVehicleState(
          displayPosition: m.position,
          targetPosition: m.position,
          fadeOpacity: 0,
        );
      } else if (_distance(existing.targetPosition, m.position) > 0.00001) {
        existing.trail.insert(0, existing.displayPosition);
        if (existing.trail.length > _maxTrail) {
          existing.trail.removeLast();
        }
        existing.targetPosition = m.position;
        existing.interpolationT = liveEnabled ? 0 : 1;
      }
    }

    // Fade out removed markers.
    for (final id in _states.keys.toList()) {
      if (!ids.contains(id)) {
        final s = _states[id]!;
        s.fadeOpacity = math.max(0, s.fadeOpacity - dt * 3);
        if (s.fadeOpacity <= 0) _states.remove(id);
      }
    }

    // Advance interpolation + fade in.
    for (final s in _states.values) {
      if (liveEnabled && s.interpolationT < 1) {
        s.interpolationT = math.min(1, s.interpolationT + dt / _lerpDurationSec);
        s.displayPosition = LatLng(
          _lerp(s.displayPosition.latitude, s.targetPosition.latitude,
              _ease(s.interpolationT)),
          _lerp(s.displayPosition.longitude, s.targetPosition.longitude,
              _ease(s.interpolationT)),
        );
      } else {
        s.displayPosition = s.targetPosition;
        s.interpolationT = 1;
      }
      if (s.fadeOpacity < 1) {
        s.fadeOpacity = math.min(1, s.fadeOpacity + dt * 4);
      }
    }
  }

  LatLng positionFor(TerrainMarker m) =>
      _states[m.id]?.displayPosition ?? m.position;

  double opacityFor(String id) => _states[id]?.fadeOpacity ?? 1.0;

  List<LatLng> trailFor(String id) => _states[id]?.trail ?? const [];

  void clear() => _states.clear();

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _ease(double t) => t * (2 - t);

  static double _distance(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return math.sqrt(dLat * dLat + dLng * dLng);
  }
}
