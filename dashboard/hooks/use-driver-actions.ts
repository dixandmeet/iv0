"use client";

import { useCallback, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { AddDriverPayload, DriverLookupResult } from "@/lib/drivers-types";

export function useDriverActions() {
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const lookupByEmail = useCallback(async (email: string): Promise<DriverLookupResult | null> => {
    const supabase = createClient();
    const { data, error: rpcError } = await supabase.rpc("find_user_by_email_for_driver", {
      p_email: email.trim(),
    });

    if (rpcError) throw new Error(rpcError.message);
    const row = (data as DriverLookupResult[] | null)?.[0];
    return row ?? null;
  }, []);

  const addDriver = useCallback(async (payload: AddDriverPayload) => {
    setSubmitting(true);
    setError(null);

    try {
      const supabase = createClient();
      const { data: userId, error: rpcError } = await supabase.rpc("add_or_promote_driver", {
        p_email: payload.email.trim(),
        p_display_name: payload.display_name.trim() || null,
        p_depot_id: payload.depot_id,
      });

      if (!rpcError && userId) {
        setSubmitting(false);
        return { userId: userId as string, invited: false };
      }

      if (
        payload.invite_if_missing &&
        rpcError?.message.includes("Aucun compte associé")
      ) {
        const res = await fetch("/api/drivers/invite", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            email: payload.email.trim(),
            display_name: payload.display_name.trim(),
            depot_id: payload.depot_id,
          }),
        });
        const body = (await res.json()) as { userId?: string; error?: string };
        if (!res.ok) throw new Error(body.error ?? "Invitation impossible");
        setSubmitting(false);
        return { userId: body.userId!, invited: true };
      }

      throw new Error(rpcError?.message ?? "Impossible d'ajouter le conducteur");
    } catch (e) {
      const message = e instanceof Error ? e.message : "Erreur inattendue";
      setError(message);
      setSubmitting(false);
      throw e;
    }
  }, []);

  const approveRequest = useCallback(
    async (requestId: string, depotId: string | null) => {
      setSubmitting(true);
      setError(null);
      const supabase = createClient();
      const { error: rpcError } = await supabase.rpc("review_driver_registration_request", {
        p_request_id: requestId,
        p_action: "approve",
        p_depot_id: depotId,
      });
      setSubmitting(false);
      if (rpcError) {
        setError(rpcError.message);
        throw new Error(rpcError.message);
      }
    },
    [],
  );

  const rejectRequest = useCallback(async (requestId: string, reason: string) => {
    setSubmitting(true);
    setError(null);
    const supabase = createClient();
    const { error: rpcError } = await supabase.rpc("review_driver_registration_request", {
      p_request_id: requestId,
      p_action: "reject",
      p_rejection_reason: reason.trim() || null,
    });
    setSubmitting(false);
    if (rpcError) {
      setError(rpcError.message);
      throw new Error(rpcError.message);
    }
  }, []);

  return {
    lookupByEmail,
    addDriver,
    approveRequest,
    rejectRequest,
    submitting,
    error,
  };
}
