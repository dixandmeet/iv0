import { pointCoordinates } from "@/lib/geo";
import { computePunctualityRate } from "@/lib/alerts";
import type {
  GtfsRoute,
  GtfsStop,
  LiveFleetPosition,
  NetworkIncident,
} from "@/lib/types";
import type {
  LineStatus,
  RegulationLine,
  RegulationStop,
  RegulationVehicle,
} from "@/lib/regulation-mock-data";
import {
  getDepotLinesForRoute,
  isDepotRoute,
  makeLineId,
} from "@/lib/depot-lines";
import { depotLineStopCount } from "@/lib/depot-types";

export interface RouteTimelinePoint {
  stopId: string;
  stationId?: string;
  name: string;
  coordinates: [number, number];
  theoreticalTime: string;
  isTerminus?: boolean;
}

const NEAR_STOP_METERS = 350;

export function getTimelineMinWidth(stopCount: number, stopColumnPx = 72): number {
  return 72 + stopCount * stopColumnPx;
}

function hasValidCoords(coords: [number, number]): boolean {
  return coords[0] !== 0 || coords[1] !== 0;
}

/** Complète les coordonnées manquantes pour conserver tous les arrêts du schéma */
export function interpolateTimelineCoordinates(
  points: RouteTimelinePoint[],
): RouteTimelinePoint[] {
  if (points.length === 0) return points;

  const result = points.map((p) => ({
    ...p,
    coordinates: [...p.coordinates] as [number, number],
  }));

  const first = result.findIndex((p) => hasValidCoords(p.coordinates));
  if (first === -1) {
    const baseLng = -1.55;
    const baseLat = 47.21;
    const step = 0.004;
    return result.map((p, i) => ({
      ...p,
      coordinates: [baseLng + i * step, baseLat] as [number, number],
    }));
  }

  let last = result.length - 1;
  while (last >= 0 && !hasValidCoords(result[last].coordinates)) last -= 1;

  for (let i = 0; i < first; i++) {
    const t = (first - i) / (first + 1);
    result[i].coordinates = [
      result[first].coordinates[0] - t * 0.012,
      result[first].coordinates[1],
    ];
  }

  let prev = first;
  for (let i = first + 1; i <= last; i++) {
    if (!hasValidCoords(result[i].coordinates)) continue;
    for (let j = prev + 1; j < i; j++) {
      const t = (j - prev) / (i - prev);
      result[j].coordinates = [
        result[prev].coordinates[0] +
          t * (result[i].coordinates[0] - result[prev].coordinates[0]),
        result[prev].coordinates[1] +
          t * (result[i].coordinates[1] - result[prev].coordinates[1]),
      ];
    }
    prev = i;
  }

  for (let i = last + 1; i < result.length; i++) {
    const t = (i - last) / Math.max(result.length - last, 1);
    result[i].coordinates = [
      result[last].coordinates[0] + t * 0.012,
      result[last].coordinates[1],
    ];
  }

  return result;
}

function haversineMeters(a: [number, number], b: [number, number]): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const [lng1, lat1] = a;
  const [lng2, lat2] = b;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}

function parseRouteTerminals(longName: string | null): { origin: string; destination: string } {
  if (!longName) return { origin: "—", destination: "—" };
  const parts = longName.split(/\s[-–/]\s|\s\/\s/);
  if (parts.length >= 2) {
    return { origin: parts[0].trim(), destination: parts[parts.length - 1].trim() };
  }
  return { origin: longName.trim(), destination: longName.trim() };
}

function routeTypeLabel(routeType: number): string {
  if (routeType === 0) return "Tramway";
  if (routeType === 2) return "Train";
  if (routeType === 4) return "Navibus";
  return "Bus";
}

export function isTramRoute(route: GtfsRoute): boolean {
  if (route.route_type === 0) return true;
  const label = `${route.route_short_name ?? ""} ${route.route_long_name ?? ""}`.toLowerCase();
  return label.includes("tram");
}

