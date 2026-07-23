"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { StationListItem } from "@/lib/stations-types";
import { useNetwork } from "@/components/network/network-provider";

const MIN_QUERY_LENGTH = 2;
const SUGGESTION_LIMIT = 8;
const DEBOUNCE_MS = 250;

export function useStationSearchSuggestions(query: string) {
  const { network } = useNetwork();
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
      const { data, error } = await supabase
        .from("stations")
        .select("id, network_id, name, commune, status, latitude_center, longitude_center, stops(id)")
        .eq("network_id", network.id)
        .ilike("name", `%${trimmed}%`)
        .order("name")
        .limit(SUGGESTION_LIMIT);
      if (cancelled) return;
      if (error || !data) {
        setSuggestions([]);
      } else {
        setSuggestions(
          data.map((row: Record<string, unknown>) => ({
            id: row.id as string,
            network_id: row.network_id as string,
            name: row.name as string,
            commune: (row.commune as string) ?? null,
            status: (row.status as StationListItem["status"]) ?? "active",
            latitude_center: row.latitude_center as number | null,
            longitude_center: row.longitude_center as number | null,
            stop_count: Array.isArray(row.stops) ? row.stops.length : 0,
          })),
        );
      }
      setLoading(false);
    }, DEBOUNCE_MS);

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [query, network.id]);

  return { suggestions, loading, hasQuery: query.trim().length >= MIN_QUERY_LENGTH };
}
