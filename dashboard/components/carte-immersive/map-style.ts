import type maplibregl from "maplibre-gl";

/** Reskin sombre "premium" du style OpenFreeMap Liberty, appliqué couche par couche. */
export function applyDarkReskin(map: maplibregl.Map) {
  const set = (id: string, prop: string, val: unknown) => {
    try {
      map.setPaintProperty(id, prop, val as never);
    } catch {
      // certaines couches n'ont pas cette propriété selon la version du style
    }
  };
  for (const layer of map.getStyle().layers) {
    const id = layer.id;
    if (layer.type === "background") set(id, "background-color", "#0b1512");
    else if (layer.type === "fill-extrusion") {
      set(id, "fill-extrusion-color", "#1f3b34");
      set(id, "fill-extrusion-opacity", 0.92);
    } else if (layer.type === "fill") {
      if (/building/i.test(id)) set(id, "fill-color", "#16211e");
      else if (/water/i.test(id)) set(id, "fill-color", "#0e2a27");
      else if (/(wood|forest|park|grass|garden|scrub|golf|pitch|cemetery)/i.test(id))
        set(id, "fill-color", "#132420");
      else set(id, "fill-color", "#0d1714");
    } else if (layer.type === "line") {
      if (/water|river|stream|canal/i.test(id)) set(id, "line-color", "#12352f");
      else set(id, "line-color", "#243733");
    } else if (layer.type === "symbol") {
      set(id, "text-color", "#93a7a1");
      set(id, "text-halo-color", "#0a1210");
    }
  }
}

export type MapAtmosphere = {
  period: "dawn" | "day" | "dusk" | "night";
  condition: "clear" | "cloudy" | "fog" | "rain" | "snow" | "storm";
};

/** Recolore la ville 3D selon la lumière ambiante et la météo du hero. */
export function applyAtmosphereReskin(map: maplibregl.Map, atmosphere: MapAtmosphere) {
  const daylight = atmosphere.period === "day" || atmosphere.period === "dawn";
  const wet = atmosphere.condition === "rain" || atmosphere.condition === "storm";
  const muted = atmosphere.condition === "cloudy" || atmosphere.condition === "fog" || wet;
  const snowy = atmosphere.condition === "snow";

  const palette = atmosphere.period === "night"
    ? { ground: "#0b151b", road: "#263740", water: "#102b39", park: "#142923", building: "#263a42", text: "#9fb2b9", halo: "#091116" }
    : atmosphere.period === "dusk"
      ? { ground: "#3f4549", road: "#676661", water: "#375c69", park: "#465b4b", building: "#7a6d61", text: "#e8ded0", halo: "#343a3c" }
      : muted
        ? { ground: "#778188", road: "#9aa0a2", water: "#668895", park: "#748b7b", building: "#a5aaab", text: "#eef2f2", halo: "#657077" }
        : { ground: "#b9b6a6", road: "#ddd6bd", water: "#72aabd", park: "#8fa77e", building: "#d4c7ac", text: "#263b40", halo: "#e8dfc8" };

  if (snowy) {
    palette.ground = daylight ? "#cbd1d2" : "#28343b";
    palette.park = daylight ? "#b8c5c0" : "#243630";
    palette.building = daylight ? "#d9dddc" : "#3b4850";
  }

  const set = (id: string, prop: string, value: unknown) => {
    try {
      map.setPaintProperty(id, prop, value as never);
    } catch {
      // Le style Liberty peut renommer ou omettre certains calques.
    }
  };

  for (const layer of map.getStyle().layers) {
    const id = layer.id;
    if (layer.type === "background") set(id, "background-color", palette.ground);
    else if (layer.type === "fill-extrusion") {
      set(id, "fill-extrusion-color", palette.building);
      set(id, "fill-extrusion-opacity", wet ? 0.82 : 0.9);
    } else if (/^(immersive-map|hero-|section-|screen-|guide-|tracking-)/.test(id)) {
      // Les couches fonctionnelles conservent leurs couleurs métier.
      continue;
    } else if (layer.type === "fill") {
      if (/building/i.test(id)) set(id, "fill-color", palette.building);
      else if (/water/i.test(id)) set(id, "fill-color", palette.water);
      else if (/(wood|forest|park|grass|garden|scrub|golf|pitch|cemetery)/i.test(id)) set(id, "fill-color", palette.park);
      else set(id, "fill-color", palette.ground);
    } else if (layer.type === "line") {
      set(id, "line-color", /water|river|stream|canal/i.test(id) ? palette.water : palette.road);
    } else if (layer.type === "symbol") {
      set(id, "text-color", palette.text);
      set(id, "text-halo-color", palette.halo);
    }
  }
}

