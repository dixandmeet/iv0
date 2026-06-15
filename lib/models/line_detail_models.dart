/// Statut d'un passage affiché sur la page détail ligne.
enum DepartureStatus { realtime, theoretical, delayed }

/// Un créneau de départ pour les cartes « Prochains passages ».
class DepartureSlot {
  final int waitMinutes;
  final DateTime departureTime;
  final DepartureStatus status;

  const DepartureSlot({
    required this.waitMinutes,
    required this.departureTime,
    required this.status,
  });
}

/// Niveau d'occupation estimé du véhicule.
enum VehicleOccupancy { low, medium, high }

/// Données contextuelles d'aide à la décision.
class DecisionInsight {
  final int recommendedLeaveMinutes;
  final int walkMinutes;
  final int walkMeters;
  final double vehicleDistanceKm;
  final bool willMissPassage;
  final bool willArriveBeforeVehicle;

  const DecisionInsight({
    required this.recommendedLeaveMinutes,
    required this.walkMinutes,
    required this.walkMeters,
    required this.vehicleDistanceKm,
    required this.willMissPassage,
    required this.willArriveBeforeVehicle,
  });
}
