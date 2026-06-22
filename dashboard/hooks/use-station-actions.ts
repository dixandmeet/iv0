"use client";

import { useCallback, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import {
  DUPLICATE_STATION_NAME_ERROR,
  isDuplicateStationNameError,
  type StationFormPayload,
} from "@/lib/stations-types";

const DEFAULT_NETWORK_CODE = "naolib-nantes";

async function logStationAudit(
  stationId: string,
  action: string,
  changes: Record<string, unknown>,
  userId: string | undefined,
) {
  const supabase = createClient();
  await supabase.from("station_audit_log").insert({
    station_id: stationId,
    action,
    changes,
    performed_by: userId ?? null,
  });
}

export function useStationActions() {
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

  const createStation = useCallback(async (payload: StationFormPayload) => {
    setSubmitting(true);
    setError(null);
    const supabase = createClient();
    const { data: { user } } = await supabase.auth.getUser();
    const networkId = await getNetworkId();
    if (!networkId) throw new Error("Réseau introuvable");

    const { data, error: insertError } = await supabase
      .from("stations")
      .insert({
        network_id: networkId,
        name: payload.name.trim(),
        description: payload.description ?? null,
        commune: payload.commune ?? "Nantes",
        latitude_center: payload.latitude_center ?? null,
        longitude_center: payload.longitude_center ?? null,
        status: payload.status,
        updated_by: user?.id,
      })
      .select("id")
      .single();

    if (insertError) {
      const msg = isDuplicateStationNameError(insertError.message)
        ? DUPLICATE_STATION_NAME_ERROR
        : insertError.message;
      setError(msg);
      setSubmitting(false);
      throw new Error(msg);
    }

    await logStationAudit(data.id, "created", payload as unknown as Record<string, unknown>, user?.id);
    setSubmitting(false);
    return data.id as string;
  }, [getNetworkId]);

  const updateStation = useCallback(
    async (stationId: string, payload: Partial<StationFormPayload>) => {
      setSubmitting(true);
      setError(null);
      const supabase = createClient();
      const { data: { user } } = await supabase.auth.getUser();
      const updates: Record<string, unknown> = { updated_by: user?.id };
      if (payload.name != null) updates.name = payload.name.trim();
      if (payload.description !== undefined) updates.description = payload.description;
      if (payload.commune !== undefined) updates.commune = payload.commune;
      if (payload.latitude_center !== undefined) updates.latitude_center = payload.latitude_center;
      if (payload.longitude_center !== undefined) updates.longitude_center = payload.longitude_center;
      if (payload.status != null) updates.status = payload.status;

      const { error: updateError } = await supabase
        .from("stations")
        .update(updates)
        .eq("id", stationId);

      if (updateError) {
        const msg = isDuplicateStationNameError(updateError.message)
          ? DUPLICATE_STATION_NAME_ERROR
          : updateError.message;
        setError(msg);
        setSubmitting(false);
        throw new Error(msg);
      }

      await logStationAudit(stationId, "updated", updates, user?.id);
      setSubmitting(false);
    },
    [],
  );

  const disableStation = useCallback(async (stationId: string) => {
    setSubmitting(true);
    setError(null);
    const supabase = createClient();
    const { data: { user } } = await supabase.auth.getUser();
    const { error: updateError } = await supabase
      .from("stations")
      .update({ status: "inactive", updated_by: user?.id })
      .eq("id", stationId);
    if (updateError) {
      setError(updateError.message);
      setSubmitting(false);
      throw new Error(updateError.message);
    }
    await logStationAudit(stationId, "disabled", { status: "inactive" }, user?.id);
    setSubmitting(false);
  }, []);

  return { createStation, updateStation, disableStation, submitting, error };
}
