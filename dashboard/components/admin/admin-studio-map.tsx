"use client";

import type * as React from "react";
import { useEffect, useMemo, useRef, useState } from "react";
import "maplibre-gl/dist/maplibre-gl.css";
import maplibregl from "maplibre-gl";
import {
  AlertTriangle,
  Box,
  BusFront,
  CarTaxiFront,
  Check,
  Flag,
  Layers3,
  LocateFixed,
  Map,
  Maximize2,
  Rotate3D,
  ShieldCheck,
  Store,
  TramFront,
  UsersRound,
} from "lucide-react";
import {
  BABINIERE_STOP,
  NANTES_BUS_ROUTE,
  NANTES_CENTER,
  NANTES_LIGNE00_ROUTE,
  NANTES_TRAM_ROUTE,
} from "@/lib/landing-map-style";
import { attachMapLibreErrorHandler } from "@/lib/maplibre-errors";
import {
  addExtrudedBuildings,
  applyDarkReskin,
  registerMissingImageFallback,
} from "@/components/carte-immersive/map-style";
import { cn } from "@/lib/utils";

type StudioMobilityMapProps = {
  dense?: boolean;
  large?: boolean;
  visibleLayers?: Record<StudioLayerId, boolean>;
};

type MapMode = "3d" | "2d";

export type StudioLayerId =
  | "bus"
  | "tram"
  | "stops"
  | "lines"
  | "travelers"
  | "drivers"
  | "controllers"
  | "shops"
  | "vtc"
  | "incidents";

const DEFAULT_LAYERS: Record<StudioLayerId, boolean> = {
  bus: true,
  tram: true,
  stops: true,
  lines: true,
  travelers: true,
  drivers: true,
  controllers: true,
  shops: true,
  vtc: true,
  incidents: true,
};

const STUDIO_SOURCE_IDS = [
  "studio-routes",
  "studio-stops",
  "studio-vehicles",
  "studio-people",
  "studio-shops",
  "studio-vtc",
  "studio-incidents",
] as const;

const STUDIO_LAYER_IDS = [
  "studio-route-glow",
  "studio-route-line",
  "studio-stops",
  "studio-vehicles",
  "studio-people",
  "studio-shops",
  "studio-vtc",
  "studio-incidents",
  "studio-route-labels",
] as const;

const routeFeatures: GeoJSON.FeatureCollection<GeoJSON.LineString> = {
  type: "FeatureCollection",
  features: [
    {
      ...NANTES_TRAM_ROUTE,
      properties: { id: "tram-1", type: "tram", label: "Tram 1", color: "#60a5fa" },
    },
    {
      ...NANTES_LIGNE00_ROUTE,
      properties: { id: "bus-c6", type: "bus", label: "Bus C6", color: "#34d399" },
    },
    {
      ...NANTES_BUS_ROUTE,
      properties: { id: "bus-c4", type: "bus", label: "Bus C4", color: "#22c55e" },
    },
    {
      type: "Feature",
      properties: { id: "navibus-n1", type: "bus", label: "Navibus", color: "#facc15" },
      geometry: {
        type: "LineString",
        coordinates: [
          [-1.579, 47.199],
          [-1.5706, 47.2015],
          [-1.5625, 47.2048],
          [-1.5536, 47.207],
          [-1.544, 47.2088],
        ],
      },
    },
  ],
};

const stopFeatures: GeoJSON.FeatureCollection<GeoJSON.Point> = {
  type: "FeatureCollection",
  features: [
    featurePoint("Commerce", [-1.5608, 47.2134], { type: "stop", line: "Tram 1" }),
    featurePoint("Gare Nord", [-1.5438, 47.2328], { type: "stop", line: "Tram 1" }),
    featurePoint("Duchesse Anne", [-1.5504, 47.2182], { type: "stop", line: "Tram 1" }),
    featurePoint("Haluchère - Batignolles", [-1.5225, 47.2489], { type: "stop", line: "Bus C6" }),
    featurePoint("Babinière", BABINIERE_STOP, { type: "stop", line: "Bus C6" }),
    featurePoint("Île de Nantes", [-1.5482, 47.2044], { type: "stop", line: "Navibus" }),
  ],
};

