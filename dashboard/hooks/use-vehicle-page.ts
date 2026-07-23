"use client";

import { useMemo } from "react";
import { useOperationsData } from "@/hooks/use-operations-data";
import { useDriversData } from "@/hooks/use-drivers-data";
import { useGtfsData } from "@/hooks/use-gtfs-data";
import { useRouteTimeline } from "@/hooks/use-route-timeline";
import { useLineFleetTracking } from "@/hooks/use-line-fleet-tracking";
import { buildDepotRegulationLines } from "@/lib/regulation-depot";
import { buildRegulationLines, enrichLineWithTimeline } from "@/lib/regulation-data";
import { gtfsRouteIdFromLineId } from "@/lib/depot-lines";
import { getDepotLineByCompositeId } from "@/lib/depot-lines";
import type { RegulationLine } from "@/lib/regulation-mock-data";
import type { LiveFleetPosition } from "@/lib/types";
import { travelerCommentsForVehicle } from "@/lib/traveler-comments";
import {
  buildStaticDemoFleetPosition,
  fleetPositionFromRegulationVehicle,
} from "@/lib/vehicle-position";
import { resolveLineIdFromShortName } from "@/lib/vehicle-routes";

interface UseVehiclePageOptions {
  vehicleId: string;
  lineShortName: string | null;
  service: string | null;
  isDemo: boolean;
  delayMin: number;
}

function minimalRegulationLine(lineId: string, shortName: string): RegulationLine {
  const depotLine = getDepotLineByCompositeId(lineId);
  return {
    id: lineId,
    shortName,
    origin: depotLine?.origin ?? "—",
    destination: depotLine?.destination ?? "—",
    status: "normal",
    vehicleCount: 1,
    avgDelay: 0,
    incidentCount: 0,
    transportType: "bus",
    depotCode: lineId.includes(":") ? lineId.split(":")[0] : "",
    routeId: gtfsRouteIdFromLineId(lineId),
    stopCount: 0,
    maxVehicles: 1,
    punctuality: 100,
    firstDeparture: "—",
    lastDeparture: "—",
    stops: [],
    segmentQuality: [],
    vehicles: [],
    lineColor: depotLine?.lineColor ?? "#22C55E",
  };
}

export function useVehiclePage({
  vehicleId,
  lineShortName,
  service,
  isDemo,
  delayMin,
}: UseVehiclePageOptions) {
  const { fleet, incidents, loading, error, lastUpdated, refresh } = useOperationsData();
  const { drivers } = useDriversData();
  const { routes, loading: gtfsLoading } = useGtfsData();

  const liveVehicle = useMemo(
    () => fleet.find((vehicle) => vehicle.id === vehicleId) ?? null,
    [fleet, vehicleId],
  );

  const lineId = useMemo(
    () => (lineShortName ? resolveLineIdFromShortName(lineShortName, routes) : null),
    [lineShortName, routes],
  );

  const gtfsRouteId = lineId ? gtfsRouteIdFromLineId(lineId) : lineShortName;

  const fleetOnRoute = useMemo(() => {
    if (liveVehicle) return [liveVehicle];
    if (!gtfsRouteId) return [];
    return fleet.filter((vehicle) => vehicle.route_id === gtfsRouteId);
  }, [fleet, liveVehicle, gtfsRouteId]);

  const { topology, timelineStops, loading: timelineLoading, error: timelineError } = useRouteTimeline({
    routeId: lineId,
    preferredTripId: liveVehicle?.trip_id,
    enabled: !!lineId,
  });

  const baseLine = useMemo((): RegulationLine | null => {
    if (!lineId || !lineShortName) return null;

    const schemaLines = buildDepotRegulationLines(fleet, incidents);
    const fromSchema = schemaLines.find((line) => line.id === lineId);
    if (fromSchema) return fromSchema;

    if (routes.length > 0) {
      const gtfsLines = buildRegulationLines(routes, fleet, incidents);
      const fromGtfs = gtfsLines.find((line) => line.id === lineId);
      if (fromGtfs) return fromGtfs;
    }

    return minimalRegulationLine(lineId, lineShortName);
  }, [lineId, lineShortName, fleet, incidents, routes]);

  const displayLine = useMemo((): RegulationLine | null => {
    if (!baseLine) return null;
    if (timelineStops.length < 2) return baseLine;
    return enrichLineWithTimeline(baseLine, timelineStops, fleetOnRoute);
  }, [baseLine, timelineStops, fleetOnRoute]);

  const stopCount = displayLine?.stops.length ?? 0;

  const { vehicles: trackedVehicles, isLive } = useLineFleetTracking(
    fleetOnRoute,
    timelineStops,
    lineShortName ?? "—",
    stopCount,
    vehicleId,
    isDemo,
  );

  const trackedVehicle = useMemo(
    () =>
      trackedVehicles.find((vehicle) => vehicle.id === vehicleId) ??
      trackedVehicles[0] ??
      null,
    [trackedVehicles, vehicleId],
  );

  const mapVehicle = useMemo((): LiveFleetPosition | null => {
    if (liveVehicle) return liveVehicle;

    if (trackedVehicle && timelineStops.length >= 2 && gtfsRouteId) {
      return fleetPositionFromRegulationVehicle(
        trackedVehicle,
        timelineStops,
        gtfsRouteId,
        buildStaticDemoFleetPosition(vehicleId, gtfsRouteId, delayMin),
      );
    }

    if (isDemo && lineShortName) {
      return buildStaticDemoFleetPosition(vehicleId, lineShortName, delayMin);
    }

    return null;
  }, [
    liveVehicle,
    trackedVehicle,
    timelineStops,
    gtfsRouteId,
    vehicleId,
    delayMin,
    isDemo,
    lineShortName,
  ]);

  const driver = useMemo(
    () =>
      mapVehicle?.driver_session_id
        ? drivers.find((session) => session.id === mapVehicle.driver_session_id) ?? null
        : null,
    [drivers, mapVehicle],
  );

  const comments = useMemo(() => {
    if (!lineShortName) return [];
    const vehicleService = service ?? trackedVehicle?.service ?? vehicleId;
    const stopName = displayLine?.stops[trackedVehicle?.segmentIndex ?? 0]?.name;
    const currentDelay = trackedVehicle?.currentDelay ?? delayMin;
    return travelerCommentsForVehicle(
      lineShortName,
      vehicleService,
      stopName,
      currentDelay,
    );
  }, [lineShortName, service, trackedVehicle, vehicleId, displayLine, delayMin]);

  const pageLoading = (loading || gtfsLoading) && !mapVehicle;
  const pageError = error ?? timelineError;

  return {
    mapVehicle,
    displayLine,
    topology,
    timelineStops,
    fleetOnRoute,
    trackedVehicle,
    trackedDelay: trackedVehicle?.currentDelay ?? delayMin,
    driver,
    comments,
    incidents,
    isLive: isLive || !!liveVehicle,
    isDemo: !isLive && !liveVehicle && isDemo,
    loading: pageLoading,
    timelineLoading,
    error: pageError,
    lastUpdated,
    refresh,
    serviceLabel: service ?? trackedVehicle?.service ?? vehicleId,
    lineShortName,
  };
}
