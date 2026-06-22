"use client";

import { useCallback, useEffect, useRef } from "react";
import "maplibre-gl/dist/maplibre-gl.css";
import maplibregl from "maplibre-gl";
import {
  createDarkMapStyle,
  buildRouteLayer,
  buildRouteCasingLayer,
  NANTES_TRAM_ROUTE,
  NANTES_CENTER,
} from "@/lib/landing-map-style";
import type { MsrAgent, MsrMapIncident, MsrStation, MsrZone } from "@/lib/msr-mock-data";

export interface MsrMapLayerToggles {
  zones: boolean;
  agents: boolean;
  incidents: boolean;
  stations: boolean;
}

interface MsrMissionsMapProps {
  zones: MsrZone[];
  agents: MsrAgent[];
  incidents: MsrMapIncident[];
  stations: MsrStation[];
  layers: MsrMapLayerToggles;
  onLayerToggle: (key: keyof MsrMapLayerToggles) => void;
  selectedMissionTeamId?: string | null;
}

export function MsrMissionsMap({
  zones,
  agents,
  incidents,
  stations,
  layers,
  onLayerToggle,
  selectedMissionTeamId,
}: MsrMissionsMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const agentMarkersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
  const incidentMarkersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
  const stationMarkersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
  const zoneMarkersRef = useRef<Map<string, maplibregl.Marker>>(new Map());

  const clearMarkers = useCallback(
    (ref: React.MutableRefObject<Map<string, maplibregl.Marker>>) => {
      ref.current.forEach((m) => m.remove());
      ref.current.clear();
    },
    [],
  );

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: createDarkMapStyle(),
      center: NANTES_CENTER,
      zoom: 12.5,
      attributionControl: false,
    });

    map.addControl(
      new maplibregl.NavigationControl({ showCompass: false }),
      "bottom-left",
    );

    map.on("load", () => {
      map.addSource("tram-t1", {
        type: "geojson",
        data: NANTES_TRAM_ROUTE,
      });
      map.addLayer(buildRouteCasingLayer("tram-t1", 8));
      map.addLayer(
        buildRouteLayer("tram-t1", "#3B82F6", 4),
      );

      zones.forEach((zone) => {
        const sourceId = `zone-${zone.id}`;
        map.addSource(sourceId, {
          type: "geojson",
          data: {
            type: "Feature",
            properties: { teamName: zone.teamName, color: zone.color },
            geometry: {
              type: "Polygon",
              coordinates: [zone.coordinates],
            },
          },
        });
        map.addLayer({
          id: `${sourceId}-fill`,
          type: "fill",
          source: sourceId,
          paint: {
            "fill-color": zone.color,
            "fill-opacity": 0.15,
          },
        });
        map.addLayer({
          id: `${sourceId}-outline`,
          type: "line",
          source: sourceId,
          paint: {
            "line-color": zone.color,
            "line-width": 2,
            "line-opacity": 0.6,
          },
        });
      });
    });

    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, [zones]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !map.isStyleLoaded()) return;

    zones.forEach((zone) => {
      const fillId = `zone-${zone.id}-fill`;
      const outlineId = `zone-${zone.id}-outline`;
      if (map.getLayer(fillId)) {
        map.setLayoutProperty(
          fillId,
          "visibility",
          layers.zones ? "visible" : "none",
        );
        map.setLayoutProperty(
          outlineId,
          "visibility",
          layers.zones ? "visible" : "none",
        );
        const highlight = selectedMissionTeamId === zone.teamId;
        map.setPaintProperty(fillId, "fill-opacity", highlight ? 0.28 : 0.15);
      }
    });
  }, [layers.zones, zones, selectedMissionTeamId]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !map.isStyleLoaded()) return;

    clearMarkers(agentMarkersRef);
    if (!layers.agents) return;

    agents.forEach((agent) => {
      const el = document.createElement("div");
      el.className = "msr-map-agent-marker";
      el.textContent = agent.initials;
      el.title = agent.name;

      const marker = new maplibregl.Marker({ element: el })
        .setLngLat(agent.position)
        .addTo(map);
      agentMarkersRef.current.set(agent.id, marker);
    });
  }, [agents, layers.agents, clearMarkers]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !map.isStyleLoaded()) return;

    clearMarkers(incidentMarkersRef);
    if (!layers.incidents) return;

    incidents.forEach((incident) => {
      const el = document.createElement("div");
      el.className = "msr-map-incident-marker";
      el.innerHTML = '<span class="msr-map-incident-pulse"></span><span>!</span>';
      el.title = incident.title;

      const marker = new maplibregl.Marker({ element: el })
        .setLngLat(incident.position)
        .addTo(map);
      incidentMarkersRef.current.set(incident.id, marker);
    });
  }, [incidents, layers.incidents, clearMarkers]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !map.isStyleLoaded()) return;

    clearMarkers(stationMarkersRef);
    if (!layers.stations) return;

    stations.forEach((station) => {
      const el = document.createElement("div");
      el.className = "msr-map-station-marker";
      el.title = station.name;

      const marker = new maplibregl.Marker({ element: el })
        .setLngLat(station.position)
        .addTo(map);
      stationMarkersRef.current.set(station.id, marker);
    });
  }, [stations, layers.stations, clearMarkers]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !map.isStyleLoaded() || !layers.zones) return;

    clearMarkers(zoneMarkersRef);
    zones.forEach((zone) => {
      const lngs = zone.coordinates.map(([lng]) => lng);
      const lats = zone.coordinates.map(([, lat]) => lat);
      const centerLng = (Math.min(...lngs) + Math.max(...lngs)) / 2;
      const centerLat = (Math.min(...lats) + Math.max(...lats)) / 2;

      const el = document.createElement("div");
      el.className = "msr-map-zone-label";
      el.style.borderColor = `${zone.color}66`;
      el.style.background = `${zone.color}22`;
      el.innerHTML = `<strong>${zone.teamName}</strong><span>${zone.agentCount} agents</span>`;

      const marker = new maplibregl.Marker({ element: el, anchor: "center" })
        .setLngLat([centerLng, centerLat])
        .addTo(map);
      zoneMarkersRef.current.set(zone.id, marker);
    });
  }, [zones, layers.zones, clearMarkers]);

  const legendItems: {
    key: keyof MsrMapLayerToggles;
    label: string;
    color: string;
  }[] = [
    { key: "zones", label: "Zones", color: "#3B82F6" },
    { key: "agents", label: "Agents", color: "#22C55E" },
    { key: "incidents", label: "Incidents", color: "#EF4444" },
    { key: "stations", label: "Stations", color: "#94A3B8" },
  ];

  return (
    <div className="msr-map-panel">
      <div className="msr-map-legend">
        {legendItems.map((item) => (
          <button
            key={item.key}
            type="button"
            className={`msr-legend-item${layers[item.key] ? "" : " msr-legend-item--off"}`}
            onClick={() => onLayerToggle(item.key)}
          >
            <span
              className="msr-legend-dot"
              style={{ background: layers[item.key] ? item.color : "#334155" }}
            />
            {item.label}
          </button>
        ))}
      </div>
      <div ref={containerRef} className="msr-map-container" />
      <div className="msr-map-minimap" aria-hidden />
    </div>
  );
}
