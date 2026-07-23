"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { GtfsRoute } from "@/lib/types";
import { useNetwork } from "@/components/network/network-provider";

export function useGtfsData() {
  const { isPilotNetwork } = useNetwork();
  const [routes, setRoutes] = useState<GtfsRoute[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    if (!isPilotNetwork) {
      setRoutes([]);
      setLoading(false);
      setError(null);
      return;
    }
    const supabase = createClient();
    setError(null);

    const { data, error: routesError } = await supabase
      .from("gtfs_routes")
      .select("route_id, route_short_name, route_long_name, route_type, route_color")
      .order("route_short_name");

    if (routesError) {
      setError(routesError.message);
    } else if (data) {
      setRoutes(data as GtfsRoute[]);
    }
    setLoading(false);
  }, [isPilotNetwork]);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  return { routes, loading, error, refresh: loadData };
}
