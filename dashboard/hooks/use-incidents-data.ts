"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { NetworkIncident } from "@/lib/types";
import { useNetwork } from "@/components/network/network-provider";

export type IncidentStatusFilter =
  | "open"
  | "acknowledged"
  | "in_progress"
  | "resolved"
  | "closed"
  | "all";

export type IncidentSeverityFilter = "info" | "warning" | "critical" | "all";

interface UseIncidentsDataOptions {
  statusFilter?: IncidentStatusFilter;
  severityFilter?: IncidentSeverityFilter;
}

export function useIncidentsData(options: UseIncidentsDataOptions = {}) {
  const { network, isPilotNetwork, schemaReady } = useNetwork();
  const { statusFilter = "all", severityFilter = "all" } = options;
  const [incidents, setIncidents] = useState<NetworkIncident[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const loadData = useCallback(async () => {
    const supabase = createClient();
    setError(null);

    if (!schemaReady && !isPilotNetwork) {
      setIncidents([]);
      setLastUpdated(new Date());
      setLoading(false);
      return;
    }

    let query = supabase
      .from("network_incidents")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(100);

    if (schemaReady) query = query.eq("network_id", network.id);

    if (statusFilter !== "all") {
      query = query.eq("status", statusFilter);
    } else {
      query = query.in("status", [
        "open",
        "acknowledged",
        "in_progress",
        "resolved",
        "closed",
      ]);
    }

    if (severityFilter !== "all") {
      query = query.eq("severity", severityFilter);
    }

    const { data, error: fetchError } = await query;

    if (fetchError) {
      setError(fetchError.message);
    } else if (data) {
      setIncidents(data as NetworkIncident[]);
      setLastUpdated(new Date());
    }

    setLoading(false);
  }, [statusFilter, severityFilter, isPilotNetwork, network.id, schemaReady]);

  useEffect(() => {
    setLoading(true);
    loadData();
    const supabase = createClient();

    const channel = supabase
      .channel("incidents-page")
      .on(
        "postgres_changes",
        schemaReady
          ? { event: "*", schema: "public", table: "network_incidents", filter: `network_id=eq.${network.id}` }
          : { event: "*", schema: "public", table: "network_incidents" },
        () => loadData(),
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [loadData, network.id, schemaReady]);

  return { incidents, loading, error, lastUpdated, refresh: loadData };
}
