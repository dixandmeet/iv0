import 'package:shared/shared.dart';

import '../../widgets/driver/driver_map_marker.dart';
import '../driver/driver_workspace_mode.dart';
import 'terrain_map_layers.dart';

/// Mode d'affichage de la page Terrain selon le profil utilisateur.
enum TerrainDisplayMode {
  voyageur,
  conducteur,
  intervention,
  supervision,
}

extension TerrainDisplayModeX on TerrainDisplayMode {
  String get label => switch (this) {
        TerrainDisplayMode.voyageur => 'Voyageur',
        TerrainDisplayMode.conducteur => 'Conducteur',
        TerrainDisplayMode.intervention => 'Intervention',
        TerrainDisplayMode.supervision => 'Supervision',
      };

  /// Couches activées par défaut pour ce mode.
  TerrainMapLayers get defaultLayers => switch (this) {
        TerrainDisplayMode.voyageur => const TerrainMapLayers(
            vehicles: true,
            stations: true,
            incidents: false,
            lines: false,
            controle: false,
            msr: false,
          ),
        TerrainDisplayMode.conducteur => const TerrainMapLayers(
            vehicles: true,
            stations: true,
            incidents: true,
            lines: false,
            releves: true,
            controle: true,
            msr: true,
          ),
        TerrainDisplayMode.intervention => const TerrainMapLayers(
            vehicles: false,
            stations: false,
            incidents: true,
            controle: true,
            msr: true,
            zones: true,
          ),
        TerrainDisplayMode.supervision => const TerrainMapLayers(
            vehicles: true,
            stations: true,
            incidents: true,
            lines: true,
            releves: true,
            controle: true,
            msr: true,
            zones: true,
          ),
      };

  /// Labels des chips filtre visibles.
  List<String> get visibleFilterLabels => switch (this) {
        TerrainDisplayMode.voyageur =>
          const ['Tous', 'Bus', 'Tram'],
        TerrainDisplayMode.conducteur =>
          const ['Tous', 'Bus', 'Tram', 'Contrôle', 'Intervention', 'Incidents', 'Assistance'],
        TerrainDisplayMode.intervention =>
          const ['Tous', 'Contrôle', 'Intervention', 'Incidents', 'Assistance'],
        TerrainDisplayMode.supervision =>
          const ['Tous', 'Bus', 'Tram', 'Contrôle', 'Intervention', 'Incidents', 'Assistance'],
      };

  String get defaultFilterLabel => switch (this) {
        TerrainDisplayMode.voyageur => 'Tous',
        TerrainDisplayMode.conducteur => 'Tous',
        TerrainDisplayMode.intervention => 'Intervention',
        TerrainDisplayMode.supervision => 'Tous',
      };

  /// Priorité de type pour la recherche (bonus scoring).
  TerrainMarkerType? get searchPriorityType => switch (this) {
        TerrainDisplayMode.voyageur => TerrainMarkerType.bus,
        TerrainDisplayMode.conducteur => TerrainMarkerType.bus,
        TerrainDisplayMode.intervention => TerrainMarkerType.msr,
        TerrainDisplayMode.supervision => null,
      };

  /// Afficher les stats en format proximité plutôt que flotte.
  bool get preferProximityStats => this == TerrainDisplayMode.voyageur;

  /// Actions disponibles dans la fiche détail (niveau 3).
  List<TerrainDetailAction> get detailActions => switch (this) {
        TerrainDisplayMode.voyageur => const [
            TerrainDetailAction.follow,
            TerrainDetailAction.viewLine,
            TerrainDetailAction.alert,
          ],
        TerrainDisplayMode.conducteur => const [
            TerrainDetailAction.follow,
            TerrainDetailAction.join,
            TerrainDetailAction.contact,
            TerrainDetailAction.share,
          ],
        TerrainDisplayMode.intervention => const [
            TerrainDetailAction.follow,
            TerrainDetailAction.contact,
            TerrainDetailAction.share,
            TerrainDetailAction.history,
            TerrainDetailAction.comments,
          ],
        TerrainDisplayMode.supervision => TerrainDetailAction.values,
      };

  static TerrainDisplayMode resolve({
    required AppUserRole role,
    required DriverWorkspaceMode workspace,
    bool isRegulator = false,
  }) {
    if (role == AppUserRole.passenger) {
      return TerrainDisplayMode.voyageur;
    }
    if (isRegulator) return TerrainDisplayMode.supervision;
    switch (workspace) {
      case DriverWorkspaceMode.intervention:
        return TerrainDisplayMode.intervention;
      case DriverWorkspaceMode.controle:
        return TerrainDisplayMode.intervention;
      case DriverWorkspaceMode.conduite:
        return TerrainDisplayMode.conducteur;
    }
  }
}

/// Actions métier de la fiche véhicule.
enum TerrainDetailAction {
  follow,
  viewLine,
  join,
  share,
  alert,
  comments,
  history,
  contact,
  route,
}

extension TerrainDetailActionX on TerrainDetailAction {
  String get label => switch (this) {
        TerrainDetailAction.follow => 'Suivre',
        TerrainDetailAction.viewLine => 'Voir la ligne',
        TerrainDetailAction.join => 'Rejoindre',
        TerrainDetailAction.share => 'Partager',
        TerrainDetailAction.alert => 'Recevoir une alerte',
        TerrainDetailAction.comments => 'Commentaires',
        TerrainDetailAction.history => 'Historique',
        TerrainDetailAction.contact => 'Contacter',
        TerrainDetailAction.route => 'Itinéraire',
      };
}

/// Mapping label chip → type marqueur.
const terrainFilterTypes = <String, TerrainMarkerType?>{
  'Tous': null,
  'Bus': TerrainMarkerType.bus,
  'Tram': TerrainMarkerType.tram,
  'Contrôle': TerrainMarkerType.controle,
  'Intervention': TerrainMarkerType.msr,
  'Incidents': TerrainMarkerType.incident,
  'Assistance': TerrainMarkerType.assistance,
};
