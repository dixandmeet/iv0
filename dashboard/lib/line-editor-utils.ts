import { NANTES_CENTER } from "@/lib/landing-map-style";
import type {
  EditorTransportMode,
  LineEditorState,
  LineVoice,
  PointType,
  RoutePoint,
  StopDetails,
} from "@/lib/line-editor-types";
import { POINT_TYPE_LABELS } from "@/lib/line-editor-types";

const EARTH_RADIUS_KM = 6371;

export function haversineKm(
  a: [number, number],
  b: [number, number],
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const [lng1, lat1] = a;
  const [lng2, lat2] = b;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(x));
}

export function segmentDistanceKm(points: RoutePoint[]): number {
  let total = 0;
  for (let i = 1; i < points.length; i++) {
    total += haversineKm(points[i - 1].coordinates, points[i].coordinates);
  }
  return total;
}

export function formatDistance(km: number): string {
  if (km < 1) return `${Math.round(km * 1000)} m`;
  return `${km.toFixed(1)} km`;
}

export function countStops(points: RoutePoint[]): number {
  return points.filter(
    (p) =>
      p.type === "stop" ||
      p.type === "terminus_start" ||
      p.type === "terminus_end" ||
      p.type === "hub",
  ).length;
}

export function estimatedTravelMinutes(points: RoutePoint[]): number {
  const stopPoints = points.filter((p) => p.stop);
  const fromStops = stopPoints.reduce(
    (sum, p) => sum + (p.stop?.travelTimeMinutes ?? 0),
    0,
  );
  if (fromStops > 0) return fromStops;
  const km = segmentDistanceKm(points);
  return Math.round((km / 25) * 60);
}

