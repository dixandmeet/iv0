"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { LiveFleetPosition, NetworkIncident } from "@/lib/types";

export function useOperationsData() {
  const [fleet, setFleet] = useState<LiveFleetPosition[]>([]);
  const [incidents, setIncidents] = useState<NetworkIncident[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const loadData = useCallback(async () => {
    const supabase = createClient();
    setError(null);

    const { error: rpcError } = await supabase.rpc("refresh_live_fleet_positions");
    if (rpcError && !rpcError.message.includes("does not exist")) {
      // Ignorer si la RPC n'est pas déployée
    }

    const [fleetRes, incidentsRes] = await Promise.all([
      supabase
        .from("live_fleet_positions")
        .select("*")
        .order("reliability_score", { ascending: false }),
      supabase
        .from("network_incidents")
        .select("*")
        .in("status", ["open", "acknowledged", "in_progress"])
        .order("created_at", { ascending: false })
        .limit(20),
    ]);

    const errors: string[] = [];
    if (fleetRes.error) errors.push(fleetRes.error.message);
    if (incidentsRes.error) errors.push(incidentsRes.error.message);

    if (errors.length > 0) {
      setError(errors.join(" · "));
    } else {
      if (fleetRes.data) setFleet(fleetRes.data as LiveFleetPosition[]);
      if (incidentsRes.data) setIncidents(incidentsRes.data as NetworkIncident[]);
      setLastUpdated(new Date());
    }

    setLoading(false);
  }, []);

  useEffect(() => {
    loadData();
    const supabase = createClient();

    const fleetChannel = supabase
      .channel("dashboard-fleet")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "live_fleet_positions" },
        () => loadData(),
      )
      .subscribe();

    const incidentsChannel = supabase
      .channel("dashboard-incidents")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "network_incidents" },
        () => loadData(),
      )
      .subscribe();

    const poll = setInterval(loadData, 5000);

    return () => {
      clearInterval(poll);
      supabase.removeChannel(fleetChannel);
      supabase.removeChannel(incidentsChannel);
    };
  }, [loadData]);

  return { fleet, incidents, loading, error, lastUpdated, refresh: loadData };
}
