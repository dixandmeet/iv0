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

/** Fond clair lisible — éditeur de ligne (voies, noms de rues, quartiers). */
export function createEditorMapStyle(): StyleSpecification {
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