export function isNavibusRoute(route: GtfsRoute): boolean {
  if (route.route_type === 4) return true;
  const label = `${route.route_short_name ?? ""} ${route.route_long_name ?? ""}`.toLowerCase();
  return label.includes("navibus") || label.includes("bateau") || label.includes("ferry");
}

function networkDepotCode(route: GtfsRoute): "NETWORK" | "TRAM" | "NAV" {
  if (isNavibusRoute(route)) return "NAV";
  if (isTramRoute(route)) return "TRAM";
  return "NETWORK";
}

function sortRegulationLines(lines: RegulationLine[]): RegulationLine[] {
  return [...lines].sort((a, b) => {
    if (b.vehicleCount !== a.vehicleCount) return b.vehicleCount - a.vehicleCount;
    if (a.depotCode !== b.depotCode) return a.depotCode.localeCompare(b.depotCode);
    return a.shortName.localeCompare(b.shortName, "fr", { numeric: true });
  });
}

function buildLineFromRoute(
  route: GtfsRoute,
  fleetByRoute: Map<string, LiveFleetPosition[]>,
  incidentsByRoute: Map<string, number>,
  overrides: Partial<RegulationLine> & Pick<RegulationLine, "id" | "depotCode" | "routeId">,
): RegulationLine {
  const vehicles = fleetByRoute.get(route.route_id) ?? [];
  const parsed = parseRouteTerminals(route.route_long_name);
  const delays = vehicles.map((v) => delayMinutes(v.estimated_delay_seconds));
  const avgDelay =
    delays.length > 0
      ? Math.round(delays.reduce((a, b) => a + b, 0) / delays.length)
      : 0;
  const incidentCount = incidentsByRoute.get(route.route_id) ?? 0;
  const punctuality = vehicles.length > 0 ? computePunctualityRate(vehicles) : 100;

  return {
    shortName: route.route_short_name ?? route.route_id,
    origin: overrides.origin ?? parsed.origin,
    destination: overrides.destination ?? parsed.destination,
    status: computeLineStatus(avgDelay, incidentCount, vehicles),
    vehicleCount: vehicles.length,
    avgDelay,
    incidentCount,
    transportType: routeTypeLabel(route.route_type),
    stopCount: overrides.stopCount ?? 0,
    maxVehicles: Math.max(vehicles.length, 1),
    punctuality,
    firstDeparture: "—",
    lastDeparture: "—",
    stops: [],
    segmentQuality: [],
    vehicles: [],
    lineColor: overrides.lineColor ?? lineColorFromRoute(route),
    ...overrides,
  };
}

function lineColorFromRoute(route: GtfsRoute): string {
  if (route.route_color) return `#${route.route_color.replace("#", "")}`;
  if (route.route_type === 0) return "#22C55E";
  return "#2563EB";
}

function delayMinutes(delaySeconds: number | null | undefined): number {
  return Math.round((delaySeconds ?? 0) / 60);
}

function qualityFromDelayMinutes(minutes: number): "on-time" | "light-delay" | "major-delay" {
  if (minutes <= 0) return "on-time";
  if (minutes <= 4) return "light-delay";
  return "major-delay";
}

function computeLineStatus(
  avgDelayMin: number,
  incidentCount: number,
  vehicles: LiveFleetPosition[],
): LineStatus {
  const hasCriticalIncident = incidentCount > 0 && avgDelayMin >= 10;
  const criticalVehicles = vehicles.filter(
    (v) => (v.estimated_delay_seconds ?? 0) >= 600,
  ).length;
  if (criticalVehicles > 0 || hasCriticalIncident || avgDelayMin >= 10) return "critique";
  if (avgDelayMin >= 2 || incidentCount > 0) return "perturbe";
  return "normal";
}

function formatIntervalTime(value: unknown): string {
  if (typeof value !== "string") return "—";
  const match = value.match(/(\d{1,2}):(\d{2})/);
  if (!match) return "—";
  return `${match[1].padStart(2, "0")}:${match[2]}`;
}

