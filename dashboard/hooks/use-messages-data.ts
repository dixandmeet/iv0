"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { StaffMessage } from "@/lib/types";
import { isMissingTableError, isRelationshipError } from "@/lib/supabase-errors";

export function useMessagesData() {
  const [messages, setMessages] = useState<StaffMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    const supabase = createClient();
    setError(null);

    let result = await supabase
      .from("staff_messages")
      .select(
        "*, sender:user_profiles!staff_messages_sender_id_fkey(display_name), recipient:user_profiles!staff_messages_recipient_id_fkey(display_name)",
      )
      .order("created_at", { ascending: false })
      .limit(100);

    if (result.error && isRelationshipError(result.error.message)) {
      result = await supabase
        .from("staff_messages")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(100);
    }

    if (result.error) {
      if (!isMissingTableError(result.error.message)) {
        setError(result.error.message);
      }
    } else if (result.data) {
      setMessages(result.data as StaffMessage[]);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    loadData();
    const supabase = createClient();
    const channel = supabase
      .channel("staff-messages")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "staff_messages" },
        () => loadData(),
      )
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [loadData]);

  const sendMessage = async (payload: {
    recipient_id?: string | null;
    recipient_role?: string | null;
    route_id?: string | null;
    subject?: string;
    body: string;
    message_type: StaffMessage["message_type"];
  }) => {
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) throw new Error("Non authentifié");

    const { error: insertError } = await supabase.from("staff_messages").insert({
      sender_id: user.id,
      ...payload,
    });
    if (insertError) {
      if (isMissingTableError(insertError.message)) {
        throw new Error(
          "Table staff_messages absente — appliquez la migration 007_regulator_features.sql",
        );
      }
      throw new Error(insertError.message);
    }
    await loadData();
  };

  return { messages, loading, error, refresh: loadData, sendMessage };
}
