import { fetchRoadSegment } from "@/lib/osrm-route";
import {
  createRoutePoint,
  haversineKm,
  reorderStopsInPoints,
} from "@/lib/line-editor-utils";
import type { EditorTransportMode, RoutePoint } from "@/lib/line-editor-types";

const DECIMATE_KM = 0.035;

export function decimateRouteCoords(
  coords: [number, number][],
  minKm = DECIMATE_KM,
): [number, number][] {
  if (coords.length <= 2) return coords;

  const result: [number, number][] = [coords[0]];
  let last = coords[0];

  for (let i = 1; i < coords.length; i++) {
    const coord = coords[i];
    const isLast = i === coords.length - 1;
    if (isLast || haversineKm(last, coord) >= minKm) {
      result.push(coord);
      last = coord;
    }
  }

  return result;
}

function coordsNear(
  a: [number, number],
  b: [number, number],
  epsilon = 1e-6,
): boolean {
  return Math.abs(a[0] - b[0]) < epsilon && Math.abs(a[1] - b[1]) < epsilon;
}

export async function tracePointsOnRoads(
  points: RoutePoint[],
  mode: EditorTransportMode,
  lineId?: string,
  signal?: AbortSignal,
): Promise<RoutePoint[]> {
  if (points.length < 2) return points;
  if (mode === "boat") {
    throw new Error("Le tracé sur voies n'est pas disponible pour le mode bateau");
  }

  const rebuilt: RoutePoint[] = [points[0]];

  for (let i = 1; i < points.length; i++) {
    const from = points[i - 1].coordinates;
    const to = points[i].coordinates;
    const segmentCoords = await fetchRoadSegment(from, to, { mode, lineId, signal });
    const decimated = decimateRouteCoords(
      segmentCoords.length >= 2 ? segmentCoords : [from, to],
    );

    for (let j = 1; j < decimated.length - 1; j++) {
      const coord = decimated[j];
      if (coordsNear(coord, from) || coordsNear(coord, to)) continue;
      rebuilt.push(createRoutePoint(coord, "passage"));
    }

    rebuilt.push(points[i]);
  }

  return reorderStopsInPoints(rebuilt);
}

export async function traceSegmentBetween(
  points: RoutePoint[],
  fromId: string,
  toId: string,
  mode: EditorTransportMode,
  lineId?: string,
  signal?: AbortSignal,
): Promise<RoutePoint[]> {
  if (fromId === toId) {
    throw new Error("Choisissez un point de destination différent");
  }

  const fromIdx = points.findIndex((point) => point.id === fromId);
  const toIdx = points.findIndex((point) => point.id === toId);

  if (fromIdx < 0 || toIdx < 0) {
    throw new Error("Point introuvable sur la ligne");
  }
  if (fromIdx >= toIdx) {
    throw new Error(
      "La destination doit être située après le point de départ sur la ligne",
    );
  }

  if (mode === "boat") {
    throw new Error("Le tracé sur voies n'est pas disponible pour le mode bateau");
  }

  const from = points[fromIdx];
  const to = points[toIdx];
  const segmentCoords = await fetchRoadSegment(
    from.coordinates,
    to.coordinates,
    { mode, lineId, signal },
  );
  const decimated = decimateRouteCoords(
    segmentCoords.length >= 2
      ? segmentCoords
      : [from.coordinates, to.coordinates],
  );

  const segment: RoutePoint[] = [from];
  for (let j = 1; j < decimated.length - 1; j++) {
    const coord = decimated[j];
    if (coordsNear(coord, from.coordinates) || coordsNear(coord, to.coordinates)) {
      continue;
    }
    segment.push(createRoutePoint(coord, "passage"));
  }
  segment.push(to);

  return reorderStopsInPoints([
    ...points.slice(0, fromIdx),
    ...segment,
    ...points.slice(toIdx + 1),
  ]);
}
