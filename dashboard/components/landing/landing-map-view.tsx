"use client";

import { useEffect, useRef, useState, type MutableRefObject } from "react";
import { useInView } from "framer-motion";
import "maplibre-gl/dist/maplibre-gl.css";
import maplibregl from "maplibre-gl";
import { cn } from "@/lib/utils";
import {
  buildRouteGlowLayer,
  buildRouteLayer,
  createDarkMapStyle,
  type LandingMapMarker,
  type LandingMapVehicle,
  type MapBounds,
} from "@/lib/landing-map-style";

type RouteConfig = {
  id: string;
  data: GeoJSON.Feature<GeoJSON.LineString>;
  color: string;
  width?: number;
  dashed?: boolean;
  glow?: boolean;
};

type LandingMapViewProps = {
  center: [number, number];
  zoom: number;
  className?: string;
  interactive?: boolean;
  eager?: boolean;
  markers?: LandingMapMarker[];
  routes?: RouteConfig[];
  vehicles?: LandingMapVehicle[];
  showUserLocation?: { lng: number; lat: number };
  ariaLabel?: string;
  minZoom?: number;
  maxZoom?: number;
  bearing?: number;
  pitch?: number;
  bounds?: MapBounds;
  fitPadding?: number;
};

function createMarkerElement(marker: LandingMapMarker) {
  const isPilot = marker.status === "pilot";
  const el = document.createElement("div");
  el.className = "landing-map-marker";
  el.innerHTML = `
    <div class="landing-map-marker-inner ${isPilot ? "landing-map-marker-pilot" : "landing-map-marker-coming"}">
      ${isPilot ? '<span class="landing-map-marker-pulse" aria-hidden="true"></span>' : ""}
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
        <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/>
        <circle cx="12" cy="10" r="3"/>
      </svg>
      <span class="landing-map-marker-label">${marker.label}</span>
      ${marker.badge ? `<span class="landing-map-marker-badge">${marker.badge}</span>` : ""}
    </div>
  `;
  return el;
}

function createVehicleElement(vehicle: LandingMapVehicle) {
  const el = document.createElement("div");
  el.className = "landing-map-vehicle";
  el.title = vehicle.label;
  el.innerHTML = `
    <span class="landing-map-vehicle-dot ${vehicle.pulse ? "landing-map-vehicle-pulse" : ""}" style="background:${vehicle.color};box-shadow:0 0 12px ${vehicle.color}88"></span>
  `;
  return el;
}

function createUserLocationElement() {
  const el = document.createElement("div");
  el.className = "landing-map-user";
  el.innerHTML = `
    <span class="landing-map-user-ring" aria-hidden="true"></span>
    <span class="landing-map-user-dot" aria-hidden="true"></span>
  `;
  return el;
}

function removeRoute(map: maplibregl.Map, id: string) {
  const layerIds = [id, `${id}-glow`];
  for (const layerId of layerIds) {
    if (map.getLayer(layerId)) map.removeLayer(layerId);
  }
  if (map.getSource(id)) map.removeSource(id);
}

function syncRoutes(
  map: maplibregl.Map,
  routes: RouteConfig[],
  routeIdsRef: MutableRefObject<string[]>,
) {
  if (!map.isStyleLoaded()) return;

  const activeIds = new Set(routes.map((route) => route.id));

  for (const id of routeIdsRef.current) {
    if (!activeIds.has(id)) removeRoute(map, id);
  }
  routeIdsRef.current = routes.map((route) => route.id);

  routes.forEach((route) => {
    const existing = map.getSource(route.id) as maplibregl.GeoJSONSource | undefined;

    if (existing) {
      existing.setData(route.data);
    } else {
      map.addSource(route.id, {
        type: "geojson",
        data: route.data,
      });
    }

    if (route.glow !== false) {
      if (!map.getLayer(`${route.id}-glow`)) {
        map.addLayer(
          buildRouteGlowLayer(route.id, route.color, (route.width ?? 5) + 8),
        );
      } else {
        map.setPaintProperty(`${route.id}-glow`, "line-color", route.color);
        map.setPaintProperty(
          `${route.id}-glow`,
          "line-width",
          (route.width ?? 5) + 8,
        );
      }
    } else if (map.getLayer(`${route.id}-glow`)) {
      map.removeLayer(`${route.id}-glow`);
    }

    if (map.getLayer(route.id)) {
      map.setPaintProperty(route.id, "line-color", route.color);
      map.setPaintProperty(route.id, "line-width", route.width ?? 5);
      if (route.dashed) {
        map.setPaintProperty(route.id, "line-dasharray", [1.5, 1.2]);
      } else {
        map.setPaintProperty(route.id, "line-dasharray", undefined);
      }
    } else {
      map.addLayer(
        buildRouteLayer(
          route.id,
          route.color,
          route.width ?? 5,
          route.dashed,
        ),
      );
    }
  });
}

