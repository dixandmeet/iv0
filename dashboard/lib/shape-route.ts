import { projectOnPolyline } from "@/lib/regulation-data";
import { haversineKm } from "@/lib/line-editor-utils";

const MAX_SNAP_METERS = 180;

function haversineMeters(a: [number, number], b: [number, number]): number {
  return haversineKm(a, b) * 1000;
}

function closestOnPolyline(
  polyline: [number, number][],
  point: [number, number],
): {
  distanceAlong: number;
  closestPoint: [number, number];
  snapMeters: number;
} {
  const { segmentIndex, segmentProgress } = projectOnPolyline(polyline, point);
  const a = polyline[segmentIndex];
  const b = polyline[segmentIndex + 1] ?? a;
  const closestPoint: [number, number] = [
    a[0] + (b[0] - a[0]) * segmentProgress,
    a[1] + (b[1] - a[1]) * segmentProgress,
  ];

  let distanceAlong = 0;
  for (let i = 0; i < segmentIndex; i++) {
    distanceAlong += haversineMeters(polyline[i], polyline[i + 1]);
  }
  distanceAlong += haversineMeters(a, closestPoint);

  return {
    distanceAlong,
    closestPoint,
    snapMeters: haversineMeters(point, closestPoint),
  };
}

function buildSegmentBetweenDistances(
  polyline: [number, number][],
  startDist: number,
  endDist: number,
  startPoint: [number, number],
  endPoint: [number, number],
): [number, number][] {
  const result: [number, number][] = [startPoint];
  let cumulative = 0;

  for (let i = 0; i < polyline.length; i++) {
    if (i > 0) {
      cumulative += haversineMeters(polyline[i - 1], polyline[i]);
    }
    if (cumulative > startDist && cumulative < endDist) {
      const vertex = polyline[i];
      if (!coordsEqual(result[result.length - 1], vertex)) {
        result.push(vertex);
      }
    }
  }

  if (!coordsEqual(result[result.length - 1], endPoint)) {
    result.push(endPoint);
  }

  return result;
}

function coordsEqual(
  a: [number, number],
  b: [number, number],
  epsilon = 1e-7,
): boolean {
  return Math.abs(a[0] - b[0]) < epsilon && Math.abs(a[1] - b[1]) < epsilon;
}

function tryExtractOnPolyline(
  polyline: [number, number][],
  from: [number, number],
  to: [number, number],
): [number, number][] | null {
  const fromProj = closestOnPolyline(polyline, from);
  const toProj = closestOnPolyline(polyline, to);

  if (
    fromProj.snapMeters > MAX_SNAP_METERS ||
    toProj.snapMeters > MAX_SNAP_METERS
  ) {
    return null;
  }

  if (Math.abs(fromProj.distanceAlong - toProj.distanceAlong) < 1) {
    return [fromProj.closestPoint, toProj.closestPoint];
  }

  if (fromProj.distanceAlong < toProj.distanceAlong) {
    return buildSegmentBetweenDistances(
      polyline,
      fromProj.distanceAlong,
      toProj.distanceAlong,
      fromProj.closestPoint,
      toProj.closestPoint,
    );
  }

  const reversed = [...polyline].reverse();
  const fromRev = closestOnPolyline(reversed, from);
  const toRev = closestOnPolyline(reversed, to);

  if (
    fromRev.snapMeters > MAX_SNAP_METERS ||
    toRev.snapMeters > MAX_SNAP_METERS ||
    fromRev.distanceAlong >= toRev.distanceAlong
  ) {
    return null;
  }

  return buildSegmentBetweenDistances(
    reversed,
    fromRev.distanceAlong,
    toRev.distanceAlong,
    fromRev.closestPoint,
    toRev.closestPoint,
  );
}

/** Extrait le tronçon le plus pertinent le long d'un réseau de tracés GTFS. */
export function routeAlongShapes(
  shapes: [number, number][][],
  from: [number, number],
  to: [number, number],
): [number, number][] | null {
  let best: [number, number][] | null = null;
  let bestScore = Infinity;

  for (const shape of shapes) {
    if (shape.length < 2) continue;
    const segment = tryExtractOnPolyline(shape, from, to);
    if (!segment || segment.length < 2) continue;

    const fromProj = closestOnPolyline(shape, from);
    const toProj = closestOnPolyline(shape, to);
    const score = fromProj.snapMeters + toProj.snapMeters;
    if (score < bestScore) {
      bestScore = score;
      best = segment;
    }
  }

  return best;
}
