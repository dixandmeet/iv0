"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { DriverSession } from "@/lib/types";
import { isRelationshipError } from "@/lib/supabase-errors";
import { useNetwork } from "@/components/network/network-provider";

export function useDriversData() {
  const { network, isPilotNetwork, schemaReady } = useNetwork();
  const [drivers, setDrivers] = useState<DriverSession[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const loadData = useCallback(async () => {
    const supabase = createClient();
    setError(null);

    if (!schemaReady && !isPilotNetwork) {
      setDrivers([]);
      setLastUpdated(new Date());
      setLoading(false);
      return;
    }

    let primaryQuery = supabase
      .from("driver_sessions")
      .select("*, driver:user_profiles(display_name, role)")
      .in("status", ["detecting", "active", "paused"])
      .order("started_at", { ascending: false })
      .limit(50);
    if (schemaReady) primaryQuery = primaryQuery.eq("network_id", network.id);
    let result = await primaryQuery;

    if (result.error && isRelationshipError(result.error.message)) {
      let fallbackQuery = supabase
        .from("driver_sessions")
        .select("*")
        .in("status", ["detecting", "active", "paused"])
        .order("started_at", { ascending: false })
        .limit(50);
      if (schemaReady) fallbackQuery = fallbackQuery.eq("network_id", network.id);
      result = await fallbackQuery;
    }

    if (result.error) {
      setError(result.error.message);
    } else if (result.data) {
      setDrivers(result.data as DriverSession[]);
      setLastUpdated(new Date());
    }
    setLoading(false);
  }, [isPilotNetwork, network.id, schemaReady]);

  useEffect(() => {
    loadData();
    const supabase = createClient();
    const channel = supabase
      .channel("drivers-page")
      .on(
        "postgres_changes",
        schemaReady
          ? { event: "*", schema: "public", table: "driver_sessions", filter: `network_id=eq.${network.id}` }
          : { event: "*", schema: "public", table: "driver_sessions" },
        () => loadData(),
      )
      .subscribe();
    const poll = setInterval(loadData, 15000);
    return () => {
      clearInterval(poll);
      void supabase.removeChannel(channel);
    };
  }, [loadData]);

  return { drivers, loading, error, lastUpdated, refresh: loadData };
}
