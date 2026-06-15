"use client";

import {
  forwardRef,
  useCallback,
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
} from "react";
import { useTheme } from "next-themes";
import "maplibre-gl/dist/maplibre-gl.css";
import maplibregl from "maplibre-gl";
import type { GtfsStop, LiveFleetPosition, NetworkIncident } from "@/lib/types";
import { reliabilityColor, severityColor, sourceLabel } from "@/lib/types";
import { pointCoordinates } from "@/lib/geo";
import { createDarkMapStyle, NANTES_CENTER } from "@/lib/landing-map-style";

export interface FleetMapHandle {
  flyToVehicle: (vehicleId: string) => void;
  flyToIncident: (incidentId: string) => void;
}

interface FleetMapProps {
  fleet: LiveFleetPosition[];
  incidents?: NetworkIncident[];
  stops?: GtfsStop[];
  selectedVehicleId?: string | null;
  selectedIncidentId?: string | null;
  onSelectVehicle?: (id: string | null) => void;
  onSelectIncident?: (id: string | null) => void;
  incidentsOnly?: boolean;
  routeFilter?: string;
  showStops?: boolean;
}

function osmStyle(): maplibregl.StyleSpecification {
  return {
    version: 8,
    sources: {
      osm: {
        type: "raster",
        tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
        tileSize: 256,
        attribution: "© OpenStreetMap",
      },
    },
    layers: [{ id: "osm", type: "raster", source: "osm" }],
  };
}

function mapStyle(isDark: boolean): maplibregl.StyleSpecification {
  return isDark ? createDarkMapStyle() : osmStyle();
}

