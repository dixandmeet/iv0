"use client";

import { useEffect, useRef } from "react";
import "maplibre-gl/dist/maplibre-gl.css";
import maplibregl from "maplibre-gl";
import { createDarkMapStyle, NANTES_CENTER } from "@/lib/landing-map-style";

type PreviewVehicle = {
  lng: number;
  lat: number;
  color: string;
  pulse?: boolean;
};

// Positions décoratives autour du centre de Nantes.
const VEHICLES: PreviewVehicle[] = [
  { lng: -1.5566, lat: 47.2159, color: "#3b82f6", pulse: true },
  { lng: -1.5486, lat: 47.2206, color: "#7DF7C0" },
  { lng: -1.5588, lat: 47.2232, color: "#3b82f6" },
  { lng: -1.5502, lat: 47.2138, color: "#7DF7C0" },
];

/**
 * Vraie carte (CARTO dark, MapLibre) utilisée comme aperçu du poste de contrôle.
 * Non-interactive : purement illustrative dans le hero.
 */
export function ConsoleMap() {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!containerRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: createDarkMapStyle(),
      center: NANTES_CENTER,
      zoom: 12.6,
      interactive: false,
      attributionControl: false,
    });

    map.addControl(
      new maplibregl.AttributionControl({ compact: true }),
      "bottom-right",
    );

    // Le conteneur (grid) prend sa largeur finale après l'init : recaler la carte.
    const resizeObserver = new ResizeObserver(() => map.resize());
    resizeObserver.observe(containerRef.current);

    map.on("load", () => {
      map.resize();
      VEHICLES.forEach((v) => {
        const el = document.createElement("div");
        el.style.cssText = `position:relative;width:12px;height:12px;`;
        el.innerHTML = `
          ${v.pulse ? `<span style="position:absolute;inset:0;border-radius:9999px;background:${v.color};opacity:.5;animation:aule-ping 1.6s cubic-bezier(0,0,.2,1) infinite;"></span>` : ""}
          <span style="position:absolute;inset:0;border-radius:9999px;background:${v.color};box-shadow:0 0 0 2px #07101f;"></span>
        `;
        new maplibregl.Marker({ element: el }).setLngLat([v.lng, v.lat]).addTo(map);
      });
    });

    return () => {
      resizeObserver.disconnect();
      map.remove();
    };
  }, []);

  return (
    <>
      <style>{`@keyframes aule-ping{75%,100%{transform:scale(2.4);opacity:0}}`}</style>
      <div ref={containerRef} className="h-full w-full" aria-hidden="true" />
    </>
  );
}
