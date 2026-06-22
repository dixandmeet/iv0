"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { StationListItem } from "@/lib/stations-types";

const MIN_QUERY_LENGTH = 2;
const SUGGESTION_LIMIT = 8;
const DEBOUNCE_MS = 250;

export function useStationSearchSuggestions(query: string) {
  const [suggestions, setSuggestions] = useState<StationListItem[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const trimmed = query.trim();
    if (trimmed.length < MIN_QUERY_LENGTH) {
      setSuggestions([]);
      setLoading(false);
      return;
    }

    let cancelled = false;
    setLoading(true);
    const timer = window.setTimeout(async () => {
      const supabase = createClient();
      const { data, error } = await supabase.rpc("search_stations", {
        p_query: trimmed,
        p_audience: "staff",
        p_limit: SUGGESTION_LIMIT,
      });
      if (cancelled) return;
      if (error || !data) {
        setSuggestions([]);
      } else {
        setSuggestions(
          data.map((row: Record<string, unknown>) => ({
            id: row.id as string,
            network_id: "",
            name: row.name as string,
            commune: (row.commune as string) ?? null,
            status: (row.status as StationListItem["status"]) ?? "active",
            latitude_center: row.latitude_center as number | null,
            longitude_center: row.longitude_center as number | null,
            stop_count: Number(row.stop_count ?? 0),
          })),
        );
      }
      setLoading(false);
    }, DEBOUNCE_MS);

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [query]);

  return { suggestions, loading, hasQuery: query.trim().length >= MIN_QUERY_LENGTH };
}
