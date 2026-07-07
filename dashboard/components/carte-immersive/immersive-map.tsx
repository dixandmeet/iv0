"use client";

import "maplibre-gl/dist/maplibre-gl.css";
import maplibregl from "maplibre-gl";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  CATEGORIES,
  CITY_CENTER,
  ROUTE_DELTAS,
  SHOP_DEFS,
  SHOP_DELTAS,
  VEHICLE_DEFS,
  buildMenu,
  fmt,
  type ShopDef,
  type VehicleDef,
} from "@/lib/carte-immersive/data";
import { pathLen, pointAt, type LatLng } from "@/lib/carte-immersive/geo";
import type { MapVehicle } from "@/lib/carte-immersive/vehicles";
import { useImmersiveFleet } from "@/hooks/use-immersive-fleet";
import {
  addExtrudedBuildings,
  applyDarkReskin,
  ensureRouteLayer,
  ensureTransitTracesLayer,
  hideGenericPois,
  registerMissingImageFallback,
  setTransitTracesFilter,
} from "./map-style";
import type {
  DashboardLineSearchItem,
  RealLineTrace,
} from "@/lib/carte-immersive/real-lines";
import { loadCustomRegulationLines } from "@/lib/regulation-custom-line";
import { loadLineEditorDraft } from "@/lib/line-editor-persistence";
import { getVoicePoints, isStopType } from "@/lib/line-editor-utils";
import { travelerCommentsForVehicle } from "@/lib/traveler-comments";
import { createDestElement, createShopElement, createUserElement } from "./map-markers";
import {
  TopBar,
  type GlobalSearchSuggestion,
  type ImmersiveViewer,
} from "./top-bar";
import { QuickActionsPanel } from "./quick-actions-panel";
import { FiltersPanel, type FilterKey } from "./filters-panel";
import { GeoPrompt } from "./geo-prompt";
import { RoutePanel, type RouteMode, type RouteStep } from "./route-panel";
import { FocusPanel, type RideItem, type ShopResultItem, type SortMode } from "./focus-panel";
import { DetailPanel, type SelectedDetail } from "./detail-panel";
import { MerchantSheet, type MenuChip, type CartLine } from "./merchant-sheet";
import { Vehicle3DLayer } from "./vehicle-3d-layer";
import {
  TrackingPanel,
  type TrackingPanelData,
  type TrackingStopPlanItem,
} from "./tracking-panel";

type SelectedKind = "vehicle" | "shop" | null;
type FocusMode = "ride" | "shop" | null;
type GeocodeResult = { name: string; label: string; latLng: LatLng };
type SearchLineSelection = {
  title: string;
  mode: "bus" | "tram" | "navibus";
  subtitle: string;
  coords: LatLng[];
  stopCount?: number;
};

type LoadedLineMapData = {
  trace: LatLng[];
  stops: LineStop[];
};

type LineStop = { id: string; name: string; lat: number; lng: number };

type LineVehicleAnimation = {
  id: string;
  coords: LatLng[];
  length: number;
  startedAt: number;
  travelDuration: number;
};

type VehiclePose = {
  lat: number;
  lng: number;
  heading: number;
  speedMps: number | null;
};

type VehicleTracking = {
  vehicleId: string;
  type: "bus" | "tram" | "navibus";
  title: string;
  destination: string;
  nextStop: string;
  status: string;
  route: LatLng[];
  stops: LineStop[];
  nextStopPosition: LatLng | null;
  hasRealtime: boolean;
};

type TrackingMetrics = {
  distanceToStopM: number | null;
  etaMinutes: number | null;
  distanceToUserM: number | null;
};

type RouteProjection = {
  point: LatLng;
  distance: number;
  segmentIndex: number;
  direction: 1 | -1;
  totalDistance: number;
};

const GEOLOCATION_CONSENT_KEY = "aule:geolocation-consent";
const TRACKING_ROUTE_FRONT_OFFSET_METERS = 30;
const TRACKING_CAMERA_UPDATE_INTERVAL_SECONDS = 0.08;
const TRACKING_ROUTE_MASK_SOURCE_ID = "immersive-map-tracking-route-mask-source";
const TRACKING_ROUTE_MASK_LAYER_ID = "immersive-map-tracking-route-mask-layer";
const NAVIBUS_SEARCH_LINES: Array<{
  id: string;
  title: string;
  subtitle: string;
  coords: LatLng[];
}> = [
  {
    id: "N1",
    title: "Navibus N1",
    subtitle: "Gare Maritime ↔ Trentemoult",
    coords: [
      [47.2079, -1.5726],
      [47.1988, -1.5803],
    ],
  },
  {
    id: "N2",
    title: "Navibus N2",
    subtitle: "Hangar à Bananes ↔ Bas-Chantenay",
    coords: [
      [47.2009, -1.5734],
      [47.1994, -1.593],
    ],
  },
  {
    id: "N3",
    title: "Navibus N3",
    subtitle: "Trentemoult ↔ Bas-Chantenay",
    coords: [
      [47.1988, -1.5803],
      [47.1994, -1.593],
    ],
  },
];

function createLineStopElement(
  name: string,
  index: number,
  total: number,
  color: string,
): HTMLButtonElement {
  const terminal = index === 0 || index === total - 1;
  const element = document.createElement("button");
  element.type = "button";
  element.title = name;
  element.setAttribute("aria-label", `Arrêt ${name}`);
  element.style.width = terminal ? "19px" : "13px";
  element.style.height = terminal ? "19px" : "13px";
  element.style.padding = "0";
  element.style.borderRadius = "50%";
  element.style.border = `${terminal ? 4 : 3}px solid ${color}`;
  element.style.background = "#ffffff";
  element.style.boxShadow = "0 3px 10px rgba(0,0,0,.42)";
  element.style.cursor = "pointer";
  return element;
}

function distanceMetersBetween(a: LatLng, b: LatLng) {
  const earthRadius = 6_371_000;
  const lat1 = (a[0] * Math.PI) / 180;
  const lat2 = (b[0] * Math.PI) / 180;
  const deltaLat = ((b[0] - a[0]) * Math.PI) / 180;
  const deltaLng = ((b[1] - a[1]) * Math.PI) / 180;
  const value =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLng / 2) ** 2;
  return earthRadius * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
}

function headingDeltaDegrees(a: number, b: number) {
  return ((a - b + 540) % 360) - 180;
}

function segmentHeadingDegrees(a: LatLng, b: LatLng) {
  const meanLat = ((a[0] + b[0]) / 2) * (Math.PI / 180);
  const east = (b[1] - a[1]) * Math.cos(meanLat);
  const north = b[0] - a[0];
  return (Math.atan2(east, north) * 180) / Math.PI;
}

function projectPositionOnRoute(
  route: LatLng[],
  position: LatLng,
  heading?: number,
  previous?: RouteProjection | null,
): RouteProjection | null {
  if (route.length < 2) return null;

  let best:
    | {
        point: LatLng;
        distance: number;
        segmentIndex: number;
        direction: 1 | -1;
        score: number;
      }
    | null = null;
  let cumulative = 0;
  const routeTotal = pathLen(route);
  const routeTolerance = Math.max(routeTotal * 0.015, 0.00008);

  for (let index = 0; index < route.length - 1; index += 1) {
    const start = route[index];
    const end = route[index + 1];
    const meanLat = ((start[0] + end[0] + position[0]) / 3) * (Math.PI / 180);
    const scaleLng = Math.max(0.2, Math.cos(meanLat));
    const startX = start[1] * scaleLng;
    const startY = start[0];
    const endX = end[1] * scaleLng;
    const endY = end[0];
    const posX = position[1] * scaleLng;
    const posY = position[0];
    const dx = endX - startX;
    const dy = endY - startY;
    const segSq = dx * dx + dy * dy;
    const rawT = segSq === 0 ? 0 : ((posX - startX) * dx + (posY - startY) * dy) / segSq;
    const t = Math.max(0, Math.min(1, rawT));
    const projected: LatLng = [
      start[0] + (end[0] - start[0]) * t,
      start[1] + (end[1] - start[1]) * t,
    ];
    const segLen = Math.hypot(end[0] - start[0], end[1] - start[1]);
    const distance = cumulative + segLen * t;
    const projectedX = projected[1] * scaleLng;
    const projectedY = projected[0];
    const perpendicularSq =
      (posX - projectedX) * (posX - projectedX) +
      (posY - projectedY) * (posY - projectedY);

    const forwardHeading = segmentHeadingDegrees(start, end);
    const headingAlignment =
      typeof heading === "number"
        ? Math.cos(headingDeltaDegrees(heading, forwardHeading) * (Math.PI / 180))
        : null;
    const direction: 1 | -1 =
      headingAlignment == null
        ? previous?.direction ?? 1
        : headingAlignment >= 0
          ? 1
          : -1;

    let score = perpendicularSq;
    if (headingAlignment != null) {
      score += (1 - Math.abs(headingAlignment)) * 0.000000006;
    }
    if (previous && previous.direction === direction) {
      const movedBackward =
        direction === 1
          ? distance < previous.distance - routeTolerance
          : distance > previous.distance + routeTolerance;
      if (movedBackward) score += 0.00000008;
    }

    if (!best || score < best.score) {
      best = {
        point: projected,
        distance,
        segmentIndex: index,
        direction,
        score,
      };
    }

    cumulative += segLen;
  }

  if (!best) return null;
  return {
    point: best.point,
    distance: best.distance,
    segmentIndex: best.segmentIndex,
    direction: best.direction,
    totalDistance: routeTotal,
  };
}

function compactRoutePoints(points: LatLng[]) {
  return points.filter((point, index) => {
    if (index === 0) return true;
    const previous = points[index - 1];
    return Math.hypot(point[0] - previous[0], point[1] - previous[1]) > 0.000002;
  });
}

function interpolateRoutePoint(a: LatLng, b: LatLng, progress: number): LatLng {
  return [
    a[0] + (b[0] - a[0]) * progress,
    a[1] + (b[1] - a[1]) * progress,
  ];
}

function routeUnitDistance(a: LatLng, b: LatLng) {
  return Math.hypot(b[0] - a[0], b[1] - a[1]);
}

function advanceProjectionAlongRoute(
  route: LatLng[],
  projection: RouteProjection,
  offsetMeters: number,
): RouteProjection {
  if (route.length < 2 || offsetMeters <= 0) return projection;

  let remainingMeters = offsetMeters;
  let currentPoint = projection.point;
  let currentDistance = projection.distance;

  if (projection.direction === -1) {
    for (let index = projection.segmentIndex; index >= 0; index -= 1) {
      const targetPoint = route[index];
      const segmentMeters = distanceMetersBetween(currentPoint, targetPoint);
      const segmentUnits = routeUnitDistance(currentPoint, targetPoint);

      if (segmentMeters >= remainingMeters && segmentMeters > 0) {
        const progress = remainingMeters / segmentMeters;
        return {
          ...projection,
          point: interpolateRoutePoint(currentPoint, targetPoint, progress),
          distance: Math.max(0, currentDistance - segmentUnits * progress),
          segmentIndex: index,
        };
      }

      remainingMeters -= segmentMeters;
      currentDistance = Math.max(0, currentDistance - segmentUnits);
      currentPoint = targetPoint;
    }

    return {
      ...projection,
      point: route[0],
      distance: 0,
      segmentIndex: 0,
    };
  }

  for (
    let index = projection.segmentIndex;
    index < route.length - 1;
    index += 1
  ) {
    const targetPoint = route[index + 1];
    const segmentMeters = distanceMetersBetween(currentPoint, targetPoint);
    const segmentUnits = routeUnitDistance(currentPoint, targetPoint);

    if (segmentMeters >= remainingMeters && segmentMeters > 0) {
      const progress = remainingMeters / segmentMeters;
      return {
        ...projection,
        point: interpolateRoutePoint(currentPoint, targetPoint, progress),
        distance: Math.min(
          projection.totalDistance,
          currentDistance + segmentUnits * progress,
        ),
        segmentIndex: index,
      };
    }

    remainingMeters -= segmentMeters;
    currentDistance = Math.min(projection.totalDistance, currentDistance + segmentUnits);
    currentPoint = targetPoint;
  }

  return {
    ...projection,
    point: route[route.length - 1],
    distance: projection.totalDistance,
    segmentIndex: Math.max(0, route.length - 2),
  };
}

function buildRemainingRoute(
  route: LatLng[],
  projection: RouteProjection,
  frontOffsetMeters = 0,
) {
  if (route.length < 2) return route;
  const visualStartProjection = advanceProjectionAlongRoute(
    route,
    projection,
    frontOffsetMeters,
  );
  if (visualStartProjection.direction === -1) {
    return compactRoutePoints([
      visualStartProjection.point,
      ...route.slice(0, visualStartProjection.segmentIndex + 1).reverse(),
    ]);
  }
  return compactRoutePoints([
    visualStartProjection.point,
    ...route.slice(visualStartProjection.segmentIndex + 1),
  ]);
}