const vehicleFeatures: GeoJSON.FeatureCollection<GeoJSON.Point> = {
  type: "FeatureCollection",
  features: [
    featurePoint("Tram 1 · rame 118", [-1.5526, 47.2212], { type: "tram", status: "on_time" }),
    featurePoint("Bus C6 · 4421", [-1.5308, 47.2534], { type: "bus", status: "late" }),
    featurePoint("Bus C4 · 3910", [-1.5365, 47.2456], { type: "bus", status: "on_time" }),
  ],
};

const peopleFeatures: GeoJSON.FeatureCollection<GeoJSON.Point> = {
  type: "FeatureCollection",
  features: [
    featurePoint("Voyageurs anonymisés", [-1.557, 47.2172], { type: "traveler" }),
    featurePoint("Contrôle terrain", [-1.5482, 47.224], { type: "controller" }),
    featurePoint("Conducteur Pro", [-1.531, 47.2535], { type: "driver" }),
  ],
};

const shopFeatures: GeoJSON.FeatureCollection<GeoJSON.Point> = {
  type: "FeatureCollection",
  features: [
    featurePoint("Boulangerie Commerce", [-1.5594, 47.2145], { type: "shop" }),
    featurePoint("Café Gare", [-1.5429, 47.2322], { type: "shop" }),
  ],
};

const vtcFeatures: GeoJSON.FeatureCollection<GeoJSON.Point> = {
  type: "FeatureCollection",
  features: [
    featurePoint("VTC disponible", [-1.5658, 47.2115], { type: "vtc" }),
    featurePoint("Taxi gare", [-1.5415, 47.2317], { type: "vtc" }),
  ],
};

const incidentFeatures: GeoJSON.FeatureCollection<GeoJSON.Point> = {
  type: "FeatureCollection",
  features: [
    featurePoint("Signalement Commerce", [-1.5588, 47.2152], { type: "incident" }),
  ],
};

const filterItems: {
  id: StudioLayerId;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  description: string;
}[] = [
  { id: "bus", label: "Bus", icon: BusFront, description: "Véhicules et lignes bus" },
  { id: "tram", label: "Tram", icon: TramFront, description: "Rames et lignes tram" },
  { id: "stops", label: "Arrêts", icon: Flag, description: "Arrêts et stations" },
  { id: "lines", label: "Lignes", icon: Layers3, description: "Tracés réseau" },
  { id: "travelers", label: "Voyageurs anonymisés", icon: UsersRound, description: "Présence agrégée" },
  { id: "drivers", label: "Conducteurs", icon: BusFront, description: "Sessions Aule Pro" },
  { id: "controllers", label: "Contrôleurs", icon: ShieldCheck, description: "Équipes terrain" },
  { id: "shops", label: "Commerces", icon: Store, description: "Partenaires marketplace" },
  { id: "vtc", label: "VTC/taxis", icon: CarTaxiFront, description: "Mobilité complémentaire" },
  { id: "incidents", label: "Incidents", icon: AlertTriangle, description: "Signalements actifs" },
];

export function StudioMapWorkspace() {
  const [visibleLayers, setVisibleLayers] =
    useState<Record<StudioLayerId, boolean>>(DEFAULT_LAYERS);

  const visibleCount = Object.values(visibleLayers).filter(Boolean).length;

  return (
    <section className="admin-map-workspace">
      <aside className="admin-map-filter-panel">
        <div className="border-b border-white/10 px-4 py-4">
          <h2 className="text-sm font-semibold text-white">Filtres</h2>
          <p className="mt-1 text-xs leading-5 text-slate-500">
            {visibleCount} couches visibles sur Naolib.
          </p>
        </div>
        <div className="space-y-3 p-4">
          <select className="admin-input" defaultValue="Naolib" aria-label="Réseau">
            <option>Naolib</option>
            <option>Réseau en configuration</option>
          </select>
          <div className="grid gap-2">
            {filterItems.map((item) => (
              <MapLayerToggle
                key={item.id}
                checked={visibleLayers[item.id]}
                item={item}
                onChange={() =>
                  setVisibleLayers((current) => ({
                    ...current,
                    [item.id]: !current[item.id],
                  }))
                }
              />
            ))}
          </div>
        </div>
      </aside>

      <section className="admin-map-card">
        <div className="flex flex-wrap items-start justify-between gap-3 border-b border-white/10 px-4 py-3">
          <div>
            <h2 className="text-sm font-semibold text-white">Nantes / Naolib</h2>
            <p className="mt-1 text-xs leading-5 text-slate-500">
              Carte réelle centrée sur Nantes, enrichie avec les couches Aule Studio.
            </p>
          </div>
          <div className="flex flex-wrap gap-2 text-xs text-slate-400">
            <span className="rounded-full border border-emerald-400/25 bg-emerald-500/10 px-3 py-1 font-semibold text-emerald-100">
              OpenFreeMap
            </span>
            <span className="rounded-full border border-white/10 bg-white/[0.04] px-3 py-1 font-semibold">
              {visibleCount}/10 couches
            </span>
          </div>
        </div>
        <div className="p-4">
          <StudioMobilityMap large visibleLayers={visibleLayers} />
        </div>
      </section>
    </section>
  );
}

