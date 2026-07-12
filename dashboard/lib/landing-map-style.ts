import type { LineLayerSpecification, StyleSpecification } from "maplibre-gl";

export const NANTES_CENTER: [number, number] = [-1.5536, 47.2184];

export const FRANCE_CENTER: [number, number] = [2.15, 46.85];

/** Tronçon piéton vers l'arrêt Commerce. */
export const NANTES_WALK_ROUTE: GeoJSON.Feature<GeoJSON.LineString> = {
  type: "Feature",
  properties: { name: "Marche", color: "#94A3B8" },
  geometry: {
    type: "LineString",
    coordinates: [
      [-1.5674, 47.2052],
      [-1.5662, 47.2064],
      [-1.5651, 47.2076],
      [-1.5641, 47.2088],
      [-1.5632, 47.2100],
      [-1.5624, 47.2112],
      [-1.5616, 47.2124],
      [-1.5608, 47.2134],
    ],
  },
};

/** Tracé du tramway ligne 1 à Nantes (Commerce → Gare Nord), calé sur le réseau viaire. */
export const NANTES_TRAM_ROUTE: GeoJSON.Feature<GeoJSON.LineString> = {
  type: "Feature",
  properties: { name: "Tram 1", color: "#1B66F5" },
  geometry: {
    type: "LineString",
    coordinates: [
      [-1.5608, 47.2134],
      [-1.5600, 47.2142],
      [-1.5591, 47.2150],
      [-1.5581, 47.2159],
      [-1.5570, 47.2169],
      [-1.5558, 47.2180],
      [-1.5546, 47.2192],
      [-1.5534, 47.2204],
      [-1.5522, 47.2216],
      [-1.5510, 47.2229],
      [-1.5498, 47.2243],
      [-1.5486, 47.2258],
      [-1.5474, 47.2274],
      [-1.5462, 47.2291],
      [-1.5450, 47.2309],
      [-1.5438, 47.2328],
      [-1.5426, 47.2348],
      [-1.5414, 47.2369],
      [-1.5402, 47.2391],
      [-1.5390, 47.2414],
      [-1.5378, 47.2438],
    ],
  },
};

/** Correspondance bus C4 depuis Gare Nord. */
export const NANTES_BUS_ROUTE: GeoJSON.Feature<GeoJSON.LineString> = {
  type: "Feature",
  properties: { name: "Bus C4", color: "#8B5CF6" },
  geometry: {
    type: "LineString",
    coordinates: [
      [-1.5378, 47.2438],
      [-1.5368, 47.2452],
      [-1.5358, 47.2466],
      [-1.5348, 47.2480],
      [-1.5338, 47.2494],
      [-1.5328, 47.2508],
    ],
  },
};

/**
 * Coordonnées réelles de l'arrêt Babinière (terminus nord-est de la ligne 1 du
 * tramway nantais, à La Chapelle-sur-Erdre). Source : 47°15′33″N, 1°32′48″O.
 */
export const BABINIERE_STOP: [number, number] = [-1.5467, 47.2592];

/**
 * Tracé de la navette « Ligne 00 · Babinière ↔ Ranzay » (données démo dashboard),
 * desservant Newton, Ampère, Batignolles, Beaujoire, Halvêque, Buron et
 * Haluchère - Batignolles. Stations réelles calées sur leurs coordonnées
 * (Wikipédia / GTFS Naolib), arrêts intermédiaires interpolés.
 */
export const NANTES_LIGNE00_ROUTE: GeoJSON.Feature<GeoJSON.LineString> = {
  type: "Feature",
  properties: { name: "Ligne 00 · Babinière ↔ Ranzay", color: "#33BFA3" },
  geometry: {
    type: "LineString",
    coordinates: [
      [-1.5467, 47.2592], // Babinière (terminus)
      [-1.5438, 47.2594],
      [-1.541, 47.2596], // Newton
      [-1.538, 47.2597],
      [-1.535, 47.2598], // Ampère
      [-1.5325, 47.2597],
      [-1.53, 47.2595], // Batignolles
      [-1.5278, 47.2592],
      [-1.5258, 47.2589], // Beaujoire
      [-1.5232, 47.2581],
      [-1.5206, 47.2572], // Halvêque
      [-1.5208, 47.2551],
      [-1.5212, 47.253], // Buron
      [-1.5218, 47.251],
      [-1.5225, 47.2489], // Haluchère - Batignolles
      [-1.525, 47.2503],
      [-1.5278, 47.252],
      [-1.5308, 47.2536], // Ranzay (terminus)
    ],
  },
};

