/// Niveaux du bottom sheet radar Terrain.
enum TerrainSheetLevel {
  /// Résumé replié (~90 px).
  summary,

  /// Liste des véhicules proches.
  list,

  /// Fiche détail métier.
  detail,
}

extension TerrainSheetLevelX on TerrainSheetLevel {
  /// Taille snap relative pour DraggableScrollableSheet (base iPhone ~852 px).
  double get snapSize => switch (this) {
        TerrainSheetLevel.summary => 0.11,
        TerrainSheetLevel.list => 0.35,
        TerrainSheetLevel.detail => 0.65,
      };

  double get maxSnapSize => switch (this) {
        TerrainSheetLevel.summary => 0.11,
        TerrainSheetLevel.list => 0.35,
        TerrainSheetLevel.detail => 0.92,
      };
}
