import type { SupabaseClient } from "@supabase/supabase-js";
import type { ServedRouteBadge } from "@/lib/stations-types";
import type { StopServingLine } from "@/lib/stops-types";

interface StopGtfsRow {
  id: string;
  code: string;
  gtfs_source_id: string | null;
}

export function servingLineFromRoute(
  route: {
    route_id: string;
    route_short_name: string | null;
    route_long_name?: string | null;
    route_type?: number | null;
    route_color: string | null;
  },
): StopServingLine {
  return {
    route_id: route.route_id,
    route_short_name: route.route_short_name,
    route_long_name: route.route_long_name ?? null,
    route_type: route.route_type ?? 3,
    route_color: route.route_color,
    direction_id: null,
    trip_id: "",
    stop_sequence: 0,
    prev_stop_id: null,
    prev_stop_name: null,
    next_stop_id: null,
    next_stop_name: null,
    arrival_time: "",
    time_from_terminus_seconds: null,
  };
}

/** Repli client si le RPC PostgREST cible encore l'ancienne surcharge TEXT[]. */
export async function fetchServedRoutesFallback(
  supabase: SupabaseClient,
  stopIds: string[],
): Promise<Map<string, ServedRouteBadge[]>> {
  const routesMap = new Map<string, ServedRouteBadge[]>();
  if (!stopIds.length) return routesMap;

  const { data: stopRows } = await supabase
    .from("stops")
    .select("id, code, gtfs_source_id")
    .in("id", stopIds);

  for (const stop of (stopRows ?? []) as StopGtfsRow[]) {
    const gtfsStopId = stop.gtfs_source_id?.trim() || stop.code;
    const { data: times } = await supabase
      .from("gtfs_stop_times")
      .select("trip_id")
      .eq("stop_id", gtfsStopId)
      .limit(100);

    if (!times?.length) continue;

    const tripIds = [...new Set(times.map((row) => row.trip_id as string))].slice(0, 50);
    const { data: trips } = await supabase
      .from("gtfs_trips")
      .select("route_id")
      .in("trip_id", tripIds);

    if (!trips?.length) continue;

    const routeIds = [...new Set(trips.map((row) => row.route_id as string))];
    const { data: routeRows } = await supabase
      .from("gtfs_routes")
      .select("route_id, route_short_name, route_color")
      .in("route_id", routeIds);

    const badges: ServedRouteBadge[] = [];
    for (const route of routeRows ?? []) {
      const routeId = route.route_id as string;
      if (badges.some((b) => b.route_id === routeId)) continue;
      badges.push({
        route_id: routeId,
        route_short_name: route.route_short_name as string | null,
        route_color: route.route_color as string | null,
      });
    }

    if (badges.length) routesMap.set(stop.id, badges);
  }

  return routesMap;
}

export async function linesFromServedRoutes(
  supabase: SupabaseClient,
  routesMap: Map<string, ServedRouteBadge[]>,
): Promise<Map<string, StopServingLine[]>> {
  const linesMap = new Map<string, StopServingLine[]>();
  const routeIds = [
    ...new Set([...routesMap.values()].flat().map((route) => route.route_id)),
  ];
  if (!routeIds.length) return linesMap;

  const { data: routeRows } = await supabase
    .from("gtfs_routes")
    .select("route_id, route_short_name, route_long_name, route_type, route_color")
    .in("route_id", routeIds);

  const details = new Map(
    (routeRows ?? []).map((row) => [row.route_id as string, row]),
  );

  for (const [stopId, badges] of routesMap) {
    linesMap.set(
      stopId,
      badges.map((badge) => {
        const detail = details.get(badge.route_id);
        return servingLineFromRoute({
          route_id: badge.route_id,
          route_short_name: badge.route_short_name ?? (detail?.route_short_name as string | null) ?? null,
          route_long_name: (detail?.route_long_name as string | null) ?? null,
          route_type: (detail?.route_type as number | null) ?? null,
          route_color: badge.route_color ?? (detail?.route_color as string | null) ?? null,
        });
      }),
    );
  }

  return linesMap;
}

export function mergeStopLines(
  primary: Map<string, StopServingLine[]>,
  fallback: Map<string, StopServingLine[]>,
): Map<string, StopServingLine[]> {
  const merged = new Map(primary);
  for (const [stopId, lines] of fallback) {
    if (!merged.has(stopId) || merged.get(stopId)?.length === 0) {
      merged.set(stopId, lines);
    }
  }
  return merged;
}
