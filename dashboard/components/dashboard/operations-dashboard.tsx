"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { LiveFleetPosition, NetworkIncident } from "@/lib/types";
import { FleetMap } from "@/components/map/fleet-map";
import { FleetPanel } from "@/components/fleet/fleet-panel";
import { IncidentsPanel } from "@/components/incidents/incidents-panel";

export function OperationsDashboard() {
  const [fleet, setFleet] = useState<LiveFleetPosition[]>([]);
  const [incidents, setIncidents] = useState<NetworkIncident[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const loadData = useCallback(async () => {
    const supabase = createClient();

    try {
      await supabase.rpc("refresh_live_fleet_positions");
    } catch {
      // Table/RPC pas encore déployée — on tente quand même la lecture
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

    if (!fleetRes.error && fleetRes.data) {
      setFleet(fleetRes.data as LiveFleetPosition[]);
    }
    if (!incidentsRes.error && incidentsRes.data) {
      setIncidents(incidentsRes.data as NetworkIncident[]);
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

    const poll = setInterval(loadData, 15000);

    return () => {
      clearInterval(poll);
      supabase.removeChannel(fleetChannel);
      supabase.removeChannel(incidentsChannel);
    };
  }, [loadData]);

  return (
    <>
      <div className="dashboard-map">
        <FleetMap
          fleet={fleet}
          selectedId={selectedId}
          onSelect={setSelectedId}
        />
        {loading && (
          <div
            style={{
              position: "absolute",
              top: 12,
              left: 12,
              background: "var(--panel)",
              padding: "8px 12px",
              borderRadius: 8,
              fontSize: 13,
            }}
          >
            Chargement…
          </div>
        )}
      </div>
      <aside className="dashboard-panel" style={{ padding: 16 }}>
        <FleetPanel
          fleet={fleet}
          selectedId={selectedId}
          onSelect={setSelectedId}
        />
        <IncidentsPanel incidents={incidents} />
      </aside>
    </>
  );
}
