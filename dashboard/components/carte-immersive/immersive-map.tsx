"use client";

import "maplibre-gl/dist/maplibre-gl.css";
import maplibregl from "maplibre-gl";
import { attachMapLibreErrorHandler } from "@/lib/maplibre-errors";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { CITY_CENTER } from "@/lib/carte-immersive/data";
import {
  distanceMeters,
  pathLen,
  pointAt,
  type LatLng,
} from "@/lib/carte-immersive/geo";
import { transitRouteRefreshDelay } from "@/lib/carte-immersive/transit-quality";
import {
  vehicleScheduleMotionAt,
  type VehicleScheduleControlPoint,
} from "@/lib/carte-immersive/vehicle-schedule-motion";
import {
  selectLiveVehicleForSchedule,
  type MapVehicle,
} from "@/lib/carte-immersive/vehicles";
import { useImmersiveFleet } from "@/hooks/use-immersive-fleet";
import {
  addExtrudedBuildings,
  applyAtmosphereReskin,
  applyAtmosphereSky,
  ensureRouteLayer,
  ensureTransitTracesLayer,
  hideGenericPois,
  registerMissingImageFallback,
  setTransitTracesFilter,
} from "./map-style";
import { useHeroWeather } from "@/components/landing/use-hero-weather";
import { MapWeatherScene } from "./map-weather-scene";
import type {
  DashboardLineSearchItem,
  RealLineTrace,
} from "@/lib/carte-immersive/real-lines";
import { loadCustomRegulationLines } from "@/lib/regulation-custom-line";
import { loadLineEditorDraft } from "@/lib/line-editor-persistence";
import { getVoicePoints, isStopType } from "@/lib/line-editor-utils";
import { travelerCommentsForVehicle } from "@/lib/traveler-comments";
import {
  fetchRegisteredStopsFromDatabase,
  type RegisteredStop,
} from "@/lib/registered-stops";
import { createDestElement, createUserElement } from "./map-markers";
import { createOrbitControl, createViewControl } from "./map-controls";
import {
  TopBar,
  type GlobalSearchSuggestion,
  type ImmersiveViewer,
} from "./top-bar";
import { QuickActionsPanel } from "./quick-actions-panel";
import { FiltersPanel, type FilterKey } from "./filters-panel";
import { BottomNav } from "./bottom-nav";
import { CorrespondancesPanel } from "./correspondances-panel";
import { GeoPrompt } from "./geo-prompt";
import {
  RoutePanel,
  type RouteAlternativeOption,
  type RouteDepartureOption,
  type RouteMode,
  type RoutePreferences,
  type RouteStep,
  type RouteVehicleTracking,
} from "./route-panel";
import { DetailPanel, type SelectedDetail } from "./detail-panel";
import {
  StopSchedulePanel,
  type ScheduledPassageSelection,
  type SelectedMapStop,
} from "./stop-schedule-panel";
import { Vehicle3DLayer } from "./vehicle-3d-layer";
import { AmbientSimulationLayer } from "./ambient-simulation-layer";
import {
  TrackingPanel,
  type TrackingPanelData,
  type TrackingStopPlanItem,
} from "./tracking-panel";

type SelectedKind = "vehicle" | null;
type GeocodeResult = { name: string; label: string; latLng: LatLng };
type InitialRoutePoint = {
  label: string;
  latLng?: LatLng;
};
type SearchLineSelection = {
  title: string;
  mode: "bus" | "tram" | "navibus";
  subtitle: string;
  coords: LatLng[];
  stopCount?: number;
  vehicleCount?: number;
};

type LoadedLineSchedule = {
    generatedAt: string;
    departureId: string;
    profileId?: string;
    directionId?: number | null;
    destination: string | null;
    source: "gtfs";
    stops: Array<{
      stopId: string;
      fraction: number;
      passageInSeconds: number;
    }>;
};

type LoadedLineMapData = {
  trace: LatLng[];
  stops: LineStop[];
  schedule?: LoadedLineSchedule | null;
  schedules?: LoadedLineSchedule[];
};

type LineStop = { id: string; name: string; lat: number; lng: number };

type LineVehicleAnimation = {
  id: string;
  coords: LatLng[];
  length: number;
  startedAt: number;
  travelDuration: number;
  speedMps: number;
  routeDistanceM: number;
  scheduleStops: Array<VehicleScheduleControlPoint & { stopId: string }>;
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
  scheduledPassages: ReadonlyMap<string, number>;
};

type TrackingMetrics = {
  distanceToStopM: number | null;
  etaMinutes: number | null;
  distanceToUserM: number | null;
  distanceTraveledM: number | null;
  routeDistanceM: number | null;
};

type RouteProjection = {
  point: LatLng;
  distance: number;
  segmentIndex: number;
  direction: 1 | -1;
  totalDistance: number;
};

type RouteCandidateState = {
  id: string;
  coordinates: [number, number][];
  segments?: RouteSegmentState[];
  distanceM: number;
  durationMin: number;
  departureAt?: string;
  arrivalAt?: string;
  steps: RouteStep[];
  summary: string;
  accessible: boolean;
  alertCount: number;
};

type RouteSegmentState = {
  coordinates: [number, number][];
  color: string;
  routeId?: string;
  type: "walk" | "transit";
};

type RouteInfoState = {
  distanceM: number;
  durationMin: number;
  departureAt?: string;
  arrivalAt?: string;
  steps: RouteStep[];
  alternatives: RouteCandidateState[];
  departures: RouteCandidateState[];
  selectedAlternativeId: string;
  engine: "timetable" | "heuristic";
};

type RouteSkeletonState = {
  id: string;
  routeIds: string[];
  summary: string;
};

type RouteApiData = {
  coordinates?: [number, number][];
  segments?: RouteSegmentState[];
  distance?: number;
  duration?: number;
  departureAt?: string;
  arrivalAt?: string;
  steps?: RouteStep[];
  alternatives?: Array<{
    id: string;
    coordinates: [number, number][];
    segments?: RouteSegmentState[];
    distance: number;
    duration: number;
    departureAt?: string;
    arrivalAt?: string;
    steps: RouteStep[];
    summary: string;
    accessible: boolean;
    alerts?: unknown[];
  }>;
  departures?: Array<{
    id: string;
    coordinates: [number, number][];
    segments?: RouteSegmentState[];
    distance: number;
    duration: number;
    departureAt?: string;
    arrivalAt?: string;
    steps: RouteStep[];
    summary: string;
    accessible: boolean;
    alerts?: unknown[];
  }>;
  engine?: "timetable" | "heuristic";
  error?: string;
};

type RouteSkeletonApiData = {
  suggestions?: Array<{
    id: string;
    route_ids: string[];
    summary: string;
  }>;
  engine?: "skeleton";
  error?: string;
};

class RouteResponseFormatError extends Error {
  constructor(status: number) {
    super(
      status >= 400
        ? `Le service d’itinéraire a renvoyé une réponse invalide (HTTP ${status}).`
        : "Le service d’itinéraire a renvoyé une réponse illisible.",
    );
    this.name = "RouteResponseFormatError";
  }
}

async function readRouteResponse<T>(response: Response): Promise<T> {
  const body = await response.text();
  if (!body.trim()) throw new RouteResponseFormatError(response.status);

  try {
    return JSON.parse(body) as T;
  } catch {
    throw new RouteResponseFormatError(response.status);
  }
}

const ROUTE_ALGORITHM_VERSION = "26";

type RouteApiCandidate = NonNullable<RouteApiData["alternatives"]>[number];

function toRouteCandidate(alternative: RouteApiCandidate): RouteCandidateState {
  return {
    id: alternative.id,
    coordinates: alternative.coordinates,
    segments: alternative.segments,
    distanceM: Math.round(alternative.distance),
    durationMin: Math.max(1, Math.round(alternative.duration / 60)),
    departureAt: alternative.departureAt,
    arrivalAt: alternative.arrivalAt,
    steps: alternative.steps,
    summary: alternative.summary,
    accessible: alternative.accessible,
    alertCount: alternative.alerts?.length ?? 0,
  };
}

// Fenêtres interrogées en arrière-plan une fois le premier itinéraire affiché :
// elles alimentent « Prochains départs » sans allonger le calcul initial.
const DEFERRED_DEPARTURE_WINDOWS_MIN = [20, 40];
const MAX_DEPARTURE_OPTIONS = 3;

function mergeDepartureOptions(
  current: RouteCandidateState[],
  incoming: RouteCandidateState[],
): RouteCandidateState[] {
  const best = current[0];
  if (!best?.departureAt) return current;
  const bestAt = new Date(best.departureAt).getTime();
  const later = [...current.slice(1), ...incoming]
    .filter((candidate) => {
      const at = candidate.departureAt
        ? new Date(candidate.departureAt).getTime()
        : Number.NaN;
      return Number.isFinite(at) && at > bestAt + 30_000;
    })
    .sort(
      (a, b) =>
        new Date(a.departureAt ?? 0).getTime() -
        new Date(b.departureAt ?? 0).getTime(),
    );
  return [best, ...later]
    .filter(
      (candidate, index, values) =>
        values.findIndex(
          (value) =>
            Math.abs(
              new Date(value.departureAt ?? 0).getTime() -
                new Date(candidate.departureAt ?? 0).getTime(),
            ) < 60_000,
        ) === index,
    )
    .slice(0, MAX_DEPARTURE_OPTIONS);
}

const GEOLOCATION_CONSENT_KEY = "aule:geolocation-consent";
type GeolocationIssue =
  | "denied"
  | "insecure"
  | "timeout"
  | "unavailable"
  | "unsupported";

function geolocationIssueMessage(issue: GeolocationIssue): string {
  switch (issue) {
    case "denied":
      return "Position bloquée par le navigateur — autorisez-la depuis l’icône de localisation de la barre d’adresse.";
    case "insecure":
      return "La géolocalisation nécessite une connexion HTTPS (localhost reste autorisé en développement).";
    case "timeout":
      return "La localisation prend trop de temps — vérifiez la localisation de l’appareil puis réessayez avec le bouton cible.";
    case "unavailable":
      return "Position introuvable — vérifiez que la localisation de l’appareil est activée puis réessayez.";
    case "unsupported":
      return "La géolocalisation n’est pas disponible dans ce navigateur.";
  }
}

const NEARBY_SEARCH_STOP_LIMIT = 10;
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

function labelName(label: string) {
  return label.split(",")[0]?.trim() || label;
}

function formatNearbyDistance(distance: number): string {
  if (distance < 1_000) return `${Math.max(10, Math.round(distance / 10) * 10)} m`;
  return `${(distance / 1_000).toFixed(1).replace(".", ",")} km`;
}

function normalizePublicLineName(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .toLowerCase();
}

