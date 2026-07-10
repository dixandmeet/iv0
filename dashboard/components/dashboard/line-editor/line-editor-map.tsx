"use client";

import {
  useCallback,
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
  forwardRef,
} from "react";
import { Eraser, Loader2, Route } from "lucide-react";
import "maplibre-gl/dist/maplibre-gl.css";
import maplibregl from "maplibre-gl";
import { attachMapLibreErrorHandler } from "@/lib/maplibre-errors";
import {
  buildRouteCasingLayer,
  buildRouteGlowLayer,
  buildRouteLayer,
  NANTES_CENTER,
} from "@/lib/landing-map-style";
import {
  addExtrudedBuildings,
  applyDarkReskin,
  hideGenericPois,
  registerMissingImageFallback,
} from "@/components/carte-immersive/map-style";
import { createOrbitControl, createViewControl } from "@/components/carte-immersive/map-controls";
import {
  bearingDegrees,
  haversineKm,
  interpolateCoordinates,
  isStopType,
} from "@/lib/line-editor-utils";
import {
  POINT_TYPE_COLORS,
  LINE_VOICE_LABELS,
  type LineVoice,
  type RoutePoint,
} from "@/lib/line-editor-types";

export interface LineEditorMapHandle {
  flyToPoint: (pointId: string) => void;
}

interface LineEditorMapProps {
  points: RoutePoint[];
  /** Tracé en cours d'édition (tronc, départ ou branche actif) — pour les boutons + */
  editingPoints?: RoutePoint[];
  routeSegments?: RoutePoint[][];
  referencePoints?: RoutePoint[];
  activeVoice: LineVoice;
  lineColor: string;
  selectedPointId: string | null;
  tracing?: boolean;
  traceError?: string | null;
  canClearTrace?: boolean;
  tracePickerActive?: boolean;
  traceOriginId?: string | null;
  onTraceRoute?: () => void;
  onClearTrace?: () => void;
  onAddPoint: (coordinates: [number, number]) => void;
  onInsertPointAtSegment: (segmentIndex: number) => void;
  onSelectPoint: (pointId: string | null) => void;
  onPickTraceTarget?: (pointId: string) => void;
  onMovePoint: (pointId: string, coordinates: [number, number]) => void;
  onCommitMove: (pointId: string, coordinates: [number, number]) => void;
}

const ROUTE_SOURCE = "line-editor-route";
const REFERENCE_ROUTE_SOURCE = "line-editor-route-reference";
const ARROW_SOURCE = "line-editor-arrows";