export function LandingMapView({
  center,
  zoom,
  className,
  interactive = false,
  eager = false,
  markers = [],
  routes = [],
  vehicles = [],
  showUserLocation,
  ariaLabel = "Carte interactive",
  minZoom,
  maxZoom,
  bearing = 0,
  pitch = 0,
  bounds,
  fitPadding = 48,
}: LandingMapViewProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const markersRef = useRef<maplibregl.Marker[]>([]);
  const routeIdsRef = useRef<string[]>([]);
  const routesRef = useRef(routes);
  routesRef.current = routes;
  const isInView = useInView(containerRef, { once: true, margin: "120px" });
  const shouldInit = eager || isInView;
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!shouldInit || !containerRef.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: createDarkMapStyle(),
      center,
      zoom,
      bearing,
      pitch,
      minZoom,
      maxZoom,
      interactive,
      attributionControl: false,
      fadeDuration: 0,
    });

    const handleLoad = () => {
      syncRoutes(map, routesRef.current, routeIdsRef);
      setReady(true);
    };

    map.once("load", handleLoad);
    mapRef.current = map;

    return () => {
      map.off("load", handleLoad);
      markersRef.current.forEach((m) => m.remove());
      markersRef.current = [];
      routeIdsRef.current = [];
      map.remove();
      mapRef.current = null;
      setReady(false);
    };
    // La carte n'est créée qu'une fois ; caméra et routes se mettent à jour via d'autres effets.
  }, [shouldInit, minZoom, maxZoom, interactive]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready) return;
    syncRoutes(map, routes, routeIdsRef);
  }, [ready, routes]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready || !map.isStyleLoaded()) return;

    if (bounds) {
      map.fitBounds(bounds, {
        padding: fitPadding,
        bearing,
        pitch,
        duration: 700,
        maxZoom: 16,
      });
      return;
    }

    map.easeTo({
      center,
      zoom,
      bearing,
      pitch,
      duration: 700,
    });
  }, [ready, bounds, fitPadding, center[0], center[1], zoom, bearing, pitch]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready) return;

    markersRef.current.forEach((m) => m.remove());
    markersRef.current = [];

    markers.forEach((marker) => {
      const el = createMarkerElement(marker);
      const m = new maplibregl.Marker({ element: el, anchor: "center" })
        .setLngLat([marker.lng, marker.lat])
        .addTo(map);
      markersRef.current.push(m);
    });

    vehicles.forEach((vehicle) => {
      const el = createVehicleElement(vehicle);
      const m = new maplibregl.Marker({ element: el, anchor: "center" })
        .setLngLat([vehicle.lng, vehicle.lat])
        .addTo(map);
      markersRef.current.push(m);
    });

    if (showUserLocation) {
      const el = createUserLocationElement();
      const m = new maplibregl.Marker({ element: el, anchor: "center" })
        .setLngLat([showUserLocation.lng, showUserLocation.lat])
        .addTo(map);
      markersRef.current.push(m);
    }
  }, [ready, markers, vehicles, showUserLocation]);

  useEffect(() => {
    const map = mapRef.current;
    const container = containerRef.current;
    if (!map || !container || !ready) return;

    const resize = () => map.resize();
    resize();

    const observer = new ResizeObserver(resize);
    observer.observe(container);
    return () => observer.disconnect();
  }, [ready]);

  return (
    <div
      ref={containerRef}
      role="img"
      aria-label={ariaLabel}
      className={cn("landing-map-container", className)}
    />
  );
}