export function applyAtmosphereSky(map: maplibregl.Map, atmosphere: MapAtmosphere) {
  const { period, condition } = atmosphere;
  const overcast = condition === "rain" || condition === "storm" || condition === "fog";
  const colors = period === "night"
    ? { sky: "#07121d", horizon: "#17313e", fog: "#0b1720" }
    : period === "dawn"
      ? { sky: overcast ? "#82909b" : "#6f9fbd", horizon: overcast ? "#aa9b91" : "#f0a878", fog: "#a48f82" }
      : period === "dusk"
        ? { sky: overcast ? "#5d6874" : "#6a6988", horizon: overcast ? "#927d78" : "#e18966", fog: "#74656a" }
        : { sky: overcast ? "#84939d" : "#70b8dc", horizon: overcast ? "#b6bdc0" : "#d8edf3", fog: overcast ? "#9aa5aa" : "#c8e1e6" };
  try {
    map.setSky({
      "sky-color": colors.sky,
      "horizon-color": colors.horizon,
      "fog-color": colors.fog,
      "sky-horizon-blend": 0.45,
      "horizon-fog-blend": overcast ? 0.9 : 0.55,
      "fog-ground-blend": overcast ? 0.82 : 0.48,
    });
  } catch {
    // Le ciel custom dépend de la version MapLibre utilisée par le navigateur.
  }
}

/** Ajoute les bâtiments 3D extrudés à partir de la source vectorielle OpenMapTiles du style. */
export function addExtrudedBuildings(map: maplibregl.Map) {
  try {
    const sources = map.getStyle().sources;
    let vectorSourceId: string | null = null;
    for (const key in sources) {
      if (sources[key].type === "vector") {
        vectorSourceId = key;
        break;
      }
    }
    let labelLayerId: string | undefined;
    for (const layer of map.getStyle().layers) {
      if (layer.type === "symbol" && "layout" in layer && layer.layout && "text-field" in layer.layout) {
        labelLayerId = layer.id;
        break;
      }
    }
    if (vectorSourceId && !map.getLayer("immersive-map-3d-buildings")) {
      map.addLayer(
        {
          id: "immersive-map-3d-buildings",
          source: vectorSourceId,
          "source-layer": "building",
          type: "fill-extrusion",
          minzoom: 13,
          paint: {
            "fill-extrusion-color": [
              "interpolate",
              ["linear"],
              ["coalesce", ["get", "render_height"], ["get", "height"], 6],
              0, "#1a2622",
              30, "#22403a",
              90, "#2b5a4f",
              180, "#356e60",
            ],
            "fill-extrusion-height": [
              "interpolate",
              ["linear"],
              ["zoom"],
              13, 0,
              15.5, ["coalesce", ["get", "render_height"], ["get", "height"], 8],
            ],
            "fill-extrusion-base": ["coalesce", ["get", "render_min_height"], ["get", "min_height"], 0],
            "fill-extrusion-opacity": 0.9,
          },
        },
        labelLayerId,
      );
    }
  } catch {
    // le style distant peut évoluer ; on ne bloque jamais le reste de l'init sur cette couche
  }
}