export function StudioMobilityMap({
  dense,
  large,
  visibleLayers = DEFAULT_LAYERS,
}: StudioMobilityMapProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const [mode, setMode] = useState<MapMode>("3d");
  const [loaded, setLoaded] = useState(false);
  const [selectedFeature, setSelectedFeature] = useState<string>("Naolib · réseau Nantes");
  const [mapError, setMapError] = useState<string | null>(null);

  const activeLayerSummary = useMemo(() => {
    const active = filterItems
      .filter((item) => visibleLayers[item.id])
      .slice(0, 3)
      .map((item) => item.label);
    if (active.length === 0) return "Aucune couche active";
    return active.join(" · ");
  }, [visibleLayers]);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    let map: maplibregl.Map;
    try {
      map = new maplibregl.Map({
        container: containerRef.current,
        style: "https://tiles.openfreemap.org/styles/liberty",
        center: NANTES_CENTER,
        zoom: large ? 13.2 : 12.6,
        pitch: 58,
        bearing: -24,
        attributionControl: { compact: true },
        canvasContextAttributes: { antialias: true },
      });
    } catch {
      queueMicrotask(() => {
        setMapError("La carte n'a pas pu s'initialiser sur cet appareil.");
      });
      return;
    }

    mapRef.current = map;
    const detachErrorHandler = attachMapLibreErrorHandler(map, "AdminStudioMap");
    registerMissingImageFallback(map);
    map.dragRotate.enable();
    map.touchZoomRotate.enableRotation();
    map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), "bottom-right");

    const resizeObserver = new ResizeObserver(() => map.resize());
    resizeObserver.observe(containerRef.current);

    map.on("load", () => {
      try {
        map.setSky({
          "sky-color": "#071120",
          "horizon-color": "#12233d",
          "fog-color": "#071120",
          "sky-horizon-blend": 0.48,
          "horizon-fog-blend": 0.62,
          "fog-ground-blend": 0.58,
        });
      } catch {
        // Older WebGL contexts can ignore sky settings.
      }
      applyDarkReskin(map);
      addExtrudedBuildings(map);
      addStudioSourcesAndLayers(map);
      bindFeatureSelection(map, setSelectedFeature);
      syncVisibility(map, visibleLayers);
      setLoaded(true);
      requestAnimationFrame(() => map.resize());
    });

    return () => {
      resizeObserver.disconnect();
      detachErrorHandler();
      map.remove();
      mapRef.current = null;
    };
  }, [large, visibleLayers]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !loaded) return;
    syncVisibility(map, visibleLayers);
  }, [loaded, visibleLayers]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !loaded) return;
    map.easeTo({
      pitch: mode === "3d" ? 58 : 0,
      bearing: mode === "3d" ? -24 : 0,
      duration: 650,
      essential: true,
    });
    if (map.getLayer("immersive-map-3d-buildings")) {
      map.setLayoutProperty(
        "immersive-map-3d-buildings",
        "visibility",
        mode === "3d" ? "visible" : "none",
      );
    }
  }, [loaded, mode]);

  const resetView = () => {
    mapRef.current?.easeTo({
      center: NANTES_CENTER,
      zoom: large ? 13.2 : 12.6,
      pitch: mode === "3d" ? 58 : 0,
      bearing: mode === "3d" ? -24 : 0,
      duration: 700,
      essential: true,
    });
  };

  return (
    <div
      className={cn(
        "admin-real-map relative overflow-hidden rounded-lg border border-white/10 bg-[#061120]",
        large ? "min-h-[620px]" : dense ? "min-h-[360px]" : "min-h-[460px]",
      )}
      data-map-mode={mode}
    >
      <div ref={containerRef} className="absolute inset-0" data-testid="admin-studio-real-map" />

      {!loaded && !mapError && (
        <div className="absolute inset-0 flex items-center justify-center bg-[#061120] text-sm font-semibold text-slate-300">
          Chargement de la carte Naolib...
        </div>
      )}

      {mapError && (
        <div className="absolute inset-0 flex items-center justify-center bg-[#061120] p-6 text-center text-sm text-red-100">
          {mapError}
        </div>
      )}

      <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(180deg,rgba(6,17,32,.22),rgba(6,17,32,.08)_44%,rgba(6,17,32,.35))]" />

      <div className="absolute left-4 top-4 flex max-w-[calc(100%-150px)] flex-wrap gap-2">
        <MapBadge tone="blue" label="Bus suivis" />
        <MapBadge tone="green" label="Lignes tram" />
        <MapBadge tone="yellow" label="Commerces" />
      </div>

      <div className="absolute right-4 top-4 flex rounded-lg border border-white/10 bg-black/55 p-1 backdrop-blur">
        <button
          className={cn(
            "inline-flex h-9 items-center gap-2 rounded-md px-3 text-xs font-bold transition",
            mode === "3d" ? "bg-blue-500 text-white" : "text-slate-300 hover:bg-white/10",
          )}
          type="button"
          onClick={() => setMode("3d")}
          aria-pressed={mode === "3d"}
        >
          <Rotate3D className="h-4 w-4" />
          3D
        </button>
        <button
          className={cn(
            "inline-flex h-9 items-center gap-2 rounded-md px-3 text-xs font-bold transition",
            mode === "2d" ? "bg-blue-500 text-white" : "text-slate-300 hover:bg-white/10",
          )}
          type="button"
          onClick={() => setMode("2d")}
          aria-pressed={mode === "2d"}
        >
          <Map className="h-4 w-4" />
          2D
        </button>
      </div>

      <div className="absolute bottom-4 left-4 max-w-md rounded-lg border border-white/10 bg-black/60 p-4 backdrop-blur">
        <div className="flex items-center gap-2">
          <Box className="h-4 w-4 text-blue-200" />
          <p className="text-sm font-semibold text-white">Nantes · Naolib · Vue {mode.toUpperCase()}</p>
        </div>
        <p className="mt-1 text-xs leading-5 text-slate-400">
          {selectedFeature} · {activeLayerSummary}
        </p>
      </div>

      <div className="absolute bottom-4 right-4 flex gap-2">
        <button
          className="inline-flex h-10 w-10 items-center justify-center rounded-lg border border-white/10 bg-black/55 text-slate-200 backdrop-blur transition hover:bg-white/10"
          type="button"
          aria-label="Recentrer la carte"
          onClick={resetView}
        >
          <LocateFixed className="h-4 w-4" />
        </button>
        <button
          className="inline-flex h-10 w-10 items-center justify-center rounded-lg border border-white/10 bg-black/55 text-slate-200 backdrop-blur transition hover:bg-white/10"
          type="button"
          aria-label="Agrandir la carte"
        >
          <Maximize2 className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}

