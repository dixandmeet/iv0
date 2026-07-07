"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";

export type HubView = "activity" | "discussions" | "notifications" | "tasks" | "documents";

export function useHubData(view: HubView = "activity") {
  const [data, setData] = useState<unknown[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const supabase = createClient();
    setLoading(true);
    setError(null);
    const { data: raw, error: rpcError } = await supabase.rpc("get_hub_feed", {
      p_view: view,
      p_limit: 50,
    });
    if (rpcError) {
      setError(rpcError.message);
      setData([]);
    } else {
      setData(Array.isArray(raw) ? raw : []);
    }
    setLoading(false);
  }, [view]);

  useEffect(() => {
    load();
    const supabase = createClient();
    const channel = supabase
      .channel(`hub-${view}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "user_notifications" },
        () => load(),
      )
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [load, view]);

  return { data, loading, error, refresh: load };
}

export function useResourceShell(resourceId: string | null) {
  const [shell, setShell] = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!resourceId) return;
    const supabase = createClient();
    setLoading(true);
    const { data, error: rpcError } = await supabase.rpc("get_resource_shell", {
      p_resource_id: resourceId,
    });
    if (rpcError) setError(rpcError.message);
    else setShell(data as Record<string, unknown>);
    setLoading(false);
  }, [resourceId]);

  useEffect(() => {
    void load();
  }, [load]);

  return { shell, loading, error, refresh: load };
}

export async function sendChannelMessage(channelId: string, body: string) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Non authentifié");
  const { error } = await supabase.from("messages").insert({
    channel_id: channelId,
    sender_id: user.id,
    message_type: "text",
    body,
  });
  if (error) throw new Error(error.message);
}
