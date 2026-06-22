"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import "maplibre-gl/dist/maplibre-gl.css";
import maplibregl from "maplibre-gl";
import {
  buildRouteGlowLayer,
  buildRouteLayer,
  createDetailMapStyle,
  NANTES_CENTER,
} from "@/lib/landing-map-style";
import { pointCoordinates } from "@/lib/geo";
import type { NearbyStop, StopServingLine } from "@/lib/stops-types";
import {
  collectMapServingLines,
  groupMapRoutes,
  routeBadgeStyle,
  routeTypeLabel,
} from "@/lib/stops-utils";

interface StopDetailMapProps {
  coordinates: [number, number] | null;
  stopName: string;
  nearby: NearbyStop[];
  lines: StopServingLine[];
  draggable?: boolean;
  onMove?: (coordinates: [number, number]) => void;
}

const MAX_ROUTE_SHAPES = 24;
const SHAPE_POINT_LIMIT = 2000;

function routeColor(line: StopServingLine): string {
  const hex = line.route_color?.replace("#", "") ?? "2563eb";
  return `#${hex}`;
}

function sourceIdForRoute(routeId: string): string {
  return `shape-${routeId.replace(/[^a-zA-Z0-9_-]/g, "_")}`;
}

function createMainMarkerElement(stopName: string): HTMLElement {
  const row = document.createElement("div");
  row.className = "stops-map-marker-main";
  const dot = document.createElement("span");
  dot.className = "stops-map-marker-dot";
  const label = document.createElement("span");
  label.className = "stops-map-marker-label";
  label.textContent = stopName;
  row.appendChild(dot);
  row.appendChild(label);
  return row;
}

function buildStopPopupHtml(stop: NearbyStop): string {
  const routes = groupMapRoutes(stop.serving_lines ?? []);
  const linesHtml = routes.length
    ? routes
        .map((r) => {
          const style = routeBadgeStyle(r.route_color);
          const dirs = [
            r.has_aller ? "A" : "",
            r.has_retour ? "R" : "",
          ]
            .filter(Boolean)
            .join("·");
          return `<span class="stops-map-popup-chip" style="background:${style.backgroundColor};color:${style.color}">${r.route_short_name}${dirs ? `<small>${dirs}</small>` : ""}</span>`;
        })
        .join("")
    : `<span class="stops-map-popup-empty">Aucune ligne</span>`;

  const title = stop.stop_code
    ? `${stop.stop_name} <span class="stops-map-popup-code">${stop.stop_code}</span>`
    : stop.stop_name;

  return `<div class="stops-map-popup"><strong>${title}</strong><div class="stops-map-popup-chips">${linesHtml}</div></div>`;
}

function createNearbyMarkerElement(
  stop: NearbyStop,
  map: maplibregl.Map,
  coords: [number, number],
): HTMLElement {
  const dot = document.createElement("button");
  dot.type = "button";
  dot.className = "stops-map-marker-nearby-btn";
  dot.setAttribute("aria-label", stop.stop_name);

  const popup = new maplibregl.Popup({
    closeButton: false,
    closeOnClick: false,
    offset: 10,
    className: "stops-map-popup-root",
  });

  const showPopup = () => {
    popup.setLngLat(coords).setHTML(buildStopPopupHtml(stop)).addTo(map);
  };
  const hidePopup = () => popup.remove();

  dot.addEventListener("mouseenter", showPopup);
  dot.addEventListener("focus", showPopup);
  dot.addEventListener("mouseleave", hidePopup);
  dot.addEventListener("blur", hidePopup);

  return dot;
}

function directionHint(group: { has_aller: boolean; has_retour: boolean }): string | null {
  if (group.has_aller && group.has_retour) return "A·R";
  if (group.has_aller) return "A";
  if (group.has_retour) return "R";
  return null;
}