export function bearingDegrees(
  from: [number, number],
  to: [number, number],
): number {
  const [lng1, lat1] = from;
  const [lng2, lat2] = to;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const lat1r = (lat1 * Math.PI) / 180;
  const lat2r = (lat2 * Math.PI) / 180;
  const y = Math.sin(dLng) * Math.cos(lat2r);
  const x =
    Math.cos(lat1r) * Math.sin(lat2r) -
    Math.sin(lat1r) * Math.cos(lat2r) * Math.cos(dLng);
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

export function interpolateCoordinates(
  a: [number, number],
  b: [number, number],
  t = 0.5,
): [number, number] {
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
}

export function distancePointToSegmentKm(
  point: [number, number],
  start: [number, number],
  end: [number, number],
): number {
  const [px, py] = point;
  const [ax, ay] = start;
  const [bx, by] = end;
  const dx = bx - ax;
  const dy = by - ay;
  const lenSq = dx * dx + dy * dy;

  if (lenSq === 0) return haversineKm(point, start);

  let t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
  t = Math.max(0, Math.min(1, t));
  const projection = interpolateCoordinates(start, end, t);
  return haversineKm(point, projection);
}

/** Index où insérer un nouveau point le long du tracé (0 = début, length = fin). */
export function findSegmentInsertIndex(
  points: RoutePoint[],
  coordinates: [number, number],
): number {
  if (points.length === 0) return 0;
  if (points.length === 1) return 1;

  let bestIndex = points.length;
  let bestDistance = Infinity;

  for (let i = 0; i < points.length - 1; i++) {
    const distance = distancePointToSegmentKm(
      coordinates,
      points[i].coordinates,
      points[i + 1].coordinates,
    );
    if (distance < bestDistance) {
      bestDistance = distance;
      bestIndex = i + 1;
    }
  }

  return bestIndex;
}

export function createPointId(): string {
  return `pt-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
}

function defaultStopDetails(order: number): StopDetails {
  return {
    name: "",
    code: "",
    address: "",
    direction: "both",
    order,
    travelTimeMinutes: 3,
    wheelchairAccessible: false,
    connections: "",
    notes: "",
  };
}

export function createRoutePoint(
  coordinates: [number, number],
  type: PointType = "passage",
  order = 1,
): RoutePoint {
  const point: RoutePoint = {
    id: createPointId(),
    coordinates,
    type,
  };
  if (type !== "passage") {
    point.stop = defaultStopDetails(order);
  } else {
    point.gps = {
      name: "",
      radiusMeters: 15,
      estimatedMinutes: 1,
      notes: "",
    };
  }
  return point;
}

export function getVoicePoints(
  state: Pick<LineEditorState, "activeVoice" | "pointsAller" | "pointsRetour">,
  voice?: LineVoice,
): RoutePoint[] {
  return (voice ?? state.activeVoice) === "aller"
    ? state.pointsAller
    : state.pointsRetour;
}

export function setVoicePoints(
  state: LineEditorState,
  points: RoutePoint[],
  voice?: LineVoice,
): LineEditorState {
  const target = voice ?? state.activeVoice;
  return target === "aller"
    ? { ...state, pointsAller: points }
    : { ...state, pointsRetour: points };
}

export function updateVoicePoints(
  state: LineEditorState,
  updater: (points: RoutePoint[]) => RoutePoint[],
  voice?: LineVoice,
): LineEditorState {
  return setVoicePoints(state, updater(getVoicePoints(state, voice)), voice);
}

function flipPointTypeForRetour(type: PointType): PointType {
  if (type === "terminus_start") return "terminus_end";
  if (type === "terminus_end") return "terminus_start";
  return type;
}

export function createRetourPointsFromAller(pointsAller: RoutePoint[]): RoutePoint[] {
  if (pointsAller.length === 0) return [];

  const reversed = [...pointsAller].reverse();
  return reorderStopsInPoints(
    reversed.map((point) => {
      const next: RoutePoint = {
        id: createPointId(),
        coordinates: [...point.coordinates],
        type: flipPointTypeForRetour(point.type),
      };

      if (point.stop) {
        next.stop = { ...point.stop };
      }

      return next;
    }),
  );
}

export function normalizeLineEditorState(
  state: Partial<LineEditorState> & { points?: RoutePoint[] },
): LineEditorState {
  const { points: legacyPoints, ...rest } = state;
  const pointsAller = rest.pointsAller ?? legacyPoints ?? [];
  const pointsRetour = rest.pointsRetour ?? [];

  return {
    id: rest.id ?? `editor-${Date.now()}`,
    name: rest.name ?? "Nouvelle ligne",
    shortName: rest.shortName ?? "N",
    color: rest.color ?? "#3B82F6",
    transportMode: rest.transportMode ?? "bus",
    directionAller: rest.directionAller ?? "",
    directionRetour: rest.directionRetour ?? "",
    status: rest.status ?? "draft",
    pointsAller,
    pointsRetour,
    branchesAller: rest.branchesAller ?? [],
    branchesRetour: rest.branchesRetour ?? [],
    originLegsAller: rest.originLegsAller ?? [],
    originLegsRetour: rest.originLegsRetour ?? [],
    activeBranchId: rest.activeBranchId ?? null,
    activeOriginLegId: rest.activeOriginLegId ?? null,
    activeVoice: rest.activeVoice ?? "aller",
    selectedPointId:
      rest.selectedPointId ?? pointsAller[0]?.id ?? pointsRetour[0]?.id ?? null,
  };
}

export function createEmptyLineEditorState(
  overrides?: Partial<LineEditorState>,
): LineEditorState {
  return normalizeLineEditorState({
    id: `editor-${Date.now()}`,
    name: "Nouvelle ligne",
    shortName: "N",
    color: "#3B82F6",
    transportMode: "bus",
    directionAller: "",
    directionRetour: "",
    status: "draft",
    pointsAller: [],
    pointsRetour: [],
    branchesAller: [],
    branchesRetour: [],
    originLegsAller: [],
    originLegsRetour: [],
    activeBranchId: null,
    activeOriginLegId: null,
    activeVoice: "aller",
    selectedPointId: null,
    ...overrides,
  });
}

export function createDemoLineEditorState(): LineEditorState {
  const baseLng = NANTES_CENTER[0];
  const baseLat = NANTES_CENTER[1];
  const offsets: Array<[number, number]> = [
    [0, 0],
    [0.012, 0.004],
    [0.022, 0.001],
    [0.035, -0.003],
    [0.048, -0.006],
  ];

  const points: RoutePoint[] = offsets.map(([dLng, dLat], i) => {
    const coords: [number, number] = [baseLng + dLng, baseLat + dLat];
    if (i === 0) {
      return {
        id: createPointId(),
        coordinates: coords,
        type: "terminus_start" as const,
        stop: {
          name: "Commerce",
          code: "COM01",
          address: "",
          direction: "both",
          order: 1,
          travelTimeMinutes: 0,
          wheelchairAccessible: true,
          connections: "Tram 1, Tram 2, Bus C3",
          notes: "",
        },
      };
    }
    if (i === offsets.length - 1) {
      return {
        id: createPointId(),
        coordinates: coords,
        type: "terminus_end" as const,
        stop: {
          name: "Gare Nord",
          code: "GN01",
          address: "",
          direction: "both",
          order: 5,
          travelTimeMinutes: 4,
          wheelchairAccessible: true,
          connections: "TER, Bus C4",
          notes: "Accès PMR côté nord",
        },
      };
    }
    if (i === 2) {
      return {
        id: createPointId(),
        coordinates: coords,
        type: "hub" as const,
        stop: {
          name: "Talensac",
          code: "TAL02",
          address: "",
          direction: "both",
          order: 3,
          travelTimeMinutes: 3,
          wheelchairAccessible: true,
          connections: "Bus 10, Bus 12",
          notes: "",
        },
      };
    }
    return {
      id: createPointId(),
      coordinates: coords,
      type: i === 1 ? ("stop" as const) : ("passage" as const),
      ...(i === 1
        ? {
            stop: {
              name: "Bouffay",
              code: "BOU03",
              address: "",
              direction: "aller",
              order: 2,
              travelTimeMinutes: 2,
              wheelchairAccessible: false,
              connections: "",
              notes: "",
            },
          }
        : {}),
    };
  });

  return createEmptyLineEditorState({
    name: "Ligne C4",
    shortName: "C4",
    color: "#8B5CF6",
    transportMode: "bus",
    directionAller: "Commerce → Gare Nord",
    directionRetour: "Gare Nord → Commerce",
    status: "draft",
    pointsAller: points,
    pointsRetour: createRetourPointsFromAller(points),
    activeVoice: "aller",
    selectedPointId: points[0]?.id ?? null,
  });
}

export function isStopType(type: PointType): boolean {
  return type !== "passage";
}

export function reorderStopsInPoints(points: RoutePoint[]): RoutePoint[] {
  let order = 1;
  return points.map((p) => {
    if (!isStopType(p.type) || !p.stop) return p;
    const next = { ...p, stop: { ...p.stop, order } };
    order += 1;
    return next;
  });
}

function interpolateCoords(
  a: [number, number],
  b: [number, number],
  t = 0.5,
): [number, number] {
  return interpolateCoordinates(a, b, t);
}

function offsetCoords(
  coords: [number, number],
  dLng: number,
  dLat: number,
): [number, number] {
  return [coords[0] + dLng, coords[1] + dLat];
}

/**
 * Place un nouvel arrêt sur le segment suivant, sans l'envoyer au milieu d'un
 * long tracé. On avance au maximum de 120 m, ou jusqu'au milieu du segment si
 * le prochain point de passage est très proche.
 */
function nearbyCoordinateOnRoute(
  from: [number, number],
  to: [number, number],
): [number, number] {
  const distanceKm = haversineKm(from, to);
  if (distanceKm < 0.001) {
    return offsetCoords(from, 0.00015, -0.0001);
  }
  const fraction = Math.min(0.5, 0.12 / distanceKm);
  return interpolateCoords(from, to, fraction);
}

export function coordinatesForNewStop(
  points: RoutePoint[],
  stopInsertIndex: number,
): [number, number] {
  const stops = points.filter((p) => isStopType(p.type));

  if (stops.length === 0) {
    return [...NANTES_CENTER];
  }

  if (stopInsertIndex <= 0) {
    const first = stops[0];
    const firstRouteIdx = points.findIndex((p) => p.id === first.id);
    if (firstRouteIdx > 0) {
      return nearbyCoordinateOnRoute(
        points[firstRouteIdx - 1].coordinates,
        first.coordinates,
      );
    }
    return offsetCoords(first.coordinates, -0.0012, 0.0006);
  }

  if (stopInsertIndex >= stops.length) {
    const last = stops[stops.length - 1];
    const lastRouteIdx = points.findIndex((p) => p.id === last.id);
    if (lastRouteIdx < points.length - 1) {
      return nearbyCoordinateOnRoute(
        last.coordinates,
        points[lastRouteIdx + 1].coordinates,
      );
    }
    return offsetCoords(last.coordinates, 0.0012, -0.0006);
  }

  const prevStop = stops[stopInsertIndex - 1];
  const prevRouteIdx = points.findIndex((p) => p.id === prevStop.id);
  const nextRoutePoint = points[prevRouteIdx + 1] ?? stops[stopInsertIndex];

  return nearbyCoordinateOnRoute(prevStop.coordinates, nextRoutePoint.coordinates);
}

export function insertStopInPoints(
  points: RoutePoint[],
  stopInsertIndex: number,
  newStop: RoutePoint,
): RoutePoint[] {
  const stops = points.filter((p) => isStopType(p.type));

  if (stops.length === 0) {
    return reorderStopsInPoints([newStop]);
  }

  if (stopInsertIndex <= 0) {
    const firstIdx = points.findIndex((p) => p.id === stops[0].id);
    const next = [...points];
    next.splice(firstIdx, 0, newStop);
    return reorderStopsInPoints(next);
  }

  if (stopInsertIndex >= stops.length) {
    const lastIdx = points.findIndex((p) => p.id === stops[stops.length - 1].id);
    const next = [...points];
    next.splice(lastIdx + 1, 0, newStop);
    return reorderStopsInPoints(next);
  }

  // L'arrêt prend immédiatement place après l'arrêt précédent dans le tableau
  // du tracé. Il reste donc avant le premier point de passage du segment (par
  // exemple avant le point 85), au lieu d'être ajouté juste avant le terminus.
  const previousStop = stops[stopInsertIndex - 1];
  const previousIdx = points.findIndex((p) => p.id === previousStop.id);
  const next = [...points];
  next.splice(previousIdx + 1, 0, newStop);
  return reorderStopsInPoints(next);
}

export function lineEditorFromRegulationLine(
  line: {
    id: string;
    shortName: string;
    origin: string;
    destination: string;
    lineColor: string;
    transportType: string;
    stops: Array<{ name: string; isTerminus?: boolean }>;
  },
): LineEditorState {
  const baseLng = NANTES_CENTER[0];
  const baseLat = NANTES_CENTER[1];
  const count = Math.max(line.stops.length, 2);

  const points: RoutePoint[] = line.stops.map((stop, i) => {
    const t = i / (count - 1 || 1);
    const coords: [number, number] = [
      baseLng + t * 0.04 - 0.01,
      baseLat + Math.sin(t * Math.PI) * 0.008,
    ];
    const isFirst = i === 0;
    const isLast = i === line.stops.length - 1;
    const type: PointType = isFirst
      ? "terminus_start"
      : isLast
        ? "terminus_end"
        : "stop";

    return {
      id: createPointId(),
      coordinates: coords,
      type,
      stop: {
        name: stop.name,
        code: "",
        address: "",
        direction: "both",
        order: i + 1,
        travelTimeMinutes: i === 0 ? 0 : 3,
        wheelchairAccessible: false,
        connections: "",
        notes: "",
      },
    };
  });

  const mode: EditorTransportMode = line.transportType
    .toLowerCase()
    .includes("tram")
    ? "tram"
    : line.transportType.toLowerCase().includes("nav")
      ? "boat"
      : "bus";

  return createEmptyLineEditorState({
    id: line.id,
    name: `Ligne ${line.shortName}`,
    shortName: line.shortName,
    color: line.lineColor,
    transportMode: mode,
    directionAller: `${line.origin} → ${line.destination}`,
    directionRetour: `${line.destination} → ${line.origin}`,
    status: "draft",
    pointsAller: points,
    pointsRetour: createRetourPointsFromAller(points),
    activeVoice: "aller",
    selectedPointId: points[0]?.id ?? null,
  });
}

export function pointRouteLabel(
  point: RoutePoint,
  allPoints: RoutePoint[],
): string {
  if (isStopType(point.type) && point.stop?.name?.trim()) {
    return point.stop.name.trim();
  }
  if (point.type === "passage") {
    const index = allPoints
      .filter((candidate) => candidate.type === "passage")
      .findIndex((candidate) => candidate.id === point.id);
    return `Passage ${index + 1}`;
  }
  return POINT_TYPE_LABELS[point.type];
}

export function pointsAfterInRoute(
  allPoints: RoutePoint[],
  pointId: string,
): RoutePoint[] {
  const index = allPoints.findIndex((point) => point.id === pointId);
  if (index < 0) return [];
  return allPoints.slice(index + 1);
}