function routeDistanceMeters(points: LatLng[]) {
  let distance = 0;
  for (let index = 1; index < points.length; index += 1) {
    distance += distanceMetersBetween(points[index - 1], points[index]);
  }
  return distance;
}

function buildRouteSliceToDistance(
  route: LatLng[],
  projection: RouteProjection,
  targetDistance: number,
) {
  const targetPoint = pointAt(route, targetDistance);
  if (projection.direction === -1) {
    const points = [projection.point];
    for (let index = projection.segmentIndex; index >= 0; index -= 1) {
      const pointDistance = pathLen(route.slice(0, index + 1));
      if (pointDistance <= targetDistance) break;
      points.push(route[index]);
    }
    points.push([targetPoint.lat, targetPoint.lng]);
    return compactRoutePoints(points);
  }

  const points = [projection.point];
  let cumulative = 0;
  for (let index = 0; index < route.length - 1; index += 1) {
    const segLen = Math.hypot(
      route[index + 1][0] - route[index][0],
      route[index + 1][1] - route[index][1],
    );
    const nextDistance = cumulative + segLen;
    if (nextDistance > projection.distance && nextDistance < targetDistance) {
      points.push(route[index + 1]);
    }
    cumulative = nextDistance;
    if (cumulative >= targetDistance) break;
  }
  points.push([targetPoint.lat, targetPoint.lng]);
  return compactRoutePoints(points);
}

function findNextStopOnRoute(
  route: LatLng[],
  stops: LineStop[],
  projection: RouteProjection,
) {
  if (stops.length === 0) return null;
  const tolerance = Math.max(projection.totalDistance * 0.01, 0.00006);
  const stopProgress = stops
    .map((stop) => {
      const stopProjection = projectPositionOnRoute(route, [stop.lat, stop.lng]);
      return stopProjection
        ? { stop, distance: stopProjection.distance }
        : null;
    })
    .filter((item): item is { stop: LineStop; distance: number } => Boolean(item));

  const next = stopProgress
    .filter((item) =>
      projection.direction === 1
        ? item.distance > projection.distance + tolerance
        : item.distance < projection.distance - tolerance,
    )
    .sort((a, b) =>
      projection.direction === 1
        ? a.distance - b.distance
        : b.distance - a.distance,
    )[0];

  if (next) return next;
  return projection.direction === 1
    ? stopProgress.sort((a, b) => b.distance - a.distance)[0] ?? null
    : stopProgress.sort((a, b) => a.distance - b.distance)[0] ?? null;
}

function getRemainingStopsOnRoute(
  route: LatLng[],
  stops: LineStop[],
  projection: RouteProjection | null,
) {
  if (!projection || route.length < 2) return stops;
  const tolerance = Math.max(projection.totalDistance * 0.006, 0.00004);
  return stops
    .map((stop) => {
      const stopProjection = projectPositionOnRoute(route, [stop.lat, stop.lng]);
      return stopProjection
        ? { stop, distance: stopProjection.distance }
        : null;
    })
    .filter((item): item is { stop: LineStop; distance: number } => Boolean(item))
    .filter((item) =>
      projection.direction === 1
        ? item.distance >= projection.distance - tolerance
        : item.distance <= projection.distance + tolerance,
    )
    .sort((a, b) =>
      projection.direction === 1
        ? a.distance - b.distance
        : b.distance - a.distance,
    )
    .map((item) => item.stop);
}

function buildTrackingStopPlan(
  route: LatLng[],
  stops: LineStop[],
  projection: RouteProjection | null,
  nextStopName: string,
): TrackingStopPlanItem[] {
  if (stops.length === 0) return [];

  if (!projection || route.length < 2) {
    const nextIndex = Math.max(
      0,
      stops.findIndex((stop) => stop.name === nextStopName),
    );
    return stops.map((stop, index) => ({
      id: stop.id,
      name: stop.name,
      state:
        index < nextIndex
          ? "passed"
          : index === nextIndex
            ? "next"
            : "upcoming",
    }));
  }

  const tolerance = Math.max(projection.totalDistance * 0.008, 0.00005);
  const stopProgress = stops
    .map((stop, order) => {
      const stopProjection = projectPositionOnRoute(route, [stop.lat, stop.lng]);
      return {
        stop,
        order,
        distance: stopProjection?.distance ?? order,
      };
    })
    .sort((a, b) =>
      projection.direction === 1
        ? a.distance - b.distance
        : b.distance - a.distance,
    );
  const nextByProgress = stopProgress.find((item) =>
    projection.direction === 1
      ? item.distance > projection.distance + tolerance
      : item.distance < projection.distance - tolerance,
  );
  const nextStopId =
    nextByProgress?.stop.id ??
    stopProgress.find((item) => item.stop.name === nextStopName)?.stop.id ??
    stopProgress[stopProgress.length - 1]?.stop.id;

  return stopProgress.map((item) => {
    const isPassed =
      projection.direction === 1
        ? item.distance < projection.distance - tolerance
        : item.distance > projection.distance + tolerance;
    return {
      id: item.stop.id,
      name: item.stop.name,
      state:
        item.stop.id === nextStopId
          ? "next"
          : isPassed
            ? "passed"
            : "upcoming",
    };
  });
}

function updateRouteSource(map: maplibregl.Map, route: LatLng[]) {
  const source = map.getSource("immersive-map-route") as
    | maplibregl.GeoJSONSource
    | undefined;
  if (!source || route.length < 2) return;
  source.setData({
    type: "Feature",
    properties: { tracking: true },
    geometry: {
      type: "LineString",
      coordinates: route.map(([lat, lng]) => [lng, lat]),
    },
  });
}

function updateTrackingRouteMask(map: maplibregl.Map, position: LatLng | null) {
  if (!map.getSource(TRACKING_ROUTE_MASK_SOURCE_ID)) {
    map.addSource(TRACKING_ROUTE_MASK_SOURCE_ID, {
      type: "geojson",
      data: { type: "FeatureCollection", features: [] },
    });
  }

  if (!map.getLayer(TRACKING_ROUTE_MASK_LAYER_ID)) {
    const layer: maplibregl.CircleLayerSpecification = {
      id: TRACKING_ROUTE_MASK_LAYER_ID,
      type: "circle",
      source: TRACKING_ROUTE_MASK_SOURCE_ID,
      paint: {
        "circle-radius": [
          "interpolate",
          ["linear"],
          ["zoom"],
          14,
          14,
          17,
          25,
          19,
          34,
        ],
        "circle-color": "#06120f",
        "circle-opacity": 0.94,
        "circle-blur": 0.18,
        "circle-stroke-width": 1,
        "circle-stroke-color": "rgba(51, 191, 163, 0.22)",
      },
    };
    const beforeLayer = map.getLayer("immersive-vehicle-models")
      ? "immersive-vehicle-models"
      : undefined;
    if (beforeLayer) map.addLayer(layer, beforeLayer);
    else map.addLayer(layer);
  }

  const source = map.getSource(TRACKING_ROUTE_MASK_SOURCE_ID) as
    | maplibregl.GeoJSONSource
    | undefined;
  source?.setData(
    position
      ? {
          type: "Feature",
          properties: {},
          geometry: {
            type: "Point",
            coordinates: [position[1], position[0]],
          },
        }
      : { type: "FeatureCollection", features: [] },
  );
}

function createLocateControl(onLocate: () => void): maplibregl.IControl {
  let container: HTMLDivElement | null = null;
  let button: HTMLButtonElement | null = null;

  return {
    onAdd() {
      container = document.createElement("div");
      container.className = "maplibregl-ctrl maplibregl-ctrl-group";

      button = document.createElement("button");
      button.type = "button";
      button.className = "maplibregl-ctrl-geolocate";
      button.title = "Recentrer sur ma position";
      button.setAttribute("aria-label", "Recentrer la carte sur ma position");

      const icon = document.createElement("span");
      icon.className = "maplibregl-ctrl-icon";
      icon.setAttribute("aria-hidden", "true");
      button.appendChild(icon);
      button.addEventListener("click", onLocate);
      container.appendChild(button);

      return container;
    },
    onRemove() {
      button?.removeEventListener("click", onLocate);
      container?.remove();
      button = null;
      container = null;
    },
  };
}

/** Utilise le tracé GTFS réel du véhicule s'il est disponible, sinon le trajet fictif de démo. */
function pathCoords(v: VehicleDef, realPaths: Record<string, LatLng[]>): LatLng[] {
  const real = realPaths[v.id];
  if (real && real.length >= 2) return real;
  return ROUTE_DELTAS[v.path].map((d) => [CITY_CENTER[0] + d[0], CITY_CENTER[1] + d[1]]);
}

type ImmersiveMapProps = {
  realPaths?: Record<string, LatLng[]>;
  realLineTraces?: RealLineTrace[];
  dashboardLines?: DashboardLineSearchItem[];
  viewer?: ImmersiveViewer | null;
};