const routeClockFormatter = new Intl.DateTimeFormat("fr-FR", {
  timeZone: "Europe/Paris",
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});
const routeDayClockFormatter = new Intl.DateTimeFormat("fr-FR", {
  timeZone: "Europe/Paris",
  weekday: "short",
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});
const routeDayKeyFormatter = new Intl.DateTimeFormat("fr-CA", {
  timeZone: "Europe/Paris",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

function routeDate(value: string | undefined, fallback: Date): Date {
  if (!value) return fallback;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? fallback : parsed;
}

function formatRouteDate(value: Date, reference = new Date()): string {
  return routeDayKeyFormatter.format(value) === routeDayKeyFormatter.format(reference)
    ? routeClockFormatter.format(value)
    : routeDayClockFormatter.format(value).replace(",", "");
}

function parseInitialRouteMode(value: string | null): RouteMode {
  return value === "car" ? "car" : "transit";
}

function parseInitialRoutePoint(
  params: URLSearchParams,
  labelKey: string,
  latKey: string,
  lngKey: string,
): InitialRoutePoint | null {
  const label = params.get(labelKey)?.trim() ?? "";
  const rawLat = params.get(latKey);
  const rawLng = params.get(lngKey);
  const lat = rawLat == null ? Number.NaN : Number(rawLat);
  const lng = rawLng == null ? Number.NaN : Number(rawLng);

  if (Number.isFinite(lat) && Number.isFinite(lng)) {
    return {
      label: label || "Adresse sélectionnée",
      latLng: [lat, lng],
    };
  }

  return label.length >= 3 ? { label } : null;
}

function createLineStopElement(
  name: string,
  index: number,
  total: number,
  color: string,
  onClick?: () => void,
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
  if (onClick) element.addEventListener("click", onClick);
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
  scheduledPassages: ReadonlyMap<string, number>,
): TrackingStopPlanItem[] {
  if (stops.length === 0) return [];

  if (!projection || route.length < 2) {
    const nextIndex = Math.max(
      0,
      stops.findIndex((stop) => stop.name === nextStopName),
    );
    return stops.map((stop, index) => ({
      id: stop.id,
      occurrenceKey: `${index}:${stop.id}`,
      name: stop.name,
      passageAt: scheduledPassages.get(stop.id) ?? null,
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
  // Le marqueur du véhicule doit se poser sur l'arrêt courant : le premier
  // arrêt non encore dépassé (seuil symétrique de `isPassed` ci-dessous). Ainsi,
  // un véhicule à quai (ex. au terminus, 0 km) reste marqué SUR cet arrêt et non
  // sur le suivant.
  const nextByProgress = stopProgress.find((item) =>
    projection.direction === 1
      ? item.distance >= projection.distance - tolerance
      : item.distance <= projection.distance + tolerance,
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
      occurrenceKey: `${item.order}:${item.stop.id}`,
      name: item.stop.name,
      passageAt: scheduledPassages.get(item.stop.id) ?? null,
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

function plannedRouteGeoJson(
  coordinates: [number, number][],
  segments: RouteSegmentState[] | undefined,
) {
  const visibleSegments = (segments ?? []).filter(
    (segment) => segment.coordinates.length >= 2,
  );
  return {
    type: "FeatureCollection" as const,
    features: (visibleSegments.length
      ? visibleSegments
      : [{ coordinates, color: "#33bfa3", type: "transit" as const }]
    ).map((segment) => ({
      type: "Feature" as const,
      properties: {
        color: segment.color,
        routeId: "routeId" in segment ? (segment.routeId ?? null) : null,
        segmentType: segment.type,
      },
      geometry: {
        type: "LineString" as const,
        coordinates: segment.coordinates,
      },
    })),
  };
}

function showPlannedRoute(
  map: maplibregl.Map,
  coordinates: [number, number][],
  segments: RouteSegmentState[] | undefined,
) {
  const source = map.getSource("immersive-map-route") as maplibregl.GeoJSONSource | undefined;
  source?.setData(plannedRouteGeoJson(coordinates, segments));
  if (!map.getLayer("immersive-map-route-line")) return;
  try {
    map.setLayoutProperty("immersive-map-route-line", "line-cap", "round");
    map.setPaintProperty("immersive-map-route-line", "line-color", [
      "coalesce",
      ["get", "color"],
      "#33bfa3",
    ]);
    map.setPaintProperty("immersive-map-route-line", "line-width", 5);
  } catch (error) {
    // Le style initial de la couche contient déjà ces valeurs. Certains
    // WebKit/Safari lèvent néanmoins une DOMException pendant leur réapplication.
    console.warn("Impossible de réinitialiser le style du trajet", error);
  }
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
  const ambientLayerRef = useRef<AmbientSimulationLayer | null>(null);
  const userMarkerRef = useRef<maplibregl.Marker | null>(null);
  const destMarkerRef = useRef<maplibregl.Marker | null>(null);
  const selectedStopMarkerRef = useRef<maplibregl.Marker | null>(null);
  const lineStopMarkersRef = useRef<maplibregl.Marker[]>([]);
  const showLineStopsRef = useRef<(stops: LineStop[], color?: string) => void>(
    () => {},
  );
  const lineVehicleAnimationsRef = useRef<Map<string, LineVehicleAnimation>>(
    new Map(),
  );
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
  const trackingAlertTimeoutRef = useRef<ReturnType<typeof setTimeout> | undefined>(
    undefined,
  );
  const userPositionRef = useRef<LatLng | null>(null);
  const geoWatchIdRef = useRef<number | null>(null);
  const locateActionRef = useRef<() => void>(() => {});
  const viewActionRef = useRef<() => void>(() => {});
  const rotateActionRef = useRef<(degrees: number) => void>(() => {});
  const viewControlButtonRef = useRef<HTMLButtonElement | null>(null);
  const realPathsRef = useRef(realPaths);
  const { vehicles: liveVehicles, mode: fleetMode, stale: fleetStale } = useImmersiveFleet();
  const [weatherLocation, setWeatherLocation] = useState({
    lat: CITY_CENTER[0],
    lng: CITY_CENTER[1],
  });
  const mapWeather = useHeroWeather(weatherLocation);
  const mapWeatherRef = useRef(mapWeather);
  mapWeatherRef.current = mapWeather;

  const [filters, setFilters] = useState<Record<FilterKey, boolean>>({
    bus: true,
    tram: true,
  });
  const [ambientEnabled, setAmbientEnabled] = useState(true);
  const [selectedKind, setSelectedKind] = useState<SelectedKind>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [globalSearchQuery, setGlobalSearchQuery] = useState("");
  const [geoPosition, setGeoPosition] = useState<LatLng | null>(null);
  const [stopCatalog, setStopCatalog] = useState<RegisteredStop[]>([]);
  const [stopLinesById, setStopLinesById] = useState<Record<string, string[]>>({});
  const requestedStopLinesRef = useRef(new Set<string>());
  const [selectedStop, setSelectedStop] = useState<SelectedMapStop | null>(null);
  // Contexte de retour vers les « Horaires de la journée » après un suivi :
  // mémorise l'arrêt/ligne d'origine pour rouvrir la bonne vue au « Quitter le suivi ».
  const [scheduleReturn, setScheduleReturn] = useState<{
    stopId: string;
    line: string;
    direction: string;
    lineColor: string;
    serviceDate: string;
  } | null>(null);
  const trackingOriginRef = useRef<{
    stop: SelectedMapStop;
    line: string;
    direction: string;
    lineColor: string;
    serviceDate: string;
  } | null>(null);
  const [searchLineSelection, setSearchLineSelection] =
    useState<SearchLineSelection | null>(null);
  const [publishedCustomLines, setPublishedCustomLines] = useState<
    DashboardLineSearchItem[]
  >([]);
  const [lineVehicles, setLineVehicles] = useState<MapVehicle[]>([]);
  const [tracking, setTracking] = useState<VehicleTracking | null>(null);
  const [trackingMetrics, setTrackingMetrics] = useState<TrackingMetrics>({
    distanceToStopM: null,
    etaMinutes: null,
    distanceToUserM: null,
    distanceTraveledM: null,
    routeDistanceM: null,
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
  const [geoNotice, setGeoNotice] = useState<string | null>(null);
  const [destName, setDestName] = useState("");
  const [routeMode, setRouteMode] = useState<RouteMode>("transit");
  const [routePreferences, setRoutePreferences] = useState<RoutePreferences>({
    accessible: false,
    avoidDisruptions: true,
    maxTransfers: 2,
  });
  const [routeLoading, setRouteLoading] = useState(false);
  const [routeError, setRouteError] = useState<string | null>(null);
  const [routeInfo, setRouteInfo] = useState<RouteInfoState | null>(null);
  const [routeSkeletons, setRouteSkeletons] = useState<RouteSkeletonState[]>([]);
  const activeRouteRef = useRef<{ origin: LatLng; dest: LatLng; destName: string } | null>(null);
  const routeRequestRef = useRef<AbortController | null>(null);
  const routePrefetchRef = useRef<AbortController | null>(null);
  const routeDeparturesRef = useRef<AbortController | null>(null);
  const refreshedDepartureRef = useRef<string | null>(null);
  const [originAddress, setOriginAddress] = useState("Votre position actuelle");
  const [originIsCurrent, setOriginIsCurrent] = useState(true);
  const [selectedOrigin, setSelectedOrigin] = useState<GeocodeResult | null>(null);
  const [originSuggestions, setOriginSuggestions] = useState<GeocodeResult[]>([]);
  const [originSuggestionsLoading, setOriginSuggestionsLoading] = useState(false);
  const [showOriginSuggestions, setShowOriginSuggestions] = useState(false);
  const originSearchRequestRef = useRef(0);
  const originIsCurrentRef = useRef(true);
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
  const [showCorrespondances, setShowCorrespondances] = useState(false);
  // Sur mobile la recherche globale est déportée dans la barre du bas : ce
  // drapeau la fait apparaître en surcouche du header.
  const [mobileSearchOpen, setMobileSearchOpen] = useState(false);
  const [view3D, setView3D] = useState(true);
  const [mapError, setMapError] = useState<string | null>(null);
  const [mapReady, setMapReady] = useState(false);

  useEffect(() => {
    if (selectedStop) return;
    selectedStopMarkerRef.current?.remove();
    selectedStopMarkerRef.current = null;
    mapRef.current?.setPadding({ top: 0, right: 0, bottom: 0, left: 0 });
  }, [selectedStop]);

  useEffect(() => {
    let cancelled = false;
    void fetchRegisteredStopsFromDatabase()
      .then((stops) => {
        if (!cancelled) setStopCatalog(stops);
      })
      .catch(() => {
        if (!cancelled) setStopCatalog([]);
      });
    return () => {
      cancelled = true;
    };
  }, []);
  const initialRouteStartedRef = useRef(false);

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
    return lineVehicles.length > 0 ? [...liveVehicles, ...lineVehicles] : liveVehicles;
  }, [lineVehicles, liveVehicles]);

  const displayVehiclesRef = useRef(displayVehicles);
  const previewIdsRef = useRef(new Set<string>());
  displayVehiclesRef.current = displayVehicles;
  previewIdsRef.current = new Set(
    displayVehicles.filter((vehicle) => vehicle.mode === "preview").map((vehicle) => vehicle.id),
  );

  // ===== Sélection =====
  const select = useCallback((kind: "vehicle", id: string) => {
    setSelectedKind(kind);
    setSelectedId(id);
    setSearchLineSelection(null);
    setRouteActive(false);
  }, []);

  // Toujours à jour : les marqueurs (créés une seule fois) appellent ce callback
  // via cette ref pour éviter les fermetures obsolètes (stale closures).
  const apiRef = useRef({ select });
  useEffect(() => {
    apiRef.current = { select };
  }, [select]);

  // ===== Construction des marqueurs (appelée une fois, après le chargement du style) =====
  const buildMarkers = useCallback(() => {
    const map = mapRef.current;
    if (!map) return;

    // Ne jamais afficher Nantes comme une fausse position utilisateur pendant
    // que le navigateur attend encore une mesure GPS.
    const initialUserPosition = userPositionRef.current;
    if (!initialUserPosition) return;

    // Le GPS peut répondre avant le chargement du style : dans ce cas
    // placeUserMarker a déjà posé un marqueur, il faut le déplacer plutôt que
    // d'en empiler un second (double marqueur à l'écran).
    if (userMarkerRef.current) {
      userMarkerRef.current.setLngLat([initialUserPosition[1], initialUserPosition[0]]);
      return;
    }

    const userEl = createUserElement();
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
          TRACKING_CAMERA_UPDATE_INTERVAL_SECONDS &&
        !map.isZooming()
      ) {
        trackingCameraUpdatedAtRef.current = now;
        map.easeTo({
          center: [pose.lng, pose.lat],
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
            activeTracking.scheduledPassages,
          ),
        );
        const distanceToUserM = userPositionRef.current
          ? distanceMetersBetween(vehiclePosition, userPositionRef.current)
          : null;
        const speedMps = Math.max(
          4,
          pose.speedMps ?? (activeTracking.type === "tram" ? 11 : 9),
        );
        const routeDistanceM = routeDistanceMeters(activeTracking.route);
        const distanceRemainingM = routeProjection
          ? routeDistanceMeters(
              buildRemainingRoute(activeTracking.route, routeProjection),
            )
          : null;
        setTrackingMetrics({
          distanceToStopM,
          etaMinutes:
            distanceToStopM == null ? null : distanceToStopM / speedMps / 60,
          distanceToUserM,
          distanceTraveledM:
            distanceRemainingM == null
              ? null
              : Math.max(0, routeDistanceM - distanceRemainingM),
          routeDistanceM,
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

    for (const lineAnimation of lineVehicleAnimationsRef.current.values()) {
      if (!previewIdsRef.current.has(lineAnimation.id)) continue;
      let distance = 0;
      let reverse = false;
      let currentSpeedMps = lineAnimation.speedMps;
      const scheduledMotion = vehicleScheduleMotionAt(
        lineAnimation.scheduleStops,
        Date.now(),
      );

      if (scheduledMotion) {
        distance = scheduledMotion.fraction * lineAnimation.length;
        reverse = scheduledMotion.fractionPerSecond < 0;
        currentSpeedMps = scheduledMotion.stopped
          ? 0
          : Math.abs(scheduledMotion.fractionPerSecond) *
            lineAnimation.routeDistanceM;
      } else {
        const terminalPause = 20;
        const elapsed = Math.max(0, now - lineAnimation.startedAt);
        const legDuration = lineAnimation.travelDuration;
        const cycleDuration = 2 * (legDuration + terminalPause);
        const phase = elapsed % cycleDuration;

        if (phase < terminalPause) {
          distance = 0;
          currentSpeedMps = 0;
        } else if (phase < terminalPause + legDuration) {
          distance =
            ((phase - terminalPause) / legDuration) * lineAnimation.length;
        } else if (phase < terminalPause * 2 + legDuration) {
          distance = lineAnimation.length;
          reverse = true;
          currentSpeedMps = 0;
        } else {
          distance =
            (1 -
              (phase - terminalPause * 2 - legDuration) / legDuration) *
            lineAnimation.length;
          reverse = true;
        }
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
        speedMps: currentSpeedMps,
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
    const detachMapErrorHandler = attachMapLibreErrorHandler(map, "ImmersiveMap");
    registerMissingImageFallback(map);
    map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), "bottom-right");
    map.addControl(createLocateControl(() => locateActionRef.current()), "bottom-right");
    map.addControl(
      createViewControl(
        () => viewActionRef.current(),
        (button) => {
          viewControlButtonRef.current = button;
        },
      ),
      "bottom-right",
    );
    map.addControl(
      createOrbitControl(
        () => rotateActionRef.current(-30),
        () => rotateActionRef.current(30),
      ),
      "bottom-right",
    );
    map.dragRotate.enable();
    map.touchZoomRotate.enableRotation();
    requestAnimationFrame(() => map.resize());
    const resizeTimer = setTimeout(() => map.resize(), 300);

    const handleViewportResize = () => map.resize();
    const resizeObserver = new ResizeObserver(handleViewportResize);
    resizeObserver.observe(mapContainerRef.current);
    window.addEventListener("orientationchange", handleViewportResize);
    window.visualViewport?.addEventListener("resize", handleViewportResize);

    map.on("load", () => {
      addExtrudedBuildings(map);
      applyAtmosphereSky(map, mapWeatherRef.current);
      applyAtmosphereReskin(map, mapWeatherRef.current);
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
      const ambientLayer = new AmbientSimulationLayer();
      ambientLayerRef.current = ambientLayer;
      ambientLayer.setEnabled(ambientEnabled);
      ambientLayer.setTransitStops(
        stopCatalog.flatMap((stop) =>
          stop.coordinates ? [{ lng: stop.coordinates[0], lat: stop.coordinates[1] }] : [],
        ),
      );
      map.addLayer(ambientLayer);
      const vehicleLayer = new Vehicle3DLayer({
        onSelect: (id) => apiRef.current.select("vehicle", id),
      });
      vehicleLayer.setAtmosphere(mapWeatherRef.current);
      vehicleLayerRef.current = vehicleLayer;
      vehicleLayer.setVehicles(displayVehiclesRef.current);
      map.addLayer(vehicleLayer);
      ambientLayer.moveBelowTransit();
      vehicleLayer.moveToTop();
      buildMarkers();
      readyRef.current = true;
      setMapReady(true);

      const hasInitialRoute = new URLSearchParams(window.location.search).get("route") === "1";
      if (!hasInitialRoute) {
        const knownPosition = userPositionRef.current;
        const introCenter = knownPosition ?? CITY_CENTER;
        map.flyTo({
          center: [introCenter[1], introCenter[0]],
          zoom: 15.6,
          pitch: 58,
          bearing: -18,
          duration: 2400,
        });
      }
      rafRef.current = requestAnimationFrame(tick);
    });

    return () => {
      clearTimeout(resizeTimer);
      resizeObserver.disconnect();
      window.removeEventListener("orientationchange", handleViewportResize);
      window.visualViewport?.removeEventListener("resize", handleViewportResize);
      cancelAnimationFrame(rafRef.current);
      detachMapErrorHandler();
      userMarkerRef.current?.remove();
      userMarkerRef.current = null;
      map.remove();
      mapRef.current = null;
      vehicleLayerRef.current = null;
      ambientLayerRef.current = null;
      readyRef.current = false;
      setMapReady(false);
    };
    // La carte n'est montée qu'une fois ; les mises à jour passent par les refs et actions ci-dessous.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !readyRef.current || !map.isStyleLoaded()) return;
    applyAtmosphereSky(map, mapWeather);
    applyAtmosphereReskin(map, mapWeather);
    vehicleLayerRef.current?.setAtmosphere(mapWeather);
    vehicleLayerRef.current?.moveToTop();
  }, [mapWeather]);

  useEffect(() => {
    vehicleLayerRef.current?.setVehicles(displayVehicles);
  }, [displayVehicles]);

  useEffect(() => {
    ambientLayerRef.current?.setTransitStops(
      stopCatalog.flatMap((stop) =>
        stop.coordinates ? [{ lng: stop.coordinates[0], lat: stop.coordinates[1] }] : [],
      ),
    );
  }, [stopCatalog, mapReady]);

  useEffect(() => {
    ambientLayerRef.current?.setEnabled(ambientEnabled);
  }, [ambientEnabled, mapReady]);

  useEffect(() => {
    vehicleLayerRef.current?.setSelected(
      tracking?.vehicleId ??
        (selectedKind === "vehicle" ? selectedId : null),
    );
  }, [selectedKind, selectedId, tracking?.vehicleId]);

  useEffect(() => {
    const layer = vehicleLayerRef.current;
    if (!layer) return;
    layer.setView3D(view3D);
    layer.setFilter("bus", filters.bus);
    layer.setFilter("tram", filters.tram);
  }, [view3D, filters]);

  useEffect(
    () => () => {
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
  viewActionRef.current = toggleView;

  const rotateMap = (degrees: number) => {
    const map = mapRef.current;
    if (!map) return;
    map.stop();
    map.easeTo({
      bearing: map.getBearing() + degrees,
      duration: 320,
      easing: (value) => 1 - Math.pow(1 - value, 3),
    });
  };
  rotateActionRef.current = rotateMap;

  useEffect(() => {
    const button = viewControlButtonRef.current;
    if (!button) return;
    button.classList.toggle("immersive-map-view-control--active", view3D);
    button.setAttribute("aria-pressed", String(view3D));
    button.title = view3D ? "Passer en vue 2D" : "Passer en vue 3D";
    button.setAttribute("aria-label", button.title);

    const icon = button.querySelector<HTMLElement>(".immersive-map-view-control-icon");
    if (icon) icon.textContent = view3D ? "3D" : "2D";
  }, [view3D]);

  // ===== Géolocalisation (réelle, via l'API navigateur) =====
  const flyToPosition = (center: LatLng, pitchOverride?: number, bearingOverride?: number, duration = 1800) => {
    const map = mapRef.current;
    if (!map) return;
    map.stop();
    map.flyTo({
      center: [center[1], center[0]],
      zoom: 17.3,
      pitch: pitchOverride ?? (view3D ? 60 : 0),
      bearing: bearingOverride ?? (view3D ? -14 : 0),
      duration,
    });
  };

  const placeUserMarker = (position: LatLng, isGpsPosition = true) => {
    userPositionRef.current = position;
    if (isGpsPosition) {
      setGeoPosition((current) =>
        current && distanceMeters(current, position) < 10 ? current : position,
      );
    }
    const roundedLocation = {
      lat: Number(position[0].toFixed(2)),
      lng: Number(position[1].toFixed(2)),
    };
    setWeatherLocation((current) =>
      current.lat === roundedLocation.lat && current.lng === roundedLocation.lng
        ? current
        : roundedLocation,
    );
    if (!userMarkerRef.current && mapRef.current) {
      userMarkerRef.current = new maplibregl.Marker({
        element: createUserElement(),
        anchor: "center",
      })
        .setLngLat([position[1], position[0]])
        .addTo(mapRef.current);
    } else {
      userMarkerRef.current?.setLngLat([position[1], position[0]]);
    }
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
      if (originIsCurrentRef.current) setOriginAddress(label || "Votre position actuelle");
    } catch {
      if (originIsCurrentRef.current) setOriginAddress("Votre position actuelle");
    } finally {
      setOriginAddressLoading(false);
    }
  }, []);

  const locateUser = useCallback((
    onFound: (position: LatLng) => void,
    onError: (issue: GeolocationIssue) => void,
  ) => {
    if (!window.isSecureContext) {
      onError("insecure");
      return;
    }
    if (!("geolocation" in navigator)) {
      onError("unsupported");
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => onFound([pos.coords.latitude, pos.coords.longitude]),
      (error) => {
        if (error.code === error.PERMISSION_DENIED) onError("denied");
        else if (error.code === error.TIMEOUT) onError("timeout");
        else onError("unavailable");
      },
      // Une position réseau/Wi-Fi arrive beaucoup plus régulièrement sur les
      // navigateurs desktop. Le watch haute précision l'affinera ensuite.
      { enableHighAccuracy: false, timeout: 15000, maximumAge: 300000 },
    );
  }, []);

  const startWatchingPosition = useCallback(() => {
    if (!("geolocation" in navigator) || geoWatchIdRef.current != null) return;
    geoWatchIdRef.current = navigator.geolocation.watchPosition(
      (pos) => placeUserMarker([pos.coords.latitude, pos.coords.longitude]),
      (error) => {
        if (error.code === error.PERMISSION_DENIED) {
          localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
          setGeoGranted(false);
          setGeoNotice(geolocationIssueMessage("denied"));
        }
      },
      { enableHighAccuracy: true, timeout: 20000, maximumAge: 30000 },
    );
  }, []);

  const onGeoAllow = () => {
    setGeoPromptVisible(false);
    locateUser(
      (position) => {
        localStorage.setItem(GEOLOCATION_CONSENT_KEY, "granted");
        setGeoGranted(true);
        setGeoNotice(null);
        placeUserMarker(position);
        void resolveOriginAddress(position);
        flyToPosition(position);
        startWatchingPosition();
      },
      (issue) => {
        localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
        setGeoGranted(false);
        setGeoNotice(geolocationIssueMessage(issue));
      },
    );
  };
  const onGeoDeny = () => {
    setGeoGranted(false);
    setGeoPromptVisible(false);
    setGeoNotice("Carte centrée sur Nantes — activez votre position pour un suivi personnalisé.");
  };
  const onLocateClick = () => {
    setGeoNotice(null);

    // Le dernier point GPS connu permet un recentrage immédiat, même si une
    // nouvelle mesure haute précision met plusieurs secondes à arriver.
    const knownPosition = userPositionRef.current;
    if (knownPosition) flyToPosition(knownPosition);

    locateUser(
      (position) => {
        localStorage.setItem(GEOLOCATION_CONSENT_KEY, "granted");
        setGeoGranted(true);
        placeUserMarker(position);
        void resolveOriginAddress(position);
        flyToPosition(position);
        startWatchingPosition();
      },
      (issue) => {
        localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
        setGeoGranted(false);
        setGeoNotice(geolocationIssueMessage(issue));
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
        setGeoNotice(geolocationIssueMessage("denied"));
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
          setGeoNotice(null);
          placeUserMarker(position);
          void resolveOriginAddress(position);
          flyToPosition(position, undefined, undefined, 0);
          startWatchingPosition();
        },
        (issue) => {
          if (cancelled) return;
          localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
          setGeoGranted(false);
          setGeoNotice(geolocationIssueMessage(issue));
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

  useEffect(() => {
    const query = originAddress.trim();
    const requestId = ++originSearchRequestRef.current;

    if (
      originIsCurrent ||
      query.length < 3 ||
      selectedOrigin?.label === query
    ) {
      setOriginSuggestions([]);
      setOriginSuggestionsLoading(false);
      return;
    }

    const handle = setTimeout(() => {
      setOriginSuggestionsLoading(true);
      void geocodeQuery(query).then((results) => {
        if (originSearchRequestRef.current !== requestId) return;
        setOriginSuggestions(results);
        setOriginSuggestionsLoading(false);
      });
    }, 320);

    return () => clearTimeout(handle);
  }, [originAddress, originIsCurrent, selectedOrigin]);

  const routeApiUrl = (
    mode: RouteMode,
    origin: LatLng,
    dest: LatLng,
    preferences: RoutePreferences,
    preview = false,
    departureAt?: Date,
  ) => {
    const params = new URLSearchParams({
      v: ROUTE_ALGORITHM_VERSION,
      mode: mode === "transit" ? "transit" : mode,
      from: `${origin[1]},${origin[0]}`,
      to: `${dest[1]},${dest[0]}`,
    });
    if (mode === "transit") {
      params.set("accessible", preferences.accessible ? "1" : "0");
      params.set("avoidDisruptions", preferences.avoidDisruptions ? "1" : "0");
      params.set("maxTransfers", String(preferences.maxTransfers));
      if (preview) params.set("preview", "1");
      if (departureAt) params.set("departureAt", departureAt.toISOString());
    }
    return `/api/route?${params.toString()}`;
  };

  // Recharge les vrais départs suivants (+20 et +40 min) une fois le premier
  // itinéraire affiché : le serveur ne calcule plus qu'une fenêtre horaire sur
  // le chemin critique, ces requêtes complètent le panneau en arrière-plan.
  const loadDeferredDepartures = (
    origin: LatLng,
    dest: LatLng,
    preferences: RoutePreferences,
  ) => {
    routeDeparturesRef.current?.abort();
    const controller = new AbortController();
    routeDeparturesRef.current = controller;
    void (async () => {
      const windows = await Promise.all(
        DEFERRED_DEPARTURE_WINDOWS_MIN.map(async (minutes) => {
          try {
            const url = routeApiUrl(
              "transit",
              origin,
              dest,
              preferences,
              false,
              new Date(Date.now() + minutes * 60_000),
            );
            const res = await fetch(url, { signal: controller.signal });
            const data = (await res.json()) as RouteApiData;
            return res.ok && data.engine === "timetable" ? data : null;
          } catch {
            return null;
          }
        }),
      );
      if (controller.signal.aborted) return;
      if (routeDeparturesRef.current === controller)
        routeDeparturesRef.current = null;
      const incoming = windows
        .flatMap((data) => data?.departures ?? data?.alternatives ?? [])
        .map(toRouteCandidate);
      if (!incoming.length) return;
      setRouteInfo((current) =>
        current?.engine === "timetable"
          ? {
              ...current,
              departures: mergeDepartureOptions(current.departures, incoming),
            }
          : current,
      );
    })();
  };

  const computeRoute = async (
    mode: RouteMode,
    origin: LatLng,
    dest: LatLng,
    name: string,
    preferences = routePreferences,
    departureAt?: Date,
    preserveCurrentRoute = false,
  ) => {
    const map = mapRef.current;
    if (!map) return;

    routeRequestRef.current?.abort();
    routeDeparturesRef.current?.abort();
    routeDeparturesRef.current = null;
    const controller = new AbortController();
    routeRequestRef.current = controller;

    activeRouteRef.current = { origin, dest, destName: name };
    setRouteActive(true);
    setRouteLoading(true);
    setRouteError(null);
    if (!preserveCurrentRoute) setRouteInfo(null);
    setRouteSkeletons([]);

    let routeRendered = false;
    let resultApplied = false;
    let finalResultApplied = false;
    let appliedEngine: "timetable" | "heuristic" | null = null;
    let lastError: Error | null = null;

    const fetchRouteResponse = async <T,>(
      url: string,
    ): Promise<{ res: Response; data: T }> => {
      const request = () =>
        fetch(url, {
          signal: controller.signal,
          cache: "no-store",
          headers: { Accept: "application/json" },
        });
      let res = await request();
      try {
        return { res, data: await readRouteResponse<T>(res) };
      } catch (error) {
        if (!(error instanceof RouteResponseFormatError) || controller.signal.aborted) {
          throw error;
        }
        // Une réponse HTML transitoire du serveur de développement produit ce
        // message dans Safari. Un unique réessai évite de figer le panneau.
        res = await request();
        return { res, data: await readRouteResponse<T>(res) };
      }
    };

    const fetchRouteData = async (url: string) => {
      const { res, data } = await fetchRouteResponse<RouteApiData>(url);
      if (!res.ok || !data.coordinates) {
        throw new Error(data.error ?? "Itinéraire indisponible");
      }
      return data;
    };

    const fetchRouteSkeletons = async (url: string) => {
      const { res, data } = await fetchRouteResponse<RouteSkeletonApiData>(url);
      if (!res.ok) throw new Error(data.error ?? "Aperçu indisponible");
      return (data.suggestions ?? []).map((suggestion) => ({
        id: suggestion.id,
        routeIds: suggestion.route_ids,
        summary: suggestion.summary,
      }));
    };

    const applyRouteData = (data: RouteApiData) => {
      if (routeRequestRef.current !== controller || !data.coordinates) return;

      const primaryDurationMin = Math.max(1, Math.round((data.duration ?? 0) / 60));
      const primaryDistanceM = Math.round(data.distance ?? 0);
      const primaryDistanceLabel =
        primaryDistanceM >= 1000
          ? `${(primaryDistanceM / 1000).toFixed(1)} km`
          : `${primaryDistanceM} m`;
      const primarySteps =
        data.steps ??
        ([
          {
            icon: mode === "car" ? "🚗" : "🚶",
            label: mode === "car" ? `En voiture jusqu'à ${name}` : `Marche à pied jusqu'à ${name}`,
            detail: primaryDistanceLabel,
            duration: `${primaryDurationMin} min`,
          },
        ] as RouteStep[]);
      const alternatives: RouteCandidateState[] = data.alternatives?.length
        ? data.alternatives.map(toRouteCandidate)
        : [
            {
              id: "primary",
              coordinates: data.coordinates,
              segments: data.segments,
              distanceM: primaryDistanceM,
              durationMin: primaryDurationMin,
              departureAt: data.departureAt,
              arrivalAt: data.arrivalAt,
              steps: primarySteps,
              summary: mode === "car" ? "Voiture" : "Meilleur itinéraire",
              accessible: false,
              alertCount: 0,
            },
          ];
      const departures = data.departures?.length
        ? data.departures.map(toRouteCandidate)
        : alternatives;
      const selected = alternatives[0];

      setRouteInfo({
        distanceM: selected.distanceM,
        durationMin: selected.durationMin,
        departureAt: selected.departureAt,
        arrivalAt: selected.arrivalAt,
        steps: selected.steps,
        alternatives,
        departures,
        selectedAlternativeId: selected.id,
        engine: data.engine ?? "heuristic",
      });
      setRouteSkeletons([]);
      resultApplied = true;
      appliedEngine = data.engine ?? "heuristic";

      try {
        showPlannedRoute(map, selected.coordinates, selected.segments);
      } catch (error) {
        // Le détail du trajet reste utilisable même si WebKit refuse une mise
        // à jour de la couche GeoJSON.
        console.warn("Impossible d’afficher le tracé de l’itinéraire", error);
      }

      if (!routeRendered) {
        routeRendered = true;
        try {
          destMarkerRef.current?.remove();
          destMarkerRef.current = new maplibregl.Marker({
            element: createDestElement(),
            anchor: "bottom",
          })
            .setLngLat([dest[1], dest[0]])
            .addTo(map);
        } catch (error) {
          console.warn("Impossible d’afficher le repère de destination", error);
        }

        try {
          const bounds = new maplibregl.LngLatBounds(
            [origin[1], origin[0]],
            [origin[1], origin[0]],
          );
          bounds.extend([dest[1], dest[0]]);
          map.fitBounds(bounds, {
            padding: { top: 140, bottom: 120, left: 380, right: 120 },
            pitch: view3D ? 50 : 0,
            duration: 1600,
            maxZoom: 16.5,
          });
        } catch (error) {
          console.warn("Impossible de cadrer l’itinéraire", error);
        }
      }
    };

    try {
      const completeUrl = routeApiUrl(
        mode,
        origin,
        dest,
        preferences,
        false,
        departureAt,
      );
      if (mode !== "transit") {
        applyRouteData(await fetchRouteData(completeUrl));
        finalResultApplied = true;
      } else {
        const previewUrl = routeApiUrl(
          mode,
          origin,
          dest,
          preferences,
          true,
          departureAt,
        );
        let skeletonsApplied = false;
        const previewRequest = fetchRouteSkeletons(previewUrl)
          .then((suggestions) => {
            if (!finalResultApplied && suggestions.length) {
              setRouteSkeletons(suggestions);
              skeletonsApplied = true;
            }
          })
          .catch((error: unknown) => {
            if (!controller.signal.aborted) {
              lastError = error instanceof Error ? error : new Error("Aperçu indisponible");
            }
          });
        const completeRequest = fetchRouteData(completeUrl)
          .then((data) => {
            finalResultApplied = true;
            applyRouteData(data);
          })
          .catch((error: unknown) => {
            if (!controller.signal.aborted) {
              lastError = error instanceof Error ? error : new Error("Itinéraire indisponible");
            }
          });

        await Promise.all([previewRequest, completeRequest]);
        if (!resultApplied && skeletonsApplied) return;
        if (
          resultApplied &&
          appliedEngine === "timetable" &&
          routeRequestRef.current === controller
        ) {
          loadDeferredDepartures(origin, dest, preferences);
        }
      }

      if (!resultApplied && lastError) throw lastError;
    } catch (err) {
      if (controller.signal.aborted) return;
      setRouteError(err instanceof Error ? err.message : "Itinéraire indisponible");
    } finally {
      if (routeRequestRef.current === controller) {
        routeRequestRef.current = null;
        setRouteLoading(false);
      }
    }
  };

  useEffect(() => {
    const departureAt = routeInfo?.departureAt;
    if (
      !routeActive ||
      routeMode !== "transit" ||
      routeLoading ||
      routeInfo?.engine !== "timetable" ||
      !departureAt ||
      refreshedDepartureRef.current === departureAt
    ) {
      return;
    }

    const delay = transitRouteRefreshDelay(departureAt);
    if (delay == null) return;

    const timer = window.setTimeout(() => {
      const active = activeRouteRef.current;
      if (!active || routeRequestRef.current) return;
      refreshedDepartureRef.current = departureAt;
      void computeRoute(
        "transit",
        active.origin,
        active.dest,
        active.destName,
        routePreferences,
        new Date(),
        true,
      );
    }, delay);

    return () => window.clearTimeout(timer);
    // Le recalcul doit uniquement être reprogrammé quand l'état temporel de
    // l'itinéraire change, pas à chaque nouvelle identité de computeRoute.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    routeActive,
    routeInfo?.departureAt,
    routeInfo?.engine,
    routeLoading,
    routeMode,
    routePreferences,
  ]);

  const prefetchTransitRoute = (origin: LatLng | null | undefined, dest: LatLng) => {
    if (!origin || routeMode !== "transit") return;
    routePrefetchRef.current?.abort();
    const controller = new AbortController();
    routePrefetchRef.current = controller;
    const url = routeApiUrl("transit", origin, dest, routePreferences);
    void fetch(url, { signal: controller.signal })
      .catch(() => undefined)
      .finally(() => {
        if (routePrefetchRef.current === controller) routePrefetchRef.current = null;
      });
  };

  const onSearchSubmit = async () => {
    const rawQuery = searchQuery.trim();
    if (rawQuery.length < 3) {
      setSearchError("Saisissez une adresse ou un lieu d’au moins 3 caractères.");
      return;
    }

    setDestinationLoading(true);
    setSearchError(null);
    try {
      const rawOrigin = originAddress.trim();
      const originResult = originIsCurrent
        ? null
        : selectedOrigin?.label === rawOrigin
          ? selectedOrigin
          : rawOrigin.length >= 3
            ? (await geocodeQuery(rawOrigin))[0]
            : null;
      const origin = originIsCurrent ? userPositionRef.current : originResult?.latLng;
      if (!origin) {
        setSearchError(
          originIsCurrent
            ? "Votre position GPS est indisponible. Saisissez une adresse ou un arrêt de départ."
            : "Point de départ introuvable. Saisissez une adresse ou choisissez un arrêt proposé.",
        );
        if (originIsCurrent) setGeoPromptVisible(true);
        return;
      }

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
    prefetchTransitRoute(
      originIsCurrent ? userPositionRef.current : selectedOrigin?.latLng,
      destination.latLng,
    );
  };

  const updateOriginQuery = (value: string) => {
    originIsCurrentRef.current = false;
    setOriginIsCurrent(false);
    setOriginAddress(value);
    setSelectedOrigin(null);
    setOriginSuggestions([]);
    setShowOriginSuggestions(value.trim().length >= 2);
    setSearchError(null);
  };

  const pickOriginSuggestion = (origin: GeocodeResult) => {
    originIsCurrentRef.current = false;
    setOriginIsCurrent(false);
    setOriginAddress(origin.label);
    setSelectedOrigin(origin);
    setOriginSuggestions([]);
    setShowOriginSuggestions(false);
    setSearchError(null);
    if (selectedDestination) prefetchTransitRoute(origin.latLng, selectedDestination.latLng);
  };

  const clearOrigin = () => {
    originIsCurrentRef.current = false;
    setOriginIsCurrent(false);
    setOriginAddress("");
    setSelectedOrigin(null);
    setOriginSuggestions([]);
    setShowOriginSuggestions(false);
    setSearchError(null);
  };

  const useCurrentPositionAsOrigin = () => {
    originIsCurrentRef.current = true;
    setOriginIsCurrent(true);
    setSelectedOrigin(null);
    setOriginSuggestions([]);
    setShowOriginSuggestions(false);
    setSearchError(null);
    const position = userPositionRef.current;
    if (position) {
      void resolveOriginAddress(position);
    } else {
      setOriginAddress("Votre position actuelle");
      setGeoPromptVisible(true);
    }
  };

  const changeRouteMode = (mode: RouteMode) => {
    setRouteMode(mode);
    const active = activeRouteRef.current;
    if (active) void computeRoute(mode, active.origin, active.dest, active.destName);
  };

  const changeRoutePreferences = (preferences: RoutePreferences) => {
    setRoutePreferences(preferences);
    const active = activeRouteRef.current;
    if (active && routeMode === "transit") {
      void computeRoute("transit", active.origin, active.dest, active.destName, preferences);
    }
  };

  const selectRouteAlternative = (id: string) => {
    const alternative = [...(routeInfo?.alternatives ?? []), ...(routeInfo?.departures ?? [])]
      .find((candidate) => candidate.id === id);
    const map = mapRef.current;
    if (!alternative || !map) return;
    try {
      showPlannedRoute(map, alternative.coordinates, alternative.segments);
    } catch (error) {
      console.warn("Impossible d’afficher l’itinéraire alternatif", error);
    }
    setRouteInfo((current) =>
      current
        ? {
            ...current,
            distanceM: alternative.distanceM,
            durationMin: alternative.durationMin,
            departureAt: alternative.departureAt,
            arrivalAt: alternative.arrivalAt,
            steps: alternative.steps,
            selectedAlternativeId: alternative.id,
          }
        : current,
    );
  };

  useEffect(() => {
    if (!mapReady || initialRouteStartedRef.current) return;

    const params = new URLSearchParams(window.location.search);
    if (params.get("route") !== "1") return;

    initialRouteStartedRef.current = true;
    const requestedMode = parseInitialRouteMode(params.get("mode"));
    const originRequest = parseInitialRoutePoint(params, "from", "fromLat", "fromLng");
    const destinationRequest = parseInitialRoutePoint(params, "to", "toLat", "toLng");

    const resolvePoint = async (
      point: InitialRoutePoint | null,
    ): Promise<GeocodeResult | null> => {
      if (!point) return null;
      if (point.latLng) {
        return {
          name: labelName(point.label),
          label: point.label,
          latLng: point.latLng,
        };
      }

      return (await geocodeQuery(point.label))[0] ?? null;
    };

    const launchInitialRoute = async () => {
      if (!destinationRequest) {
        setSearchError("Destination manquante pour calculer l’itinéraire.");
        setShowRouteInputs(true);
        return;
      }

      setRouteMode(requestedMode);
      setSearchQuery(destinationRequest.label);
      setSearchError(null);
      setSelectedKind(null);
      setSelectedId(null);
      setShowRouteInputs(true);
      setQuickCollapsed(true);
      setDestinationLoading(true);

      try {
        const [originResult, destinationResult] = await Promise.all([
          resolvePoint(originRequest),
          resolvePoint(destinationRequest),
        ]);
        const fallbackOrigin = userPositionRef.current;
        const origin = originResult?.latLng ?? fallbackOrigin;

        if (!origin) {
          setSearchError("Adresse de départ introuvable. Autorisez votre position ou saisissez une adresse.");
          setGeoPromptVisible(true);
          return;
        }

        if (!destinationResult) {
          setSearchError("Adresse de destination introuvable. Vérifiez la saisie puis réessayez.");
          return;
        }

        if (originResult) {
          originIsCurrentRef.current = false;
          setOriginIsCurrent(false);
          setOriginAddress(originResult.label);
          setSelectedOrigin(originResult);
          placeUserMarker(originResult.latLng, false);
        }

        setSelectedDestination(destinationResult);
        setDestName(destinationResult.name);
        setShowRouteInputs(false);
        await computeRoute(
          requestedMode,
          origin,
          destinationResult.latLng,
          destinationResult.name,
        );
      } finally {
        setDestinationLoading(false);
      }
    };

    void launchInitialRoute();
    // Cette lecture d'URL doit s'exécuter une seule fois, dès que la carte est prête.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mapReady]);

  const closeRoute = () => {
    routeRequestRef.current?.abort();
    routeRequestRef.current = null;
    routePrefetchRef.current?.abort();
    routePrefetchRef.current = null;
    routeDeparturesRef.current?.abort();
    routeDeparturesRef.current = null;
    setRouteLoading(false);
    setRouteActive(false);
    setRouteError(null);
    setSearchError(null);
    setAddressSuggestions([]);
    setShowAddressSuggestions(false);
    setSelectedDestination(null);
    setRouteInfo(null);
    setRouteSkeletons([]);
    setShowRouteInputs(false);
    activeRouteRef.current = null;
    refreshedDepartureRef.current = null;
    const map = mapRef.current;
    const src = map?.getSource("immersive-map-route") as maplibregl.GeoJSONSource | undefined;
    src?.setData({ type: "FeatureCollection", features: [] });
    destMarkerRef.current?.remove();
    destMarkerRef.current = null;
  };

  // ===== Filtres & actions rapides =====
  const setVehicleTypeDisplay = (type: FilterKey, show: boolean) => {
    vehicleLayerRef.current?.setFilter(type, show);
    const nextFilters = { ...filters, [type]: show };
    const map = mapRef.current;
    if (map) {
      setTransitTracesFilter(
        map,
        (["bus", "tram"] as const).filter((t) => nextFilters[t]),
      );
    }
  };

  const ensureVisible = (keys: FilterKey[]) => {
    setFilters((f) => {
      const upd = { ...f };
      for (const k of keys) upd[k] = true;
      return upd;
    });
    for (const k of keys) setVehicleTypeDisplay(k, true);
  };

  const qaRoute = () => {
    setMobileSearchOpen(false);
    setSearchQuery("");
    setSearchError(null);
    setShowCorrespondances(false);
    setShowRouteInputs(true);
    setSelectedKind(null);
    setSelectedId(null);
  };

  const qaCorrespondances = () => {
    setMobileSearchOpen(false);
    setSearchQuery("");
    setSearchError(null);
    setShowRouteInputs(false);
    setRouteActive(false);
    setSelectedStop(null);
    setSelectedKind(null);
    setSelectedId(null);
    setSearchLineSelection(null);
    clearSelectedLineMap();
    setShowCorrespondances(true);
    // Sans position connue, on déclenche la géolocalisation : la liste se
    // remplira automatiquement dès que le point GPS arrive.
    if (!userPositionRef.current) onLocateClick();
  };

  const handleCorrespondanceSelect = (stop: {
    id: string;
    name: string;
    code: string;
    lat?: number;
    lng?: number;
  }) => {
    setShowCorrespondances(false);
    const selection = {
      id: stop.id,
      name: stop.name,
      code: stop.code,
      stationName: stop.name,
      lat: stop.lat,
      lng: stop.lng,
    };
    setSelectedStop(selection);
    if (stop.lat != null && stop.lng != null) focusSelectedStop(selection);
  };

  const closeSelection = () => {
    setSelectedKind(null);
    setSelectedId(null);
    setSearchLineSelection(null);
    clearSelectedLineMap();
  };

  // ===== Dérivés pour le rendu =====
  const nearbyStops = useMemo(() => {
    if (!geoPosition) return [];
    return stopCatalog
      .flatMap((stop) =>
        stop.coordinates
          ? [
              {
                stop,
                distanceMeters: distanceMeters(geoPosition, [
                  stop.coordinates[1],
                  stop.coordinates[0],
                ]),
              },
            ]
          : [],
      )
      .sort((a, b) => a.distanceMeters - b.distanceMeters)
      .slice(0, NEARBY_SEARCH_STOP_LIMIT);
  }, [geoPosition, stopCatalog]);
  const nearbyStopIds = nearbyStops.map(({ stop }) => stop.id);
  const nearbyStopIdsKey = nearbyStopIds.join(",");

  const globalSearchSuggestions = useMemo<GlobalSearchSuggestion[]>(() => {
    const stopGroups = new Map<
      string,
      {
        stop: RegisteredStop;
        names: Set<string>;
        codes: Set<string>;
        count: number;
        distanceMeters: number | null;
      }
    >();
    for (const stop of stopCatalog) {
      const publicName = stop.stationName || stop.name;
      const key = publicName
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, " ")
        .trim();
      const stopDistance =
        geoPosition && stop.coordinates
          ? distanceMeters(geoPosition, [stop.coordinates[1], stop.coordinates[0]])
          : null;
      const existing = stopGroups.get(key);
      if (existing) {
        existing.names.add(stop.name);
        if (stop.code) existing.codes.add(stop.code);
        existing.count += 1;
        if (
          stopDistance != null &&
          (existing.distanceMeters == null || stopDistance < existing.distanceMeters)
        ) {
          existing.stop = stop;
          existing.distanceMeters = stopDistance;
        }
      } else {
        stopGroups.set(key, {
          stop,
          names: new Set([stop.name]),
          codes: new Set(stop.code ? [stop.code] : []),
          count: 1,
          distanceMeters: stopDistance,
        });
      }
    }
    const stopSuggestions = [...stopGroups.values()]
      .sort((a, b) => {
        if (geoPosition) {
          const distanceDelta =
            (a.distanceMeters ?? Number.POSITIVE_INFINITY) -
            (b.distanceMeters ?? Number.POSITIVE_INFINITY);
          if (distanceDelta !== 0) return distanceDelta;
        }
        return (a.stop.stationName || a.stop.name).localeCompare(
          b.stop.stationName || b.stop.name,
          "fr",
          { sensitivity: "base" },
        );
      })
      .map(({ stop, names, codes, count, distanceMeters: stopDistance }) => ({
        id: `stop:${stop.id}`,
        category: "stop" as const,
        mode: "stop" as const,
        title: stop.stationName || stop.name,
        subtitle: `${
          stopDistance == null ? "" : `À ${formatNearbyDistance(stopDistance)} · `
        }${count > 1 ? "Station Naolib" : "Arrêt Naolib"}`,
        keywords: `${[...names].join(" ")} ${[...codes].join(" ")} arrêt station horaires passages`,
        distanceMeters: stopDistance ?? undefined,
      }));

    const nearbyLines = new Map<
      string,
      { distanceMeters: number; stopName: string }
    >();
    nearbyStops.forEach(({ stop, distanceMeters: stopDistance }) => {
      for (const shortName of stopLinesById[stop.id] ?? []) {
        const key = normalizePublicLineName(shortName);
        const existing = nearbyLines.get(key);
        if (!existing || stopDistance < existing.distanceMeters) {
          nearbyLines.set(key, {
            distanceMeters: stopDistance,
            stopName: stop.stationName || stop.name,
          });
        }
      }
    });
    const uniqueDashboardLines = new Map(
      [...dashboardLines, ...publishedCustomLines].map((line) => [line.id, line]),
    );
    const lineSuggestions = [...uniqueDashboardLines.values()]
      .map((line) => {
        const transport = line.transportType.toLowerCase();
        const isManualLine = line.id.startsWith("network:") || line.id.startsWith("custom:");
        const mode = transport.includes("tram")
          ? ("tram" as const)
          : transport.includes("navibus") || transport.includes("bateau")
            ? ("navibus" as const)
            : ("bus" as const);
        const modeLabel = mode === "tram" ? "Tram" : mode === "navibus" ? "Navibus" : "Bus";
        const nearby = nearbyLines.get(normalizePublicLineName(line.shortName));
        return {
          suggestion: {
            id: `line:dashboard:${line.id}`,
            category: "line" as const,
            mode,
            title: `${modeLabel} ${line.shortName}`,
            subtitle: nearby
              ? `${nearby.stopName} à ${formatNearbyDistance(nearby.distanceMeters)} · ${line.origin} ↔ ${line.destination}`
              : `${line.origin} ↔ ${line.destination} · ${isManualLine ? "Manuelle" : "GTFS"} · ${line.depotCode}`,
            keywords: `${line.shortName} ${line.routeId} ${line.origin} ${line.destination} ${line.depotCode} ${isManualLine ? "manuelle créée" : "gtfs importée"} ligne transport`,
            color: line.color,
            distanceMeters: nearby?.distanceMeters,
          },
          nearbyDistance: nearby?.distanceMeters ?? Number.POSITIVE_INFINITY,
        };
      })
      .sort(
        (a, b) =>
          a.nearbyDistance - b.nearbyDistance ||
          a.suggestion.title.localeCompare(b.suggestion.title, "fr", { numeric: true }),
      )
      .map(({ suggestion }) => suggestion);

    return [...stopSuggestions, ...lineSuggestions];
  }, [
    dashboardLines,
    geoPosition,
    nearbyStops,
    publishedCustomLines,
    stopCatalog,
    stopLinesById,
  ]);

  // Arrêts (stations) autour de l'utilisateur, triés du plus proche au plus
  // lointain, avec les numéros des lignes qui y passent. Les deux sens d'une
  // même station sont regroupés et leurs lignes fusionnées.
  const nearbyStopCorrespondances = useMemo(() => {
    // Métadonnées de ligne (couleur, mode) par nom normalisé.
    const lineMeta = new Map<
      string,
      { shortName: string; color?: string; mode: "bus" | "tram" | "navibus" }
    >();
    for (const line of [...dashboardLines, ...publishedCustomLines]) {
      const key = normalizePublicLineName(line.shortName);
      if (lineMeta.has(key)) continue;
      const transport = line.transportType.toLowerCase();
      const mode = transport.includes("tram")
        ? ("tram" as const)
        : transport.includes("navibus") || transport.includes("bateau")
          ? ("navibus" as const)
          : ("bus" as const);
      lineMeta.set(key, { shortName: line.shortName, color: line.color, mode });
    }

    const groups = new Map<
      string,
      { stop: RegisteredStop; distanceMeters: number; lineNames: Map<string, string> }
    >();
    for (const { stop, distanceMeters: stopDistance } of nearbyStops) {
      const groupKey = normalizePublicLineName(stop.stationName || stop.name);
      let group = groups.get(groupKey);
      if (!group) {
        group = { stop, distanceMeters: stopDistance, lineNames: new Map() };
        groups.set(groupKey, group);
      } else if (stopDistance < group.distanceMeters) {
        group.stop = stop;
        group.distanceMeters = stopDistance;
      }
      for (const raw of stopLinesById[stop.id] ?? []) {
        const lineKey = normalizePublicLineName(raw);
        if (!group.lineNames.has(lineKey)) group.lineNames.set(lineKey, raw);
      }
    }

    return [...groups.values()]
      .map(({ stop, distanceMeters: stopDistance, lineNames }) => ({
        id: stop.id,
        name: stop.stationName || stop.name,
        code: stop.code,
        lat: stop.coordinates?.[1],
        lng: stop.coordinates?.[0],
        distanceMeters: stopDistance,
        lines: [...lineNames.entries()]
          .map(([lineKey, raw]) => {
            const meta = lineMeta.get(lineKey);
            return {
              shortName: meta?.shortName ?? raw,
              color: meta?.color,
              mode: meta?.mode ?? ("bus" as const),
            };
          })
          .sort((a, b) =>
            a.shortName.localeCompare(b.shortName, "fr", { numeric: true }),
          ),
      }))
      .sort((a, b) => a.distanceMeters - b.distanceMeters);
  }, [nearbyStops, stopLinesById, dashboardLines, publishedCustomLines]);

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

  const focusSelectedStop = useCallback(
    (stop: SelectedMapStop) => {
      if (stop.lat == null || stop.lng == null) return;
      const map = mapRef.current;
      if (!map) return;

      selectedStopMarkerRef.current?.remove();
      selectedStopMarkerRef.current = new maplibregl.Marker({
        element: createLineStopElement(stop.name, 0, 1, "#5fe0c4"),
        anchor: "center",
      })
        .setLngLat([stop.lng, stop.lat])
        .addTo(map);

      const desktopPanel = window.innerWidth >= 720;
      map.flyTo({
        center: [stop.lng, stop.lat],
        zoom: 17.8,
        pitch: view3D ? 56 : 0,
        padding: desktopPanel
          ? { top: 100, right: 70, bottom: 90, left: 430 }
          : { top: 90, right: 24, bottom: 330, left: 24 },
        duration: 1_200,
        essential: true,
      });
    },
    [view3D],
  );

  const clearSelectedLineMap = useCallback(() => {
    lineStopMarkersRef.current.forEach((marker) => marker.remove());
    lineStopMarkersRef.current = [];
    for (const lineVehicleId of lineVehicleAnimationsRef.current.keys()) {
      previewAnglesRef.current.delete(lineVehicleId);
    }
    lineVehicleAnimationsRef.current.clear();
    activeLineMapDataRef.current = null;
    setLineVehicles([]);

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
            () => {
              const selected = {
                id: stop.id,
                name: stop.name,
                code: stop.id,
                stationName: stop.name,
                lat: stop.lat,
                lng: stop.lng,
              } satisfies SelectedMapStop;
              setSearchLineSelection(null);
              setSelectedStop(selected);
              focusSelectedStop(selected);
            },
          ),
          anchor: "center",
        })
          .setLngLat([stop.lng, stop.lat])
          .addTo(map),
      );

      if (suggestion.mode === "bus" || suggestion.mode === "tram") {
        const length = pathLen(data.trace);
        const routeDistanceM = routeDistanceMeters(data.trace);
        const vehicleType = suggestion.mode;
        const speedMps = vehicleType === "tram" ? 7.5 : 5.8;
        const travelDuration = Math.max(
          45,
          routeDistanceM / speedMps,
        );
        const schedules = data.schedules?.length
          ? data.schedules
          : data.schedule
            ? [data.schedule]
            : [null];
        const vehicles = schedules.map((schedule, index): MapVehicle => {
          const vehicleId = `selected-line:${line.id}:${schedule?.departureId ?? index}`;
          const scheduleReferenceAt = schedule
            ? new Date(schedule.generatedAt).getTime()
            : Number.NaN;
          const scheduleStops =
            schedule && Number.isFinite(scheduleReferenceAt)
              ? schedule.stops.map((stop) => ({
                  stopId: stop.stopId,
                  fraction: stop.fraction,
                  passageAtMs:
                    scheduleReferenceAt + stop.passageInSeconds * 1_000,
                }))
              : [];
          const initialMotion = vehicleScheduleMotionAt(scheduleStops, Date.now());
          const start = pointAt(
            data.trace,
            (initialMotion?.fraction ?? 0) * length,
          );
          const nextScheduledStopId = schedule?.stops.find(
            (stop) => stop.passageInSeconds > 0,
          )?.stopId;
          const nextScheduledStop = data.stops.find(
            (stop) => stop.id === nextScheduledStopId,
          );
          lineVehicleAnimationsRef.current.set(vehicleId, {
            id: vehicleId,
            coords: data.trace,
            length,
            startedAt: performance.now() / 1_000,
            travelDuration,
            speedMps,
            routeDistanceM,
            scheduleStops,
          });
          return {
            id: vehicleId,
            type: vehicleType,
            mode: "preview",
            lat: start.lat,
            lng: start.lng,
            heading: 0,
            speedMps,
            recordedAt: null,
            routeId: line.shortName,
            destination: schedule?.destination ?? line.destination,
            preview: {
              id: vehicleId,
              type: vehicleType,
              line: suggestion.title,
              dest: schedule?.destination ?? line.destination,
              nextStop:
                nextScheduledStop?.name ??
                data.stops[1]?.name ??
                data.stops[0]?.name,
              status: schedule
                ? "Calé sur les horaires de station"
                : "Position estimée sur le tracé",
            },
          };
        });
        setLineVehicles(vehicles);
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
        vehicleCount: data.schedules?.length ?? (data.schedule ? 1 : 0),
      });
      focusSearchCoordinates(
        data.trace,
        suggestion.mode === "navibus" ? 14.8 : 15.8,
      );
    },
    [clearSelectedLineMap, focusSearchCoordinates, focusSelectedStop],
  );

  const handleGlobalSearchSelect = (suggestion: GlobalSearchSuggestion) => {
      setGlobalSearchQuery(suggestion.title);
      setShowRouteInputs(false);
      setRouteActive(false);
      setSelectedKind(null);
      setSelectedId(null);

      if (suggestion.id.startsWith("stop:")) {
        const stopId = suggestion.id.slice("stop:".length);
        const stop = stopCatalog.find((item) => item.id === stopId);
        if (!stop) return;
        setSelectedStop({
          id: stop.id,
          name: stop.name,
          code: stop.code,
          stationName: stop.stationName,
          lat: stop.coordinates?.[1],
          lng: stop.coordinates?.[0],
        });
        if (stop.coordinates) {
          focusSelectedStop({
            id: stop.id,
            name: stop.name,
            code: stop.code,
            stationName: stop.stationName,
            lat: stop.coordinates[1],
            lng: stop.coordinates[0],
          });
        }
        return;
      }

      setSelectedStop(null);

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

  const startVehicleTracking = async (
    vehicleId: string,
    vehicleOverride?: MapVehicle,
  ) => {
    const vehicle =
      vehicleOverride ?? displayVehicles.find((item) => item.id === vehicleId);
    if (!vehicle || (vehicle.type !== "bus" && vehicle.type !== "tram")) return;

    let route: LatLng[] = [];
    let stops: LineStop[] = [];
    let hasRealtime = vehicle.mode === "live" && !fleetStale;
    const scheduledPassages = new Map<string, number>();
    const preview = vehicle.preview;
    const activeLineAnimation = lineVehicleAnimationsRef.current.get(vehicleId);

    if (
      activeLineAnimation &&
      activeLineMapDataRef.current
    ) {
      route = activeLineMapDataRef.current.trace;
      stops = activeLineMapDataRef.current.stops;
      for (const stop of activeLineAnimation.scheduleStops) {
        scheduledPassages.set(stop.stopId, stop.passageAtMs);
      }
      hasRealtime = false;
    } else if (preview) {
      route = realPathsRef.current[preview.id] ?? [];
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
      scheduledPassages,
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
    const initialRouteDistanceM = routeDistanceMeters(route);
    const initialDistanceRemainingM = initialRouteProjection
      ? routeDistanceMeters(buildRemainingRoute(route, initialRouteProjection))
      : null;
    setTracking(activeTracking);
    setTrackingStopPlan(
      buildTrackingStopPlan(
        route,
        stops,
        initialRouteProjection,
        nextStop?.name ?? preview?.nextStop ?? "Non renseigné",
        activeTracking.scheduledPassages,
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
      distanceTraveledM:
        initialDistanceRemainingM == null
          ? null
          : Math.max(0, initialRouteDistanceM - initialDistanceRemainingM),
      routeDistanceM: initialRouteDistanceM,
    });
    setTrackingStopsVisible(false);
    trackingStopsVisibleRef.current = false;
    lineStopMarkersRef.current.forEach((marker) => marker.remove());
    lineStopMarkersRef.current = [];
    setSelectedKind(null);
    setSelectedId(null);
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

  const startScheduledPassageTracking = async (
    passage: ScheduledPassageSelection | RouteVehicleTracking,
  ) => {
    const params = new URLSearchParams({
      lineId: passage.routeId,
      departureId: passage.departureId,
      profileId: passage.profileId,
      serviceDate: passage.serviceDate,
    });
    const response = await fetch(`/api/carte-immersive/line?${params.toString()}`, {
      cache: "no-store",
    });
    const data = (await response.json()) as LoadedLineMapData & { error?: string };
    if (
      !response.ok
      || !data.schedule
      || !Array.isArray(data.trace)
      || data.trace.length < 2
    ) {
      throw new Error(
        data.error || "La position de ce véhicule n'est pas encore disponible.",
      );
    }

    const scheduleReferenceAt = new Date(data.schedule.generatedAt).getTime();
    if (!Number.isFinite(scheduleReferenceAt)) {
      throw new Error("L'horaire de cette course est momentanément indisponible.");
    }
    const scheduleStops = data.schedule.stops.map((stop) => ({
      stopId: stop.stopId,
      fraction: stop.fraction,
      passageAtMs: scheduleReferenceAt + stop.passageInSeconds * 1_000,
    }));
    const initialMotion = vehicleScheduleMotionAt(scheduleStops, Date.now());
    if (!initialMotion || scheduleStops.length < 2) {
      throw new Error("Le trajet de ce véhicule ne peut pas encore être localisé.");
    }

    const length = pathLen(data.trace);
    const estimatedPosition = pointAt(
      data.trace,
      initialMotion.fraction * length,
    );
    const liveVehicle = fleetStale
      ? null
      : selectLiveVehicleForSchedule(liveVehicles, {
          line: passage.line,
          routeId: passage.routeId,
          direction: passage.direction,
          estimatedPosition,
        });

    // Mémorise l'arrêt d'origine (vue « Horaires de la journée ») pour pouvoir y
    // revenir au « Quitter le suivi ». Un suivi lancé depuis l'itinéraire
    // (RouteVehicleTracking, sans couleur de ligne) n'a pas de retour d'arrêt.
    trackingOriginRef.current =
      selectedStop && "lineColor" in passage
        ? {
            stop: selectedStop,
            line: passage.line,
            direction: passage.direction,
            lineColor: passage.lineColor,
            serviceDate: passage.serviceDate,
          }
        : null;

    selectedStopMarkerRef.current?.remove();
    selectedStopMarkerRef.current = null;
    setSelectedStop(null);
    setSearchLineSelection(null);
    clearSelectedLineMap();

    if (liveVehicle) {
      await startVehicleTracking(liveVehicle.id);
      return;
    }

    activeLineMapDataRef.current = data;
    const vehicleId = `scheduled:${passage.serviceDate}:${passage.departureId}`;
    const routeDistanceM = routeDistanceMeters(data.trace);
    const speedMps = passage.vehicleType === "tram" ? 7.5 : 5.8;
    const nextScheduledStopId = data.schedule.stops.find(
      (stop) => stop.passageInSeconds > 0,
    )?.stopId;
    const nextScheduledStop = data.stops.find(
      (stop) => stop.id === nextScheduledStopId,
    );
    const scheduledVehicle: MapVehicle = {
      id: vehicleId,
      type: passage.vehicleType,
      mode: "preview",
      lat: estimatedPosition.lat,
      lng: estimatedPosition.lng,
      heading: 0,
      speedMps,
      recordedAt: null,
      routeId: passage.routeId,
      destination: data.schedule.destination ?? passage.direction,
      preview: {
        id: vehicleId,
        type: passage.vehicleType,
        line: `Ligne ${passage.line}`,
        dest: data.schedule.destination ?? passage.direction,
        nextStop:
          nextScheduledStop?.name ?? data.stops[1]?.name ?? data.stops[0]?.name,
        status: "Position théorique calculée depuis les horaires GTFS",
      },
    };
    setLineVehicles([scheduledVehicle]);
    lineVehicleAnimationsRef.current.set(vehicleId, {
      id: vehicleId,
      coords: data.trace,
      length,
      startedAt: performance.now() / 1_000,
      travelDuration: Math.max(45, routeDistanceM / speedMps),
      speedMps,
      routeDistanceM,
      scheduleStops,
    });
    await startVehicleTracking(vehicleId, scheduledVehicle);
  };

  const stopVehicleTracking = () => {
    // Retour éventuel vers les « Horaires de la journée » de l'arrêt d'origine.
    const origin = trackingOriginRef.current;
    trackingOriginRef.current = null;

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

    // Priorité au retour vers l'arrêt d'origine : on rouvre le panneau des
    // horaires de la journée (ligne + date mémorisées) et on recentre l'arrêt.
    if (origin) {
      const source = map?.getSource("immersive-map-route") as
        | maplibregl.GeoJSONSource
        | undefined;
      source?.setData({ type: "FeatureCollection", features: [] });
      setScheduleReturn({
        stopId: origin.stop.id,
        line: origin.line,
        direction: origin.direction,
        lineColor: origin.lineColor,
        serviceDate: origin.serviceDate,
      });
      setSelectedStop(origin.stop);
      focusSelectedStop(origin.stop);
      return;
    }

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

      if (mapVehicle?.preview) {
        const v = mapVehicle.preview;
        return {
          emoji: v.type === "tram" ? "🚋" : "🚌",
          title: v.line ?? "",
          subtitle: `Aperçu · ${v.type === "bus" ? "Bus en circulation" : "Tramway en circulation"}`,
          facts: [
            { k: "Destination", v: v.dest ?? "" },
            { k: "Prochain arrêt", v: v.nextStop ?? "" },
            { k: "Statut", v: v.status ?? "" },
          ],
          actionLabel: v.type === "bus" ? "Suivre ce bus" : "Suivre ce tram",
          action: () => void startVehicleTracking(mapVehicle.id),
        };
      }
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
          ? [{
              k: "Véhicules",
              v:
                searchLineSelection.vehicleCount != null
                  ? `${searchLineSelection.vehicleCount} en circulation`
                  : "En mouvement",
            }]
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

  const visibleDetail = tracking || selectedStop ? null : detail ?? searchLineDetail;

  const bottomNavVisible =
    !tracking &&
    !showRouteInputs &&
    !routeActive &&
    !visibleDetail &&
    !selectedStop &&
    !showCorrespondances;

  const routeFallbackDeparture = new Date();
  const routeDeparture = routeInfo
    ? routeDate(routeInfo.departureAt, routeFallbackDeparture)
    : routeFallbackDeparture;
  const routeArrival = routeInfo
    ? routeDate(
        routeInfo.arrivalAt,
        new Date(routeDeparture.getTime() + routeInfo.durationMin * 60_000),
      )
    : routeFallbackDeparture;
  const departureStr = routeInfo ? formatRouteDate(routeDeparture) : "";
  const arrivalStr = routeInfo ? formatRouteDate(routeArrival) : "";
  const routeSteps: RouteStep[] = routeInfo?.steps ?? [];
  const routeAlternatives: RouteAlternativeOption[] =
    routeInfo?.alternatives.map((alternative) => {
      const departure = routeDate(alternative.departureAt, routeFallbackDeparture);
      const arrival = routeDate(
        alternative.arrivalAt,
        new Date(departure.getTime() + alternative.durationMin * 60_000),
      );
      return {
        id: alternative.id,
        duration: alternative.durationMin,
        departure: formatRouteDate(departure),
        arrival: formatRouteDate(arrival),
        summary: alternative.summary,
        accessible: alternative.accessible,
        alertCount: alternative.alertCount,
      };
    }) ?? [];
  const routeDepartures: RouteDepartureOption[] =
    routeInfo?.departures.map((alternative) => {
      const departure = routeDate(alternative.departureAt, routeFallbackDeparture);
      const arrival = routeDate(
        alternative.arrivalAt,
        new Date(departure.getTime() + alternative.durationMin * 60_000),
      );
      return {
        id: alternative.id,
        duration: alternative.durationMin,
        departure: formatRouteDate(departure),
        arrival: formatRouteDate(arrival),
        summary: alternative.summary,
        accessible: alternative.accessible,
        alertCount: alternative.alertCount,
      };
    }) ?? [];
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
        distanceTraveledM: trackingMetrics.distanceTraveledM,
        routeDistanceM: trackingMetrics.routeDistanceM,
        status: tracking.status,
        hasRealtime: tracking.hasRealtime,
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

  const buildRouteStopSuggestions = (value: string, idPrefix: string) => {
    const query = value
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .trim();
    if (query.length < 2) return [];

    const seen = new Set<string>();
    return stopCatalog
      .filter((stop) => {
        const searchable = `${stop.stationName ?? ""} ${stop.name} ${stop.code}`
          .normalize("NFD")
          .replace(/[\u0300-\u036f]/g, "")
          .toLowerCase();
        return searchable.includes(query);
      })
      .filter((stop) => {
        const key = (stop.stationName || stop.name)
          .normalize("NFD")
          .replace(/[\u0300-\u036f]/g, "")
          .toLowerCase();
        if (seen.has(key)) return false;
        seen.add(key);
        return Boolean(stop.coordinates);
      })
      .slice(0, 5)
      .map((stop) => {
        const name = stop.stationName || stop.name;
        const lines = stopLinesById[stop.id] ?? [];
        const serviceLabel = lines.length
          ? `${lines.length > 1 ? "Lignes" : "Ligne"} ${lines.join(" · ")}`
          : "Arrêt Naolib";
        return {
          id: `${idPrefix}-${stop.id}`,
          stopId: stop.id,
          label: `${name}, ${serviceLabel}`,
          destination: {
            name,
            label: name,
            latLng: [stop.coordinates![1], stop.coordinates![0]] as LatLng,
          },
        };
      });
  };
  const routeStopSuggestions = buildRouteStopSuggestions(searchQuery, "route-stop");
  const originStopSuggestions = originIsCurrent
    ? []
    : buildRouteStopSuggestions(originAddress, "origin-stop");
  const suggestedStopIds = [...new Set([
    ...nearbyStopIds,
    ...routeStopSuggestions.map((suggestion) => suggestion.stopId),
    ...originStopSuggestions.map((suggestion) => suggestion.stopId),
  ])];
  const suggestedStopIdsKey = suggestedStopIds.join(",");

  useEffect(() => {
    const missingIds = suggestedStopIdsKey.split(",").filter(Boolean).filter(
      (id) => stopLinesById[id] === undefined && !requestedStopLinesRef.current.has(id),
    );
    if (!missingIds.length) return;

    missingIds.forEach((id) => requestedStopLinesRef.current.add(id));
    const batches = Array.from(
      { length: Math.ceil(missingIds.length / NEARBY_SEARCH_STOP_LIMIT) },
      (_, index) =>
        missingIds.slice(
          index * NEARBY_SEARCH_STOP_LIMIT,
          (index + 1) * NEARBY_SEARCH_STOP_LIMIT,
        ),
    );
    void Promise.all(
      batches.map(async (ids) => {
        const response = await fetch(
          `/api/carte-immersive/stop-lines?ids=${encodeURIComponent(ids.join(","))}`,
          { cache: "no-store" },
        );
        if (!response.ok) throw new Error("Lignes indisponibles");
        return response.json() as Promise<{
          linesByStopId?: Record<string, string[]>;
        }>;
      }),
    )
      .then((results) => {
        const linesByStopId = Object.assign(
          {},
          ...results.map((data) => data.linesByStopId ?? {}),
        );
        setStopLinesById((current) => ({ ...current, ...linesByStopId }));
      })
      .catch(() => {
        missingIds.forEach((id) => requestedStopLinesRef.current.delete(id));
      });
  }, [nearbyStopIdsKey, suggestedStopIdsKey, stopLinesById]);
  const contextPanelOpen = Boolean(
    routeActive || visibleDetail || selectedStop || tracking,
  );

  return (
    <div
      className={`immersive-map-root${bottomNavVisible ? " immersive-map-root--nav-visible" : ""}${
        contextPanelOpen ? " immersive-map-root--context-open" : ""
      }`}
      data-period={mapWeather.period}
      data-weather={mapWeather.condition}
    >
      <div className="immersive-map-canvas">
        <div ref={mapContainerRef} className="h-full w-full" />
        {mapError && (
          <div className="flex h-full w-full items-center justify-center px-8 text-center text-sm text-white/70">
            {mapError}
          </div>
        )}
      </div>
      <MapWeatherScene weather={mapWeather} />
      <div className="immersive-map-vignette" />
      <div className="immersive-map-vignette-top" />
      {/* La pastille n'apparaît qu'en temps réel : en aperçu elle n'apportait rien. */}
      {bottomNavVisible && fleetMode === "live" && (
        <div
          className={`immersive-map-live-status immersive-map-live-status--${fleetMode}${
            fleetStale ? " immersive-map-live-status--stale" : ""
          }`}
          aria-live="polite"
          aria-label={`Temps réel. Météo : ${mapWeather.label}`}
        >
          <span className="immersive-map-live-status-dot" />
          <span>{fleetStale
            ? "Temps réel · signal en attente"
            : `${liveVehicles.length} véhicule${liveVehicles.length > 1 ? "s" : ""} en direct`}</span>
          <span className="immersive-map-live-status-separator" aria-hidden="true" />
          <span className="immersive-map-live-status-weather">
            {mapWeather.temperature != null ? `${Math.round(mapWeather.temperature)}° · ` : ""}
            {mapWeather.label} · <span className="immersive-map-weather-source">Open-Meteo</span>
          </span>
        </div>
      )}

      <TopBar
        viewer={viewer}
        globalSearchQuery={globalSearchQuery}
        globalSearchSuggestions={globalSearchSuggestions}
        onGlobalSearchChange={setGlobalSearchQuery}
        onGlobalSearchSelect={handleGlobalSearchSelect}
        mobileSearchOpen={mobileSearchOpen}
        onMobileSearchOpenChange={setMobileSearchOpen}
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
        onCloseInputs={closeRoute}
        originAddress={originAddress}
        originIsCurrent={originIsCurrent}
        onOriginChange={updateOriginQuery}
        onOriginFocus={() => {
          if (!originIsCurrent && originAddress.trim().length >= 2) {
            setShowOriginSuggestions(true);
          }
        }}
        onOriginBlur={() => {
          setTimeout(() => setShowOriginSuggestions(false), 120);
        }}
        onOriginClear={clearOrigin}
        onUseCurrentPosition={useCurrentPositionAsOrigin}
        originAddressLoading={originAddressLoading}
        destinationLoading={destinationLoading}
        searchError={searchError}
        showAddressSuggestions={
          showAddressSuggestions &&
          (addressSuggestionsLoading || routeStopSuggestions.length > 0 || addressSuggestions.length > 0)
        }
        addressSuggestionsLoading={addressSuggestionsLoading}
        addressSuggestions={[
          ...routeStopSuggestions.map((suggestion) => ({
            id: suggestion.id,
            label: suggestion.label,
            kind: "stop" as const,
            onPick: () => pickAddressSuggestion(suggestion.destination),
          })),
          ...addressSuggestions.map((suggestion, index) => ({
            id: `${suggestion.latLng[0]}-${suggestion.latLng[1]}-${index}`,
            label: suggestion.label,
            kind: "address" as const,
            onPick: () => pickAddressSuggestion(suggestion),
          })),
        ]}
        showOriginSuggestions={
          showOriginSuggestions &&
          (originSuggestionsLoading || originStopSuggestions.length > 0 || originSuggestions.length > 0)
        }
        originSuggestionsLoading={originSuggestionsLoading}
        originSuggestions={[
          ...originStopSuggestions.map((suggestion) => ({
            id: suggestion.id,
            label: suggestion.label,
            kind: "stop" as const,
            onPick: () => pickOriginSuggestion(suggestion.destination),
          })),
          ...originSuggestions.map((suggestion, index) => ({
            id: `origin-${suggestion.latLng[0]}-${suggestion.latLng[1]}-${index}`,
            label: suggestion.label,
            kind: "address" as const,
            onPick: () => pickOriginSuggestion(suggestion),
          })),
        ]}
      />

      <QuickActionsPanel
        visible={geoGranted && bottomNavVisible}
        collapsed={quickCollapsed}
        onToggleCollapse={() => setQuickCollapsed((c) => !c)}
        onRoute={qaRoute}
      />

      {bottomNavVisible && (
        <FiltersPanel
          filters={filters}
          onToggle={(key) => {
            const show = !filters[key];
            setFilters((current) => ({ ...current, [key]: show }));
            setVehicleTypeDisplay(key, show);
          }}
          ambientEnabled={ambientEnabled}
          onAmbientToggle={() => setAmbientEnabled((current) => !current)}
        />
      )}

      <GeoPrompt
        promptVisible={geoPromptVisible}
        notice={geoNotice}
        onAllow={onGeoAllow}
        onDeny={onGeoDeny}
      />

      <BottomNav
        visible={bottomNavVisible}
        onSearch={() => setMobileSearchOpen(true)}
        onRoute={qaRoute}
        onCorrespondances={qaCorrespondances}
      />

      {showCorrespondances && (
        <CorrespondancesPanel
          stops={nearbyStopCorrespondances}
          locating={!geoPosition}
          onSelect={handleCorrespondanceSelect}
          onClose={() => setShowCorrespondances(false)}
        />
      )}

      {routeActive && (
        <RoutePanel
          destName={destName}
          duration={routeInfo?.durationMin ?? 0}
          departure={departureStr}
          arrival={arrivalStr}
          steps={routeSteps}
          loading={routeLoading}
          error={routeError}
          mode={routeMode}
          alternatives={routeAlternatives}
          departures={routeDepartures}
          provisionalAlternatives={routeSkeletons}
          selectedAlternativeId={routeInfo?.selectedAlternativeId ?? null}
          preferences={routePreferences}
          advancedAvailable={routeInfo?.engine === "timetable"}
          onModeChange={changeRouteMode}
          onAlternativeChange={selectRouteAlternative}
          onDepartureChange={selectRouteAlternative}
          onTrackVehicle={startScheduledPassageTracking}
          onPreferencesChange={changeRoutePreferences}
          onClose={closeRoute}
        />
      )}

      {visibleDetail && (
        <DetailPanel selected={visibleDetail} onClose={closeSelection} />
      )}

      {selectedStop && (
        <StopSchedulePanel
          key={selectedStop.id}
          stop={selectedStop}
          initialLine={
            scheduleReturn && scheduleReturn.stopId === selectedStop.id
              ? {
                  line: scheduleReturn.line,
                  direction: scheduleReturn.direction,
                  lineColor: scheduleReturn.lineColor,
                }
              : null
          }
          initialDate={
            scheduleReturn && scheduleReturn.stopId === selectedStop.id
              ? scheduleReturn.serviceDate
              : undefined
          }
          onTrackPassage={startScheduledPassageTracking}
          onClose={() => {
            selectedStopMarkerRef.current?.remove();
            selectedStopMarkerRef.current = null;
            setSelectedStop(null);
            setScheduleReturn(null);
          }}
        />
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

    </div>
  );
}