export function buildStopsFromShape(
  shapeCoords: [number, number][],
  allStops: GtfsStop[],
): RouteTimelinePoint[] {
  if (shapeCoords.length < 2) return [];

  const candidates: Array<RouteTimelinePoint & { distanceAlong: number }> = [];

  for (const stop of allStops) {
    const coords = pointCoordinates(stop.geom);
    if (!coords) continue;

    let bestDist = Infinity;
    let bestAlong = 0;
    let cumulative = 0;

    for (let i = 0; i < shapeCoords.length - 1; i++) {
      const a = shapeCoords[i];
      const b = shapeCoords[i + 1];
      const segLen = haversineMeters(a, b);
      const { segmentProgress } = projectOnPolyline([a, b], coords);
      const along = cumulative + segmentProgress * segLen;
      const projPoint: [number, number] = [
        a[0] + (b[0] - a[0]) * segmentProgress,
        a[1] + (b[1] - a[1]) * segmentProgress,
      ];
      const dist = haversineMeters(coords, projPoint);

      if (dist < bestDist) {
        bestDist = dist;
        bestAlong = along;
      }
      cumulative += segLen;
    }

    if (bestDist <= NEAR_STOP_METERS) {
      candidates.push({
        stopId: stop.stop_id,
        stationId: stop.station_id,
        name: stop.stop_name,
        coordinates: coords,
        theoreticalTime: "—",
        distanceAlong: bestAlong,
      });
    }
  }

  const seen = new Set<string>();
  const ordered = candidates
    .sort((a, b) => a.distanceAlong - b.distanceAlong)
    .filter((stop) => {
      const key = stop.name.replace(/\d+$/, "").trim();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .map(({ distanceAlong: _d, ...stop }) => stop);

  if (ordered.length >= 2) {
    ordered[0].isTerminus = true;
    ordered[ordered.length - 1].isTerminus = true;
  }

  return ordered;
}

export function projectVehicleOnTimeline(
  timelineStops: RouteTimelinePoint[],
  vehicleCoords: [number, number],
): { segmentIndex: number; segmentProgress: number } {
  const geoIndices = timelineStops
    .map((stop, index) => (hasValidCoords(stop.coordinates) ? index : -1))
    .filter((index) => index >= 0);

  if (geoIndices.length < 2) {
    return { segmentIndex: 0, segmentProgress: 0 };
  }

  const polyline = geoIndices.map((index) => timelineStops[index].coordinates);
  const proj = projectOnPolyline(polyline, vehicleCoords);
  const i0 = geoIndices[proj.segmentIndex];
  const i1 = geoIndices[Math.min(proj.segmentIndex + 1, geoIndices.length - 1)];
  const fullIndex = i0 + proj.segmentProgress * Math.max(i1 - i0, 1);

  return {
    segmentIndex: Math.min(Math.floor(fullIndex), timelineStops.length - 2),
    segmentProgress: fullIndex - Math.floor(fullIndex),
  };
}

export function projectOnPolyline(
  polyline: [number, number][],
  point: [number, number],
): { segmentIndex: number; segmentProgress: number } {
  if (polyline.length < 2) return { segmentIndex: 0, segmentProgress: 0 };

  let bestSegment = 0;
  let bestProgress = 0;
  let bestDist = Infinity;

  for (let i = 0; i < polyline.length - 1; i++) {
    const a = polyline[i];
    const b = polyline[i + 1];
    const ax = a[0];
    const ay = a[1];
    const bx = b[0];
    const by = b[1];
    const px = point[0];
    const py = point[1];
    const dx = bx - ax;
    const dy = by - ay;
    const lenSq = dx * dx + dy * dy;
    let t = lenSq > 0 ? ((px - ax) * dx + (py - ay) * dy) / lenSq : 0;
    t = Math.max(0, Math.min(1, t));
    const proj: [number, number] = [ax + t * dx, ay + t * dy];
    const dist = haversineMeters(point, proj);

    if (dist < bestDist) {
      bestDist = dist;
      bestSegment = i;
      bestProgress = t;
    }
  }

  return { segmentIndex: bestSegment, segmentProgress: bestProgress };
}

export function buildVehicleDelays(
  stopCount: number,
  segmentIndex: number,
  delayMin: number,
): number[] {
  if (stopCount <= 0) return [];
  if (stopCount === 1) return [delayMin];

  return Array.from({ length: stopCount }, (_, i) => {
    if (i < segmentIndex) {
      return Math.max(-2, delayMin - (segmentIndex - i));
    }
    if (i === segmentIndex) return delayMin;
    return Math.min(delayMin + (i - segmentIndex), delayMin + 4);
  });
}

function buildSegmentQuality(
  vehicles: RegulationVehicle[],
  segmentCount: number,
): Array<"on-time" | "light-delay" | "major-delay"> {
  if (segmentCount <= 0) return [];
  return Array.from({ length: segmentCount }, (_, seg) => {
    const delays = vehicles
      .map((v) => v.delays[Math.min(seg, v.delays.length - 1)] ?? 0)
      .filter((d) => d !== undefined);
    if (delays.length === 0) return "on-time";
    const avg = delays.reduce((a, b) => a + b, 0) / delays.length;
    return qualityFromDelayMinutes(Math.round(avg));
  });
}

export function buildRegulationLines(
  routes: GtfsRoute[],
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

  const lines: RegulationLine[] = [];

  for (const route of routes) {
    const depot = isDepotRoute(route.route_id);
    const tram = isTramRoute(route);
    const navibus = isNavibusRoute(route);

    if (depot) {
      for (const depotLine of getDepotLinesForRoute(route.route_id)) {
        lines.push(
          buildLineFromRoute(route, fleetByRoute, incidentsByRoute, {
            id: makeLineId(depotLine.depotCode, route.route_id),
            routeId: route.route_id,
            depotCode: depotLine.depotCode,
            origin: depotLine.origin,
            destination: depotLine.destination,
            stopCount: depotLineStopCount(depotLine),
            lineColor: depotLine.lineColor ?? lineColorFromRoute(route),
          }),
        );
      }
      continue;
    }

    const networkCode = networkDepotCode(route);
    lines.push(
      buildLineFromRoute(route, fleetByRoute, incidentsByRoute, {
        id: makeLineId(networkCode, route.route_id),
        routeId: route.route_id,
        depotCode: networkCode,
        transportType: navibus ? "Navibus" : tram ? "Tramway" : routeTypeLabel(route.route_type),
      }),
    );
  }

  return sortRegulationLines(lines);
}

export function formatVehicleService(
  lineShortName: string,
  tripId: string | null | undefined,
  fallbackIndex: number,
): string {
  if (tripId) {
    const suffix = tripId.match(/(\d+)\s*$/);
    if (suffix) {
      return `${lineShortName}-${parseInt(suffix[1], 10)}`;
    }
  }
  return `${lineShortName}-${fallbackIndex + 1}`;
}

export function buildVehiclesFromFleet(
  fleet: LiveFleetPosition[],
  timelineStops: RouteTimelinePoint[],
  lineShortName: string,
): RegulationVehicle[] {
  const displayStops = interpolateTimelineCoordinates(timelineStops);
  const stopCount = displayStops.length;
  if (stopCount < 2) return [];

  const sortedFleet = [...fleet].sort((a, b) => a.id.localeCompare(b.id));

  return sortedFleet.map((vehicle, index) => {
    const coords = pointCoordinates(vehicle.geom);
    const delayMin = delayMinutes(vehicle.estimated_delay_seconds);
    const position =
      coords && displayStops.length >= 2
        ? projectVehicleOnTimeline(displayStops, coords)
        : {
            segmentIndex: Math.min(index, Math.max(displayStops.length - 2, 0)),
            segmentProgress: 0.3 + (index % 5) * 0.1,
          };

    const segmentIndex = Math.min(
      position.segmentIndex,
      Math.max(stopCount - 2, 0),
    );

    return {
      id: vehicle.id,
      service: formatVehicleService(lineShortName, vehicle.trip_id, index),
      currentDelay: delayMin,
      delays: buildVehicleDelays(stopCount, segmentIndex, delayMin),
      segmentIndex,
      segmentProgress: position.segmentProgress,
    };
  });
}

export function enrichLineWithTimeline(
  line: RegulationLine,
  timelineStops: RouteTimelinePoint[],
  fleetOnRoute: LiveFleetPosition[],
): RegulationLine {
  const displayStops = interpolateTimelineCoordinates(timelineStops);

  const regulationStops: RegulationStop[] = displayStops.map((s) => ({
    stopId: s.stopId,
    stationId: s.stationId,
    name: s.name,
    theoreticalTime: s.theoreticalTime,
    isTerminus: s.isTerminus,
    unavailable: false,
  }));

  const sortedFleet = [...fleetOnRoute].sort((a, b) =>
    a.id.localeCompare(b.id),
  );

  const vehicles: RegulationVehicle[] = buildVehiclesFromFleet(
    sortedFleet,
    timelineStops,
    line.shortName,
  );

  const segmentCount = Math.max(regulationStops.length - 1, 0);

  return {
    ...line,
    stopCount: timelineStops.length,
    maxVehicles: Math.max(line.maxVehicles, fleetOnRoute.length),
    stops: regulationStops,
    vehicles,
    segmentQuality: buildSegmentQuality(vehicles, segmentCount),
    firstDeparture: timelineStops[0]?.theoreticalTime ?? "—",
    lastDeparture: timelineStops[timelineStops.length - 1]?.theoreticalTime ?? "—",
  };
}

export function mapStopTimesToTimeline(
  rows: Array<{
    stop_sequence: number;
    arrival_time: unknown;
    stop_id: string;
    stop:
      | { code: string; name: string; geom: unknown; stationId?: string }
      | null;
  }>,
): RouteTimelinePoint[] {
  type PointWithSequence = RouteTimelinePoint & { stopSequence: number };

  const points = rows
    .map((row): PointWithSequence | null => {
      const stopRow = row.stop;
      const coords = pointCoordinates(stopRow?.geom);
      if (!coords || !stopRow) return null;
      return {
        stopId: row.stop_id,
        stationId: stopRow.stationId,
        name: stopRow.name,
        coordinates: coords,
        theoreticalTime: formatIntervalTime(row.arrival_time),
        stopSequence: row.stop_sequence,
      };
    })
    .filter((p): p is PointWithSequence => p !== null)
    .sort((a, b) => a.stopSequence - b.stopSequence);

  if (points.length >= 2) {
    points[0].isTerminus = true;
    points[points.length - 1].isTerminus = true;
  }

  return points.map(({ stopSequence: _s, ...point }) => point);
}

export function formatKpiNumber(value: number): string {
  return new Intl.NumberFormat("fr-FR").format(value);
}

/** Véhicules fictifs pour prévisualiser la frise sans flotte en direct. */
export function buildDemoVehicles(
  stopCount: number,
  lineShortName = "—",
): RegulationVehicle[] {
  if (stopCount < 2) return [];

  const samples = [
    { segmentIndex: 1, segmentProgress: 0.35, delay: 0 },
    { segmentIndex: 4, segmentProgress: 0.6, delay: 3 },
    { segmentIndex: 7, segmentProgress: 0.25, delay: -1 },
    { segmentIndex: 10, segmentProgress: 0.55, delay: 6 },
  ];

  return samples
    .filter((s) => s.segmentIndex < stopCount - 1)
    .map((sample, index) => {
      const segmentIndex = Math.min(sample.segmentIndex, stopCount - 2);
      return {
        id: `${lineShortName}-${String(index + 1).padStart(2, "0")}`,
        service: `${lineShortName}-${index + 1}`,
        currentDelay: sample.delay,
        delays: buildVehicleDelays(stopCount, segmentIndex, sample.delay),
        segmentIndex,
        segmentProgress: sample.segmentProgress,
      };
    });
}
