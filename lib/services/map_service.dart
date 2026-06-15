import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/community_vehicle.dart';
import '../models/transport_visuals.dart';

// Couleurs sémantiques fixes pour les tracés / badges carte (alignées Aule).
const Color _mapBlue = Color(0xFF1B66F5);
const Color _mapOrange = Color(0xFFF59E0B);
const Color _mapGreen = Color(0xFF16A34A);
const Color _mapRed = Color(0xFFDC2626);
const Color _mapGrey = Color(0xFF9AA4B2);

class MapService with ChangeNotifier {
  static const Color brandPrimary = Color(0xFF0B1220);
  static const Color brandAccent = _mapBlue;

  // Couleurs associées aux modes de transport (utilisées surtout pour les
  // tracés ; les badges portent la couleur de ligne réelle quand elle existe).
  Color getTransportColor(String transportType, {String? routeColorHex}) {
    if (routeColorHex != null && routeColorHex.isNotEmpty) {
      try {
        final hex = routeColorHex.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    switch (transportType.toLowerCase()) {
      case 'tram':
        return _mapBlue;
      case 'busway':
        return _mapOrange;
      case 'navibus':
        return const Color(0xFF2FA9C4);
      case 'bus':
      default:
        return _mapBlue;
    }
  }

  // Nom lisible du type de transport
  String getTransportLabel(String transportType) {
    switch (transportType.toLowerCase()) {
      case 'tram':
        return 'Tramway';
      case 'busway':
        return 'Busway';
      case 'navibus':
        return 'Navibus';
      case 'bus':
      default:
        return 'Bus';
    }
  }

  // Icône appropriée
  IconData getTransportIcon(String transportType) {
    switch (transportType.toLowerCase()) {
      case 'tram':
        return LucideIcons.tramFront;
      case 'busway':
        return LucideIcons.busFront;
      case 'navibus':
        return LucideIcons.ship;
      case 'bus':
      default:
        return LucideIcons.bus;
    }
  }

  // Couleur du niveau de fiabilité
  Color getReliabilityColor(String level) {
    switch (level.toLowerCase()) {
      case 'fort':
        return _mapGreen;
      case 'moyen':
        return _mapOrange;
      case 'faible':
      default:
        return _mapGrey;
    }
  }
}

/// Statut horaire d'un véhicule, formaté pour les capsules / fiches.
class VehicleStatus {
  final String text;
  final Color color;
  const VehicleStatus(this.text, this.color);
}

VehicleStatus vehicleStatus(CommunityVehicle v) {
  final delay = v.estimatedDelaySeconds;
  if (delay == null) return const VehicleStatus("à l'heure", _mapGreen);
  if (delay > 30) {
    final min = (delay / 60).ceil();
    return VehicleStatus('+$min min', min >= 4 ? _mapRed : _mapOrange);
  }
  if (delay < -30) {
    final min = (delay.abs() / 60).ceil();
    return VehicleStatus("-$min min", _mapGreen);
  }
  return const VehicleStatus("à l'heure", _mapGreen);
}

/// Niveau d'affluence estimé à partir du nombre de co-voyageurs détectés.
CrowdLevel vehicleCrowd(CommunityVehicle v) {
  if (v.activeUserCount >= 5) return CrowdLevel.high;
  if (v.activeUserCount >= 2) return CrowdLevel.mid;
  return CrowdLevel.low;
}

String crowdLabel(CrowdLevel level) {
  switch (level) {
    case CrowdLevel.low:
      return 'Faible';
    case CrowdLevel.mid:
      return 'Moyenne';
    case CrowdLevel.high:
      return 'Élevée';
  }
}
