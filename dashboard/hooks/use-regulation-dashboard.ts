"use client";

import { useMemo } from "react";
import { useOperationsData } from "@/hooks/use-operations-data";
import { useDriversData } from "@/hooks/use-drivers-data";
import { useGtfsData } from "@/hooks/use-gtfs-data";
import { useRouteTimeline } from "@/hooks/use-route-timeline";
import { computeOperationalAlerts } from "@/lib/alerts";
import {
  buildRegulationLines,
  enrichLineWithTimeline,
} from "@/lib/regulation-data";
import { buildDepotRegulationLines } from "@/lib/regulation-depot";
import { computePunctualityRate, sumActiveUsers } from "@/lib/alerts";
import type { RegulationLine } from "@/lib/regulation-mock-data";
import { gtfsRouteIdFromLineId } from "@/lib/depot-lines";
import { useNetwork } from "@/components/network/network-provider";
import type { LineEditorState } from "@/lib/line-editor-types";

export function useRegulationDashboard(
  selectedLineId: string | null,
  selectedVariantByLine: Record<string, string> = {},
  editorState: LineEditorState | null = null,
) {
  const { isPilotNetwork } = useNetwork();
  const { fleet, incidents, loading, error, lastUpdated, refresh } =
    useOperationsData();
  const {
    drivers,
    loading: driversLoading,
    error: driversError,
    refresh: refreshDrivers,
  } = useDriversData();
  const { routes, loading: gtfsLoading } = useGtfsData();

  const lines = useMemo(() => {
    // Le catalogue des dépôts est une source de démonstration Naolib. Il ne
    // doit jamais initialiser un réseau créé par un nouvel utilisateur.
    const schemaLines = isPilotNetwork
      ? buildDepotRegulationLines(fleet, incidents)
      : [];

    if (routes.length === 0) {
      return schemaLines;
    }

    const gtfsLines = buildRegulationLines(routes, fleet, incidents);
    const gtfsById = new Map(gtfsLines.map((line) => [line.id, line]));
    const schemaIds = new Set(schemaLines.map((line) => line.id));

    const depotMerged = schemaLines.map((line) => gtfsById.get(line.id) ?? line);
    const networkLines = gtfsLines.filter((line) => !schemaIds.has(line.id));

    return [...depotMerged, ...networkLines].sort((a, b) => {
      if (b.vehicleCount !== a.vehicleCount) return b.vehicleCount - a.vehicleCount;
      if (a.depotCode !== b.depotCode) return a.depotCode.localeCompare(b.depotCode);
      return a.shortName.localeCompare(b.shortName, "fr", { numeric: true });
    });
  }, [routes, fleet, incidents, isPilotNetwork]);

  const effectiveLineId = useMemo(
    () => {
      const requestedRouteId = selectedLineId?.startsWith("network:")
        ? selectedLineId.slice(selectedLineId.lastIndexOf(":") + 1)
        : selectedLineId;
      const requestedLine = selectedLineId
        ? lines.find((line) => line.id === selectedLineId) ??
          lines.find((line) => line.routeId === requestedRouteId)
        : null;

      return requestedLine?.id ??
        lines.find((line) => line.vehicleCount > 0)?.id ??
        lines[0]?.id ??
        null;
    },
    [selectedLineId, lines],
  );

  const preferredTripId = useMemo(() => {
    if (!effectiveLineId) return null;
    const gtfsRouteId = gtfsRouteIdFromLineId(effectiveLineId);
    return fleet.find((v) => v.route_id === gtfsRouteId)?.trip_id ?? null;
  }, [fleet, effectiveLineId]);

  const selectedVariantId = effectiveLineId
    ? selectedVariantByLine[effectiveLineId] ??
      (selectedLineId ? selectedVariantByLine[selectedLineId] : null) ??
      null
    : null;

  const { topology, timelineStops, loading: timelineLoading, error: timelineError } =
    useRouteTimeline({
      routeId: effectiveLineId,
      preferredTripId,
      selectedVariantId,
      editorState,
    });

  const alerts = useMemo(
    () => computeOperationalAlerts(fleet, incidents, drivers),
    [fleet, incidents, drivers],
  );

  const selectedLine = useMemo((): RegulationLine | null => {
    const base =
      lines.find((line) => line.id === effectiveLineId) ??
      lines[0] ??
      null;

    if (!base) return null;

    const gtfsRouteId = base.routeId ?? gtfsRouteIdFromLineId(base.id);
    const fleetOnRoute = fleet.filter((v) => v.route_id === gtfsRouteId);
    if (timelineStops.length < 2) return base;

    return enrichLineWithTimeline(base, timelineStops, fleetOnRoute);
  }, [lines, effectiveLineId, timelineStops, fleet]);

  const fleetOnRoute = useMemo(() => {
    const base =
      lines.find((line) => line.id === effectiveLineId) ??
      lines[0] ??
      null;
    if (!base) return [];
    const gtfsRouteId = base.routeId ?? gtfsRouteIdFromLineId(base.id);
    return fleet.filter((v) => v.route_id === gtfsRouteId);
  }, [lines, effectiveLineId, fleet]);

  const connectedDrivers = drivers.filter(
    (d) => d.status === "active" || d.status === "paused",
  ).length;

  const priorityAlerts = alerts.filter(
    (a) => a.severity === "critical" || a.severity === "warning",
  ).length;

  return {
    lines,
    selectedLine,
    fleet,
    fleetOnRoute,
    topology,
    timelineStops,
    incidents,
    drivers,
    alerts,
    loading: loading || gtfsLoading,
    driversLoading,
    timelineLoading,
    error: error ?? driversError ?? timelineError,
    lastUpdated,
    refresh,
    refreshDrivers,
    kpis: {
      vehicleCount: fleet.length,
      connectedDrivers,
      punctuality: computePunctualityRate(fleet),
      incidentCount: incidents.length,
      alertCount: priorityAlerts,
      activeUsers: sumActiveUsers(fleet),
    },
  };
}
