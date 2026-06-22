"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import {
  fetchServedRoutesFallback,
  linesFromServedRoutes,
  mergeStopLines,
} from "@/lib/station-routes";
import type { StationDetail, StationStopItem, ServedRouteBadge } from "@/lib/stations-types";
import type { StopDeparture, StopServingLine } from "@/lib/stops-types";
import type { NetworkIncident } from "@/lib/types";

function buildRoutesMap(rows: Record<string, unknown>[] | null): Map<string, ServedRouteBadge[]> {
  const routesMap = new Map<string, ServedRouteBadge[]>();
  for (const row of rows ?? []) {
    const sid = row.stop_id as string;
    const list = routesMap.get(sid) ?? [];
    if (!list.some((route) => route.route_id === row.route_id)) {
      list.push({
        route_id: row.route_id as string,
        route_short_name: row.route_short_name as string | null,
        route_color: row.route_color as string | null,
      });
    }
    routesMap.set(sid, list);
  }
  return routesMap;
}

function totalRouteCount(routesMap: Map<string, ServedRouteBadge[]>): number {
  return [...routesMap.values()].reduce((count, routes) => count + routes.length, 0);
}

export function useStationDetail(stationId: string | null) {
  const [detail, setDetail] = useState<StationDetail | null>(null);
  const [stopRoutes, setStopRoutes] = useState<Map<string, ServedRouteBadge[]>>(new Map());
  const [stopLines, setStopLines] = useState<Map<string, StopServingLine[]>>(new Map());
  const [stopDepartures, setStopDepartures] = useState<Map<string, StopDeparture[]>>(new Map());
  const [incidents, setIncidents] = useState<NetworkIncident[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadDetail = useCallback(async () => {
    if (!stationId) {
      setDetail(null);
      return;
    }
    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { data, error: rpcError } = await supabase.rpc("get_station_detail", {
      p_station_id: stationId,
      p_audience: "staff",
    });
    if (rpcError || !data) {
      setError(rpcError?.message ?? "Station introuvable");
      setDetail(null);
      setLoading(false);
      return;
    }
    const parsed = data as StationDetail;
    setDetail(parsed);
    setLoading(false);

    const stopIds = parsed.stops.map((s) => s.id);
    if (!stopIds.length) return;

    const { data: routes, error: routesError } = await supabase.rpc("get_stops_served_routes", {
      p_stop_ids: stopIds,
    });

    let routesMap = buildRoutesMap((routes as Record<string, unknown>[] | null) ?? null);
    if (routesError || totalRouteCount(routesMap) === 0) {
      routesMap = await fetchServedRoutesFallback(supabase, stopIds);
    }
    setStopRoutes(routesMap);

    const linesMap = new Map<string, StopServingLine[]>();
    const depMap = new Map<string, StopDeparture[]>();
    await Promise.all(
      stopIds.map(async (sid) => {
        const [{ data: lines }, { data: deps }] = await Promise.all([
          supabase.rpc("get_stop_serving_lines", { p_stop_id: sid }),
          supabase.rpc("get_stop_departures", { p_stop_id: sid, p_limit: 8 }),
        ]);
        if (lines?.length) linesMap.set(sid, lines as StopServingLine[]);
        if (deps?.length) depMap.set(sid, deps as StopDeparture[]);
      }),
    );

    const needsLineFallback = stopIds.some((sid) => !linesMap.get(sid)?.length);
    const mergedLines =
      needsLineFallback && totalRouteCount(routesMap) > 0
        ? mergeStopLines(linesMap, await linesFromServedRoutes(supabase, routesMap))
        : linesMap;

    setStopLines(mergedLines);
    setStopDepartures(depMap);

    const codes = parsed.stops.map((s) => s.code);
    const { data: incData } = await supabase
      .from("network_incidents")
      .select("*")
      .in("status", ["open", "monitoring"])
      .order("created_at", { ascending: false })
      .limit(50);
    const filtered = (incData ?? []).filter((inc) => {
      const meta = (inc as { metadata?: { stop_code?: string } }).metadata;
      return meta?.stop_code && codes.includes(meta.stop_code);
    });
    setIncidents(filtered as NetworkIncident[]);
  }, [stationId]);

  useEffect(() => {
    void loadDetail();
  }, [loadDetail]);

  const stopsWithRoutes = useMemo<StationStopItem[]>(
    () =>
      detail?.stops.map((s) => ({
        ...s,
        served_routes: stopRoutes.get(s.id) ?? [],
      })) ?? [],
    [detail, stopRoutes],
  );

  const enrichedDetail = useMemo<StationDetail | null>(
    () => (detail ? { ...detail, stops: stopsWithRoutes } : null),
    [detail, stopsWithRoutes],
  );

  return {
    detail: enrichedDetail,
    stopLines,
    stopDepartures,
    incidents,
    loading,
    error,
    refresh: loadDetail,
  };
}
