import 'package:latlong2/latlong.dart';

import '../../models/driver/terrain_marker.dart';
import '../../widgets/driver/driver_map_marker.dart';

/// Statistiques opérationnelles pour le bandeau et le radar résumé.
class TerrainOperationalStats {
  final int bus;
  final int tram;
  final int controle;
  final int msr;
  final int incidents;
  final int assistance;
  final int activeTotal;
  final int nearbyCount;
  final int nearbyIncidents;

  const TerrainOperationalStats({
    this.bus = 0,
    this.tram = 0,
    this.controle = 0,
    this.msr = 0,
    this.incidents = 0,
    this.assistance = 0,
    this.activeTotal = 0,
    this.nearbyCount = 0,
    this.nearbyIncidents = 0,
  });
}

class TerrainNearbyVehicle {
  final TerrainMarker marker;
  final double distanceMeters;
  final String statusLabel;
  final String delayLabel;

  const TerrainNearbyVehicle({
    required this.marker,
    required this.distanceMeters,
    required this.statusLabel,
    required this.delayLabel,
  });
}

/// Calcul des véhicules proches et statistiques temps réel.
class TerrainNearbyService {
  static const _distance = Distance();
  static const nearbyRadiusM = 1200.0;

  static TerrainOperationalStats computeStats({
    required List<TerrainMarker> markers,
    LatLng? userPosition,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    var bus = 0, tram = 0, controle = 0, msr = 0, incidents = 0, assistance = 0;
    var nearby = 0, nearbyIncidents = 0;

    for (final m in markers) {
      if (m.isVehicle && m.freshnessAt(t) == TerrainFreshness.hidden) continue;

      switch (m.type) {
        case TerrainMarkerType.bus:
          bus++;
        case TerrainMarkerType.tram:
          tram++;
        case TerrainMarkerType.controle:
          controle++;
        case TerrainMarkerType.msr:
          msr++;
        case TerrainMarkerType.incident:
          incidents++;
        case TerrainMarkerType.assistance:
          assistance++;
        case TerrainMarkerType.arret:
          break;
      }

      if (userPosition != null) {
        final d = _distance.as(LengthUnit.Meter, userPosition, m.position);
        if (d <= nearbyRadiusM) {
          if (m.isVehicle ||
              m.type == TerrainMarkerType.controle ||
              m.type == TerrainMarkerType.msr) {
            nearby++;
          }
          if (m.type == TerrainMarkerType.incident) nearbyIncidents++;
        }
      }
    }

    return TerrainOperationalStats(
      bus: bus,
      tram: tram,
      controle: controle,
      msr: msr,
      incidents: incidents,
      assistance: assistance,
      activeTotal: bus + tram + controle + msr,
      nearbyCount: nearby,
      nearbyIncidents: nearbyIncidents,
    );
  }

  static List<TerrainNearbyVehicle> nearbyVehicles({
    required List<TerrainMarker> markers,
    required LatLng? userPosition,
    TerrainMarkerType? filterType,
    DateTime? now,
    int limit = 50,
  }) {
    if (userPosition == null) return const [];
    final t = now ?? DateTime.now();
    final list = <TerrainNearbyVehicle>[];

    for (final m in markers) {
      if (filterType != null && m.type != filterType) continue;
      if (m.isVehicle && m.freshnessAt(t) == TerrainFreshness.hidden) continue;
      if (!m.isVehicle &&
          m.type != TerrainMarkerType.controle &&
          m.type != TerrainMarkerType.msr &&
          m.type != TerrainMarkerType.incident) {
        continue;
      }

      final d = _distance.as(LengthUnit.Meter, userPosition, m.position);
      list.add(
        TerrainNearbyVehicle(
          marker: m,
          distanceMeters: d,
          statusLabel: statusLabel(m, t),
          delayLabel: _delayLabel(m),
        ),
      );
    }

    list.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return list.take(limit).toList();
  }

  /// Libellé d'état d'un marqueur (« En service », « GPS perdu », « Incident »…).
  static String statusLabel(TerrainMarker m, [DateTime? now]) {
    final t = now ?? DateTime.now();
    if (m.isVehicle) {
      final f = m.freshnessAt(t);
      if (f == TerrainFreshness.stale) return 'GPS perdu';
      if (m.speedKmh < 1 && (m.delayMinutes ?? 0) > 10) return 'Hors service';
      return 'En service';
    }
    return switch (m.type) {
      TerrainMarkerType.controle => 'Contrôle actif',
      TerrainMarkerType.msr => 'MSR en mission',
      TerrainMarkerType.incident => 'Incident',
      TerrainMarkerType.assistance => 'Demande d\'assistance',
      _ => m.type.label,
    };
  }

  /// Pastille emoji d'état, alignée sur [statusLabel].
  static String statusDot(TerrainMarker m, [DateTime? now]) {
    final t = now ?? DateTime.now();
    if (m.isVehicle) {
      if (m.freshnessAt(t) == TerrainFreshness.stale) return '🟠';
      if (m.speedKmh < 1 && (m.delayMinutes ?? 0) > 10) return '⚪';
      return '🟢';
    }
    return switch (m.type) {
      TerrainMarkerType.controle => '🟣',
      TerrainMarkerType.msr => '🟠',
      TerrainMarkerType.incident => '🔴',
      TerrainMarkerType.assistance => '🆘',
      _ => '🟢',
    };
  }

  static String _delayLabel(TerrainMarker m) {
    if (!m.isVehicle || m.delayMinutes == null) return '';
    final d = m.delayMinutes!;
    if (d == 0) return 'À l\'heure';
    if (d > 0) return '+$d min';
    return '$d min';
  }

  static String formatDistance(double meters) {
    if (meters < 950) return 'à ${(meters / 10).round() * 10} mètres';
    return 'à ${(meters / 1000).toStringAsFixed(1)} km';
  }
}
