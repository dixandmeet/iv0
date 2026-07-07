import 'package:latlong2/latlong.dart';

import '../gtfs.dart';
import '../../widgets/driver/driver_map_marker.dart'
    show TerrainMarkerType, TerrainMarkerTypeX;

/// Fraîcheur d'un marqueur d'après l'âge de sa dernière position GPS.
///
/// - [active] : < 60 s — marqueur plein, halo.
/// - [stale]  : 60 s à 5 min — marqueur grisé (donnée vieillissante).
/// - [hidden] : > 5 min — marqueur masqué (donnée périmée).
enum TerrainFreshness { active, stale, hidden }

/// Un objet géolocalisé affiché sur la carte Terrain (snapshot immuable).
///
/// Les coordonnées sont de vraies coordonnées GPS (latlong2). Selon le type, le
/// marqueur porte ou non des informations véhicule (ligne, direction, retard…).
class TerrainMarker {
  final String id;
  final TerrainMarkerType type;
  final LatLng position;

  /// Cap en degrés (0 = nord, sens horaire). Utilisé pour orienter les véhicules.
  final double headingDeg;

  /// Vitesse instantanée en km/h (0 pour un objet immobile).
  final double speedKmh;

  /// Horodatage du dernier point GPS reçu (sert au calcul de fraîcheur).
  final DateTime updatedAt;

  // --- Détails véhicule (bus / tram) — null pour agents / incidents ---
  final String? code; // ex. « Bus 3625 »
  final String? line; // ex. « C6 »
  final String? direction; // ex. « Direction Hermeland »
  final int? delayMinutes; // + retard / - avance
  final int? gpsReliability; // fiabilité GPS 0..100

  /// Contexte libre pour les marqueurs non-véhicule (message d'incident, zone
  /// MSR…), affiché en sous-titre de la fiche.
  final String? detail;

  const TerrainMarker({
    required this.id,
    required this.type,
    required this.position,
    required this.updatedAt,
    this.headingDeg = 0,
    this.speedKmh = 0,
    this.code,
    this.line,
    this.direction,
    this.delayMinutes,
    this.gpsReliability,
    this.detail,
  });

  /// Marqueur statique pour un arrêt bus/tram GTFS.
  factory TerrainMarker.fromStop(GtfsStop stop) => TerrainMarker(
        id: 'stop:${stop.stopId}',
        type: TerrainMarkerType.arret,
        position: stop.position,
        updatedAt: DateTime.now(),
        code: stop.stopName,
      );

  bool get isStop => type == TerrainMarkerType.arret;

  bool get isVehicle =>
      type == TerrainMarkerType.bus || type == TerrainMarkerType.tram;

  /// Libellé court affiché par défaut dans la fiche (« Bus 3625 », « Équipe MSR »…).
  String get title => code ?? type.label;

  TerrainFreshness freshnessAt(DateTime now) {
    final age = now.difference(updatedAt);
    if (age.inSeconds < 60) return TerrainFreshness.active;
    if (age.inMinutes < 5) return TerrainFreshness.stale;
    return TerrainFreshness.hidden;
  }

  TerrainMarker copyWith({
    LatLng? position,
    double? headingDeg,
    double? speedKmh,
    DateTime? updatedAt,
    int? delayMinutes,
    int? gpsReliability,
  }) {
    return TerrainMarker(
      id: id,
      type: type,
      position: position ?? this.position,
      updatedAt: updatedAt ?? this.updatedAt,
      headingDeg: headingDeg ?? this.headingDeg,
      speedKmh: speedKmh ?? this.speedKmh,
      code: code,
      line: line,
      direction: direction,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      gpsReliability: gpsReliability ?? this.gpsReliability,
      detail: detail,
    );
  }
}
