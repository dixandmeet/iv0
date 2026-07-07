/// Couches cartographiques activables sur la page Terrain.
class TerrainMapLayers {
  final bool vehicles;
  final bool stations;
  final bool incidents;
  final bool lines;
  final bool releves;
  final bool controle;
  final bool msr;
  final bool zones;

  const TerrainMapLayers({
    this.vehicles = true,
    this.stations = true,
    this.incidents = true,
    this.lines = false,
    this.releves = false,
    this.controle = true,
    this.msr = true,
    this.zones = false,
  });

  TerrainMapLayers copyWith({
    bool? vehicles,
    bool? stations,
    bool? incidents,
    bool? lines,
    bool? releves,
    bool? controle,
    bool? msr,
    bool? zones,
  }) {
    return TerrainMapLayers(
      vehicles: vehicles ?? this.vehicles,
      stations: stations ?? this.stations,
      incidents: incidents ?? this.incidents,
      lines: lines ?? this.lines,
      releves: releves ?? this.releves,
      controle: controle ?? this.controle,
      msr: msr ?? this.msr,
      zones: zones ?? this.zones,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TerrainMapLayers &&
      vehicles == other.vehicles &&
      stations == other.stations &&
      incidents == other.incidents &&
      lines == other.lines &&
      releves == other.releves &&
      controle == other.controle &&
      msr == other.msr &&
      zones == other.zones;

  @override
  int get hashCode => Object.hash(
        vehicles,
        stations,
        incidents,
        lines,
        releves,
        controle,
        msr,
        zones,
      );
}
