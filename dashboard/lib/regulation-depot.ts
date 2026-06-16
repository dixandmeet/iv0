import { pointCoordinates } from "@/lib/geo";
import { computePunctualityRate } from "@/lib/alerts";
import type { GtfsStop, LiveFleetPosition, NetworkIncident } from "@/lib/types";
import type { RegulationLine } from "@/lib/regulation-mock-data";
import {
  ALL_DEPOT_LINES,
  getDepotLine,
  makeLineId,
} from "@/lib/depot-lines";
import {
  interpolateTimelineCoordinates,
  type RouteTimelinePoint,
} from "@/lib/regulation-data";

function delayMinutes(delaySeconds: number | null | undefined): number {
  return Math.round((delaySeconds ?? 0) / 60);
}

function computeLineStatus(
  avgDelayMin: number,
  incidentCount: number,
  vehicles: LiveFleetPosition[],
): RegulationLine["status"] {
  const criticalVehicles = vehicles.filter(
    (v) => (v.estimated_delay_seconds ?? 0) >= 600,
  ).length;
  if (criticalVehicles > 0 || (incidentCount > 0 && avgDelayMin >= 10) || avgDelayMin >= 10) {
    return "critique";
  }
  if (avgDelayMin >= 2 || incidentCount > 0) return "perturbe";
  return "normal";
}

export function normalizeStopName(name: string): string {
  return name
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toUpperCase()
    .replace(/[^A-Z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function findGtfsStopByName(name: string, allStops: GtfsStop[]): GtfsStop | null {
  const target = normalizeStopName(name);
  if (!target) return null;

  const aliases: Record<string, string[]> = {
    "MF BELLEVUE": ["MENDES FRANCE", "BELLEVUE", "MF BEL"],
    "RD PT RENNES": ["ROND POINT RENNES", "ROND PT RENNES"],
    "RD PT VANNES": ["ROND POINT VANNES"],
    "RD PT DE PARIS": ["ROND POINT PARIS", "ROND PT PARIS"],
    "JEAN MACE": ["JEAN MAC"],
    "ST JEAN BAPTISTE": ["SAINT JEAN BAPTISTE"],
    "ST NICOLAS": ["SAINT NICOLAS"],
    "ST CLAIR": ["SAINT CLAIR"],
    "ST CLEMENT": ["SAINT CLEMENT"],
    "ST LAURENT": ["SAINT LAURENT"],
    "50 OTAGES": ["CINQUANTE OTAGES"],
    "RP DE RENNES": ["ROND POINT RENNES"],
    "HOTEL DE REGION": ["HOTEL DE VILLE", "HOTEL REGION"],
    "GRENERAIE": ["GRÊNERAIE"],
    "GARE DE L ETAT": ["GARE DE L'ETAT"],
  };

  const candidates = [target, ...(aliases[target] ?? [])];

  for (const stop of allStops) {
    const normalized = normalizeStopName(stop.stop_name);
    if (candidates.some((c) => normalized === c || normalized.includes(c) || c.includes(normalized))) {
      return stop;
    }
  }

  for (const stop of allStops) {
    const normalized = normalizeStopName(stop.stop_name);
    const targetTokens = target.split(" ").filter((t) => t.length > 3);
    const matches = targetTokens.filter((t) => normalized.includes(t)).length;
    if (matches >= Math.max(1, Math.ceil(targetTokens.length * 0.6))) {
      return stop;
    }
  }

  return null;
}

export function resolveDepotStopsToTimeline(
  stopNames: string[],
  allStops: GtfsStop[],
  depotCode: string,
): RouteTimelinePoint[] {
  const points: RouteTimelinePoint[] = [];

  for (let i = 0; i < stopNames.length; i++) {
    const name = stopNames[i];
    const gtfsStop = findGtfsStopByName(name, allStops);
    const coords = gtfsStop ? pointCoordinates(gtfsStop.geom) : null;

    points.push({
      stopId: gtfsStop?.stop_id ?? `${depotCode.toLowerCase()}-${i}`,
      name,
      coordinates: coords ?? [0, 0],
      theoreticalTime: "—",
      isTerminus: i === 0 || i === stopNames.length - 1,
    });
  }

  if (stopNames.length < 2) return [];

  return interpolateTimelineCoordinates(points);
}

/** @deprecated */
export const resolveBeleStopsToTimeline = resolveDepotStopsToTimeline;

export function buildDepotRegulationLines(
  fleet: LiveFleetPosition[],
  incidents: NetworkIncident[],
): RegulationLine[] {
  const fleetByRoute = new Map<string, LiveFleetPosition[]>();
  for (const v of fleet) {
    const list = fleetByRoute.get(v.route_id) ?? [];
    list.push(v);
    fleetByRoute.set(v.route_id, list);
  }

  const incidentsByRoute = new Map<string, number>();
  for (const inc of incidents) {
    if (!inc.route_id) continue;
    incidentsByRoute.set(inc.route_id, (incidentsByRoute.get(inc.route_id) ?? 0) + 1);
  }

  return ALL_DEPOT_LINES.map((depotLine) => {
    const vehicles = fleetByRoute.get(depotLine.id) ?? [];
    const delays = vehicles.map((v) => delayMinutes(v.estimated_delay_seconds));
    const avgDelay =
      delays.length > 0
        ? Math.round(delays.reduce((a, b) => a + b, 0) / delays.length)
        : 0;
    const incidentCount = incidentsByRoute.get(depotLine.id) ?? 0;
    const punctuality = vehicles.length > 0 ? computePunctualityRate(vehicles) : 100;

    return {
      id: makeLineId(depotLine.depotCode, depotLine.id),
      routeId: depotLine.id,
      depotCode: depotLine.depotCode,
      shortName: depotLine.shortName,
      origin: depotLine.origin,
      destination: depotLine.destination,
      status: computeLineStatus(avgDelay, incidentCount, vehicles),
      vehicleCount: vehicles.length,
      avgDelay,
      incidentCount,
      transportType: "Bus",
      stopCount: depotLine.stops.length,
      maxVehicles: Math.max(vehicles.length, 1),
      punctuality,
      firstDeparture: "—",
      lastDeparture: "—",
      stops: [],
      segmentQuality: [],
      vehicles: [],
      lineColor: depotLine.lineColor,
    };
  }).sort((a, b) => {
    if (b.vehicleCount !== a.vehicleCount) return b.vehicleCount - a.vehicleCount;
    if (a.depotCode !== b.depotCode) return a.depotCode.localeCompare(b.depotCode);
    return a.shortName.localeCompare(b.shortName, "fr", { numeric: true });
  });
}

/** @deprecated */
export const buildBeleDepotRegulationLines = buildDepotRegulationLines;

export function buildDepotTimelineFromSchema(
  depotCode: string,
  routeId: string,
  allStops: GtfsStop[],
): RouteTimelinePoint[] {
  const depotLine = getDepotLine(depotCode, routeId);
  if (!depotLine) return [];
  return resolveDepotStopsToTimeline(depotLine.stops, allStops, depotCode);
}

/** @deprecated */
export function buildBeleTimelineFromSchema(
  routeId: string,
  allStops: GtfsStop[],
): RouteTimelinePoint[] {
  return buildDepotTimelineFromSchema("BLX", routeId, allStops);
}
