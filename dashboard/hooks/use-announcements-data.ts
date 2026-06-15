"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { PassengerAnnouncement } from "@/lib/types";
import { isMissingTableError } from "@/lib/supabase-errors";

export function useAnnouncementsData() {
  const [announcements, setAnnouncements] = useState<PassengerAnnouncement[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    const supabase = createClient();
    setError(null);

    const { data, error: fetchError } = await supabase
      .from("passenger_announcements")
      .select("*")
      .order("published_at", { ascending: false })
      .limit(100);

    if (fetchError) {
      if (!isMissingTableError(fetchError.message)) {
        setError(fetchError.message);
      }
    } else if (data) {
      setAnnouncements(data as PassengerAnnouncement[]);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    loadData();
    const supabase = createClient();
    const channel = supabase
      .channel("passenger-announcements")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "passenger_announcements" },
        () => loadData(),
      )
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [loadData]);

  const publishAnnouncement = async (payload: {
    title: string;
    message: string;
    announcement_type: PassengerAnnouncement["announcement_type"];
    route_ids: string[];
    severity: PassengerAnnouncement["severity"];
    incident_id?: string | null;
    expires_at?: string | null;
  }) => {
    const supabase = createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error("Non authentifié");

    const { error: insertError } = await supabase
      .from("passenger_announcements")
      .insert({
        ...payload,
        published_by: user.id,
        is_active: true,
      });
    if (insertError) {
      if (isMissingTableError(insertError.message)) {
        throw new Error(
          "Table passenger_announcements absente — appliquez la migration 007_regulator_features.sql",
        );
      }
      throw new Error(insertError.message);
    }
    await loadData();
  };

  const deactivateAnnouncement = async (id: string) => {
    const supabase = createClient();
    const { error: updateError } = await supabase
      .from("passenger_announcements")
      .update({ is_active: false })
      .eq("id", id);
    if (updateError) throw new Error(updateError.message);
    await loadData();
  };

  return {
    announcements,
    loading,
    error,
    refresh: loadData,
    publishAnnouncement,
    deactivateAnnouncement,
  };
}
