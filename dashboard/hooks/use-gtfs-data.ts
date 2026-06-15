"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { GtfsRoute, GtfsStop } from "@/lib/types";

export function useGtfsData() {
  const [routes, setRoutes] = useState<GtfsRoute[]>([]);
  const [stops, setStops] = useState<GtfsStop[]>([]);
  const [loading, setLoading] = useState(true);

  const loadData = useCallback(async () => {
    const supabase = createClient();

    const [routesRes, stopsRes] = await Promise.all([
      supabase
        .from("gtfs_routes")
        .select("route_id, route_short_name, route_long_name, route_type, route_color")
        .order("route_short_name"),
      supabase
        .from("gtfs_stops")
        .select("stop_id, stop_name, geom")
        .limit(500),
    ]);

    if (routesRes.data) setRoutes(routesRes.data as GtfsRoute[]);
    if (stopsRes.data) setStops(stopsRes.data as GtfsStop[]);
    setLoading(false);
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  return { routes, stops, loading, refresh: loadData };
}
