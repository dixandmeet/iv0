import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

interface PageProps {
  params: Promise<{ stopId: string }>;
}

export default async function LegacyStopRedirectPage({ params }: PageProps) {
  const { stopId } = await params;
  const supabase = await createClient();

  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(stopId);

  const { data } = isUuid
    ? await supabase.from("stops").select("id, station_id").eq("id", stopId).maybeSingle()
    : await supabase.from("stops").select("id, station_id").eq("code", stopId).maybeSingle();

  if (data?.station_id && data?.id) {
    redirect(`/stations/${data.station_id}/arrets/${data.id}`);
  }

  redirect("/stations");
}
