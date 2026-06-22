"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type {
  DepotOption,
  DriverRegistrationRequest,
  RegisteredDriver,
} from "@/lib/drivers-types";

export function useDriversManagement() {
  const [requests, setRequests] = useState<DriverRegistrationRequest[]>([]);
  const [roster, setRoster] = useState<RegisteredDriver[]>([]);
  const [depots, setDepots] = useState<DepotOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    const supabase = createClient();
    setError(null);

    const [requestsRes, rosterRes, depotsRes] = await Promise.all([
      supabase.rpc("list_pending_driver_requests"),
      supabase.rpc("list_registered_drivers"),
      supabase.from("depots").select("id, code, name").order("name"),
    ]);

    if (requestsRes.error) {
      setError(requestsRes.error.message);
    } else {
      setRequests((requestsRes.data ?? []) as DriverRegistrationRequest[]);
    }

    if (rosterRes.error && !requestsRes.error) {
      setError(rosterRes.error.message);
    } else if (!rosterRes.error) {
      setRoster((rosterRes.data ?? []) as RegisteredDriver[]);
    }

    if (!depotsRes.error && depotsRes.data) {
      setDepots(depotsRes.data as DepotOption[]);
    }

    setLoading(false);
  }, []);

  useEffect(() => {
    loadData();
    const supabase = createClient();
    const channel = supabase
      .channel("drivers-management")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "driver_registration_requests" },
        () => loadData(),
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "user_profiles" },
        () => loadData(),
      )
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [loadData]);

  return {
    requests,
    roster,
    depots,
    loading,
    error,
    refresh: loadData,
    pendingCount: requests.length,
  };
}