export function StopDetailMap({
  coordinates,
  stopName,
  nearby,
  lines,
  draggable = false,
  onMove,
}: StopDetailMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const mainMarkerRef = useRef<maplibregl.Marker | null>(null);
  const nearbyMarkersRef = useRef<maplibregl.Marker[]>([]);
  const shapeRoutesRef = useRef<{ sourceId: string; routeId: string }[]>([]);
  const [focusedRouteId, setFocusedRouteId] = useState<string | null>(null);
  const focusedRouteIdRef = useRef(focusedRouteId);
  focusedRouteIdRef.current = focusedRouteId;

  const routeGroups = useMemo(
    () => groupMapRoutes(collectMapServingLines(lines, nearby)),
    [lines, nearby],
  );

  const clearShapes = useCallback((map: maplibregl.Map) => {
    for (const { sourceId } of shapeRoutesRef.current) {
      if (map.getLayer(`${sourceId}-glow`)) map.removeLayer(`${sourceId}-glow`);
      if (map.getLayer(sourceId)) map.removeLayer(sourceId);
      if (map.getSource(sourceId)) map.removeSource(sourceId);
    }
    shapeRoutesRef.current = [];
  }, []);

  const applyRouteFocus = useCallback((map: maplibregl.Map, focusId: string | null) => {
    for (const { sourceId, routeId } of shapeRoutesRef.current) {
      const dimmed = focusId != null && routeId !== focusId;
      if (map.getLayer(sourceId)) {
        map.setPaintProperty(sourceId, "line-opacity", dimmed ? 0.12 : 0.95);
      }
      if (map.getLayer(`${sourceId}-glow`)) {
        map.setPaintProperty(`${sourceId}-glow`, "line-opacity", dimmed ? 0.06 : 0.28);
      }
    }
  }, []);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    const map = new maplibregl.Map({
      container: containerRef.current,
      style: createDetailMapStyle(),
      center: NANTES_CENTER,
      zoom: 14,
      attributionControl: false,
    });
    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right");
    mapRef.current = map;
    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !coordinates) return;

    mainMarkerRef.current?.remove();
    const el = createMainMarkerElement(stopName);

    const marker = new maplibregl.Marker({ element: el, draggable, anchor: "bottom" })
      .setLngLat(coordinates)
      .addTo(map);

    if (draggable && onMove) {
      marker.on("dragend", () => {
        const lngLat = marker.getLngLat();
        onMove([lngLat.lng, lngLat.lat]);
      });
    }

    mainMarkerRef.current = marker;

    const bounds = new maplibregl.LngLatBounds();
    bounds.extend(coordinates);
    for (const stop of nearby) {
      const c = pointCoordinates(stop.geom);
      if (c) bounds.extend(c);
    }
    if (nearby.length > 0) {
      map.fitBounds(bounds, { padding: { top: 48, bottom: 72, left: 48, right: 48 }, maxZoom: 16, duration: 600 });
    } else {
      map.flyTo({ center: coordinates, zoom: 16, duration: 600 });
    }

    return () => {
      marker.remove();
    };
  }, [coordinates, stopName, nearby, draggable, onMove]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    nearbyMarkersRef.current.forEach((m) => m.remove());
    nearbyMarkersRef.current = [];

    for (const stop of nearby) {
      const coords = pointCoordinates(stop.geom);
      if (!coords) continue;
      const el = createNearbyMarkerElement(stop, map, coords);
      const marker = new maplibregl.Marker({ element: el, anchor: "center" })
        .setLngLat(coords)
        .addTo(map);
      nearbyMarkersRef.current.push(marker);
    }
  }, [nearby]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !coordinates) return;

    const loadShapes = async () => {
      if (!map.isStyleLoaded()) return;
      try {
        clearShapes(map);
        const uniqueRoutes = groupMapRoutes(collectMapServingLines(lines, nearby)).slice(
          0,
          MAX_ROUTE_SHAPES,
        );
        if (!uniqueRoutes.length) return;

        const { createClient } = await import("@/lib/supabase/client");
        const supabase = createClient();

        for (const group of uniqueRoutes) {
          const { data: trips } = await supabase
            .from("gtfs_trips")
            .select("shape_id")
            .eq("route_id", group.route_id)
            .not("shape_id", "is", null)
            .limit(1);
          const shapeId = trips?.[0]?.shape_id;
          if (!shapeId) continue;

          const { data: shapePts } = await supabase
            .from("gtfs_shapes")
            .select("shape_pt_sequence, geom")
            .eq("shape_id", shapeId)
            .order("shape_pt_sequence")
            .limit(SHAPE_POINT_LIMIT);

          if (!shapePts?.length) continue;

          const coords = shapePts
            .map((p) => pointCoordinates(p.geom))
            .filter((c): c is [number, number] => c != null);

          if (coords.length < 2) continue;

          const sourceId = sourceIdForRoute(group.route_id);
          if (map.getSource(sourceId)) continue;

          const color = routeColor({
            route_id: group.route_id,
            route_short_name: group.route_short_name,
            route_long_name: null,
            route_type: group.route_type,
            route_color: group.route_color,
            direction_id: null,
            trip_id: "",
            stop_sequence: 0,
            prev_stop_id: null,
            prev_stop_name: null,
            next_stop_id: null,
            next_stop_name: null,
            arrival_time: "",
            time_from_terminus_seconds: null,
          });

          shapeRoutesRef.current.push({ sourceId, routeId: group.route_id });

          map.addSource(sourceId, {
            type: "geojson",
            data: {
              type: "Feature",
              properties: { color, routeId: group.route_id },
              geometry: { type: "LineString", coordinates: coords },
            },
          });

          map.addLayer(buildRouteGlowLayer(sourceId, color, 14));
          map.addLayer(buildRouteLayer(sourceId, color, 5));
        }

        applyRouteFocus(map, focusedRouteIdRef.current);
      } catch {
        // Ne pas bloquer la fiche si le tracé ne charge pas
      }
    };

    if (map.isStyleLoaded()) {
      void loadShapes();
    } else {
      map.once("load", () => void loadShapes());
    }
  }, [lines, nearby, coordinates, clearShapes, applyRouteFocus]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;
    applyRouteFocus(map, focusedRouteId);
  }, [focusedRouteId, applyRouteFocus]);

  const toggleRouteFocus = (routeId: string) => {
    setFocusedRouteId((current) => (current === routeId ? null : routeId));
  };

  return (
    <div className="stops-detail-map-wrap">
      <div ref={containerRef} className="stops-detail-map stops-detail-map--transit" />
      {routeGroups.length > 0 && (
        <div className="stops-map-legend" aria-label="Lignes desservies">
          <div className="stops-map-legend-head">
            <span className="stops-map-legend-title">Lignes desservies</span>
            {focusedRouteId && (
              <button
                type="button"
                className="stops-map-legend-reset"
                onClick={() => setFocusedRouteId(null)}
              >
                Tout afficher
              </button>
            )}
          </div>
          <div className="stops-map-legend-grid" role="list">
            {routeGroups.map((group) => {
              const style = routeBadgeStyle(group.route_color);
              const hint = directionHint(group);
              const active = focusedRouteId === group.route_id;
              return (
                <button
                  key={group.route_id}
                  type="button"
                  role="listitem"
                  className={`stops-map-legend-chip${active ? " stops-map-legend-chip--active" : ""}`}
                  style={{ backgroundColor: style.backgroundColor, color: style.color }}
                  title={`${routeTypeLabel(group.route_type)} · ${group.route_short_name}`}
                  onClick={() => toggleRouteFocus(group.route_id)}
                >
                  <span className="stops-map-legend-chip-name">{group.route_short_name}</span>
                  {hint && <span className="stops-map-legend-chip-dir">{hint}</span>}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
