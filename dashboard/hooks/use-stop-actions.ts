"use client";

import { useCallback, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { StopFormPayload, StopListItem, StopStatus } from "@/lib/stops-types";
import type { StopSource, StopTransportMode } from "@/lib/stations-types";

const DEFAULT_NETWORK_CODE = "naolib-nantes";

async function logAudit(
  stopUuid: string,
  stopCode: string,
  action: string,
  changes: Record<string, unknown>,
  userId: string | undefined,
) {
  const supabase = createClient();
  await supabase.from("stop_audit_log").insert({
    stop_id: stopCode,
    stop_uuid: stopUuid,
    action,
    changes,
    performed_by: userId ?? null,
  });
}

export function useStopActions() {
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getNetworkId = useCallback(async () => {
    const supabase = createClient();
    const { data } = await supabase
      .from("networks")
      .select("id")
      .eq("code", DEFAULT_NETWORK_CODE)
      .maybeSingle();
    return data?.id as string | undefined;
  }, []);

  const createStop = useCallback(
    async (stationId: string, payload: StopFormPayload) => {
      setSubmitting(true);
      setError(null);
      const supabase = createClient();
      const { data: { user } } = await supabase.auth.getUser();
      const networkId = await getNetworkId();
      if (!networkId) throw new Error("Réseau introuvable");
      const [lng, lat] = payload.coordinates;

      const { data, error: insertError } = await supabase
        .from("stops")
        .insert({
          network_id: networkId,
          station_id: stationId,
          code: payload.code.toUpperCase(),
          name: payload.name ?? null,
          latitude: lat,
          longitude: lng,
          platform: payload.platform ?? null,
          transport_mode: payload.transport_mode,
          source: payload.source,
          gtfs_source_id: payload.source === "gtfs" ? payload.code : null,
          is_accessible: payload.is_accessible,
          status: payload.status,
          address: payload.address ?? null,
          tariff_zone: payload.tariff_zone ?? null,
          updated_by: user?.id,
        })
        .select("id, code")
        .single();

      if (insertError) {
        setError(insertError.message);
        setSubmitting(false);
        throw new Error(insertError.message);
      }

      if (payload.source === "gtfs") {
        await supabase.from("gtfs_stop_mapping").insert({
          network_id: networkId,
          gtfs_stop_id: payload.code.toUpperCase(),
          stop_id: data.id,
        });
      }

      await logAudit(data.id, data.code, "created", payload as unknown as Record<string, unknown>, user?.id);
      setSubmitting(false);
      return data.id as string;
    },
    [getNetworkId],
  );

  const updateStop = useCallback(async (stopId: string, payload: Partial<StopFormPayload>) => {
    setSubmitting(true);
    setError(null);
    const supabase = createClient();
    const { data: { user } } = await supabase.auth.getUser();

    const updates: Record<string, unknown> = { updated_by: user?.id };
    if (payload.name !== undefined) updates.name = payload.name;
    if (payload.status != null) updates.status = payload.status;
    if (payload.address !== undefined) updates.address = payload.address;
    if (payload.tariff_zone !== undefined) updates.tariff_zone = payload.tariff_zone;
    if (payload.platform !== undefined) updates.platform = payload.platform;
    if (payload.transport_mode != null) updates.transport_mode = payload.transport_mode;
    if (payload.is_accessible != null) updates.is_accessible = payload.is_accessible;
    if (payload.coordinates) {
      updates.latitude = payload.coordinates[1];
      updates.longitude = payload.coordinates[0];
    }

    const { data: existing } = await supabase.from("stops").select("code").eq("id", stopId).single();
    const { error: updateError } = await supabase.from("stops").update(updates).eq("id", stopId);

    if (updateError) {
      setError(updateError.message);
      setSubmitting(false);
      throw new Error(updateError.message);
    }

    await logAudit(stopId, existing?.code ?? stopId, "updated", updates, user?.id);
    setSubmitting(false);
  }, []);

  const disableStop = useCallback(async (stopId: string) => {
    setSubmitting(true);
    setError(null);
    const supabase = createClient();
    const { data: { user } } = await supabase.auth.getUser();
    const { data: existing } = await supabase.from("stops").select("code").eq("id", stopId).single();
    const { error: updateError } = await supabase
      .from("stops")
      .update({ status: "inactive", updated_by: user?.id })
      .eq("id", stopId);
    if (updateError) {
      setError(updateError.message);
      setSubmitting(false);
      throw new Error(updateError.message);
    }
    await logAudit(stopId, existing?.code ?? stopId, "disabled", { status: "inactive" }, user?.id);
    setSubmitting(false);
  }, []);

  const importStops = useCallback(
    async (stationId: string, rows: Array<Record<string, string>>) => {
      setSubmitting(true);
      const errors: string[] = [];
      let success = 0;
      for (const row of rows) {
        try {
          await createStop(stationId, {
            code: row.stop_id || row.code,
            name: row.stop_name || row.name || null,
            status: (row.status as StopStatus) || "active",
            address: row.address || null,
            tariff_zone: row.tariff_zone || null,
            platform: row.platform || null,
            transport_mode: (row.transport_mode as StopTransportMode) || "bus",
            source: (row.source as StopSource) || "manual",
            is_accessible: row.is_accessible === "1" || row.wheelchair_boarding === "1",
            coordinates: [
              parseFloat(row.lng) || -1.5536,
              parseFloat(row.lat) || 47.2184,
            ],
          });
          success++;
        } catch (e) {
          errors.push(e instanceof Error ? e.message : String(e));
        }
      }
      setSubmitting(false);
      return { success, errors };
    },
    [createStop],
  );

  return { createStop, updateStop, disableStop, importStops, submitting, error };
}

export type { StopListItem };
