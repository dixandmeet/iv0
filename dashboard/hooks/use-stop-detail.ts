"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { StopDeparture, StopListItem, StopServingLine, NearbyStop, StopAuditEntry } from "@/lib/stops-types";
import type { StopSource, StopTransportMode } from "@/lib/stations-types";
import type { NetworkIncident } from "@/lib/types";

function mapStopRow(row: Record<string, unknown>, stationName?: string): StopListItem {
  const geom = row.geom as StopListItem["geom"];
  return {
    id: row.id as string,
    station_id: row.station_id as string,
    network_id: row.network_id as string,
    code: row.code as string,
    name: (row.name as string) ?? null,
    latitude: row.latitude as number,
    longitude: row.longitude as number,
    geom,
    platform: (row.platform as string) ?? null,
    transport_mode: row.transport_mode as StopTransportMode,
    source: row.source as StopSource,
    gtfs_source_id: (row.gtfs_source_id as string) ?? null,
    is_accessible: Boolean(row.is_accessible),
    status: (row.status as StopListItem["status"]) ?? "active",
    address: (row.address as string) ?? null,
    tariff_zone: (row.tariff_zone as string) ?? null,
    updated_at: (row.updated_at as string) ?? new Date().toISOString(),
    served_routes: [],
    station_name: stationName,
  };
}

export function useStopDetail(stopId: string | null) {
  const [stop, setStop] = useState<StopListItem | null>(null);
  const [lines, setLines] = useState<StopServingLine[]>([]);
  const [departures, setDepartures] = useState<StopDeparture[]>([]);
  const [incidents, setIncidents] = useState<NetworkIncident[]>([]);
  const [history, setHistory] = useState<StopAuditEntry[]>([]);
  const [nearby, setNearby] = useState<NearbyStop[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadStop = useCallback(async () => {
    if (!stopId) {
      setStop(null);
      return;
    }
    const supabase = createClient();
    const { data, error: fetchError } = await supabase
      .from("stops")
      .select("*, stations(name)")
      .eq("id", stopId)
      .maybeSingle();

    if (fetchError || !data) {
      setError(fetchError?.message ?? "Arrêt introuvable");
      return;
    }
    const station = data.stations as { name: string } | { name: string }[] | null;
    const stationName = Array.isArray(station) ? station[0]?.name : station?.name;
    setStop(mapStopRow(data as Record<string, unknown>, stationName));
  }, [stopId]);

  const loadLines = useCallback(async () => {
    if (!stopId) return;
    const supabase = createClient();
    const { data } = await supabase.rpc("get_stop_serving_lines", { p_stop_id: stopId });
    setLines((data as StopServingLine[]) ?? []);
  }, [stopId]);

  const loadDepartures = useCallback(async () => {
    if (!stopId) return;
    const supabase = createClient();
    const { data } = await supabase.rpc("get_stop_departures", { p_stop_id: stopId, p_limit: 20 });
    setDepartures((data as StopDeparture[]) ?? []);
  }, [stopId]);

  const loadIncidents = useCallback(async () => {
    if (!stop?.code) return;
    const supabase = createClient();
    const { data } = await supabase
      .from("network_incidents")
      .select("*")
      .in("status", ["open", "monitoring"])
      .order("created_at", { ascending: false })
      .limit(30);
    const filtered = (data ?? []).filter((inc) => {
      const meta = (inc as { metadata?: { stop_code?: string } }).metadata;
      return meta?.stop_code === stop.code;
    });
    setIncidents(filtered as NetworkIncident[]);
  }, [stop?.code]);

  const loadHistory = useCallback(async () => {
    if (!stopId) return;
    const supabase = createClient();
    const { data } = await supabase
      .from("stop_audit_log")
      .select("*")
      .eq("stop_uuid", stopId)
      .order("created_at", { ascending: false })
      .limit(30);
    setHistory(
      (data ?? []).map((row) => ({
        id: row.id as string,
        stop_id: stopId,
        action: row.action as string,
        changes: row.changes as Record<string, unknown>,
        performed_by: row.performed_by as string | null,
        created_at: row.created_at as string,
      })),
    );
  }, [stopId]);

  const loadNearby = useCallback(async () => {
    if (!stop) return;
    const supabase = createClient();
    const { data } = await supabase.rpc("get_nearby_stops", {
      p_lng: stop.longitude,
      p_lat: stop.latitude,
      p_radius_m: 400,
      p_exclude_stop_id: stop.id,
      p_audience: "staff",
    });
    setNearby(
      (data ?? []).map((row: Record<string, unknown>) => ({
        stop_id: row.stop_id as string,
        stop_code: row.stop_code as string,
        stop_name: row.stop_name as string,
        station_id: row.station_id as string,
        station_name: row.station_name as string,
        status: row.status as NearbyStop["status"],
        distance_m: row.distance_m as number,
        geom: row.geom as NearbyStop["geom"],
      })),
    );
  }, [stop]);

  const refresh = useCallback(async () => {
    if (!stopId) return;
    setLoading(true);
    setError(null);
    await loadStop();
    setLoading(false);
    await Promise.all([loadLines(), loadDepartures(), loadHistory()]);
  }, [stopId, loadStop, loadLines, loadDepartures, loadHistory]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  useEffect(() => {
    if (stop) void loadIncidents();
  }, [stop, loadIncidents]);

  useEffect(() => {
    if (stop) void loadNearby();
  }, [stop, loadNearby]);

  useEffect(() => {
    if (!stopId) return;
    const interval = setInterval(() => void loadDepartures(), 30000);
    return () => clearInterval(interval);
  }, [stopId, loadDepartures]);

  return { stop, lines, departures, incidents, history, nearby, loading, error, refresh, setStop };
}