function MapLayerToggle({
  checked,
  item,
  onChange,
}: {
  checked: boolean;
  item: (typeof filterItems)[number];
  onChange: () => void;
}) {
  return (
    <button
      className={cn("admin-map-layer-toggle", checked && "active")}
      type="button"
      onClick={onChange}
      aria-pressed={checked}
      aria-label={`${checked ? "Masquer" : "Afficher"} ${item.label}`}
    >
      <span className="admin-map-layer-check">
        {checked && <Check className="h-3.5 w-3.5" />}
      </span>
      <item.icon className="h-4 w-4 text-blue-200" />
      <span className="min-w-0 flex-1">
        <span className="block truncate text-sm font-semibold">{item.label}</span>
        <span className="block truncate text-xs text-slate-500">{item.description}</span>
      </span>
    </button>
  );
}

function addStudioSourcesAndLayers(map: maplibregl.Map) {
  for (const layerId of STUDIO_LAYER_IDS) {
    if (map.getLayer(layerId)) map.removeLayer(layerId);
  }
  for (const sourceId of STUDIO_SOURCE_IDS) {
    if (map.getSource(sourceId)) map.removeSource(sourceId);
  }

  map.addSource("studio-routes", { type: "geojson", data: routeFeatures });
  map.addSource("studio-stops", { type: "geojson", data: stopFeatures });
  map.addSource("studio-vehicles", { type: "geojson", data: vehicleFeatures });
  map.addSource("studio-people", { type: "geojson", data: peopleFeatures });
  map.addSource("studio-shops", { type: "geojson", data: shopFeatures });
  map.addSource("studio-vtc", { type: "geojson", data: vtcFeatures });
  map.addSource("studio-incidents", { type: "geojson", data: incidentFeatures });

  map.addLayer({
    id: "studio-route-glow",
    type: "line",
    source: "studio-routes",
    layout: { "line-cap": "round", "line-join": "round" },
    paint: {
      "line-color": ["get", "color"],
      "line-width": 12,
      "line-opacity": 0.22,
      "line-blur": 4,
    },
  });
  map.addLayer({
    id: "studio-route-line",
    type: "line",
    source: "studio-routes",
    layout: { "line-cap": "round", "line-join": "round" },
    paint: {
      "line-color": ["get", "color"],
      "line-width": ["match", ["get", "type"], "tram", 5, 4],
      "line-opacity": 0.92,
    },
  });
  map.addLayer({
    id: "studio-route-labels",
    type: "symbol",
    source: "studio-routes",
    layout: {
      "symbol-placement": "line",
      "text-field": ["get", "label"],
      "text-size": 11,
      "text-allow-overlap": false,
      "text-ignore-placement": false,
    },
    paint: {
      "text-color": "#dbeafe",
      "text-halo-color": "#061120",
      "text-halo-width": 1.5,
    },
  });
  map.addLayer({
    id: "studio-stops",
    type: "circle",
    source: "studio-stops",
    paint: {
      "circle-radius": ["interpolate", ["linear"], ["zoom"], 11, 4, 15, 7],
      "circle-color": "#dbeafe",
      "circle-stroke-color": "#2563eb",
      "circle-stroke-width": 2,
      "circle-opacity": 0.9,
    },
  });
  map.addLayer({
    id: "studio-vehicles",
    type: "circle",
    source: "studio-vehicles",
    paint: {
      "circle-radius": ["match", ["get", "type"], "tram", 8, 7],
      "circle-color": ["match", ["get", "type"], "tram", "#60a5fa", "#34d399"],
      "circle-stroke-color": "#ffffff",
      "circle-stroke-width": 2,
      "circle-opacity": 0.95,
    },
  });
  map.addLayer({
    id: "studio-people",
    type: "circle",
    source: "studio-people",
    paint: {
      "circle-radius": ["match", ["get", "type"], "controller", 7, "driver", 7, 5],
      "circle-color": ["match", ["get", "type"], "controller", "#a78bfa", "driver", "#38bdf8", "#99f6e4"],
      "circle-stroke-color": "#061120",
      "circle-stroke-width": 1.5,
      "circle-opacity": 0.86,
    },
  });
  map.addLayer({
    id: "studio-shops",
    type: "circle",
    source: "studio-shops",
    paint: {
      "circle-radius": 7,
      "circle-color": "#facc15",
      "circle-stroke-color": "#fff7ed",
      "circle-stroke-width": 2,
      "circle-opacity": 0.95,
    },
  });
  map.addLayer({
    id: "studio-vtc",
    type: "circle",
    source: "studio-vtc",
    paint: {
      "circle-radius": 6,
      "circle-color": "#fb7185",
      "circle-stroke-color": "#ffe4e6",
      "circle-stroke-width": 1.5,
      "circle-opacity": 0.9,
    },
  });
  map.addLayer({
    id: "studio-incidents",
    type: "circle",
    source: "studio-incidents",
    paint: {
      "circle-radius": 8,
      "circle-color": "#f97316",
      "circle-stroke-color": "#fed7aa",
      "circle-stroke-width": 2,
      "circle-opacity": 0.96,
    },
  });
}

