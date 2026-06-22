import type { RegulationVehicle } from "@/lib/regulation-mock-data";
import {
  buildVehicleDelays,
  buildVehiclesFromFleet,
  type RouteTimelinePoint,
} from "@/lib/regulation-data";
import { haversineMeters } from "@/lib/stops-utils";

export { buildVehiclesFromFleet };

export function lineProgressFromSegment(
  segmentIndex: number,
  segmentProgress: number,
  stopCount: number,
): number {
  if (stopCount <= 1) return 0;
  const linear = segmentIndex + segmentProgress;
  return Math.min(Math.max(linear / (stopCount - 1), 0), 1);
}

export function segmentFromLineProgress(
  lineProgress: number,
  stopCount: number,
): { segmentIndex: number; segmentProgress: number } {
  if (stopCount <= 1) return { segmentIndex: 0, segmentProgress: 0 };
  const linear = Math.min(Math.max(lineProgress, 0), 1) * (stopCount - 1);
  const segmentIndex = Math.min(Math.floor(linear), stopCount - 2);
  return { segmentIndex, segmentProgress: linear - segmentIndex };
}

export function coordsFromLineProgress(
  timelineStops: RouteTimelinePoint[],
  lineProgress: number,
): [number, number] | null {
  if (timelineStops.length < 2) return null;
  const { segmentIndex, segmentProgress } = segmentFromLineProgress(
    lineProgress,
    timelineStops.length,
  );
  const a = timelineStops[segmentIndex]?.coordinates;
  const b = timelineStops[segmentIndex + 1]?.coordinates;
  if (!a || !b) return null;
  return [
    a[0] + (b[0] - a[0]) * segmentProgress,
    a[1] + (b[1] - a[1]) * segmentProgress,
  ];
}

export function headingFromLineProgress(
  timelineStops: RouteTimelinePoint[],
  lineProgress: number,
): number {
  if (timelineStops.length < 2) return 0;
  const { segmentIndex } = segmentFromLineProgress(lineProgress, timelineStops.length);
  const a = timelineStops[segmentIndex]?.coordinates;
  const b = timelineStops[segmentIndex + 1]?.coordinates;
  if (!a || !b) return 0;
  const dx = b[0] - a[0];
  const dy = b[1] - a[1];
  return (Math.atan2(dx, dy) * 180) / Math.PI;
}

export function computeRouteLengthMeters(stops: RouteTimelinePoint[]): number {
  if (stops.length < 2) return 1;
  let total = 0;
  for (let i = 0; i < stops.length - 1; i++) {
    total += haversineMeters(stops[i].coordinates, stops[i + 1].coordinates);
  }
  return Math.max(total, 1);
}

export function regulationVehicleFromLineProgress(state: {
  fleetId: string;
  service: string;
  lineProgress: number;
  currentDelay: number;
  stopCount: number;
}): RegulationVehicle {
  const { segmentIndex, segmentProgress } = segmentFromLineProgress(
    state.lineProgress,
    state.stopCount,
  );
  const roundedDelay = Math.round(state.currentDelay);

  return {
    id: state.fleetId,
    service: state.service,
    currentDelay: roundedDelay,
    delays: buildVehicleDelays(state.stopCount, segmentIndex, roundedDelay),
    segmentIndex,
    segmentProgress,
  };
}

/** Vitesse par défaut pour l'animation de démo (~18 km/h). */
export const DEMO_VEHICLE_SPEED_MS = 5;
