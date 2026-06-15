import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/flow_theme.dart';
import '../models/community_vehicle.dart';

class MapService with ChangeNotifier {
  // Identité FLOW
  static const Color brandPrimary = FlowColors.ink;
  static const Color brandAccent = FlowColors.blue;

  // Couleurs associées aux modes de transport (teintes FLOW sobres,
  // utilisées surtout pour les tracés ; les badges restent encre foncée).
  Color getTransportColor(String transportType, {String? routeColorHex}) {
    if (routeColorHex != null && routeColorHex.isNotEmpty) {
      try {
        final hex = routeColorHex.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    switch (transportType.toLowerCase()) {
      case 'tram':
        return FlowColors.blue;
      case 'busway':
        return FlowColors.orange;
      case 'navibus':
        return const Color(0xFF2FA9C4);
      case 'bus':
      default:
        return FlowColors.blue;
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

  // Couleur du niveau de fiabilité (sémantique FLOW)
  Color getReliabilityColor(String level) {
    switch (level.toLowerCase()) {
      case 'fort':
        return FlowColors.green;
      case 'moyen':
        return FlowColors.orange;
      case 'faible':
      default:
        return FlowColors.gWeak;
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
  if (delay == null) return const VehicleStatus("à l'heure", FlowColors.green);
  if (delay > 30) {
    final min = (delay / 60).ceil();
    return VehicleStatus('+$min min', min >= 4 ? FlowColors.red : FlowColors.orange);
  }
  if (delay < -30) {
    final min = (delay.abs() / 60).ceil();
    return VehicleStatus("-$min min", FlowColors.green);
  }
  return const VehicleStatus("à l'heure", FlowColors.green);
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