function syncVisibility(
  map: maplibregl.Map,
  visibleLayers: Record<StudioLayerId, boolean>,
) {
  setLayerVisibility(map, ["studio-route-line", "studio-route-glow", "studio-route-labels"], visibleLayers.lines);
  setLayerFilter(map, "studio-route-line", routeFilter(visibleLayers));
  setLayerFilter(map, "studio-route-glow", routeFilter(visibleLayers));
  setLayerFilter(map, "studio-route-labels", routeFilter(visibleLayers));
  setLayerVisibility(map, ["studio-stops"], visibleLayers.stops);
  setLayerVisibility(map, ["studio-vehicles"], visibleLayers.bus || visibleLayers.tram);
  setLayerFilter(map, "studio-vehicles", vehicleFilter(visibleLayers));
  setLayerVisibility(map, ["studio-people"], visibleLayers.travelers || visibleLayers.drivers || visibleLayers.controllers);
  setLayerFilter(map, "studio-people", peopleFilter(visibleLayers));
  setLayerVisibility(map, ["studio-shops"], visibleLayers.shops);
  setLayerVisibility(map, ["studio-vtc"], visibleLayers.vtc);
  setLayerVisibility(map, ["studio-incidents"], visibleLayers.incidents);
}

function bindFeatureSelection(
  map: maplibregl.Map,
  setSelectedFeature: (value: string) => void,
) {
  const clickable = [
    "studio-stops",
    "studio-vehicles",
    "studio-people",
    "studio-shops",
    "studio-vtc",
    "studio-incidents",
  ];

  for (const layerId of clickable) {
    map.on("mouseenter", layerId, () => {
      map.getCanvas().style.cursor = "pointer";
    });
    map.on("mouseleave", layerId, () => {
      map.getCanvas().style.cursor = "";
    });
    map.on("click", layerId, (event) => {
      const feature = event.features?.[0];
      const name = feature?.properties?.name;
      if (typeof name === "string") setSelectedFeature(name);
    });
  }
}

