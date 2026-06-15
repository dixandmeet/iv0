"use client";

import { useEffect, useRef } from "react";
import "maplibre-gl/dist/maplibre-gl.css";
import maplibregl from "maplibre-gl";
import type { LiveFleetPosition } from "@/lib/types";
import { reliabilityColor, sourceLabel } from "@/lib/types";

const NANTES: [number, number] = [-1.5536, 47.2184];

interface FleetMapProps {
  fleet: LiveFleetPosition[];
  selectedId: string | null;
  onSelect: (id: string | null) => void;
}

export function FleetMap({ fleet, selectedId, onSelect }: FleetMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const markersRef = useRef<Map<string, maplibregl.Marker>>(new Map());

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: {
        version: 8,
        sources: {
          osm: {
            type: "raster",
            tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
            tileSize: 256,
            attribution: "© OpenStreetMap",
          },
        },
        layers: [
          {
            id: "osm",
            type: "raster",
            source: "osm",
          },
        ],
      },
      center: NANTES,
      zoom: 12,
    });

    map.addControl(new maplibregl.NavigationControl(), "top-right");
    mapRef.current = map;

    return () => {
      markersRef.current.forEach((m) => m.remove());
      markersRef.current.clear();
      map.remove();
      mapRef.current = null;
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    markersRef.current.forEach((marker) => marker.remove());
    markersRef.current.clear();

    fleet.forEach((vehicle) => {
      const [lon, lat] = vehicle.geom.coordinates;
      const color = reliabilityColor(vehicle.reliability_score);
      const isSelected = vehicle.id === selectedId;

      const el = document.createElement("button");
      el.type = "button";
      el.title = `Ligne ${vehicle.route_id} · ${sourceLabel(vehicle.source)} · ${vehicle.reliability_score}%`;
      el.style.cssText = `
        width: ${isSelected ? 18 : 14}px;
        height: ${isSelected ? 18 : 14}px;
        border-radius: 50%;
        border: 2px solid ${isSelected ? "#fff" : "rgba(255,255,255,0.8)"};
        background: ${color};
        cursor: pointer;
        box-shadow: 0 1px 4px rgba(0,0,0,0.4);
      `;
      el.onclick = () => onSelect(vehicle.id);

      const marker = new maplibregl.Marker({ element: el })
        .setLngLat([lon, lat])
        .addTo(map);
      markersRef.current.set(vehicle.id, marker);
    });
  }, [fleet, selectedId, onSelect]);

  return (
    <div
      ref={containerRef}
      style={{ width: "100%", height: "100%", minHeight: 400 }}
    />
  );
}
