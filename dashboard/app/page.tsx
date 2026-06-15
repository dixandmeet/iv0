import { redirect } from "next/navigation";
import type { Metadata } from "next";
import { LandingPage } from "@/components/landing/landing-page";
import { createClient } from "@/lib/supabase/server";
import { WEB_STAFF_ROLES, type StaffRole } from "@/lib/types";

export const metadata: Metadata = {
  title: "Aule — GPS intelligent pour les transports en commun",
  description:
    "Trouvez le meilleur itinéraire, suivez votre bus ou tram en temps réel et recevez des alertes avant son arrivée. Gratuit pour les voyageurs.",
};

export default async function HomePage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user) {
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();

    const role = (profile?.role as StaffRole | undefined) ?? "passenger";
    if (WEB_STAFF_ROLES.includes(role)) {
      redirect("/dashboard");
    }
  }

  return <LandingPage />;
}