function midpoint(
  a: [number, number],
  b: [number, number],
): [number, number] {
  return [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
}

function buildRouteGeo(
  segments: RoutePoint[][],
): GeoJSON.Feature<GeoJSON.LineString | GeoJSON.MultiLineString> {
  const lineCoords = segments
    .filter((seg) => seg.length >= 2)
    .map((seg) => seg.map((p) => p.coordinates));

  if (lineCoords.length === 0) {
    return {
      type: "Feature",
      properties: {},
      geometry: { type: "LineString", coordinates: [] },
    };
  }

  if (lineCoords.length === 1) {
    return {
      type: "Feature",
      properties: {},
      geometry: { type: "LineString", coordinates: lineCoords[0] },
    };
  }

  return {
    type: "Feature",
    properties: {},
    geometry: { type: "MultiLineString", coordinates: lineCoords },
  };
}

function buildArrowFeaturesFromSegments(
  segments: RoutePoint[][],
): GeoJSON.FeatureCollection<GeoJSON.Point> {
  const features: GeoJSON.Feature<GeoJSON.Point>[] = [];
  for (const points of segments) {
    for (let i = 1; i < points.length; i++) {
      const from = points[i - 1].coordinates;
      const to = points[i].coordinates;
      features.push({
        type: "Feature",
        properties: { bearing: bearingDegrees(from, to) },
        geometry: { type: "Point", coordinates: midpoint(from, to) },
      });
    }
  }
  return { type: "FeatureCollection", features };
}

function buildArrowFeatures(
  points: RoutePoint[],
): GeoJSON.FeatureCollection<GeoJSON.Point> {
  const features: GeoJSON.Feature<GeoJSON.Point>[] = [];
  for (let i = 1; i < points.length; i++) {
    const from = points[i - 1].coordinates;
    const to = points[i].coordinates;
    features.push({
      type: "Feature",
      properties: { bearing: bearingDegrees(from, to) },
      geometry: { type: "Point", coordinates: midpoint(from, to) },
    });
  }
  return { type: "FeatureCollection", features };
}

function buildMarkerElement(
  point: RoutePoint,
  stopIndex: number | null,
  passageIndex: number | null,
  isSelected: boolean,
  traceRole: "origin" | "target" | null,
): HTMLButtonElement {
  const color = POINT_TYPE_COLORS[point.type];
  const isPassage = !isStopType(point.type);
  const el = document.createElement("button");
  el.type = "button";
  el.className = [
    "line-editor-marker",
    isPassage ? "line-editor-marker--passage" : "",
    isSelected ? "line-editor-marker--selected" : "",
    traceRole === "origin" ? "line-editor-marker--trace-origin" : "",
    traceRole === "target" ? "line-editor-marker--trace-target" : "",
  ]
    .filter(Boolean)
    .join(" ");
  el.style.setProperty("--marker-color", color);
  el.setAttribute(
    "aria-label",
    isPassage
      ? `Point de passage ${(passageIndex ?? 0) + 1}`
      : `Arrêt ${(stopIndex ?? 0) + 1}${point.stop?.name ? ` — ${point.stop.name}` : ""}`,
  );
  el.dataset.pointId = point.id;
  el.innerHTML = isPassage
    ? `<span class="line-editor-marker-dot"></span><span class="line-editor-marker-passage-index">P${(passageIndex ?? 0) + 1}</span>`
    : `<span class="line-editor-marker-dot"></span><span class="line-editor-marker-index">${(stopIndex ?? 0) + 1}</span>`;
  return el;
}

export const LineEditorMap = forwardRef<LineEditorMapHandle, LineEditorMapProps>(
  function LineEditorMap(
    {
      points,
      editingPoints,
      routeSegments,
      referencePoints = [],
      activeVoice,
      lineColor,
      selectedPointId,
      tracing = false,
      traceError = null,
      canClearTrace = false,
      tracePickerActive = false,
      traceOriginId = null,
      onTraceRoute,
      onClearTrace,
      onAddPoint,
      onInsertPointAtSegment,
      onSelectPoint,
      onPickTraceTarget,
      onMovePoint,
      onCommitMove,
    },
    ref,
  ) {
    const containerRef = useRef<HTMLDivElement>(null);
    const mapRef = useRef<maplibregl.Map | null>(null);
    const markersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
    const insertMarkersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
    const draggingRef = useRef<string | null>(null);
    const [view3D, setView3D] = useState(true);
    const viewControlButtonRef = useRef<HTMLButtonElement | null>(null);
    const viewActionRef = useRef<() => void>(() => {});
    const rotateActionRef = useRef<(degrees: number) => void>(() => {});
    const tracePickerActiveRef = useRef(tracePickerActive);
    tracePickerActiveRef.current = tracePickerActive;
    const callbacksRef = useRef({
      onAddPoint,
      onInsertPointAtSegment,
      onSelectPoint,
      onPickTraceTarget,
      onMovePoint,
      onCommitMove,
    });
    callbacksRef.current = {
      onAddPoint,
      onInsertPointAtSegment,
      onSelectPoint,
      onPickTraceTarget,
      onMovePoint,
      onCommitMove,
    };

    const traceOriginIndex = traceOriginId
      ? points.findIndex((point) => point.id === traceOriginId)
      : -1;
    const prevTracePickerRef = useRef(tracePickerActive);

    const getTraceRole = useCallback(
      (pointId: string, routeIndex: number): "origin" | "target" | null => {
        if (!tracePickerActive || traceOriginIndex < 0) return null;
        if (pointId === traceOriginId) return "origin";
        if (routeIndex > traceOriginIndex) return "target";
        return null;
      },
      [tracePickerActive, traceOriginId, traceOriginIndex],
    );

    const flyToPoint = useCallback(
      (pointId: string) => {
        const map = mapRef.current;
        const point = points.find((p) => p.id === pointId);
        if (!map || !point) return;
        map.flyTo({
          center: point.coordinates,
          zoom: Math.max(map.getZoom(), 15),
          duration: 800,
        });
      },
      [points],
    );

    useImperativeHandle(ref, () => ({ flyToPoint }), [flyToPoint]);

    const toggleView = useCallback(() => {
      const next = !view3D;
      setView3D(next);
      const map = mapRef.current;
      if (!map) return;
      if (next) {
        map.easeTo({ pitch: 55, bearing: -18, duration: 900 });
      } else {
        map.easeTo({ pitch: 0, bearing: 0, duration: 900 });
      }
    }, [view3D]);
    viewActionRef.current = toggleView;

    const rotateMap = useCallback((degrees: number) => {
      const map = mapRef.current;
      if (!map) return;
      map.stop();
      map.easeTo({
        bearing: map.getBearing() + degrees,
        duration: 300,
        easing: (t) => 1 - Math.pow(1 - t, 3),
      });
    }, []);
    rotateActionRef.current = rotateMap;

    useEffect(() => {
      const button = viewControlButtonRef.current;
      if (!button) return;
      button.classList.toggle("immersive-map-view-control--active", view3D);
      button.setAttribute("aria-pressed", String(view3D));
      button.title = view3D ? "Passer en vue 2D" : "Passer en vue 3D";
      button.setAttribute("aria-label", button.title);
    }, [view3D]);

    const syncRoute = useCallback(() => {
      const map = mapRef.current;
      if (!map || !map.isStyleLoaded()) return;

      const segments = routeSegments ?? [points];
      const routeGeo = buildRouteGeo(segments);

      const routeSource = map.getSource(ROUTE_SOURCE) as maplibregl.GeoJSONSource;
      routeSource?.setData(routeGeo);

      const referenceCoordinates = referencePoints.map((p) => p.coordinates);
      const referenceGeo: GeoJSON.Feature<GeoJSON.LineString> = {
        type: "Feature",
        properties: {},
        geometry: { type: "LineString", coordinates: referenceCoordinates },
      };
      const referenceSource = map.getSource(
        REFERENCE_ROUTE_SOURCE,
      ) as maplibregl.GeoJSONSource;
      referenceSource?.setData(referenceGeo);

      const arrowSource = map.getSource(ARROW_SOURCE) as maplibregl.GeoJSONSource;
      arrowSource?.setData(
        routeSegments
          ? buildArrowFeaturesFromSegments(segments)
          : buildArrowFeatures(points),
      );
    }, [points, routeSegments, referencePoints]);

    const clearMarkers = useCallback(() => {
      markersRef.current.forEach((m) => m.remove());
      markersRef.current.clear();
      insertMarkersRef.current.forEach((m) => m.remove());
      insertMarkersRef.current.clear();
    }, []);

    const attachMarker = useCallback(
      (
        map: maplibregl.Map,
        point: RoutePoint,
        routeIndex: number,
        stopIndex: number | null,
        passageIndex: number | null,
      ) => {
        const isSelected = point.id === selectedPointId;
        const traceRole = getTraceRole(point.id, routeIndex);
        const el = buildMarkerElement(
          point,
          stopIndex,
          passageIndex,
          isSelected,
          traceRole,
        );

        el.addEventListener("click", (e) => {
          e.stopPropagation();
          if (tracePickerActive && traceRole === "target") {
            callbacksRef.current.onPickTraceTarget?.(point.id);
            return;
          }
          if (tracePickerActive) return;
          callbacksRef.current.onSelectPoint(point.id);
        });

        const marker = new maplibregl.Marker({
          element: el,
          draggable: !tracePickerActive,
          anchor: "center",
        })
          .setLngLat(point.coordinates)
          .addTo(map);

        if (!tracePickerActive) {
          marker.on("dragstart", () => {
            draggingRef.current = point.id;
          });
          marker.on("drag", () => {
            const lngLat = marker.getLngLat();
            callbacksRef.current.onMovePoint(point.id, [lngLat.lng, lngLat.lat]);
          });
          marker.on("dragend", () => {
            const lngLat = marker.getLngLat();
            callbacksRef.current.onCommitMove(point.id, [lngLat.lng, lngLat.lat]);
            draggingRef.current = null;
          });
        }

        markersRef.current.set(point.id, marker);
      },
      [getTraceRole, selectedPointId, tracePickerActive],
    );

    const syncMarkers = useCallback(() => {
      const map = mapRef.current;
      if (!map) return;

      if (prevTracePickerRef.current !== tracePickerActive) {
        markersRef.current.forEach((marker) => marker.remove());
        markersRef.current.clear();
        prevTracePickerRef.current = tracePickerActive;
      }

      const currentIds = new Set(points.map((p) => p.id));

      markersRef.current.forEach((marker, id) => {
        if (!currentIds.has(id)) {
          marker.remove();
          markersRef.current.delete(id);
        }
      });

      let stopOrder = 0;
      let passageOrder = 0;
      points.forEach((point, routeIndex) => {
        const stopIndex = isStopType(point.type) ? stopOrder++ : null;
        const passageIndex = point.type === "passage" ? passageOrder++ : null;
        const existing = markersRef.current.get(point.id);
        const isSelected = point.id === selectedPointId;
        const isPassage = stopIndex == null;
        const traceRole = getTraceRole(point.id, routeIndex);

        if (existing) {
          existing.setLngLat(point.coordinates);
          const el = existing.getElement() as HTMLButtonElement;
          const color = POINT_TYPE_COLORS[point.type];
          el.style.setProperty("--marker-color", color);
          el.classList.toggle("line-editor-marker--selected", isSelected);
          el.classList.toggle("line-editor-marker--passage", isPassage);
          el.classList.toggle(
            "line-editor-marker--trace-origin",
            traceRole === "origin",
          );
          el.classList.toggle(
            "line-editor-marker--trace-target",
            traceRole === "target",
          );

          const indexEl = el.querySelector(".line-editor-marker-index");
          const passageEl = el.querySelector(".line-editor-marker-passage-index");
          if (isPassage) {
            indexEl?.remove();
            if (passageEl) {
              passageEl.textContent = `P${(passageIndex ?? 0) + 1}`;
            } else {
              const badge = document.createElement("span");
              badge.className = "line-editor-marker-passage-index";
              badge.textContent = `P${(passageIndex ?? 0) + 1}`;
              el.appendChild(badge);
            }
          } else {
            passageEl?.remove();
            if (indexEl) {
              indexEl.textContent = String((stopIndex ?? 0) + 1);
            } else {
              const badge = document.createElement("span");
              badge.className = "line-editor-marker-index";
              badge.textContent = String((stopIndex ?? 0) + 1);
              el.appendChild(badge);
            }
          }
        } else {
          attachMarker(map, point, routeIndex, stopIndex, passageIndex);
        }
      });
    }, [points, selectedPointId, attachMarker, getTraceRole, tracePickerActive]);

    const segmentPoints = editingPoints ?? points;

    const syncInsertMarkers = useCallback(() => {
      const map = mapRef.current;
      if (!map) return;

      if (tracePickerActive) {
        insertMarkersRef.current.forEach((marker) => marker.remove());
        insertMarkersRef.current.clear();
        return;
      }

      const segmentIds = new Set<string>();
      for (let i = 0; i < segmentPoints.length - 1; i++) {
        segmentIds.add(`seg-${i}`);
      }

      insertMarkersRef.current.forEach((marker, id) => {
        if (!segmentIds.has(id)) {
          marker.remove();
          insertMarkersRef.current.delete(id);
        }
      });

      for (let i = 0; i < segmentPoints.length - 1; i++) {
        const id = `seg-${i}`;
        const coords = interpolateCoordinates(
          segmentPoints[i].coordinates,
          segmentPoints[i + 1].coordinates,
          0.5,
        );
        const existing = insertMarkersRef.current.get(id);

        if (existing) {
          existing.setLngLat(coords);
          continue;
        }

        const el = document.createElement("button");
        el.type = "button";
        el.className = "line-editor-insert-marker";
        el.setAttribute("aria-label", "Ajouter un point de passage ici");
        el.title = "Ajouter un point de passage";
        el.textContent = "+";

        el.addEventListener("click", (e) => {
          e.stopPropagation();
          callbacksRef.current.onInsertPointAtSegment(i);
        });

        const marker = new maplibregl.Marker({
          element: el,
          anchor: "center",
        })
          .setLngLat(coords)
          .addTo(map);

        insertMarkersRef.current.set(id, marker);
      }
    }, [segmentPoints, tracePickerActive]);

    useEffect(() => {
      if (!containerRef.current || mapRef.current) return;

      const map = new maplibregl.Map({
        container: containerRef.current,
        style: "https://tiles.openfreemap.org/styles/liberty",
        center: NANTES_CENTER,
        zoom: 14,
        pitch: 55,
        bearing: -18,
        canvasContextAttributes: { antialias: true, preserveDrawingBuffer: false },
        attributionControl: { compact: true },
      });
      registerMissingImageFallback(map);
      const detachMapErrorHandler = attachMapLibreErrorHandler(map, "LineEditorMap");

      map.addControl(
        new maplibregl.NavigationControl({ visualizePitch: true }),
        "top-left",
      );
      map.addControl(
        createOrbitControl(
          () => rotateActionRef.current(-30),
          () => rotateActionRef.current(30),
        ),
        "top-left",
      );
      map.addControl(
        createViewControl(
          () => viewActionRef.current(),
          (button) => {
            viewControlButtonRef.current = button;
          },
        ),
        "top-left",
      );

      map.on("load", () => {
        try {
          map.setSky({
            "sky-color": "#0a1614",
            "horizon-color": "#12241f",
            "fog-color": "#0a1210",
            "sky-horizon-blend": 0.5,
            "horizon-fog-blend": 0.6,
            "fog-ground-blend": 0.6,
          });
        } catch {
          // certains navigateurs/versions du style ne supportent pas le ciel custom
        }

        applyDarkReskin(map);
        addExtrudedBuildings(map);
        hideGenericPois(map);

        map.addSource(ROUTE_SOURCE, {
          type: "geojson",
          data: { type: "FeatureCollection", features: [] },
        });
        map.addSource(REFERENCE_ROUTE_SOURCE, {
          type: "geojson",
          data: { type: "FeatureCollection", features: [] },
        });
        map.addSource(ARROW_SOURCE, {
          type: "geojson",
          data: { type: "FeatureCollection", features: [] },
        });

        map.addLayer(
          buildRouteLayer(REFERENCE_ROUTE_SOURCE, "#94a3b8", 4, true),
        );
        map.addLayer(buildRouteCasingLayer(ROUTE_SOURCE, 14));
        map.addLayer(buildRouteGlowLayer(ROUTE_SOURCE, lineColor, 20));
        map.addLayer(buildRouteLayer(ROUTE_SOURCE, lineColor, 7));

        map.addLayer({
          id: "line-editor-arrows",
          type: "symbol",
          source: ARROW_SOURCE,
          layout: {
            "text-field": "▶",
            "text-size": 15,
            "text-rotate": ["get", "bearing"],
            "text-rotation-alignment": "map",
            "text-allow-overlap": true,
            "text-ignore-placement": true,
          },
          paint: {
            "text-color": lineColor,
            "text-halo-color": "#ffffff",
            "text-halo-width": 2.5,
          },
        });

        syncRoute();
        syncMarkers();
        syncInsertMarkers();

        if (points.length >= 2) {
          const bounds = new maplibregl.LngLatBounds();
          points.forEach((p) => bounds.extend(p.coordinates));
          map.fitBounds(bounds, { padding: 80, maxZoom: 15 });
        }
      });

      map.on("click", (e) => {
        if (draggingRef.current || tracePickerActiveRef.current) return;
        callbacksRef.current.onAddPoint([e.lngLat.lng, e.lngLat.lat]);
      });

      mapRef.current = map;

      return () => {
        clearMarkers();
        detachMapErrorHandler();
        map.remove();
        mapRef.current = null;
      };
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    useEffect(() => {
      const container = containerRef.current;
      if (!container) return;

      const observer = new ResizeObserver(() => {
        mapRef.current?.resize();
      });
      observer.observe(container);
      return () => observer.disconnect();
    }, []);

    useEffect(() => {
      const map = mapRef.current;
      if (!map?.isStyleLoaded()) return;
      if (map.getLayer(ROUTE_SOURCE)) {
        map.setPaintProperty(`${ROUTE_SOURCE}-glow`, "line-color", lineColor);
        map.setPaintProperty(ROUTE_SOURCE, "line-color", lineColor);
        map.setPaintProperty("line-editor-arrows", "text-color", lineColor);
      }
      syncRoute();
    }, [points, lineColor, syncRoute]);

    useEffect(() => {
      syncMarkers();
      syncInsertMarkers();
    }, [syncMarkers, syncInsertMarkers, tracePickerActive]);

    const totalKm =
      points.length >= 2
        ? points
            .slice(1)
            .reduce(
              (sum, p, i) =>
                sum + haversineKm(points[i].coordinates, p.coordinates),
              0,
            )
        : 0;

    return (
      <div className="line-editor-map-wrap">
        <div ref={containerRef} className="line-editor-map" />
        <div className="line-editor-map-toolbar">
          {onTraceRoute && (
            <button
              type="button"
              className="line-editor-map-trace-btn"
              onClick={onTraceRoute}
              disabled={tracing || points.length < 2}
              title="Aligner le tracé sur le réseau routier"
            >
              {tracing ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Route className="h-4 w-4" />
              )}
              {tracing ? "Calcul…" : "Tracer l'itinéraire"}
            </button>
          )}
          {onClearTrace && (
            <button
              type="button"
              className="line-editor-map-clear-btn"
              onClick={onClearTrace}
              disabled={tracing || !canClearTrace}
              title="Supprimer les points de passage du tracé"
            >
              <Eraser className="h-4 w-4" />
              Effacer le tracé
            </button>
          )}
        </div>
        {traceError && (
          <div className="line-editor-map-trace-error" role="alert">
            {traceError}
          </div>
        )}
        <div className="line-editor-map-hint">
          {tracePickerActive
            ? "Cliquez sur un point situé plus loin sur la ligne pour proposer le tracé"
            : "Cliquez sur le tracé pour insérer un point · Utilisez les + sur la ligne · Glissez pour déplacer"}
        </div>
        {tracePickerActive && (
          <div className="line-editor-map-trace-picker-banner">
            Mode tracé actif — sélectionnez la destination ({LINE_VOICE_LABELS[activeVoice]})
          </div>
        )}
        {points.length >= 2 && (
          <div className="line-editor-map-distance">{totalKm.toFixed(1)} km</div>
        )}
      </div>
    );
  },
);
