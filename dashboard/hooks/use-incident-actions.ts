"use client";

import { useCallback, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { NetworkIncident } from "@/lib/types";
import type { IncidentActionLog } from "@/lib/types";
import { useNetwork } from "@/components/network/network-provider";

export function useIncidentActions() {
  const { network } = useNetwork();
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const createIncident = useCallback(
    async (payload: {
      incident_type: string;
      severity: NetworkIncident["severity"];
      title: string;
      description?: string;
      route_id?: string | null;
      geom?: { type: "Point"; coordinates: [number, number] } | null;
    }) => {
      setSubmitting(true);
      setError(null);
      const supabase = createClient();
      const { data: { user } } = await supabase.auth.getUser();

      const { data, error: insertError } = await supabase
        .from("network_incidents")
        .insert({
          ...payload,
          network_id: network.id,
          source: "regulator",
          reported_by: user?.id,
          status: "open",
        })
        .select()
        .single();

      if (insertError) {
        setError(insertError.message);
        setSubmitting(false);
        throw new Error(insertError.message);
      }

      const { error: logError } = await supabase.rpc("log_incident_action", {
        p_incident_id: data.id,
        p_action_type: "created",
        p_result: { by: user?.id },
      });
      if (logError) {
        // RPC optionnelle si migration 007 non appliquée
      }

      setSubmitting(false);
      return data as NetworkIncident;
    },
    [network.id],
  );

  const updateIncidentStatus = useCallback(
    async (id: string, status: string, note?: string) => {
      setSubmitting(true);
      setError(null);
      const supabase = createClient();
      const { data: { user } } = await supabase.auth.getUser();

      const updates: Record<string, unknown> = { status };
      if (status === "resolved" || status === "closed") {
        updates.resolved_at = new Date().toISOString();
      }

      const { error: updateError } = await supabase
        .from("network_incidents")
        .update(updates)
        .eq("id", id);

      if (updateError) {
        setError(updateError.message);
        setSubmitting(false);
        throw new Error(updateError.message);
      }

      const { error: logError } = await supabase.rpc("log_incident_action", {
        p_incident_id: id,
        p_action_type: `status_${status}`,
        p_result: { by: user?.id, note },
      });
      if (logError) {
        // RPC optionnelle
      }

      setSubmitting(false);
    },
    [],
  );

  const fetchActionLog = useCallback(async (incidentId: string) => {
    const supabase = createClient();
    const { data } = await supabase
      .from("incident_actions_log")
      .select("*")
      .eq("incident_id", incidentId)
      .order("executed_at", { ascending: false });
    return (data ?? []) as IncidentActionLog[];
  }, []);

  return {
    createIncident,
    updateIncidentStatus,
    fetchActionLog,
    submitting,
    error,
  };
}
