"use client";

import {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useRef,
} from "react";
import { useTheme } from "next-themes";
import "maplibre-gl/dist/maplibre-gl.css";
import maplibregl from "maplibre-gl";
import type { LiveFleetPosition, NetworkIncident } from "@/lib/types";
import { reliabilityColor, severityColor, sourceLabel } from "@/lib/types";
import { createDarkMapStyle, NANTES_CENTER } from "@/lib/landing-map-style";

export interface FleetMapHandle {
  flyToVehicle: (vehicleId: string) => void;
  flyToIncident: (incidentId: string) => void;
}

interface FleetMapProps {
  fleet: LiveFleetPosition[];
  incidents?: NetworkIncident[];
  selectedVehicleId?: string | null;
  selectedIncidentId?: string | null;
  onSelectVehicle?: (id: string | null) => void;
  onSelectIncident?: (id: string | null) => void;
  incidentsOnly?: boolean;
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

export const FleetMap = forwardRef<FleetMapHandle, FleetMapProps>(
  function FleetMap(
    {
      fleet,
      incidents = [],
      selectedVehicleId,
      selectedIncidentId,
      onSelectVehicle,
      onSelectIncident,
      incidentsOnly = false,
    },
    ref,
  ) {
    const containerRef = useRef<HTMLDivElement>(null);
    const mapRef = useRef<maplibregl.Map | null>(null);
    const vehicleMarkersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
    const incidentMarkersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
    const { resolvedTheme } = useTheme();

    useImperativeHandle(ref, () => ({
      flyToVehicle(vehicleId: string) {
        const vehicle = fleet.find((v) => v.id === vehicleId);
        if (!vehicle || !mapRef.current) return;
        const [lon, lat] = vehicle.geom.coordinates;
        mapRef.current.flyTo({ center: [lon, lat], zoom: 15, duration: 800 });
      },
      flyToIncident(incidentId: string) {
        const incident = incidents.find((i) => i.id === incidentId);
        if (!incident?.geom || !mapRef.current) return;
        const [lon, lat] = incident.geom.coordinates;
        mapRef.current.flyTo({ center: [lon, lat], zoom: 14, duration: 800 });
      },
    }));

    useEffect(() => {
      if (!containerRef.current || mapRef.current) return;

      const map = new maplibregl.Map({
        container: containerRef.current,
        style: resolvedTheme === "dark" ? createDarkMapStyle() : osmStyle(),
        center: NANTES_CENTER,
        zoom: 12,
      });

      map.addControl(new maplibregl.NavigationControl(), "top-right");
      mapRef.current = map;

      return () => {
        vehicleMarkersRef.current.forEach((m) => m.remove());
        vehicleMarkersRef.current.clear();
        incidentMarkersRef.current.forEach((m) => m.remove());
        incidentMarkersRef.current.clear();
        map.remove();
        mapRef.current = null;
      };
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    useEffect(() => {
      const map = mapRef.current;
      if (!map) return;
      map.setStyle(resolvedTheme === "dark" ? createDarkMapStyle() : osmStyle());
    }, [resolvedTheme]);

    useEffect(() => {
      const map = mapRef.current;
      if (!map || incidentsOnly) return;

      vehicleMarkersRef.current.forEach((marker) => marker.remove());
      vehicleMarkersRef.current.clear();

      fleet.forEach((vehicle) => {
        const [lon, lat] = vehicle.geom.coordinates;
        const color = reliabilityColor(vehicle.reliability_score);
        const isSelected = vehicle.id === selectedVehicleId;
        const rotation = vehicle.heading ?? 0;

        const el = document.createElement("button");
        el.type = "button";
        el.title = `Ligne ${vehicle.route_id} · ${sourceLabel(vehicle.source)} · ${vehicle.reliability_score}%`;
        el.style.cssText = `
          width: ${isSelected ? 20 : 16}px;
          height: ${isSelected ? 20 : 16}px;
          border-radius: 50%;
          border: 2px solid ${isSelected ? "#fff" : "rgba(255,255,255,0.8)"};
          background: ${color};
          cursor: pointer;
          box-shadow: 0 1px 4px rgba(0,0,0,0.4);
          transform: rotate(${rotation}deg);
        `;
        el.onclick = () => onSelectVehicle?.(vehicle.id);

        const marker = new maplibregl.Marker({ element: el })
          .setLngLat([lon, lat])
          .addTo(map);
        vehicleMarkersRef.current.set(vehicle.id, marker);
      });
    }, [fleet, selectedVehicleId, onSelectVehicle, incidentsOnly]);

    useEffect(() => {
      const map = mapRef.current;
      if (!map) return;

      incidentMarkersRef.current.forEach((marker) => marker.remove());
      incidentMarkersRef.current.clear();

      incidents.forEach((incident) => {
        if (!incident.geom) return;
        const [lon, lat] = incident.geom.coordinates;
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
    }, [incidents, selectedIncidentId, onSelectIncident]);

    useEffect(() => {
      const map = mapRef.current;
      if (!map || fleet.length === 0) return;

      if (selectedVehicleId) {
        const vehicle = fleet.find((v) => v.id === selectedVehicleId);
        if (vehicle) {
          const [lon, lat] = vehicle.geom.coordinates;
          map.flyTo({ center: [lon, lat], zoom: 14, duration: 600 });
        }
        return;
      }

      if (selectedIncidentId) {
        const incident = incidents.find((i) => i.id === selectedIncidentId);
        if (incident?.geom) {
          const [lon, lat] = incident.geom.coordinates;
          map.flyTo({ center: [lon, lat], zoom: 14, duration: 600 });
        }
        return;
      }

      if (fleet.length === 1) {
        const [lon, lat] = fleet[0].geom.coordinates;
        map.flyTo({ center: [lon, lat], zoom: 13, duration: 600 });
        return;
      }

      const bounds = new maplibregl.LngLatBounds();
      fleet.forEach((v) => bounds.extend(v.geom.coordinates));
      incidents.forEach((i) => {
        if (i.geom) bounds.extend(i.geom.coordinates);
      });
      if (!bounds.isEmpty()) {
        map.fitBounds(bounds, { padding: 60, maxZoom: 14, duration: 600 });
      }
    }, [fleet, incidents, selectedVehicleId, selectedIncidentId]);

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