/**
 * Le style de fond OpenFreeMap Liberty affiche des centaines de POI génériques
 * (commerces, restaurants, coiffeurs...) issus d'OSM, sans rapport avec les
 * commerçants partenaires Aule. On ne garde que les POI de transport
 * (poi_transit : bus/tram/rail) et on masque les autres calques poi_*.
 */
export function hideGenericPois(map: maplibregl.Map) {
  for (const layer of map.getStyle().layers) {
    if (layer.id.startsWith("poi_") && layer.id !== "poi_transit") {
      try {
        map.setLayoutProperty(layer.id, "visibility", "none");
      } catch {
        // calque déjà absent selon la version du style
      }
    }
  }
}

/**
 * Le style OpenFreeMap Liberty référence des icônes de POI (atm, bollard, gate...)
 * absentes de son sprite. MapLibre parse ces icônes dès le chargement des tuiles,
 * indépendamment de la visibilité des calques, d'où des warnings "styleimagemissing"
 * même sur les calques poi_* masqués par hideGenericPois. On comble avec une image
 * transparente pour les faire taire sans jamais bloquer le rendu.
 */
export function registerMissingImageFallback(map: maplibregl.Map) {
  map.on("styleimagemissing", (e) => {
    if (map.hasImage(e.id)) return;
    map.addImage(e.id, { width: 1, height: 1, data: new Uint8Array(4) }, { pixelRatio: 1 });
  });
}

export type TransitTraceFeature = {
  id: string;
  type: "bus" | "tram";
  color: string;
  coords: [number, number][];
};

/**
 * Affiche en permanence le tracé réel (rues/rails) suivi par chaque bus/tram de démo, pour rendre
 * visible que les véhicules circulent bien le long d'itinéraires réels et pas de trajets inventés.
 */
export function ensureTransitTracesLayer(map: maplibregl.Map, traces: TransitTraceFeature[]) {
  const data: GeoJSON.FeatureCollection = {
    type: "FeatureCollection",
    features: traces.map((t) => ({
      type: "Feature",
      properties: { id: t.id, type: t.type, color: t.color },
      geometry: { type: "LineString", coordinates: t.coords },
    })),
  };

  const source = map.getSource("immersive-map-transit-traces") as maplibregl.GeoJSONSource | undefined;
  if (source) {
    source.setData(data);
    return;
  }

  map.addSource("immersive-map-transit-traces", { type: "geojson", data });
  map.addLayer({
    id: "immersive-map-transit-traces-line",
    source: "immersive-map-transit-traces",
    type: "line",
    layout: { "line-cap": "round", "line-join": "round" },
    paint: {
      "line-color": ["get", "color"],
      "line-width": ["match", ["get", "type"], "tram", 4, 2.5],
      "line-opacity": 0.55,
      "line-dasharray": ["match", ["get", "type"], "tram", ["literal", [1]], ["literal", [2, 1.4]]],
    },
  });
}

/** Ne garde visibles que les tracés des types de véhicules actuellement affichés (filtres bus/tram). */
export function setTransitTracesFilter(map: maplibregl.Map, visibleTypes: ("bus" | "tram")[]) {
  if (!map.getLayer("immersive-map-transit-traces-line")) return;
  map.setFilter("immersive-map-transit-traces-line", ["in", ["get", "type"], ["literal", visibleTypes]]);
}

export function ensureRouteLayer(map: maplibregl.Map) {
  if (!map.getSource("immersive-map-route")) {
    map.addSource("immersive-map-route", {
      type: "geojson",
      data: { type: "FeatureCollection", features: [] },
    });
    map.addLayer({
      id: "immersive-map-route-line",
      source: "immersive-map-route",
      type: "line",
      layout: { "line-cap": "round", "line-join": "round" },
      paint: { "line-color": "#33bfa3", "line-width": 5, "line-opacity": 0.95 },
    });
  }
}