export function ImmersiveMap({
  realPaths = {},
  realLineTraces = [],
  dashboardLines = [],
  viewer = null,
}: ImmersiveMapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const readyRef = useRef(false);
  const rafRef = useRef(0);
  const vehicleLayerRef = useRef<Vehicle3DLayer | null>(null);
  const shopMarkersRef = useRef<Record<string, maplibregl.Marker>>({});
  const userMarkerRef = useRef<maplibregl.Marker | null>(null);
  const destMarkerRef = useRef<maplibregl.Marker | null>(null);
  const lineStopMarkersRef = useRef<maplibregl.Marker[]>([]);
  const showLineStopsRef = useRef<(stops: LineStop[], color?: string) => void>(
    () => {},
  );
  const lineVehicleAnimationRef = useRef<LineVehicleAnimation | null>(null);
  const activeLineMapDataRef = useRef<LoadedLineMapData | null>(null);
  const previewAnglesRef = useRef<Map<string, number>>(new Map());
  const vehiclePoseRef = useRef<Map<string, VehiclePose>>(new Map());
  const trackingRef = useRef<VehicleTracking | null>(null);
  const trackingRouteProjectionRef = useRef<RouteProjection | null>(null);
  const trackingCameraUpdatedAtRef = useRef(0);
  const trackingMetricsUpdatedAtRef = useRef(0);
  const trackingAlertedRef = useRef(false);
  const trackingNotificationRef = useRef(false);
  const trackingStopsVisibleRef = useRef(false);
  const shopSearchCenterRef = useRef<maplibregl.LngLat | null>(null);
  const orderTimeoutRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const trackingAlertTimeoutRef = useRef<ReturnType<typeof setTimeout> | undefined>(
    undefined,
  );
  const orbitingRef = useRef(false);
  const userPositionRef = useRef<LatLng | null>(null);
  const geoWatchIdRef = useRef<number | null>(null);
  const locateActionRef = useRef<() => void>(() => {});
  const realPathsRef = useRef(realPaths);
  const { vehicles: liveVehicles, mode: fleetMode, stale: fleetStale } = useImmersiveFleet();

  const [filters, setFilters] = useState<Record<FilterKey, boolean>>({
    bus: true,
    tram: true,
    vtc: true,
    taxi: true,
    shop: true,
  });
  const [selectedKind, setSelectedKind] = useState<SelectedKind>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [globalSearchQuery, setGlobalSearchQuery] = useState("");
  const [searchLineSelection, setSearchLineSelection] =
    useState<SearchLineSelection | null>(null);
  const [publishedCustomLines, setPublishedCustomLines] = useState<
    DashboardLineSearchItem[]
  >([]);
  const [lineVehicle, setLineVehicle] = useState<MapVehicle | null>(null);
  const [tracking, setTracking] = useState<VehicleTracking | null>(null);
  const [trackingMetrics, setTrackingMetrics] = useState<TrackingMetrics>({
    distanceToStopM: null,
    etaMinutes: null,
    distanceToUserM: null,
  });
  const [trackingStopPlan, setTrackingStopPlan] = useState<
    TrackingStopPlanItem[]
  >([]);
  const [trackingStopsVisible, setTrackingStopsVisible] = useState(false);
  const [trackingNotification, setTrackingNotification] = useState(false);
  const [trackingAlert, setTrackingAlert] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [routeActive, setRouteActive] = useState(false);
  const [geoGranted, setGeoGranted] = useState(false);
  const [geoPromptVisible, setGeoPromptVisible] = useState(false);
  const [geoDeniedNoticeVisible, setGeoDeniedNoticeVisible] = useState(false);
  const [destName, setDestName] = useState("");
  const [routeMode, setRouteMode] = useState<RouteMode>("foot");
  const [routeLoading, setRouteLoading] = useState(false);
  const [routeError, setRouteError] = useState<string | null>(null);
  const [routeInfo, setRouteInfo] = useState<{ distanceM: number; durationMin: number; steps: RouteStep[] } | null>(
    null,
  );
  const activeRouteRef = useRef<{ origin: LatLng; dest: LatLng; destName: string } | null>(null);
  const [originAddress, setOriginAddress] = useState("Votre position actuelle");
  const [originAddressLoading, setOriginAddressLoading] = useState(false);
  const [destinationLoading, setDestinationLoading] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);
  const [addressSuggestions, setAddressSuggestions] = useState<GeocodeResult[]>([]);
  const [addressSuggestionsLoading, setAddressSuggestionsLoading] = useState(false);
  const [showAddressSuggestions, setShowAddressSuggestions] = useState(false);
  const [selectedDestination, setSelectedDestination] = useState<GeocodeResult | null>(null);
  const addressSearchRequestRef = useRef(0);
  const [quickCollapsed, setQuickCollapsed] = useState(false);
  const [showRouteInputs, setShowRouteInputs] = useState(false);
  const [focusMode, setFocusMode] = useState<FocusMode>(null);
  const [shopQuery, setShopQuery] = useState("");
  const [activeCats, setActiveCats] = useState<Record<string, boolean>>({});
  const [sortMode, setSortMode] = useState<SortMode>("distance");
  const [showSearchArea, setShowSearchArea] = useState(false);
  const [view3D, setView3D] = useState(true);
  const [orbiting, setOrbiting] = useState(false);
  const [merchantId, setMerchantId] = useState<string | null>(null);
  const [menuCat, setMenuCat] = useState("all");
  const [cart, setCart] = useState<Record<string, number>>({});
  const [cartOpen, setCartOpen] = useState(false);
  const [orderPlaced, setOrderPlaced] = useState(false);
  const [mapError, setMapError] = useState<string | null>(null);

  useEffect(() => {
    trackingStopsVisibleRef.current = trackingStopsVisible;
  }, [trackingStopsVisible]);

  useEffect(() => {
    const published = loadCustomRegulationLines()
      .filter((line) => loadLineEditorDraft(line.id)?.status === "published")
      .map((line) => ({
        id: line.id,
        routeId: line.routeId,
        shortName: line.shortName,
        origin: line.origin,
        destination: line.destination,
        transportType: line.transportType,
        depotCode: line.depotCode,
        color: line.lineColor,
      }));
    setPublishedCustomLines(published);
  }, []);

  const displayVehicles = useMemo<MapVehicle[]>(() => {
    const previewVehicles = VEHICLE_DEFS.map((vehicle) => {
      const start = pointAt(pathCoords(vehicle, realPaths), 0);
      return {
        id: vehicle.id,
        type: vehicle.type,
        mode: "preview" as const,
        lat: start.lat,
        lng: start.lng,
        heading: 0,
        speedMps: null,
        recordedAt: null,
        routeId: vehicle.line,
        destination: vehicle.dest,
        preview: vehicle,
      };
    });
    const ridePreviews = previewVehicles.filter(
      (vehicle) => vehicle.type === "vtc" || vehicle.type === "taxi",
    );
    const vehicles =
      liveVehicles.length > 0 ? [...liveVehicles, ...ridePreviews] : previewVehicles;
    return lineVehicle ? [...vehicles, lineVehicle] : vehicles;
  }, [lineVehicle, liveVehicles, realPaths]);

  const displayVehiclesRef = useRef(displayVehicles);
  const previewIdsRef = useRef(new Set<string>());
  displayVehiclesRef.current = displayVehicles;
  previewIdsRef.current = new Set(
    displayVehicles.filter((vehicle) => vehicle.mode === "preview").map((vehicle) => vehicle.id),
  );

  // ===== Sélection & focus =====
  const select = useCallback((kind: "vehicle" | "shop", id: string) => {
    setSelectedKind(kind);
    setSelectedId(id);
    setSearchLineSelection(null);
    setRouteActive(false);
  }, []);

  const hoverShop = useCallback((id: string) => {
    const marker = shopMarkersRef.current[id];
    const inner = marker?.getElement().firstElementChild as HTMLElement | undefined;
    if (inner) {
      inner.style.transition = "transform .2s ease, box-shadow .2s ease";
      inner.style.transform = "scale(1.35)";
      inner.style.boxShadow = "0 0 0 8px rgba(51,191,163,0.35), 0 6px 14px rgba(0,0,0,0.35)";
    }
  }, []);

  const unhoverShop = useCallback((id: string) => {
    const marker = shopMarkersRef.current[id];
    const inner = marker?.getElement().firstElementChild as HTMLElement | undefined;
    if (inner) {
      inner.style.transform = "scale(1)";
      inner.style.boxShadow = "0 6px 14px rgba(0,0,0,0.35)";
    }
  }, []);

  const openMerchant = useCallback((id: string) => {
    setMerchantId(id);
    setMenuCat("all");
    setCart({});
    setCartOpen(false);
    setOrderPlaced(false);
    setSelectedKind(null);
    setSelectedId(null);
  }, []);

  // Toujours à jour : les marqueurs (créés une seule fois) appellent ces callbacks
  // via cette ref pour éviter les fermetures obsolètes (stale closures).
  const apiRef = useRef({ select, hoverShop, unhoverShop });
  useEffect(() => {
    apiRef.current = { select, hoverShop, unhoverShop };
  }, [select, hoverShop, unhoverShop]);

  // ===== Construction des marqueurs (appelée une fois, après le chargement du style) =====
  const buildMarkers = useCallback(() => {
    const map = mapRef.current;
    if (!map) return;

    for (const s of SHOP_DEFS) {
      const delta = SHOP_DELTAS[s.id];
      const el = createShopElement(s.emoji, () => apiRef.current.select("shop", s.id));
      const marker = new maplibregl.Marker({ element: el, anchor: "bottom" })
        .setLngLat([CITY_CENTER[1] + delta[1], CITY_CENTER[0] + delta[0]])
        .addTo(map);
      shopMarkersRef.current[s.id] = marker;
    }

    const userEl = createUserElement();
    const initialUserPosition = userPositionRef.current ?? CITY_CENTER;
    userMarkerRef.current = new maplibregl.Marker({ element: userEl, anchor: "center" })
      .setLngLat([initialUserPosition[1], initialUserPosition[0]])
      .addTo(map);
  }, []);

  // ===== Boucle d'animation des véhicules =====
  const tick = useCallback(function animateVehicles() {
    rafRef.current = requestAnimationFrame(animateVehicles);
    const map = mapRef.current;
    if (!map || !readyRef.current) return;
    const now = performance.now() / 1000;

    const syncTrackedVehicle = (
      id: string,
      pose: VehiclePose,
    ) => {
      vehiclePoseRef.current.set(id, pose);
      const activeTracking = trackingRef.current;
      if (!activeTracking || activeTracking.vehicleId !== id) return;
      const vehiclePosition: LatLng = [pose.lat, pose.lng];
      const routeProjection =
        activeTracking.route.length >= 2
          ? projectPositionOnRoute(
              activeTracking.route,
              vehiclePosition,
              pose.heading,
              trackingRouteProjectionRef.current,
            )
          : null;

      if (routeProjection) {
        trackingRouteProjectionRef.current = routeProjection;
        updateRouteSource(
          map,
          buildRemainingRoute(
            activeTracking.route,
            routeProjection,
            TRACKING_ROUTE_FRONT_OFFSET_METERS,
          ),
        );
        updateTrackingRouteMask(map, vehiclePosition);
      }

      if (
        now - trackingCameraUpdatedAtRef.current >=
        TRACKING_CAMERA_UPDATE_INTERVAL_SECONDS
      ) {
        trackingCameraUpdatedAtRef.current = now;
        map.easeTo({
          center: [pose.lng, pose.lat],
          zoom: 17.6,
          pitch: 67,
          bearing: pose.heading,
          duration: 140,
          easing: (value) => value,
          essential: true,
        });
      }

      if (now - trackingMetricsUpdatedAtRef.current >= 0.45) {
        trackingMetricsUpdatedAtRef.current = now;
        if (routeProjection && trackingStopsVisibleRef.current) {
          showLineStopsRef.current(
            getRemainingStopsOnRoute(
              activeTracking.route,
              activeTracking.stops,
              routeProjection,
            ),
          );
        }
        const nextStopOnRoute = routeProjection
          ? findNextStopOnRoute(
              activeTracking.route,
              activeTracking.stops,
              routeProjection,
            )
          : null;
        const nextStopPosition: LatLng | null = nextStopOnRoute
          ? [nextStopOnRoute.stop.lat, nextStopOnRoute.stop.lng]
          : activeTracking.nextStopPosition;
        const distanceToStopM =
          routeProjection && nextStopOnRoute
            ? routeDistanceMeters(
                buildRouteSliceToDistance(
                  activeTracking.route,
                  routeProjection,
                  nextStopOnRoute.distance,
                ),
              )
            : nextStopPosition
              ? distanceMetersBetween(vehiclePosition, nextStopPosition)
              : null;
        if (
          nextStopOnRoute &&
          nextStopOnRoute.stop.name !== activeTracking.nextStop
        ) {
          const updatedTracking = {
            ...activeTracking,
            nextStop: nextStopOnRoute.stop.name,
            nextStopPosition,
          };
          trackingRef.current = updatedTracking;
          setTracking(updatedTracking);
        }
        setTrackingStopPlan(
          buildTrackingStopPlan(
            activeTracking.route,
            activeTracking.stops,
            routeProjection,
            nextStopOnRoute?.stop.name ?? activeTracking.nextStop,
          ),
        );
        const distanceToUserM = userPositionRef.current
          ? distanceMetersBetween(vehiclePosition, userPositionRef.current)
          : null;
        const speedMps = Math.max(
          4,
          pose.speedMps ?? (activeTracking.type === "tram" ? 11 : 9),
        );
        setTrackingMetrics({
          distanceToStopM,
          etaMinutes:
            distanceToStopM == null ? null : distanceToStopM / speedMps / 60,
          distanceToUserM,
        });

        if (
          trackingNotificationRef.current &&
          distanceToUserM != null &&
          distanceToUserM <= 250 &&
          !trackingAlertedRef.current
        ) {
          trackingAlertedRef.current = true;
          setTrackingAlert(
            `${activeTracking.title} approche — préparez-vous à monter.`,
          );
          clearTimeout(trackingAlertTimeoutRef.current);
          trackingAlertTimeoutRef.current = setTimeout(
            () => setTrackingAlert(null),
            6500,
          );
          try {
            const audioContext = new AudioContext();
            const oscillator = audioContext.createOscillator();
            const gain = audioContext.createGain();
            oscillator.connect(gain);
            gain.connect(audioContext.destination);
            oscillator.frequency.setValueAtTime(620, audioContext.currentTime);
            oscillator.frequency.linearRampToValueAtTime(
              880,
              audioContext.currentTime + 0.22,
            );
            gain.gain.setValueAtTime(0.0001, audioContext.currentTime);
            gain.gain.exponentialRampToValueAtTime(
              0.12,
              audioContext.currentTime + 0.025,
            );
            gain.gain.exponentialRampToValueAtTime(
              0.0001,
              audioContext.currentTime + 0.42,
            );
            oscillator.start();
            oscillator.stop(audioContext.currentTime + 0.45);
          } catch {
            // L'alerte visuelle reste disponible si le son est bloqué.
          }
        }
      }
    };

    for (const v of VEHICLE_DEFS) {
      if (!previewIdsRef.current.has(v.id)) continue;

      const pts = pathCoords(v, realPathsRef.current);
      const total = pathLen(pts);
      const cycle = 2 * total;
      let d = (((now * v.speed * 0.02 + v.phase) % cycle) + cycle) % cycle;
      let reverse = false;
      if (d > total) {
        d = cycle - d;
        reverse = true;
      }
      const p = pointAt(pts, d);
      const dir = reverse ? -1 : 1;
      const eps = Math.max(0.00035, total * 0.03);
      const ahead = pointAt(pts, Math.max(0, Math.min(total, d + dir * eps)));
      const behind = pointAt(pts, Math.max(0, Math.min(total, d - dir * eps)));
      const east = (ahead.lng - behind.lng) * Math.cos((p.lat * Math.PI) / 180);
      const north = ahead.lat - behind.lat;
      let heading = (Math.atan2(east, north) * 180) / Math.PI;
      const previous = previewAnglesRef.current.get(v.id);
      if (previous != null) {
        const delta = ((heading - previous + 540) % 360) - 180;
        heading = previous + delta * 0.25;
      }
      previewAnglesRef.current.set(v.id, heading);
      vehicleLayerRef.current?.setPreviewPose(v.id, p.lat, p.lng, heading);
      syncTrackedVehicle(v.id, {
        lat: p.lat,
        lng: p.lng,
        heading,
        speedMps: null,
      });
    }

    const lineAnimation = lineVehicleAnimationRef.current;
    if (lineAnimation && previewIdsRef.current.has(lineAnimation.id)) {
      const terminalPause = 3;
      const elapsed = Math.max(0, now - lineAnimation.startedAt);
      const legDuration = lineAnimation.travelDuration;
      const cycleDuration = 2 * (legDuration + terminalPause);
      const phase = elapsed % cycleDuration;
      let distance = 0;
      let reverse = false;

      if (phase < terminalPause) {
        distance = 0;
      } else if (phase < terminalPause + legDuration) {
        distance =
          ((phase - terminalPause) / legDuration) * lineAnimation.length;
      } else if (phase < terminalPause * 2 + legDuration) {
        distance = lineAnimation.length;
        reverse = true;
      } else {
        distance =
          (1 -
            (phase - terminalPause * 2 - legDuration) / legDuration) *
          lineAnimation.length;
        reverse = true;
      }

      const p = pointAt(lineAnimation.coords, distance);
      const direction = reverse ? -1 : 1;
      const epsilon = Math.max(0.00012, lineAnimation.length * 0.008);
      const ahead = pointAt(
        lineAnimation.coords,
        Math.max(
          0,
          Math.min(
            lineAnimation.length,
            distance + direction * epsilon,
          ),
        ),
      );
      const behind = pointAt(
        lineAnimation.coords,
        Math.max(
          0,
          Math.min(
            lineAnimation.length,
            distance - direction * epsilon,
          ),
        ),
      );
      const east =
        (ahead.lng - behind.lng) * Math.cos((p.lat * Math.PI) / 180);
      const north = ahead.lat - behind.lat;
      let heading = (Math.atan2(east, north) * 180) / Math.PI;
      const previous = previewAnglesRef.current.get(lineAnimation.id);
      if (previous != null) {
        const delta = ((heading - previous + 540) % 360) - 180;
        heading = previous + delta * 0.3;
      }
      previewAnglesRef.current.set(lineAnimation.id, heading);
      vehicleLayerRef.current?.setPreviewPose(
        lineAnimation.id,
        p.lat,
        p.lng,
        heading,
      );
      syncTrackedVehicle(lineAnimation.id, {
        lat: p.lat,
        lng: p.lng,
        heading,
        speedMps: null,
      });
    }

    for (const vehicle of displayVehiclesRef.current) {
      if (vehicle.mode !== "live") continue;
      syncTrackedVehicle(vehicle.id, {
        lat: vehicle.lat,
        lng: vehicle.lng,
        heading: vehicle.heading,
        speedMps: vehicle.speedMps,
      });
    }
  }, []);

  // ===== Initialisation de la carte (une seule fois) =====
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    let map: maplibregl.Map;
    try {
      map = new maplibregl.Map({
        container: mapContainerRef.current,
        style: "https://tiles.openfreemap.org/styles/liberty",
        center: [CITY_CENTER[1], CITY_CENTER[0]],
        zoom: 14,
        pitch: 55,
        bearing: -18,
        canvasContextAttributes: { antialias: true, preserveDrawingBuffer: false },
        attributionControl: { compact: true },
      });
    } catch (err) {
      console.error("[ImmersiveMap] Échec de création du contexte WebGL", err);
      setMapError(
        "La carte 3D n'a pas pu s'initialiser sur cet appareil (WebGL indisponible).",
      );
      return;
    }
    mapRef.current = map;
    map.on("error", (e) => console.error("[ImmersiveMap] Erreur MapLibre", e.error));
    registerMissingImageFallback(map);
    map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), "bottom-right");
    map.addControl(createLocateControl(() => locateActionRef.current()), "bottom-right");
    map.dragRotate.enable();
    requestAnimationFrame(() => map.resize());
    const resizeTimer = setTimeout(() => map.resize(), 300);

    const handleViewportResize = () => map.resize();
    const resizeObserver = new ResizeObserver(handleViewportResize);
    resizeObserver.observe(mapContainerRef.current);
    window.addEventListener("orientationchange", handleViewportResize);
    window.visualViewport?.addEventListener("resize", handleViewportResize);

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
      ensureRouteLayer(map);
      ensureTransitTracesLayer(
        map,
        realLineTraces.map((t) => ({
          id: t.id,
          type: t.type,
          color: t.color,
          coords: t.coords.map(([lat, lng]) => [lng, lat] as [number, number]),
        })),
      );
      const vehicleLayer = new Vehicle3DLayer({
        onSelect: (id) => apiRef.current.select("vehicle", id),
      });
      vehicleLayerRef.current = vehicleLayer;
      vehicleLayer.setVehicles(displayVehiclesRef.current);
      map.addLayer(vehicleLayer);
      vehicleLayer.moveToTop();
      buildMarkers();
      readyRef.current = true;

      map.on("moveend", () => {
        if (focusModeRef.current !== "shop" || !shopSearchCenterRef.current) return;
        const c1 = shopSearchCenterRef.current;
        const c2 = map.getCenter();
        const d = Math.hypot(c1.lat - c2.lat, c1.lng - c2.lng);
        if (d > 0.003 && !showSearchAreaRef.current) setShowSearchArea(true);
      });

      const knownPosition = userPositionRef.current;
      const introCenter = knownPosition ?? CITY_CENTER;
      map.flyTo({
        center: [introCenter[1], introCenter[0]],
        zoom: 15.6,
        pitch: 58,
        bearing: -18,
        duration: 2400,
      });
      rafRef.current = requestAnimationFrame(tick);
    });

    return () => {
      clearTimeout(resizeTimer);
      resizeObserver.disconnect();
      window.removeEventListener("orientationchange", handleViewportResize);
      window.visualViewport?.removeEventListener("resize", handleViewportResize);
      cancelAnimationFrame(rafRef.current);
      map.remove();
      mapRef.current = null;
      vehicleLayerRef.current = null;
      readyRef.current = false;
    };
    // La carte n'est montée qu'une fois ; les mises à jour passent par les refs et actions ci-dessous.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Refs "toujours à jour" pour les callbacks de la carte (moveend) qui ne doivent pas être recréés.
  const focusModeRef = useRef<FocusMode>(null);
  const showSearchAreaRef = useRef(false);
  useEffect(() => {
    focusModeRef.current = focusMode;
    showSearchAreaRef.current = showSearchArea;
  }, [focusMode, showSearchArea]);

  useEffect(() => {
    vehicleLayerRef.current?.setVehicles(displayVehicles);
  }, [displayVehicles]);

  useEffect(() => {
    vehicleLayerRef.current?.setSelected(
      tracking?.vehicleId ??
        (selectedKind === "vehicle" ? selectedId : null),
    );
  }, [selectedKind, selectedId, tracking?.vehicleId]);

  useEffect(() => {
    vehicleLayerRef.current?.setFocus(focusMode);
  }, [focusMode]);

  useEffect(() => {
    const layer = vehicleLayerRef.current;
    if (!layer) return;
    layer.setView3D(view3D);
    layer.setFilter("bus", filters.bus);
    layer.setFilter("tram", filters.tram);
    layer.setFilter("vtc", filters.vtc);
    layer.setFilter("taxi", filters.taxi);
  }, [view3D, filters]);

  useEffect(
    () => () => {
      clearTimeout(orderTimeoutRef.current);
      clearTimeout(trackingAlertTimeoutRef.current);
    },
    [],
  );

  // ===== Vue 3D / 2D =====
  const toggleView = () => {
    const next = !view3D;
    setView3D(next);
    vehicleLayerRef.current?.setView3D(next);
    const map = mapRef.current;
    if (!map) return;
    if (next) {
      const pos = userPositionRef.current;
      map.easeTo({
        pitch: 58,
        bearing: -16,
        duration: 900,
        zoom: Math.max(map.getZoom(), 16.5),
        ...(geoGranted && pos ? { center: [pos[1], pos[0]] as [number, number] } : {}),
      });
    } else {
      map.easeTo({ pitch: 0, bearing: 0, duration: 900 });
    }
  };

  // ===== Vue 360° =====
  const toggleOrbit = () => {
    const map = mapRef.current;
    if (orbitingRef.current) {
      orbitingRef.current = false;
      setOrbiting(false);
      return;
    }
    if (!map) return;
    orbitingRef.current = true;
    setOrbiting(true);
    if (view3D && map.getPitch() < 30) map.easeTo({ pitch: 58, duration: 500 });
    const start = map.getBearing();
    const t0 = performance.now();
    const dur = 7000;
    const step = (t: number) => {
      if (!orbitingRef.current || !mapRef.current) return;
      const k = Math.min(1, (t - t0) / dur);
      const eased = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
      mapRef.current.setBearing(start + 360 * eased);
      if (k < 1) requestAnimationFrame(step);
      else {
        orbitingRef.current = false;
        setOrbiting(false);
      }
    };
    requestAnimationFrame(step);
  };

  // ===== Géolocalisation (réelle, via l'API navigateur) =====
  const flyToPosition = (center: LatLng, pitchOverride?: number, bearingOverride?: number, duration = 1800) => {
    const map = mapRef.current;
    if (!map) return;
    map.flyTo({
      center: [center[1], center[0]],
      zoom: 17.3,
      pitch: pitchOverride ?? (view3D ? 60 : 0),
      bearing: bearingOverride ?? (view3D ? -14 : 0),
      duration,
    });
  };

  const placeUserMarker = (position: LatLng) => {
    userPositionRef.current = position;
    userMarkerRef.current?.setLngLat([position[1], position[0]]);
  };

  const resolveOriginAddress = useCallback(async (position: LatLng) => {
    setOriginAddressLoading(true);
    try {
      const params = new URLSearchParams({
        lat: String(position[0]),
        lng: String(position[1]),
      });
      const response = await fetch(`/api/geocode?${params.toString()}`, { cache: "no-store" });
      if (!response.ok) throw new Error("Adresse indisponible");

      const data = (await response.json()) as { result?: { label?: string } };
      const label = data.result?.label?.trim();
      setOriginAddress(label || "Votre position actuelle");
    } catch {
      setOriginAddress("Votre position actuelle");
    } finally {
      setOriginAddressLoading(false);
    }
  }, []);

  const locateUser = useCallback((onFound: (position: LatLng) => void, onError: () => void) => {
    if (!("geolocation" in navigator)) {
      onError();
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => onFound([pos.coords.latitude, pos.coords.longitude]),
      () => onError(),
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 10000 },
    );
  }, []);

  const startWatchingPosition = useCallback(() => {
    if (!("geolocation" in navigator) || geoWatchIdRef.current != null) return;
    geoWatchIdRef.current = navigator.geolocation.watchPosition(
      (pos) => placeUserMarker([pos.coords.latitude, pos.coords.longitude]),
      () => {},
      { enableHighAccuracy: true, maximumAge: 10000 },
    );
  }, []);

  const onGeoAllow = () => {
    setGeoPromptVisible(false);
    locateUser(
      (position) => {
        localStorage.setItem(GEOLOCATION_CONSENT_KEY, "granted");
        setGeoGranted(true);
        setGeoDeniedNoticeVisible(false);
        placeUserMarker(position);
        void resolveOriginAddress(position);
        flyToPosition(position);
        startWatchingPosition();
      },
      () => {
        localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
        setGeoGranted(false);
        setGeoDeniedNoticeVisible(true);
      },
    );
  };
  const onGeoDeny = () => {
    setGeoGranted(false);
    setGeoPromptVisible(false);
    setGeoDeniedNoticeVisible(true);
  };
  const onLocateClick = () => {
    setGeoDeniedNoticeVisible(false);
    locateUser(
      (position) => {
        localStorage.setItem(GEOLOCATION_CONSENT_KEY, "granted");
        setGeoGranted(true);
        placeUserMarker(position);
        void resolveOriginAddress(position);
        flyToPosition(position);
        startWatchingPosition();
      },
      () => {
        localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
        setGeoGranted(false);
        setGeoDeniedNoticeVisible(true);
      },
    );
  };
  locateActionRef.current = onLocateClick;

  useEffect(() => {
    let cancelled = false;

    const restoreGeolocationConsent = async () => {
      const consentWasGranted = localStorage.getItem(GEOLOCATION_CONSENT_KEY) === "granted";
      let permissionState: PermissionState | null = null;

      if ("permissions" in navigator) {
        try {
          const permission = await navigator.permissions.query({ name: "geolocation" });
          permissionState = permission.state;
        } catch {
          // Certains navigateurs ne prennent pas en charge la requête de permission géolocalisation.
        }
      }

      if (cancelled) return;

      if (permissionState === "denied") {
        localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
        setGeoDeniedNoticeVisible(true);
        return;
      }

      if (permissionState === "prompt") {
        localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
        setGeoPromptVisible(true);
        return;
      }

      if (permissionState !== "granted" && !consentWasGranted) {
        setGeoPromptVisible(true);
        return;
      }

      locateUser(
        (position) => {
          if (cancelled) return;
          localStorage.setItem(GEOLOCATION_CONSENT_KEY, "granted");
          setGeoGranted(true);
          setGeoDeniedNoticeVisible(false);
          placeUserMarker(position);
          void resolveOriginAddress(position);
          flyToPosition(position, undefined, undefined, 0);
          startWatchingPosition();
        },
        () => {
          if (cancelled) return;
          localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
          setGeoGranted(false);
          setGeoDeniedNoticeVisible(true);
        },
      );
    };

    void restoreGeolocationConsent();

    return () => {
      cancelled = true;
      if (geoWatchIdRef.current != null) navigator.geolocation.clearWatch(geoWatchIdRef.current);
    };
    // La restauration ne doit s'exécuter qu'une fois au chargement de la page.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ===== Recherche =====
  async function geocodeQuery(q: string): Promise<GeocodeResult[]> {
    try {
      const res = await fetch(`/api/geocode?q=${encodeURIComponent(q)}`);
      if (!res.ok) return [];
      const data = (await res.json()) as { results?: Array<{ label: string; lat: number; lng: number }> };
      return (data.results ?? []).slice(0, 5).map((result) => {
        const [name] = result.label.split(",");
        return {
          name: name.trim(),
          label: result.label,
          latLng: [result.lat, result.lng] as LatLng,
        };
      });
    } catch {
      return [];
    }
  }

  useEffect(() => {
    const query = searchQuery.trim();
    const requestId = ++addressSearchRequestRef.current;

    if (query.length < 3 || selectedDestination?.label === query) {
      setAddressSuggestions([]);
      setAddressSuggestionsLoading(false);
      return;
    }

    const handle = setTimeout(() => {
      setAddressSuggestionsLoading(true);
      void geocodeQuery(query).then((results) => {
        if (addressSearchRequestRef.current !== requestId) return;
        setAddressSuggestions(results);
        setAddressSuggestionsLoading(false);
      });
    }, 320);

    return () => clearTimeout(handle);
  }, [searchQuery, selectedDestination]);

  const computeRoute = async (mode: RouteMode, origin: LatLng, dest: LatLng, name: string) => {
    const map = mapRef.current;
    if (!map) return;

    activeRouteRef.current = { origin, dest, destName: name };
    setRouteActive(true);
    setRouteLoading(true);
    setRouteError(null);
    setRouteInfo(null);

    try {
      const apiMode = mode === "transit" ? "transit" : mode;
      const url = `/api/route?mode=${apiMode}&from=${origin[1]},${origin[0]}&to=${dest[1]},${dest[0]}`;
      const res = await fetch(url, { cache: "no-store" });
      const data = (await res.json()) as {
        coordinates?: [number, number][];
        distance?: number;
        duration?: number;
        steps?: RouteStep[];
        error?: string;
      };
      if (!res.ok || !data.coordinates) {
        throw new Error(data.error ?? "Itinéraire indisponible");
      }

      const src = map.getSource("immersive-map-route") as maplibregl.GeoJSONSource | undefined;
      src?.setData({
        type: "Feature",
        properties: {},
        geometry: { type: "LineString", coordinates: data.coordinates },
      });
      if (map.getLayer("immersive-map-route-line")) {
        map.setLayoutProperty("immersive-map-route-line", "line-cap", "round");
        map.setPaintProperty("immersive-map-route-line", "line-color", "#33bfa3");
        map.setPaintProperty("immersive-map-route-line", "line-width", 5);
      }

      destMarkerRef.current?.remove();
      destMarkerRef.current = new maplibregl.Marker({ element: createDestElement(), anchor: "bottom" })
        .setLngLat([dest[1], dest[0]])
        .addTo(map);

      const bounds = new maplibregl.LngLatBounds([origin[1], origin[0]], [origin[1], origin[0]]);
      bounds.extend([dest[1], dest[0]]);
      map.fitBounds(bounds, {
        padding: { top: 140, bottom: 120, left: 380, right: 120 },
        pitch: view3D ? 50 : 0,
        duration: 1600,
        maxZoom: 16.5,
      });

      const durationMin = Math.max(1, Math.round((data.duration ?? 0) / 60));
      const distanceM = Math.round(data.distance ?? 0);
      const distanceLabel = distanceM >= 1000 ? `${(distanceM / 1000).toFixed(1)} km` : `${distanceM} m`;
      const steps =
        data.steps ??
        ([
          {
            icon: mode === "car" ? "🚗" : "🚶",
            label: mode === "car" ? `En voiture jusqu'à ${name}` : `Marche à pied jusqu'à ${name}`,
            detail: distanceLabel,
            duration: `${durationMin} min`,
          },
        ] as RouteStep[]);

      setRouteInfo({ distanceM, durationMin, steps });
    } catch (err) {
      setRouteError(err instanceof Error ? err.message : "Itinéraire indisponible");
    } finally {
      setRouteLoading(false);
    }
  };

  const onSearchSubmit = async () => {
    const rawQuery = searchQuery.trim();
    if (rawQuery.length < 3) {
      setSearchError("Saisissez une adresse ou un lieu d’au moins 3 caractères.");
      return;
    }

    const origin = userPositionRef.current;
    if (!origin) {
      setSearchError("Votre position GPS est nécessaire pour définir le point de départ.");
      setGeoPromptVisible(true);
      return;
    }

    setDestinationLoading(true);
    setSearchError(null);
    try {
      const destination =
        selectedDestination?.label === rawQuery
          ? selectedDestination
          : (await geocodeQuery(rawQuery))[0];
      if (!destination) {
        setSearchError("Adresse introuvable. Vérifiez la saisie puis réessayez.");
        return;
      }

      setSelectedKind(null);
      setSelectedId(null);
      setDestName(destination.name);
      setShowRouteInputs(false);
      await computeRoute(routeMode, origin, destination.latLng, destination.name);
    } finally {
      setDestinationLoading(false);
    }
  };

  const pickAddressSuggestion = (destination: GeocodeResult) => {
    setSearchQuery(destination.label);
    setSelectedDestination(destination);
    setAddressSuggestions([]);
    setShowAddressSuggestions(false);
    setSearchError(null);
  };

  const changeRouteMode = (mode: RouteMode) => {
    setRouteMode(mode);
    const active = activeRouteRef.current;
    if (active) void computeRoute(mode, active.origin, active.dest, active.destName);
  };

  const closeRoute = () => {
    setRouteActive(false);
    setRouteError(null);
    setSearchError(null);
    setAddressSuggestions([]);
    setShowAddressSuggestions(false);
    setSelectedDestination(null);
    setRouteInfo(null);
    setShowRouteInputs(false);
    activeRouteRef.current = null;
    const map = mapRef.current;
    const src = map?.getSource("immersive-map-route") as maplibregl.GeoJSONSource | undefined;
    src?.setData({ type: "FeatureCollection", features: [] });
    destMarkerRef.current?.remove();
    destMarkerRef.current = null;
  };

  // ===== Filtres & actions rapides =====
  const setVehicleTypeDisplay = (type: FilterKey, show: boolean) => {
    if (type === "shop") {
      for (const id in shopMarkersRef.current) shopMarkersRef.current[id].getElement().style.display = show ? "" : "none";
      return;
    }
    vehicleLayerRef.current?.setFilter(type, show);
    if (type === "bus" || type === "tram") {
      const nextFilters = { ...filters, [type]: show };
      const map = mapRef.current;
      if (map) {
        setTransitTracesFilter(
          map,
          (["bus", "tram"] as const).filter((t) => nextFilters[t]),
        );
      }
    }
  };

  const toggleFilter = (key: FilterKey) => {
    const next = !filters[key];
    setFilters((f) => ({ ...f, [key]: next }));
    setVehicleTypeDisplay(key, next);
  };

  const ensureVisible = (keys: FilterKey[]) => {
    setFilters((f) => {
      const upd = { ...f };
      for (const k of keys) upd[k] = true;
      return upd;
    });
    for (const k of keys) setVehicleTypeDisplay(k, true);
  };

  const applyFocus = (mode: FocusMode) => {
    vehicleLayerRef.current?.setFocus(mode);
    const setOp = (marker: maplibregl.Marker | undefined, on: boolean) => {
      if (!marker) return;
      const el = marker.getElement();
      el.style.transition = "opacity .45s ease";
      el.style.opacity = on ? "1" : "0.22";
    };
    for (const id in shopMarkersRef.current) {
      let on = true;
      if (mode === "ride") on = false;
      setOp(shopMarkersRef.current[id], on);
    }
  };

  const flyGentle = () => {
    const map = mapRef.current;
    if (!map) return;
    map.flyTo({
      center: map.getCenter(),
      zoom: Math.max(map.getZoom(), 16.6),
      pitch: view3D ? 58 : 0,
      duration: 1100,
    });
  };

  const clearFocus = () => {
    setFocusMode(null);
    setShowRouteInputs(false);
    applyFocus(null);
  };

  const qaRoute = () => {
    setFocusMode(null);
    setSearchQuery("");
    setSearchError(null);
    setShowRouteInputs(true);
    setSelectedKind(null);
    setSelectedId(null);
    applyFocus(null);
  };
  const qaRide = () => {
    ensureVisible(["vtc", "taxi"]);
    setFocusMode("ride");
    setSelectedKind(null);
    setSelectedId(null);
    setRouteActive(false);
    setSearchError(null);
    setShowRouteInputs(true);
    setQuickCollapsed(true);
    applyFocus("ride");
    flyGentle();
  };
  const qaShop = () => {
    ensureVisible(["shop"]);
    setFocusMode("shop");
    setSelectedKind(null);
    setSelectedId(null);
    setRouteActive(false);
    setShowRouteInputs(false);
    setShowSearchArea(false);
    setQuickCollapsed(true);
    applyFocus("shop");
    flyGentle();
    if (mapRef.current) shopSearchCenterRef.current = mapRef.current.getCenter();
  };

  const searchThisArea = () => {
    setShowSearchArea(false);
    if (mapRef.current) shopSearchCenterRef.current = mapRef.current.getCenter();
  };

  // ===== Commerçants : recherche / tri =====
  const computeShopResults = (): ShopDef[] => {
    const q = shopQuery.trim().toLowerCase();
    const cats = Object.keys(activeCats).filter((k) => activeCats[k]);
    let list = SHOP_DEFS.filter((s) => {
      if (cats.length && !cats.includes(s.catKey)) return false;
      if (q && !(s.name + " " + s.cat).toLowerCase().includes(q)) return false;
      return true;
    });
    list = [...list].sort((a, b) => {
      if (sortMode === "rating") return Number(b.rating) - Number(a.rating);
      if (sortMode === "delivery") return (parseInt(a.delivery) || 999) - (parseInt(b.delivery) || 999);
      if (sortMode === "price") return a.price.length - b.price.length;
      if (sortMode === "popularity") return b.popularity - a.popularity;
      if (sortMode === "open") return (b.open ? 1 : 0) - (a.open ? 1 : 0);
      return a.distM - b.distM;
    });
    return list;
  };

  // ===== Panier / commerçant =====
  const addItem = (id: string) => setCart((c) => ({ ...c, [id]: (c[id] || 0) + 1 }));
  const decItem = (id: string) =>
    setCart((c) => {
      const q = (c[id] || 0) - 1;
      const next = { ...c };
      if (q <= 0) delete next[id];
      else next[id] = q;
      return next;
    });
  const toggleCart = () => setCartOpen((o) => !o);
  const closeMerchant = () => {
    clearTimeout(orderTimeoutRef.current);
    setMerchantId(null);
    setOrderPlaced(false);
  };
  const placeOrder = () => {
    if (!Object.keys(cart).length) return;
    setOrderPlaced(true);
    clearTimeout(orderTimeoutRef.current);
    orderTimeoutRef.current = setTimeout(() => {
      setOrderPlaced(false);
      setMerchantId(null);
      setCart({});
      setCartOpen(false);
    }, 2600);
  };

  const closeSelection = () => {
    setSelectedKind(null);
    setSelectedId(null);
    setSearchLineSelection(null);
    clearSelectedLineMap();
  };

  // ===== Dérivés pour le rendu =====
  const globalSearchSuggestions = useMemo<GlobalSearchSuggestion[]>(() => {
    const uniqueDashboardLines = new Map(
      [...dashboardLines, ...publishedCustomLines].map((line) => [line.id, line]),
    );
    const lineSuggestions = [...uniqueDashboardLines.values()].map((line) => {
      const transport = line.transportType.toLowerCase();
      const mode = transport.includes("tram")
        ? ("tram" as const)
        : transport.includes("navibus") || transport.includes("bateau")
          ? ("navibus" as const)
          : ("bus" as const);
      const modeLabel = mode === "tram" ? "Tram" : mode === "navibus" ? "Navibus" : "Bus";
      return {
        id: `line:dashboard:${line.id}`,
        category: "line" as const,
        mode,
        title: `${modeLabel} ${line.shortName}`,
        subtitle: `${line.origin} ↔ ${line.destination} · ${line.depotCode}`,
        keywords: `${line.shortName} ${line.routeId} ${line.origin} ${line.destination} ${line.depotCode} ligne transport`,
      };
    });

    const driverSuggestions = VEHICLE_DEFS.filter(
      (vehicle) => vehicle.type === "vtc" || vehicle.type === "taxi",
    ).map((vehicle) => ({
      id: `driver:${vehicle.id}`,
      category: "driver" as const,
      mode: vehicle.type,
      title:
        vehicle.type === "vtc"
          ? vehicle.driver ?? "Chauffeur VTC"
          : `Taxi · ${vehicle.station ?? "Disponible"}`,
      subtitle:
        vehicle.type === "vtc"
          ? `VTC · ★ ${vehicle.rating} · Arrivée ${vehicle.eta}`
          : `Taxi disponible · Arrivée ${vehicle.eta}`,
      keywords: `${vehicle.station ?? ""} chauffeur voiture ${vehicle.dist ?? ""}`,
    }));

    const merchantSuggestions = SHOP_DEFS.map((shop) => ({
      id: `merchant:${shop.id}`,
      category: "merchant" as const,
      mode: "shop" as const,
      title: shop.name,
      subtitle: `${shop.cat} · ${shop.dist} · ${shop.open ? "Ouvert" : "Fermé"}`,
      keywords: `${shop.catKey} ${shop.cat} commerce boutique ${shop.rating}`,
    }));

    return [
      ...lineSuggestions,
      ...driverSuggestions,
      ...merchantSuggestions,
    ];
  }, [dashboardLines, publishedCustomLines]);

  const focusSearchCoordinates = useCallback(
    (coords: LatLng[], maxZoom = 16.5) => {
      const map = mapRef.current;
      if (!map || coords.length === 0) return;
      if (coords.length === 1) {
        map.flyTo({
          center: [coords[0][1], coords[0][0]],
          zoom: maxZoom,
          pitch: view3D ? 56 : 0,
          duration: 1200,
        });
        return;
      }
      const first = coords[0];
      const bounds = new maplibregl.LngLatBounds(
        [first[1], first[0]],
        [first[1], first[0]],
      );
      coords.slice(1).forEach(([lat, lng]) => bounds.extend([lng, lat]));
      map.fitBounds(bounds, {
        padding: { top: 130, right: 110, bottom: 120, left: 110 },
        maxZoom,
        pitch: view3D ? 48 : 0,
        duration: 1400,
      });
    },
    [view3D],
  );

  const clearSelectedLineMap = useCallback(() => {
    lineStopMarkersRef.current.forEach((marker) => marker.remove());
    lineStopMarkersRef.current = [];
    const lineVehicleId = lineVehicleAnimationRef.current?.id;
    if (lineVehicleId) previewAnglesRef.current.delete(lineVehicleId);
    lineVehicleAnimationRef.current = null;
    activeLineMapDataRef.current = null;
    setLineVehicle(null);

    const map = mapRef.current;
    const source = map?.getSource("immersive-map-route") as
      | maplibregl.GeoJSONSource
      | undefined;
    source?.setData({ type: "FeatureCollection", features: [] });
    if (map?.getLayer("immersive-map-transit-traces-line")) {
      map.setPaintProperty("immersive-map-transit-traces-line", "line-opacity", 0.55);
    }
  }, []);

  const displayDashboardLineOnMap = useCallback(
    async (
      line: DashboardLineSearchItem,
      suggestion: GlobalSearchSuggestion,
    ) => {
      let data: LoadedLineMapData | null = null;

      if (line.id.startsWith("custom:")) {
        const draft = loadLineEditorDraft(line.id);
        if (draft) {
          const points = getVoicePoints(draft, "aller");
          const trace = points.map(
            (point) =>
              [point.coordinates[1], point.coordinates[0]] as LatLng,
          );
          const stops = points
            .filter((point) => isStopType(point.type))
            .map((point) => ({
              id: point.id,
              name: point.stop?.name?.trim() || "Arrêt",
              lat: point.coordinates[1],
              lng: point.coordinates[0],
            }));
          if (trace.length >= 2) data = { trace, stops };
        }
      } else {
        try {
          const response = await fetch(
            `/api/carte-immersive/line?lineId=${encodeURIComponent(line.id)}`,
            { cache: "no-store" },
          );
          if (response.ok) data = (await response.json()) as LoadedLineMapData;
        } catch {
          data = null;
        }
      }

      const map = mapRef.current;
      if (!map || !data || data.trace.length < 2) return;

      clearSelectedLineMap();
      activeLineMapDataRef.current = data;
      const source = map.getSource("immersive-map-route") as
        | maplibregl.GeoJSONSource
        | undefined;
      source?.setData({
        type: "Feature",
        properties: {},
        geometry: {
          type: "LineString",
          coordinates: data.trace.map(([lat, lng]) => [lng, lat]),
        },
      });
      if (map.getLayer("immersive-map-route-line")) {
        map.setLayoutProperty("immersive-map-route-line", "line-cap", "round");
        map.setPaintProperty("immersive-map-route-line", "line-color", line.color);
        map.setPaintProperty("immersive-map-route-line", "line-width", 6);
      }
      if (map.getLayer("immersive-map-transit-traces-line")) {
        map.setPaintProperty("immersive-map-transit-traces-line", "line-opacity", 0.12);
      }

      lineStopMarkersRef.current = data.stops.map((stop, index) =>
        new maplibregl.Marker({
          element: createLineStopElement(
            stop.name,
            index,
            data.stops.length,
            line.color,
          ),
          anchor: "center",
        })
          .setLngLat([stop.lng, stop.lat])
          .addTo(map),
      );

      if (suggestion.mode === "bus" || suggestion.mode === "tram") {
        const vehicleId = `selected-line:${line.id}`;
        const start = pointAt(data.trace, 0);
        const length = pathLen(data.trace);
        const travelDuration = Math.min(
          180,
          Math.max(70, length / 0.00018),
        );
        const vehicleType = suggestion.mode;
        setLineVehicle({
          id: vehicleId,
          type: vehicleType,
          mode: "preview",
          lat: start.lat,
          lng: start.lng,
          heading: 0,
          speedMps: null,
          recordedAt: null,
          routeId: line.shortName,
          destination: line.destination,
          preview: {
            id: vehicleId,
            type: vehicleType,
            path: "",
            speed: 0,
            phase: 0,
            line: suggestion.title,
            dest: line.destination,
            nextStop: data.stops[1]?.name ?? data.stops[0]?.name,
            eta: "En circulation",
            status: "Suit le tracé de la ligne",
          },
        });
        lineVehicleAnimationRef.current = {
          id: vehicleId,
          coords: data.trace,
          length,
          startedAt: performance.now() / 1000,
          travelDuration,
        };
      }

      setSearchLineSelection({
        title: suggestion.title,
        mode:
          suggestion.mode === "tram"
            ? "tram"
            : suggestion.mode === "navibus"
              ? "navibus"
              : "bus",
        subtitle: suggestion.subtitle,
        coords: data.trace,
        stopCount: data.stops.length,
      });
      focusSearchCoordinates(
        data.trace,
        suggestion.mode === "navibus" ? 14.8 : 15.8,
      );
    },
    [clearSelectedLineMap, focusSearchCoordinates],
  );

  const handleGlobalSearchSelect = (suggestion: GlobalSearchSuggestion) => {
      setGlobalSearchQuery(suggestion.title);
      setShowRouteInputs(false);
      setRouteActive(false);
      setFocusMode(null);
      setSelectedKind(null);
      setSelectedId(null);
      applyFocus(null);

      if (suggestion.id.startsWith("merchant:")) {
        const shopId = suggestion.id.slice("merchant:".length);
        ensureVisible(["shop"]);
        select("shop", shopId);
        const marker = shopMarkersRef.current[shopId];
        if (marker) {
          const position = marker.getLngLat();
          focusSearchCoordinates([[position.lat, position.lng]]);
        }
        return;
      }

      if (suggestion.id.startsWith("driver:")) {
        const vehicleId = suggestion.id.slice("driver:".length);
        ensureVisible([suggestion.mode === "taxi" ? "taxi" : "vtc"]);
        select("vehicle", vehicleId);
        const vehicle = displayVehicles.find((item) => item.id === vehicleId);
        if (vehicle) focusSearchCoordinates([[vehicle.lat, vehicle.lng]]);
        return;
      }

      if (suggestion.id.startsWith("line:dashboard:")) {
        const lineId = suggestion.id.slice("line:dashboard:".length);
        const line = [...dashboardLines, ...publishedCustomLines].find(
          (item) => item.id === lineId,
        );
        if (!line) return;

        if (suggestion.mode === "tram") ensureVisible(["tram"]);
        if (suggestion.mode === "bus") ensureVisible(["bus"]);

        clearSelectedLineMap();
        setSearchLineSelection({
          title: suggestion.title,
          mode:
            suggestion.mode === "tram"
              ? "tram"
              : suggestion.mode === "navibus"
                ? "navibus"
                : "bus",
          subtitle: suggestion.subtitle,
          coords: [],
        });
        void displayDashboardLineOnMap(line, suggestion);
        return;
      }

      if (suggestion.id.startsWith("line:vehicle:")) {
        const vehicleId = suggestion.id.slice("line:vehicle:".length);
        ensureVisible([suggestion.mode === "tram" ? "tram" : "bus"]);
        select("vehicle", vehicleId);
        const vehicle = displayVehicles.find((item) => item.id === vehicleId);
        if (vehicle) focusSearchCoordinates([[vehicle.lat, vehicle.lng]]);
        return;
      }

      if (suggestion.id.startsWith("line:trace:")) {
        const traceId = suggestion.id.slice("line:trace:".length);
        const trace = realLineTraces.find((item) => item.id === traceId);
        if (!trace) return;
        ensureVisible([trace.type]);
        const selection: SearchLineSelection = {
          title: suggestion.title,
          mode: trace.type,
          subtitle: suggestion.subtitle,
          coords: trace.coords,
        };
        setSearchLineSelection(selection);
        focusSearchCoordinates(trace.coords, 15.8);
        return;
      }

      if (suggestion.id.startsWith("line:navibus:")) {
        const lineId = suggestion.id.slice("line:navibus:".length);
        const navibus = NAVIBUS_SEARCH_LINES.find((line) => line.id === lineId);
        if (!navibus) return;
        const selection: SearchLineSelection = {
          title: navibus.title,
          mode: "navibus",
          subtitle: navibus.subtitle,
          coords: navibus.coords,
        };
        setSearchLineSelection(selection);
        focusSearchCoordinates(navibus.coords, 14.8);
      }
  };

  const showLineStops = useCallback(
    (stops: LineStop[], color = "#33bfa3") => {
      const map = mapRef.current;
      lineStopMarkersRef.current.forEach((marker) => marker.remove());
      lineStopMarkersRef.current = [];
      if (!map) return;

      lineStopMarkersRef.current = stops.map((stop, index) =>
        new maplibregl.Marker({
          element: createLineStopElement(
            stop.name,
            index,
            stops.length,
            color,
          ),
          anchor: "center",
        })
          .setLngLat([stop.lng, stop.lat])
          .addTo(map),
      );
    },
    [],
  );
  showLineStopsRef.current = showLineStops;

  const showTrackingRoute = useCallback((route: LatLng[]) => {
    const map = mapRef.current;
    if (!map || route.length < 2) return;
    updateRouteSource(map, route);
    if (map.getLayer("immersive-map-route-line")) {
      map.setLayoutProperty("immersive-map-route-line", "line-cap", "butt");
      map.setPaintProperty(
        "immersive-map-route-line",
        "line-color",
        "#33bfa3",
      );
      map.setPaintProperty("immersive-map-route-line", "line-width", 5.5);
    }
    if (map.getLayer("immersive-map-transit-traces-line")) {
      map.setPaintProperty(
        "immersive-map-transit-traces-line",
        "line-opacity",
        0.1,
      );
    }
  }, []);

  const recenterTrackedVehicle = useCallback(() => {
    const activeTracking = trackingRef.current;
    if (!activeTracking) return;
    const vehicle = displayVehiclesRef.current.find(
      (item) => item.id === activeTracking.vehicleId,
    );
    const pose = vehiclePoseRef.current.get(activeTracking.vehicleId) ??
      (vehicle
        ? {
            lat: vehicle.lat,
            lng: vehicle.lng,
            heading: vehicle.heading,
            speedMps: vehicle.speedMps,
          }
        : null);
    if (!pose) return;
    mapRef.current?.easeTo({
      center: [pose.lng, pose.lat],
      zoom: 17.6,
      pitch: 67,
      bearing: pose.heading,
      duration: 700,
      essential: true,
    });
  }, []);

  const startVehicleTracking = async (vehicleId: string) => {
    const vehicle = displayVehicles.find((item) => item.id === vehicleId);
    if (!vehicle || (vehicle.type !== "bus" && vehicle.type !== "tram")) return;

    let route: LatLng[] = [];
    let stops: LineStop[] = [];
    let hasRealtime = vehicle.mode === "live" && !fleetStale;
    const preview =
      vehicle.preview ?? VEHICLE_DEFS.find((item) => item.id === vehicleId);
    const activeLineAnimation = lineVehicleAnimationRef.current;

    if (
      activeLineAnimation?.id === vehicleId &&
      activeLineMapDataRef.current
    ) {
      route = activeLineMapDataRef.current.trace;
      stops = activeLineMapDataRef.current.stops;
      hasRealtime = false;
    } else if (preview) {
      route = pathCoords(preview, realPathsRef.current);
      const length = pathLen(route);
      const stopPositions = [
        { name: "Départ", distance: 0 },
        {
          name: preview.nextStop || "Prochain arrêt",
          distance: length * 0.24,
        },
        {
          name: preview.dest || "Terminus",
          distance: length,
        },
      ];
      stops = stopPositions.map((stop, index) => {
        const point = pointAt(route, stop.distance);
        return {
          id: `${vehicleId}-tracking-stop-${index}`,
          name: stop.name,
          lat: point.lat,
          lng: point.lng,
        };
      });
      hasRealtime = false;
    } else {
      const matchingLine = dashboardLines.find(
        (line) =>
          line.routeId === vehicle.routeId ||
          line.shortName === vehicle.routeId,
      );
      if (matchingLine) {
        try {
          const response = await fetch(
            `/api/carte-immersive/line?lineId=${encodeURIComponent(matchingLine.id)}`,
            { cache: "no-store" },
          );
          if (response.ok) {
            const data = (await response.json()) as LoadedLineMapData;
            route = data.trace;
            stops = data.stops;
          }
        } catch {
          // Le suivi continue sur la position réelle, même sans géométrie réseau.
        }
      }
    }

    const currentPose = vehiclePoseRef.current.get(vehicleId) ?? {
      lat: vehicle.lat,
      lng: vehicle.lng,
      heading: vehicle.heading,
      speedMps: vehicle.speedMps,
    };
    const initialRouteProjection =
      route.length >= 2
        ? projectPositionOnRoute(
            route,
            [currentPose.lat, currentPose.lng],
            currentPose.heading,
          )
        : null;
    const initialNextStopOnRoute = initialRouteProjection
      ? findNextStopOnRoute(route, stops, initialRouteProjection)
      : null;
    const nextStop =
      initialNextStopOnRoute?.stop ??
      stops
        .map((stop) => ({
          stop,
          distance: distanceMetersBetween(
            [currentPose.lat, currentPose.lng],
            [stop.lat, stop.lng],
          ),
        }))
        .filter((item) => item.distance > 35)
        .sort((a, b) => a.distance - b.distance)[0]?.stop ??
      stops[stops.length - 1];
    const nextStopPosition: LatLng | null = nextStop
      ? [nextStop.lat, nextStop.lng]
      : route.length > 1
        ? [
            pointAt(route, pathLen(route) * 0.2).lat,
            pointAt(route, pathLen(route) * 0.2).lng,
          ]
        : null;

    const activeTracking: VehicleTracking = {
      vehicleId,
      type: vehicle.type,
      title:
        preview?.line ??
        (vehicle.routeId ? `Ligne ${vehicle.routeId}` : "Bus suivi"),
      destination:
        preview?.dest ?? vehicle.destination ?? "Destination non renseignée",
      nextStop: nextStop?.name ?? preview?.nextStop ?? "Non renseigné",
      status:
        preview?.status ??
        (hasRealtime ? "Position en direct" : "Tracé théorique"),
      route,
      stops,
      nextStopPosition,
      hasRealtime,
    };

    trackingRef.current = activeTracking;
    trackingRouteProjectionRef.current = initialRouteProjection;
    trackingCameraUpdatedAtRef.current = 0;
    trackingMetricsUpdatedAtRef.current = 0;
    trackingAlertedRef.current = false;
    const initialDistanceToStopM =
      initialRouteProjection && initialNextStopOnRoute
        ? routeDistanceMeters(
            buildRouteSliceToDistance(
              route,
              initialRouteProjection,
              initialNextStopOnRoute.distance,
            ),
          )
        : nextStopPosition
          ? distanceMetersBetween(
              [currentPose.lat, currentPose.lng],
              nextStopPosition,
            )
          : null;
    setTracking(activeTracking);
    setTrackingStopPlan(
      buildTrackingStopPlan(
        route,
        stops,
        initialRouteProjection,
        nextStop?.name ?? preview?.nextStop ?? "Non renseigné",
      ),
    );
    setTrackingMetrics({
      distanceToStopM: initialDistanceToStopM,
      etaMinutes: null,
      distanceToUserM: userPositionRef.current
        ? distanceMetersBetween(
            [currentPose.lat, currentPose.lng],
            userPositionRef.current,
          )
        : null,
    });
    setTrackingStopsVisible(false);
    trackingStopsVisibleRef.current = false;
    lineStopMarkersRef.current.forEach((marker) => marker.remove());
    lineStopMarkersRef.current = [];
    setSelectedKind(null);
    setSelectedId(null);
    setFocusMode(null);
    setRouteActive(false);
    setShowRouteInputs(false);
    setView3D(true);
    vehicleLayerRef.current?.setView3D(true);
    ensureVisible([vehicle.type]);
    if (initialRouteProjection) {
      showTrackingRoute(
        buildRemainingRoute(
          route,
          initialRouteProjection,
          TRACKING_ROUTE_FRONT_OFFSET_METERS,
        ),
      );
      if (mapRef.current) {
        updateTrackingRouteMask(mapRef.current, [
          currentPose.lat,
          currentPose.lng,
        ]);
      }
    } else if (route.length >= 2) {
      showTrackingRoute(route);
    }
    recenterTrackedVehicle();
  };

  const stopVehicleTracking = () => {
    trackingRef.current = null;
    trackingRouteProjectionRef.current = null;
    trackingNotificationRef.current = false;
    trackingAlertedRef.current = false;
    setTracking(null);
    setTrackingStopPlan([]);
    setTrackingNotification(false);
    setTrackingAlert(null);
    setTrackingStopsVisible(false);
    trackingStopsVisibleRef.current = false;
    clearTimeout(trackingAlertTimeoutRef.current);
    lineStopMarkersRef.current.forEach((marker) => marker.remove());
    lineStopMarkersRef.current = [];

    const map = mapRef.current;
    if (map?.getLayer("immersive-map-transit-traces-line")) {
      map.setPaintProperty(
        "immersive-map-transit-traces-line",
        "line-opacity",
        0.55,
      );
    }
    if (map?.getLayer("immersive-map-route-line")) {
      map.setLayoutProperty("immersive-map-route-line", "line-cap", "round");
    }
    if (map) updateTrackingRouteMask(map, null);
    if (searchLineSelection?.coords.length) {
      focusSearchCoordinates(searchLineSelection.coords, 15.8);
    } else {
      const source = map?.getSource("immersive-map-route") as
        | maplibregl.GeoJSONSource
        | undefined;
      source?.setData({ type: "FeatureCollection", features: [] });
      map?.easeTo({
        pitch: view3D ? 48 : 0,
        bearing: view3D ? -18 : 0,
        zoom: Math.min(map.getZoom(), 15.8),
        duration: 900,
      });
    }
  };

  const toggleTrackingStops = () => {
    if (!tracking) return;
    const nextVisible = !trackingStopsVisible;
    setTrackingStopsVisible(nextVisible);
    trackingStopsVisibleRef.current = nextVisible;
    if (nextVisible) {
      showLineStops(
        getRemainingStopsOnRoute(
          tracking.route,
          tracking.stops,
          trackingRouteProjectionRef.current,
        ),
      );
    } else {
      lineStopMarkersRef.current.forEach((marker) => marker.remove());
      lineStopMarkersRef.current = [];
    }
  };

  const toggleTrackingNotification = () => {
    const enabled = !trackingNotification;
    trackingNotificationRef.current = enabled;
    trackingAlertedRef.current = false;
    setTrackingNotification(enabled);
    if (enabled && !userPositionRef.current) {
      setTrackingAlert(
        "Alerte activée — autorisez votre position pour détecter l’approche.",
      );
      clearTimeout(trackingAlertTimeoutRef.current);
      trackingAlertTimeoutRef.current = setTimeout(
        () => setTrackingAlert(null),
        5200,
      );
    }
  };

  const confirmBoarding = () => {
    if (
      trackingMetrics.distanceToUserM == null ||
      trackingMetrics.distanceToUserM > 80
    ) {
      return;
    }
    setTrackingAlert(
      `${tracking?.title ?? "Le bus"} est à proximité — montée confirmée.`,
    );
    clearTimeout(trackingAlertTimeoutRef.current);
    trackingAlertTimeoutRef.current = setTimeout(
      () => setTrackingAlert(null),
      5200,
    );
  };

  const detail: SelectedDetail | null = useMemo(() => {
    if (!selectedKind || !selectedId) return null;
    if (selectedKind === "vehicle") {
      const mapVehicle = displayVehicles.find((vehicle) => vehicle.id === selectedId);
      if (mapVehicle?.mode === "live") {
        const ageSeconds = mapVehicle.recordedAt
          ? Math.max(
              0,
              Math.round((Date.now() - new Date(mapVehicle.recordedAt).getTime()) / 1000),
            )
          : null;
        return {
          emoji: mapVehicle.type === "tram" ? "🚋" : "🚌",
          title: mapVehicle.routeId ? `Ligne ${mapVehicle.routeId}` : "Véhicule en circulation",
          subtitle: `${mapVehicle.type === "tram" ? "Tramway" : "Bus"} · Position en direct${
            fleetStale ? " (signal ancien)" : ""
          }`,
          facts: [
            { k: "Destination", v: mapVehicle.destination || "Non renseignée" },
            {
              k: "Vitesse",
              v:
                mapVehicle.speedMps == null
                  ? "Non disponible"
                  : `${Math.round(mapVehicle.speedMps * 3.6)} km/h`,
            },
            {
              k: "Actualisation",
              v: ageSeconds == null ? "À l’instant" : `Il y a ${ageSeconds} s`,
            },
            { k: "Source", v: "Flotte Aule anonymisée" },
          ],
          actionLabel: mapVehicle.type === "tram" ? "Suivre ce tram" : "Suivre ce bus",
          action: () => void startVehicleTracking(mapVehicle.id),
        };
      }

      const v = mapVehicle?.preview ?? VEHICLE_DEFS.find((x) => x.id === selectedId);
      if (!v) return null;
      if (v.type === "bus" || v.type === "tram") {
        const facts = [
          { k: "Destination", v: v.dest ?? "" },
          { k: "Prochain arrêt", v: v.nextStop ?? "" },
          { k: "Arrivée", v: v.eta },
          { k: "Statut", v: v.status ?? "" },
        ];
        if (v.occ) facts.push({ k: "Occupation", v: v.occ });
        return {
          emoji: v.type === "bus" ? "🚌" : "🚋",
          title: v.line ?? "",
          subtitle: `Aperçu · ${v.type === "bus" ? "Bus en circulation" : "Tramway en circulation"}`,
          facts,
          actionLabel: v.type === "bus" ? "Suivre ce bus" : "Suivre ce tram",
          action: () => void startVehicleTracking(mapVehicle?.id ?? v.id),
        };
      }
      if (v.type === "vtc") {
        return {
          emoji: "🚖",
          title: v.driver ?? "",
          subtitle: "Aperçu · VTC disponible",
          facts: [
            { k: "Arrivée estimée", v: v.eta },
            { k: "Distance", v: v.dist ?? "" },
            { k: "Note", v: "★ " + v.rating },
            { k: "Tarif estimé", v: v.price ?? "" },
          ],
          actionLabel: "Réserver ce VTC",
          action: () => {},
        };
      }
      if (v.type === "taxi") {
        return {
          emoji: "🚕",
          title: "Taxi disponible",
          subtitle: `Aperçu · ${v.station ?? ""}`,
          facts: [
            { k: "Arrivée", v: v.eta },
            { k: "Station la plus proche", v: v.station ?? "" },
            { k: "Distance", v: v.dist ?? "" },
            { k: "Paiement", v: "CB / espèces" },
          ],
          actionLabel: "Commander ce taxi",
          action: () => {},
        };
      }
    }
    if (selectedKind === "shop") {
      const s = SHOP_DEFS.find((x) => x.id === selectedId);
      if (!s) return null;
      return {
        emoji: s.emoji,
        title: s.name,
        subtitle: s.cat,
        facts: [
          { k: "Distance", v: s.dist },
          { k: "À pied", v: s.walk },
          { k: "Horaires", v: s.hours },
          { k: "Note", v: "★ " + s.rating },
        ],
        actionLabel: "Commander ici",
        action: () => openMerchant(s.id),
      };
    }
    return null;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedKind, selectedId, displayVehicles, fleetStale]);

  const searchLineDetail: SelectedDetail | null = useMemo(() => {
    if (!searchLineSelection) return null;
    const modeLabel =
      searchLineSelection.mode === "navibus"
        ? "Navibus"
        : searchLineSelection.mode === "tram"
          ? "Tramway"
          : "Bus";
    return {
      emoji:
        searchLineSelection.mode === "navibus"
          ? "⛴️"
          : searchLineSelection.mode === "tram"
            ? "🚋"
            : "🚌",
      title: searchLineSelection.title,
      subtitle: searchLineSelection.subtitle,
      facts: [
        { k: "Mode", v: modeLabel },
        { k: "Réseau", v: "Aule · Nantes" },
        { k: "Service", v: "En circulation" },
        ...(searchLineSelection.stopCount != null
          ? [{ k: "Arrêts", v: String(searchLineSelection.stopCount) }]
          : []),
        ...(searchLineSelection.coords.length > 0 &&
        searchLineSelection.mode !== "navibus"
          ? [{ k: "Véhicule", v: "En mouvement" }]
          : []),
        {
          k: "Information",
          v:
            searchLineSelection.coords.length > 0
              ? "Tracé affiché"
              : "Ligne disponible dans le dashboard",
        },
      ],
      actionLabel:
        searchLineSelection.coords.length > 0 ? "Recentrer sur la ligne" : "Ligne publiée",
      action:
        searchLineSelection.coords.length > 0
          ? () => focusSearchCoordinates(searchLineSelection.coords, 15.8)
          : () => {},
    };
  }, [focusSearchCoordinates, searchLineSelection]);

  const visibleDetail = tracking ? null : detail ?? searchLineDetail;
  const focusVisible = !!focusMode && !visibleDetail;

  const rideItems: RideItem[] = useMemo(
    () =>
      VEHICLE_DEFS.filter((v) => v.type === "vtc" || v.type === "taxi").map((v) => ({
        id: v.id,
        emoji: v.type === "vtc" ? "🚖" : "🚕",
        title: v.type === "vtc" ? (v.driver ?? "") : "Taxi disponible",
        meta: `Arrivée ${v.eta} · ${v.dist}`,
        btn: v.type === "vtc" ? "Réserver" : "Commander",
        onClick: () => select("vehicle", v.id),
      })),
    [select],
  );

  const shopResults: ShopResultItem[] = useMemo(
    () =>
      computeShopResults().map((s) => ({
        id: s.id,
        emoji: s.emoji,
        title: s.name,
        cat: s.cat,
        dist: s.dist,
        walk: s.walk,
        delivery: s.delivery,
        rating: s.rating,
        price: s.price,
        openLabel: s.open ? "Ouvert" : "Fermé",
        openColor: s.open ? "#33BFA3" : "#FF6B5E",
        onClick: () => select("shop", s.id),
        onEnter: () => hoverShop(s.id),
        onLeave: () => unhoverShop(s.id),
      })),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [shopQuery, activeCats, sortMode, select, hoverShop, unhoverShop],
  );

  const merchantShop = merchantId ? SHOP_DEFS.find((s) => s.id === merchantId) : null;

  const merchantData = useMemo(() => {
    if (!merchantShop) return null;
    const fullMenu = buildMenu(merchantShop);
    const menuChips: MenuChip[] = [{ key: "all", label: "Tout" }]
      .concat(fullMenu.map((s) => ({ key: s.name, label: s.name })))
      .map((c) => ({ key: c.key, label: c.label, active: menuCat === c.key }));
    const menuSections = fullMenu.filter((s) => menuCat === "all" || s.name === menuCat);

    const flat: Record<string, { name: string; price: number }> = {};
    fullMenu.forEach((s) => s.items.forEach((it) => (flat[it.id] = { name: it.name, price: it.price })));
    let cartCount = 0;
    let cartTotal = 0;
    const cartLines: CartLine[] = [];
    for (const id in cart) {
      const it = flat[id];
      if (!it) continue;
      const q = cart[id];
      cartCount += q;
      cartTotal += q * it.price;
      cartLines.push({ id, name: it.name, qty: q, lineTotal: fmt(q * it.price) });
    }

    return {
      merchant: {
        emoji: merchantShop.emoji,
        name: merchantShop.name,
        cat: merchantShop.cat,
        open: merchantShop.open,
        openLabel: merchantShop.open ? "Ouvert" : "Fermé",
        facts: [
          { icon: "★", v: merchantShop.rating },
          { icon: "📍", v: merchantShop.dist },
          { icon: "🚶", v: merchantShop.walk + " à pied" },
          { icon: "🚴", v: merchantShop.delivery !== "—" ? merchantShop.delivery : "Retrait" },
          { icon: "🕒", v: merchantShop.hours },
        ],
      },
      menuChips,
      menuSections,
      cartLines,
      cartCount,
      cartTotalLabel: fmt(cartTotal),
    };
  }, [merchantShop, menuCat, cart]);

  const arrivalStr = routeInfo
    ? (() => {
        const arrival = new Date(Date.now() + routeInfo.durationMin * 60000);
        return `${arrival.getHours().toString().padStart(2, "0")}:${arrival.getMinutes().toString().padStart(2, "0")}`;
      })()
    : "";
  const routeSteps: RouteStep[] = routeInfo?.steps ?? [];
  const trackingModeLabel = tracking
    ? tracking.type === "tram"
      ? "Tram"
      : tracking.type === "navibus"
        ? "Navibus"
        : "Bus"
    : "Bus";
  const trackingComments = tracking
    ? travelerCommentsForVehicle(
        tracking.title.replace(/^Ligne\s+/i, ""),
        tracking.vehicleId,
        tracking.nextStop,
        tracking.status.toLowerCase().includes("retard") ? 4 : 0,
      )
    : [];
  const trackingPanelData: TrackingPanelData | null = tracking
    ? {
        emoji:
          tracking.type === "tram"
            ? "🚋"
            : tracking.type === "navibus"
              ? "⛴️"
              : "🚌",
        title: tracking.title,
        mode: tracking.type,
        destination: tracking.destination,
        nextStop: tracking.nextStop,
        eta:
          trackingMetrics.etaMinutes == null
            ? "Indisponible"
            : trackingMetrics.etaMinutes < 1
              ? "Moins d’1 min"
              : `${Math.ceil(trackingMetrics.etaMinutes)} min`,
        distance:
          trackingMetrics.distanceToStopM == null
            ? "Indisponible"
            : trackingMetrics.distanceToStopM < 1_000
              ? `${Math.max(0, Math.round(trackingMetrics.distanceToStopM))} m`
              : `${(trackingMetrics.distanceToStopM / 1_000).toFixed(1)} km`,
        status: tracking.status,
        dataStatus: tracking.hasRealtime
          ? "Position temps réel"
          : "Tracé théorique · suivi disponible",
        proximityLabel:
          trackingMetrics.distanceToUserM == null
            ? "Position requise"
            : trackingMetrics.distanceToUserM <= 80
              ? `${trackingModeLabel} à proximité`
              : trackingMetrics.distanceToUserM < 1_000
                ? `${trackingModeLabel} à ${Math.round(trackingMetrics.distanceToUserM)} m`
                : `${trackingModeLabel} à ${(trackingMetrics.distanceToUserM / 1_000).toFixed(1)} km`,
        notificationEnabled: trackingNotification,
        stopsVisible: trackingStopsVisible,
        canBoard:
          trackingMetrics.distanceToUserM != null &&
          trackingMetrics.distanceToUserM <= 80,
        approachAlert: trackingAlert,
        linePlan: trackingStopPlan,
        comments: trackingComments,
      }
    : null;

  return (
    <div className="immersive-map-root">
      <div className="immersive-map-canvas">
        <div ref={mapContainerRef} className="h-full w-full" />
        {mapError && (
          <div className="flex h-full w-full items-center justify-center px-8 text-center text-sm text-white/70">
            {mapError}
          </div>
        )}
      </div>
      <div className="immersive-map-vignette" />
      <div className="immersive-map-vignette-top" />
      {!tracking && (
        <div
          className={`immersive-map-live-status immersive-map-live-status--${fleetMode}${
            fleetStale ? " immersive-map-live-status--stale" : ""
          }`}
          aria-live="polite"
        >
          <span className="immersive-map-live-status-dot" />
          {fleetMode === "live"
            ? fleetStale
              ? "Temps réel · signal en attente"
              : `${liveVehicles.length} véhicule${liveVehicles.length > 1 ? "s" : ""} en direct`
            : "Mode aperçu"}
        </div>
      )}

      <TopBar
        viewer={viewer}
        globalSearchQuery={globalSearchQuery}
        globalSearchSuggestions={globalSearchSuggestions}
        onGlobalSearchChange={setGlobalSearchQuery}
        onGlobalSearchSelect={handleGlobalSearchSelect}
        showInputs={showRouteInputs}
        searchQuery={searchQuery}
        onSearchChange={(v) => {
          setSearchQuery(v);
          setSelectedDestination(null);
          setAddressSuggestions([]);
          setShowAddressSuggestions(v.trim().length >= 3);
          if (searchError) setSearchError(null);
        }}
        onSearchKeyDown={(e) => {
          if (e.key === "Enter") {
            e.preventDefault();
            void onSearchSubmit();
          } else if (e.key === "Escape") {
            setShowRouteInputs(false);
            setSearchError(null);
          }
        }}
        onSearchFocus={() => {
          if (searchQuery.trim().length >= 3) setShowAddressSuggestions(true);
        }}
        onSearchBlur={() => {
          setTimeout(() => setShowAddressSuggestions(false), 120);
        }}
        onSearchSubmit={() => void onSearchSubmit()}
        onCloseInputs={() => {
          closeRoute();
          clearFocus();
        }}
        originAddress={originAddress}
        originAddressLoading={originAddressLoading}
        destinationLoading={destinationLoading}
        searchError={searchError}
        showAddressSuggestions={
          showAddressSuggestions &&
          (addressSuggestionsLoading || addressSuggestions.length > 0)
        }
        addressSuggestionsLoading={addressSuggestionsLoading}
        addressSuggestions={addressSuggestions.map((suggestion, index) => ({
          id: `${suggestion.latLng[0]}-${suggestion.latLng[1]}-${index}`,
          label: suggestion.label,
          onPick: () => pickAddressSuggestion(suggestion),
        }))}
      />

      <QuickActionsPanel
        visible={geoGranted && !showRouteInputs && !tracking}
        collapsed={quickCollapsed}
        onToggleCollapse={() => setQuickCollapsed((c) => !c)}
        onRoute={qaRoute}
        onRide={qaRide}
        onShop={qaShop}
      />

      <GeoPrompt
        promptVisible={geoPromptVisible}
        deniedNoticeVisible={geoDeniedNoticeVisible}
        city="Nantes"
        onAllow={onGeoAllow}
        onDeny={onGeoDeny}
      />

      {!tracking && (
        <FiltersPanel filters={filters} onToggle={toggleFilter} />
      )}

      {routeActive && (
        <RoutePanel
          destName={destName}
          duration={routeInfo?.durationMin ?? 0}
          arrival={arrivalStr}
          steps={routeSteps}
          loading={routeLoading}
          error={routeError}
          mode={routeMode}
          onModeChange={changeRouteMode}
          onClose={closeRoute}
        />
      )}

      {focusVisible && (
        <FocusPanel
          mode={focusMode as "ride" | "shop"}
          title={focusMode === "ride" ? "VTC & taxis à proximité" : "Commerçants à proximité"}
          onClose={clearFocus}
          rideItems={rideItems}
          shopQuery={shopQuery}
          onShopQueryChange={setShopQuery}
          categories={CATEGORIES}
          activeCats={activeCats}
          onToggleCat={(key) => setActiveCats((c) => ({ ...c, [key]: !c[key] }))}
          sortMode={sortMode}
          onSortChange={setSortMode}
          showSearchArea={showSearchArea && focusMode === "shop"}
          onSearchThisArea={searchThisArea}
          shopResults={shopResults}
        />
      )}

      {visibleDetail && (
        <DetailPanel selected={visibleDetail} onClose={closeSelection} />
      )}

      {trackingPanelData && (
        <TrackingPanel
          data={trackingPanelData}
          onStop={stopVehicleTracking}
          onRecenter={recenterTrackedVehicle}
          onToggleStops={toggleTrackingStops}
          onToggleNotification={toggleTrackingNotification}
          onBoard={confirmBoarding}
        />
      )}

      {merchantShop && merchantData && (
        <MerchantSheet
          merchant={merchantData.merchant}
          menuChips={merchantData.menuChips}
          onPickMenuChip={setMenuCat}
          menuSections={merchantData.menuSections}
          cart={cart}
          onAddItem={addItem}
          onDecItem={decItem}
          fmt={fmt}
          cartLines={merchantData.cartLines}
          cartCount={merchantData.cartCount}
          cartTotalLabel={merchantData.cartTotalLabel}
          cartExpanded={cartOpen && merchantData.cartCount > 0}
          onToggleCart={toggleCart}
          onClose={closeMerchant}
          onOrder={placeOrder}
          orderConfirmVisible={orderPlaced}
        />
      )}
    </div>
  );
}
