import type { LiveFleetPosition } from "@/lib/types";
import type { RegulationVehicle } from "@/lib/regulation-mock-data";
import type { RouteTimelinePoint } from "@/lib/regulation-data";
import {
  coordsFromLineProgress,
  headingFromLineProgress,
  lineProgressFromSegment,
} from "@/lib/regulation-fleet-tracking";

export function fleetPositionFromRegulationVehicle(
  vehicle: RegulationVehicle,
  timelineStops: RouteTimelinePoint[],
  routeId: string,
  base?: Partial<LiveFleetPosition>,
): LiveFleetPosition {
  const lineProgress = lineProgressFromSegment(
    vehicle.segmentIndex,
    vehicle.segmentProgress,
    timelineStops.length,
  );
  const coords =
    coordsFromLineProgress(timelineStops, lineProgress) ??
    base?.geom?.coordinates ??
    ([-1.5534, 47.2184] as [number, number]);
  const heading = headingFromLineProgress(timelineStops, lineProgress);

  return {
    id: vehicle.id,
    route_id: routeId,
    trip_id: base?.trip_id ?? null,
    transport_type: base?.transport_type ?? "bus",
    geom: { type: "Point", coordinates: coords },
    speed: base?.speed ?? 18,
    heading: base?.heading ?? heading,
    source: base?.source ?? "operator",
    source_confidence: base?.source_confidence ?? 80,
    reliability_score: base?.reliability_score ?? 75,
    freshness_seconds: base?.freshness_seconds ?? 5,
    coherence_score: base?.coherence_score ?? 85,
    last_seen_at: new Date().toISOString(),
    estimated_delay_seconds: vehicle.currentDelay * 60,
    driver_session_id: base?.driver_session_id,
    community_vehicle_id: base?.community_vehicle_id,
    active_user_count: base?.active_user_count,
  };
}

export function buildStaticDemoFleetPosition(
  vehicleId: string,
  routeId: string,
  delayMin: number,
): LiveFleetPosition {
  return {
    id: vehicleId,
    route_id: routeId,
    trip_id: null,
    transport_type: "bus",
    geom: { type: "Point", coordinates: [-1.5534, 47.2184] },
    speed: 18,
    heading: 90,
    source: "operator",
    source_confidence: 80,
    reliability_score: 75,
    freshness_seconds: 12,
    coherence_score: 85,
    last_seen_at: new Date().toISOString(),
    estimated_delay_seconds: delayMin * 60,
  };
}
