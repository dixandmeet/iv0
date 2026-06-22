"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { StationFilters, StationListItem, StationStatus } from "@/lib/stations-types";

const PAGE_SIZE = 50;
const SEARCH_FETCH_LIMIT = 500;
const DEFAULT_NETWORK_CODE = "naolib-nantes";

const DEFAULT_FILTERS: StationFilters = {
  status: "all",
  commune: "",
};

export function useStationsData() {
  const [stations, setStations] = useState<StationListItem[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState("");
  const [filters, setFilters] = useState<StationFilters>(DEFAULT_FILTERS);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [communes, setCommunes] = useState<string[]>([]);
  const [networkId, setNetworkId] = useState<string | null>(null);

  const loadNetwork = useCallback(async () => {
    const supabase = createClient();
    const { data } = await supabase
      .from("networks")
      .select("id")
      .eq("code", DEFAULT_NETWORK_CODE)
      .maybeSingle();
    if (data) setNetworkId(data.id as string);
  }, []);

  const loadCommunes = useCallback(async () => {
    const supabase = createClient();
    const { data } = await supabase
      .from("stations")
      .select("commune")
      .not("commune", "is", null)
      .limit(500);
    const unique = [...new Set((data ?? []).map((r) => r.commune as string).filter(Boolean))].sort();
    setCommunes(unique.length ? unique : ["Nantes"]);
  }, []);

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);
    const supabase = createClient();
    const isSearch = Boolean(search.trim());

    if (isSearch) {
      const { data, error: rpcError } = await supabase.rpc("search_stations", {
        p_query: search.trim(),
        p_audience: "staff",
        p_limit: SEARCH_FETCH_LIMIT,
      });
      if (rpcError) {
        setError(rpcError.message);
        setLoading(false);
        return;
      }
      let items: StationListItem[] = (data ?? []).map(mapStationRow);
      if (filters.status !== "all") {
        items = items.filter((s: StationListItem) => s.status === filters.status);
      }
      if (filters.commune) {
        items = items.filter((s: StationListItem) => s.commune === filters.commune);
      }
      const start = page * PAGE_SIZE;
      setTotalCount(items.length);
      setStations(items.slice(start, start + PAGE_SIZE));
      setLoading(false);
      return;
    }

    let query = supabase
      .from("stations")
      .select("id, network_id, name, commune, status, latitude_center, longitude_center, description", {
        count: "exact",
      })
      .order("name")
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);

    if (filters.status !== "all") query = query.eq("status", filters.status);
    if (filters.commune) query = query.eq("commune", filters.commune);

    const { data, error: fetchError, count } = await query;
    if (fetchError) {
      setError(fetchError.message);
      setLoading(false);
      return;
    }

    const items = await enrichWithStopCounts((data ?? []).map(mapStationRow));
    setStations(items);
    setTotalCount(count ?? items.length);
    setLoading(false);
  }, [page, search, filters]);

  const enrichWithStopCounts = async (items: StationListItem[]) => {
    if (!items.length) return items;
    const supabase = createClient();
    const ids = items.map((s) => s.id);
    const { data } = await supabase.from("stops").select("station_id").in("station_id", ids);
    const counts = new Map<string, number>();
    for (const row of data ?? []) {
      const sid = row.station_id as string;
      counts.set(sid, (counts.get(sid) ?? 0) + 1);
    }
    return items.map((s) => ({ ...s, stop_count: counts.get(s.id) ?? 0 }));
  };

  useEffect(() => {
    void loadNetwork();
    void loadCommunes();
  }, [loadNetwork, loadCommunes]);

  useEffect(() => {
    void loadData();
    const supabase = createClient();
    const channel = supabase
      .channel("stations-list")
      .on("postgres_changes", { event: "*", schema: "public", table: "stations" }, () => loadData())
      .on("postgres_changes", { event: "*", schema: "public", table: "stops" }, () => loadData())
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [loadData]);

  const totalPages = useMemo(() => Math.max(1, Math.ceil(totalCount / PAGE_SIZE)), [totalCount]);

  return {
    stations,
    loading,
    error,
    search,
    setSearch,
    filters,
    setFilters,
    page,
    setPage,
    totalCount,
    totalPages,
    communes,
    networkId,
    refresh: loadData,
    PAGE_SIZE,
  };
}

function mapStationRow(row: Record<string, unknown>): StationListItem {
  return {
    id: row.id as string,
    network_id: (row.network_id as string) ?? "",
    name: row.name as string,
    commune: (row.commune as string) ?? null,
    status: (row.status as StationStatus) ?? "active",
    latitude_center: row.latitude_center as number | null,
    longitude_center: row.longitude_center as number | null,
    stop_count: Number(row.stop_count ?? 0),
    description: (row.description as string) ?? null,
  };
}

export function useStopRouteFilter() {
  const [routes, setRoutes] = useState<
    { route_id: string; route_short_name: string | null; route_type?: number }[]
  >([]);

  useEffect(() => {
    const supabase = createClient();
    void supabase
      .from("gtfs_routes")
      .select("route_id, route_short_name, route_type")
      .order("route_short_name")
      .then(({ data }) => {
        if (data) setRoutes(data);
      });
  }, []);

  return { routes };
}