export type MapBounds = [[number, number], [number, number]];

/** Extrait un tronçon d'un itinéraire ligne. */
export function sliceLineRoute(
  route: GeoJSON.Feature<GeoJSON.LineString>,
  from = 0,
  to?: number,
): GeoJSON.Feature<GeoJSON.LineString> {
  return {
    type: "Feature",
    properties: route.properties,
    geometry: {
      type: "LineString",
      coordinates: route.geometry.coordinates.slice(from, to),
    },
  };
}

/** Calcule une bounding box à partir de coordonnées [lng, lat]. */
export function boundsFromCoordinates(
  coordinates: Array<[number, number]>,
): MapBounds {
  const lngs = coordinates.map(([lng]) => lng);
  const lats = coordinates.map(([, lat]) => lat);
  return [
    [Math.min(...lngs), Math.min(...lats)],
    [Math.max(...lngs), Math.max(...lats)],
  ];
}

export type LandingMapMarker = {
  id: string;
  lng: number;
  lat: number;
  label: string;
  status?: "pilot" | "coming";
  badge?: string;
  accent?: string;
  offset?: [number, number];
  variant?: "default" | "stop";
};

export type LandingMapVehicle = {
  id: string;
  lng: number;
  lat: number;
  color: string;
  label: string;
  pulse?: boolean;
};

export function createDarkMapStyle(): StyleSpecification {
  return {
    version: 8,
    sources: {
      carto: {
        type: "raster",
        tiles: [
          "https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png",
        ],
        tileSize: 256,
        attribution:
          '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/">CARTO</a>',
      },
    },
    layers: [
      {
        id: "carto-dark",
        type: "raster",
        source: "carto",
      },
    ],
  };
}

/** Fond clair avec voies et labels — fiches arrêt / station. */
export function createDetailMapStyle(): StyleSpecification {
  return {
    version: 8,
    sources: {
      carto: {
        type: "raster",
        tiles: [
          "https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png",
        ],
        tileSize: 256,
        attribution:
          '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/">CARTO</a>',
      },
    },
    layers: [
      {
        id: "carto-voyager",
        type: "raster",
        source: "carto",
      },
    ],
  };
}

export function buildRouteCasingLayer(
  id: string,
  width = 12,
  color = "#ffffff",
): LineLayerSpecification {
  return {
    id: `${id}-casing`,
    type: "line",
    source: id,
    paint: {
      "line-color": color,
      "line-width": width,
      "line-opacity": 0.95,
    },
    layout: {
      "line-cap": "round",
      "line-join": "round",
    },
  };
}

export function buildRouteGlowLayer(
  id: string,
  color: string,
  width = 14,
): LineLayerSpecification {
  return {
    id: `${id}-glow`,
    type: "line",
    source: id,
    paint: {
      "line-color": color,
      "line-width": width,
      "line-opacity": 0.28,
      "line-blur": 3,
    },
    layout: {
      "line-cap": "round",
      "line-join": "round",
    },
  };
}

export function buildRouteLayer(
  id: string,
  color: string,
  width = 5,
  dashed = false,
): LineLayerSpecification {
  return {
    id,
    type: "line",
    source: id,
    paint: {
      "line-color": color,
      "line-width": width,
      "line-opacity": dashed ? 0.85 : 0.95,
      ...(dashed ? { "line-dasharray": [1.5, 1.2] as [number, number] } : {}),
    },
    layout: {
      "line-cap": "round",
      "line-join": "round",
    },
  };
}
