"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { StationFilters, StationListItem, StationStatus } from "@/lib/stations-types";
import { useNetwork } from "@/components/network/network-provider";

const PAGE_SIZE = 50;
const SEARCH_FETCH_LIMIT = 500;

const DEFAULT_FILTERS: StationFilters = {
  status: "all",
  commune: "",
};

async function enrichWithStopCounts(items: StationListItem[]) {
  if (!items.length) return items;
  const supabase = createClient();
  const ids = items.map((station) => station.id);
  const { data } = await supabase.from("stops").select("station_id").in("station_id", ids);
  const counts = new Map<string, number>();
  for (const row of data ?? []) {
    const stationId = row.station_id as string;
    counts.set(stationId, (counts.get(stationId) ?? 0) + 1);
  }
  return items.map((station) => ({ ...station, stop_count: counts.get(station.id) ?? 0 }));
}

export function useStationsData() {
  const { network } = useNetwork();
  const [stations, setStations] = useState<StationListItem[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState("");
  const [filters, setFilters] = useState<StationFilters>(DEFAULT_FILTERS);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [communes, setCommunes] = useState<string[]>([]);
  const loadCommunes = useCallback(async () => {
    const supabase = createClient();
    const { data } = await supabase
      .from("stations")
      .select("commune")
      .eq("network_id", network.id)
      .not("commune", "is", null)
      .limit(500);
    const unique = [...new Set((data ?? []).map((r) => r.commune as string).filter(Boolean))].sort();
    setCommunes(unique);
  }, [network.id]);

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);
    const supabase = createClient();
    const isSearch = Boolean(search.trim());

    let query = supabase
      .from("stations")
      .select("id, network_id, name, commune, status, latitude_center, longitude_center, description", {
        count: "exact",
      })
      .eq("network_id", network.id)
      .order("name")
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);

    if (filters.status !== "all") query = query.eq("status", filters.status);
    if (filters.commune) query = query.eq("commune", filters.commune);
    if (isSearch) query = query.ilike("name", `%${search.trim()}%`).limit(SEARCH_FETCH_LIMIT);

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
  }, [page, search, filters, network.id]);

  useEffect(() => {
    void loadCommunes();
  }, [loadCommunes]);

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
    networkId: network.id,
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
  const { network, isPilotNetwork } = useNetwork();
  const [routes, setRoutes] = useState<
    { route_id: string; route_short_name: string | null; route_type?: number }[]
  >([]);

  useEffect(() => {
    const supabase = createClient();
    const query = isPilotNetwork
      ? supabase.from("gtfs_routes").select("route_id, route_short_name, route_type").order("route_short_name")
      : supabase.from("network_lines").select("line_id, short_name, transport_mode").eq("network_id", network.id).order("short_name");
    void query
      .then(({ data }) => {
        if (data) setRoutes(data.map((row: Record<string, unknown>) => ({
          route_id: String(row.route_id ?? row.line_id),
          route_short_name: String(row.route_short_name ?? row.short_name),
          route_type: row.route_type == null ? 3 : Number(row.route_type),
        })));
      });
  }, [isPilotNetwork, network.id]);

  return { routes };
}