function routeFilter(visibleLayers: Record<StudioLayerId, boolean>): maplibregl.FilterSpecification {
  const visibleTypes = [
    visibleLayers.bus ? "bus" : null,
    visibleLayers.tram ? "tram" : null,
  ].filter(Boolean);
  if (visibleTypes.length === 0) return ["==", ["get", "type"], "__none__"];
  return ["in", ["get", "type"], ["literal", visibleTypes]];
}

function vehicleFilter(visibleLayers: Record<StudioLayerId, boolean>): maplibregl.FilterSpecification {
  const visibleTypes = [
    visibleLayers.bus ? "bus" : null,
    visibleLayers.tram ? "tram" : null,
  ].filter(Boolean);
  if (visibleTypes.length === 0) return ["==", ["get", "type"], "__none__"];
  return ["in", ["get", "type"], ["literal", visibleTypes]];
}

function peopleFilter(visibleLayers: Record<StudioLayerId, boolean>): maplibregl.FilterSpecification {
  const visibleTypes = [
    visibleLayers.travelers ? "traveler" : null,
    visibleLayers.drivers ? "driver" : null,
    visibleLayers.controllers ? "controller" : null,
  ].filter(Boolean);
  if (visibleTypes.length === 0) return ["==", ["get", "type"], "__none__"];
  return ["in", ["get", "type"], ["literal", visibleTypes]];
}

function setLayerVisibility(map: maplibregl.Map, layerIds: string[], visible: boolean) {
  for (const layerId of layerIds) {
    if (map.getLayer(layerId)) {
      map.setLayoutProperty(layerId, "visibility", visible ? "visible" : "none");
    }
  }
}

function setLayerFilter(
  map: maplibregl.Map,
  layerId: string,
  filter: maplibregl.FilterSpecification,
) {
  if (map.getLayer(layerId)) map.setFilter(layerId, filter);
}

function featurePoint(
  name: string,
  coordinates: [number, number],
  properties: Record<string, string>,
): GeoJSON.Feature<GeoJSON.Point> {
  return {
    type: "Feature",
    properties: { name, ...properties },
    geometry: { type: "Point", coordinates },
  };
}

function MapBadge({
  tone,
  label,
}: {
  tone: "blue" | "green" | "yellow";
  label: string;
}) {
  return (
    <div className="flex items-center gap-2 rounded-lg border border-white/15 bg-black/55 px-3 py-2 text-xs font-semibold text-white shadow-lg shadow-black/30 backdrop-blur">
      <span
        className={cn(
          "inline-block h-3 w-3 rounded-full",
          tone === "blue" && "bg-blue-300",
          tone === "green" && "bg-emerald-300",
          tone === "yellow" && "bg-amber-300",
        )}
      />
      {label}
    </div>
  );
}
