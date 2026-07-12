import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../services/map_weather_service.dart';

/// Ajoute les bâtiments 3D communs aux cartes vectorielles de l'application.
Future<void> addWeatherBuildings({
  required ml.MapLibreMapController controller,
  required MapWeatherSnapshot weather,
  required String layerId,
}) async {
  final palette = _buildingPalette(weather);
  await controller.addFillExtrusionLayer(
    'openmaptiles',
    layerId,
    ml.FillExtrusionLayerProperties(
      fillExtrusionColor: [
        'interpolate',
        ['linear'],
        [
          'coalesce',
          ['get', 'render_height'],
          ['get', 'height'],
          8,
        ],
        0,
        palette.$1,
        25,
        palette.$2,
        80,
        palette.$3,
        180,
        palette.$4,
      ],
      fillExtrusionHeight: [
        'coalesce',
        ['get', 'render_height'],
        ['get', 'height'],
        8,
      ],
      fillExtrusionBase: [
        'coalesce',
        ['get', 'render_min_height'],
        ['get', 'min_height'],
        0,
      ],
      fillExtrusionOpacity: 0.94,
      fillExtrusionVerticalGradient: true,
    ),
    belowLayerId: 'aeroway-taxiway',
    sourceLayer: 'building',
    minzoom: 14,
    enableInteraction: false,
  );
}

(String, String, String, String) _buildingPalette(MapWeatherSnapshot weather) {
  if (weather.period == MapDayPeriod.night) {
    return ('#17231f', '#244239', '#315d50', '#3a7564');
  }
  if (weather.condition == MapWeatherCondition.rain ||
      weather.condition == MapWeatherCondition.storm ||
      weather.condition == MapWeatherCondition.fog) {
    return ('#7F898D', '#98A0A2', '#ADB3B4', '#C0C5C5');
  }
  if (weather.period == MapDayPeriod.dawn ||
      weather.period == MapDayPeriod.dusk) {
    return ('#75645A', '#90776A', '#AA8A76', '#C69A7F');
  }
  return ('#A99E88', '#C0B49B', '#D1C4A8', '#E1D4B7');
}
