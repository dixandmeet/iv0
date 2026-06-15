"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { MsrMission } from "@/lib/types";

export function useMissionsData() {
  const [missions, setMissions] = useState<MsrMission[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const loadData = useCallback(async () => {
    const supabase = createClient();
    setError(null);

    const { data, error: fetchError } = await supabase
      .from("msr_missions")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(50);

    if (fetchError) {
      setError(fetchError.message);
    } else if (data) {
      setMissions(data as MsrMission[]);
      setLastUpdated(new Date());
    }

    setLoading(false);
  }, []);

  useEffect(() => {
    loadData();
    const supabase = createClient();

    const channel = supabase
      .channel("dashboard-missions")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "msr_missions" },
        () => loadData(),
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [loadData]);

  return { missions, loading, error, lastUpdated, refresh: loadData };
}