export const FleetMap = forwardRef<FleetMapHandle, FleetMapProps>(
  function FleetMap(
    {
      fleet,
      incidents = [],
      stops = [],
      selectedVehicleId,
      selectedIncidentId,
      onSelectVehicle,
      onSelectIncident,
      incidentsOnly = false,
      routeFilter = "all",
      showStops = true,
    },
    ref,
  ) {
    const containerRef = useRef<HTMLDivElement>(null);
    const mapRef = useRef<maplibregl.Map | null>(null);
    const vehicleMarkersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
    const incidentMarkersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
    const stopMarkersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
    const initialFitDoneRef = useRef(false);
    const { resolvedTheme } = useTheme();

    const isDark = resolvedTheme === "dark";

    const clearVehicleMarkers = useCallback(() => {
      vehicleMarkersRef.current.forEach((marker) => marker.remove());
      vehicleMarkersRef.current.clear();
    }, []);

    const clearIncidentMarkers = useCallback(() => {
      incidentMarkersRef.current.forEach((marker) => marker.remove());
      incidentMarkersRef.current.clear();
    }, []);

    const clearStopMarkers = useCallback(() => {
      stopMarkersRef.current.forEach((marker) => marker.remove());
      stopMarkersRef.current.clear();
    }, []);

    const visibleFleet = useMemo(() => {
      if (routeFilter === "all") return fleet;
      return fleet.filter((v) => v.route_id === routeFilter);
    }, [fleet, routeFilter]);

    const syncVehicleMarkers = useCallback(() => {
      const map = mapRef.current;
      if (!map || !map.isStyleLoaded() || incidentsOnly) return;

      clearVehicleMarkers();

      visibleFleet.forEach((vehicle) => {
        const coords = pointCoordinates(vehicle.geom);
        if (!coords) return;

        const [lon, lat] = coords;
        const color = reliabilityColor(vehicle.reliability_score);
        const isSelected = vehicle.id === selectedVehicleId;
        const rotation = vehicle.heading ?? 0;
        const hasDelay =
          vehicle.estimated_delay_seconds != null && vehicle.estimated_delay_seconds > 300;

        const el = document.createElement("button");
        el.type = "button";
        el.title = `Ligne ${vehicle.route_id} · ${sourceLabel(vehicle.source)} · ${vehicle.reliability_score}%`;
        el.style.cssText = `
          width: ${isSelected ? 22 : 18}px;
          height: ${isSelected ? 22 : 18}px;
          border-radius: 4px;
          border: 2px solid ${hasDelay ? "#ea580c" : isSelected ? "#fff" : "rgba(255,255,255,0.8)"};
          background: ${color};
          cursor: pointer;
          box-shadow: 0 1px 4px rgba(0,0,0,0.4);
          transform: rotate(${rotation}deg);
          clip-path: polygon(50% 0%, 100% 75%, 50% 100%, 0% 75%);
        `;
        el.onclick = () => onSelectVehicle?.(vehicle.id);

        const marker = new maplibregl.Marker({ element: el })
          .setLngLat([lon, lat])
          .addTo(map);
        vehicleMarkersRef.current.set(vehicle.id, marker);
      });
    }, [
      visibleFleet,
      selectedVehicleId,
      onSelectVehicle,
      incidentsOnly,
      clearVehicleMarkers,
    ]);

    const syncStopMarkers = useCallback(() => {
      const map = mapRef.current;
      if (!map || !map.isStyleLoaded() || incidentsOnly || !showStops) return;

      clearStopMarkers();

      const zoom = map.getZoom();
      if (zoom < 13) return;

      stops.slice(0, 200).forEach((stop) => {
        const coords = pointCoordinates(stop.geom);
        if (!coords) return;

        const el = document.createElement("div");
        el.style.cssText = `
          width: 6px;
          height: 6px;
          border-radius: 50%;
          background: rgba(100,116,139,0.6);
          border: 1px solid rgba(255,255,255,0.5);
        `;
        el.title = stop.stop_name;

        const marker = new maplibregl.Marker({ element: el })
          .setLngLat(coords)
          .addTo(map);
        stopMarkersRef.current.set(stop.stop_id, marker);
      });
    }, [stops, incidentsOnly, showStops, clearStopMarkers]);

    const syncIncidentMarkers = useCallback(() => {
      const map = mapRef.current;
      if (!map || !map.isStyleLoaded()) return;

      clearIncidentMarkers();

      incidents.forEach((incident) => {
        const coords = pointCoordinates(incident.geom);
        if (!coords) return;

        const [lon, lat] = coords;
        const color = severityColor(incident.severity);
        const isSelected = incident.id === selectedIncidentId;

        const el = document.createElement("button");
        el.type = "button";
        el.title = incident.title;
        el.style.cssText = `
          width: 0;
          height: 0;
          border-left: ${isSelected ? 10 : 8}px solid transparent;
          border-right: ${isSelected ? 10 : 8}px solid transparent;
          border-bottom: ${isSelected ? 16 : 14}px solid ${color};
          cursor: pointer;
          filter: drop-shadow(0 1px 3px rgba(0,0,0,0.5));
          background: transparent;
          padding: 0;
        `;
        el.onclick = () => onSelectIncident?.(incident.id);

        const marker = new maplibregl.Marker({ element: el, anchor: "bottom" })
          .setLngLat([lon, lat])
          .addTo(map);
        incidentMarkersRef.current.set(incident.id, marker);
      });
    }, [
      incidents,
      selectedIncidentId,
      onSelectIncident,
      clearIncidentMarkers,
    ]);

    const syncAllMarkers = useCallback(() => {
      syncVehicleMarkers();
      syncIncidentMarkers();
      syncStopMarkers();
    }, [syncVehicleMarkers, syncIncidentMarkers, syncStopMarkers]);

    const syncAllMarkersRef = useRef(syncAllMarkers);
    syncAllMarkersRef.current = syncAllMarkers;

    const isDarkRef = useRef(isDark);
    isDarkRef.current = isDark;

    useImperativeHandle(ref, () => ({
      flyToVehicle(vehicleId: string) {
        const vehicle = fleet.find((v) => v.id === vehicleId);
        const coords = vehicle ? pointCoordinates(vehicle.geom) : null;
        if (!coords || !mapRef.current) return;
        mapRef.current.flyTo({ center: coords, zoom: 15, duration: 800 });
      },
      flyToIncident(incidentId: string) {
        const incident = incidents.find((i) => i.id === incidentId);
        const coords = incident ? pointCoordinates(incident.geom) : null;
        if (!coords || !mapRef.current) return;
        mapRef.current.flyTo({ center: coords, zoom: 14, duration: 800 });
      },
    }));

    // Init carte une fois le thème résolu
    useEffect(() => {
      if (!containerRef.current || mapRef.current || !resolvedTheme) return;

      const map = new maplibregl.Map({
        container: containerRef.current,
        style: mapStyle(isDarkRef.current),
        center: NANTES_CENTER,
        zoom: 12,
      });

      map.addControl(new maplibregl.NavigationControl(), "top-right");
      mapRef.current = map;

      map.on("load", () => syncAllMarkersRef.current());

      return () => {
        clearVehicleMarkers();
        clearIncidentMarkers();
        clearStopMarkers();
        map.remove();
        mapRef.current = null;
        initialFitDoneRef.current = false;
      };
    }, [resolvedTheme, clearVehicleMarkers, clearIncidentMarkers, clearStopMarkers]);

    // Changement de thème (après init)
    const themeInitializedRef = useRef(false);
    useEffect(() => {
      const map = mapRef.current;
      if (!map || !resolvedTheme) return;

      if (!themeInitializedRef.current) {
        themeInitializedRef.current = true;
        return;
      }

      map.setStyle(mapStyle(isDark));
      map.once("style.load", () => syncAllMarkersRef.current());
    }, [isDark, resolvedTheme]);

    useEffect(() => {
      syncStopMarkers();
    }, [syncStopMarkers]);

    // Sync marqueurs quand les données changent
    useEffect(() => {
      syncVehicleMarkers();
    }, [syncVehicleMarkers]);

    useEffect(() => {
      syncIncidentMarkers();
    }, [syncIncidentMarkers]);

    // Zoom sur sélection
    useEffect(() => {
      const map = mapRef.current;
      if (!map || !map.isStyleLoaded()) return;

      if (selectedVehicleId) {
        const vehicle = fleet.find((v) => v.id === selectedVehicleId);
        const coords = vehicle ? pointCoordinates(vehicle.geom) : null;
        if (coords) map.flyTo({ center: coords, zoom: 14, duration: 600 });
        return;
      }

      if (selectedIncidentId) {
        const incident = incidents.find((i) => i.id === selectedIncidentId);
        const coords = incident ? pointCoordinates(incident.geom) : null;
        if (coords) map.flyTo({ center: coords, zoom: 14, duration: 600 });
      }
    }, [selectedVehicleId, selectedIncidentId, fleet, incidents]);

    // Fit bounds initial uniquement (pas à chaque poll)
    useEffect(() => {
      const map = mapRef.current;
      if (!map || !map.isStyleLoaded() || initialFitDoneRef.current) return;

      const points: [number, number][] = [];
      if (!incidentsOnly) {
        visibleFleet.forEach((v) => {
          const coords = pointCoordinates(v.geom);
          if (coords) points.push(coords);
        });
      }
      incidents.forEach((i) => {
        const coords = pointCoordinates(i.geom);
        if (coords) points.push(coords);
      });

      if (points.length === 0) return;

      initialFitDoneRef.current = true;

      if (points.length === 1) {
        map.flyTo({ center: points[0], zoom: 13, duration: 600 });
        return;
      }

      const bounds = new maplibregl.LngLatBounds();
      points.forEach((p) => bounds.extend(p));
      map.fitBounds(bounds, { padding: 60, maxZoom: 14, duration: 600 });
    }, [visibleFleet, incidents, incidentsOnly]);

    return (
      <div className="relative h-full w-full min-h-[400px]">
        <div ref={containerRef} className="h-full w-full" />
        <div className="pointer-events-none absolute bottom-3 left-3 rounded-lg border border-border bg-card/90 px-3 py-2 text-xs shadow-sm backdrop-blur-sm">
          <p className="mb-1.5 font-medium text-foreground">Légende</p>
          {!incidentsOnly && (
            <div className="mb-1.5 space-y-1 text-muted-foreground">
              <LegendDot color="#16a34a" label="Fiabilité ≥ 80%" />
              <LegendDot color="#ea580c" label="Fiabilité 50–79%" />
              <LegendDot color="#dc2626" label="Fiabilité < 50%" />
            </div>
          )}
          <div className="space-y-1 text-muted-foreground">
            <LegendTriangle color="#1b66f5" label="Info" />
            <LegendTriangle color="#ea580c" label="Alerte" />
            <LegendTriangle color="#dc2626" label="Critique" />
          </div>
        </div>
      </div>
    );
  },
);

function LegendDot({ color, label }: { color: string; label: string }) {
  return (
    <div className="flex items-center gap-2">
      <span
        className="inline-block h-2.5 w-2.5 rounded-full border border-white/80"
        style={{ background: color }}
      />
      {label}
    </div>
  );
}

function LegendTriangle({ color, label }: { color: string; label: string }) {
  return (
    <div className="flex items-center gap-2">
      <span
        className="inline-block h-0 w-0 border-x-[5px] border-b-[8px] border-x-transparent"
        style={{ borderBottomColor: color }}
      />
      {label}
    </div>
  );
}
