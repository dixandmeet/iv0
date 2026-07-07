import type { Metadata } from "next";
import { ImmersiveMap } from "@/components/carte-immersive/immersive-map";
import {
  loadDashboardLineCatalog,
  loadPublishedLineTraces,
  loadRealLineTraces,
  loadRealVehiclePaths,
  mergeLineTraces,
} from "@/lib/carte-immersive/real-lines";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  title: "Carte immersive",
  description:
    "Explorez la carte 3D immersive d'Aule : itinéraires en temps réel, VTC, taxis et commerçants à proximité.",
  robots: { index: false, follow: false },
};

export default async function CarteImmersivePage() {
  const supabase = await createClient();
  const [realPaths, authResult, publishedLineTraces, dashboardLines] = await Promise.all([
    loadRealVehiclePaths(),
    supabase.auth.getUser(),
    loadPublishedLineTraces(supabase),
    loadDashboardLineCatalog(supabase),
  ]);
  const realLineTraces = mergeLineTraces(publishedLineTraces, loadRealLineTraces());
  const user = authResult.data.user;
  let viewer: { displayName: string; avatarUrl: string | null } | null = null;

  if (user) {
    const [{ data: profile }, { data: driverByUserId }] = await Promise.all([
      supabase
        .from("user_profiles")
        .select("display_name")
        .eq("id", user.id)
        .maybeSingle(),
      supabase
        .from("drivers")
        .select("avatar_url")
        .eq("user_id", user.id)
        .maybeSingle(),
    ]);

    let driver = driverByUserId;
    if (!driver && user.email) {
      const { data: driverByEmail } = await supabase
        .from("drivers")
        .select("avatar_url")
        .ilike("email", user.email)
        .maybeSingle();
      driver = driverByEmail;
    }

    const metadata = user.user_metadata as Record<string, unknown>;
    const metadataName = [metadata.display_name, metadata.full_name, metadata.name]
      .find((value): value is string => typeof value === "string" && value.trim().length > 0);
    const metadataAvatar = [metadata.avatar_url, metadata.picture, metadata.photo_url]
      .find((value): value is string => typeof value === "string" && value.trim().length > 0);

    viewer = {
      displayName:
        profile?.display_name?.trim() ||
        metadataName?.trim() ||
        user.email?.split("@")[0] ||
        "Utilisateur",
      avatarUrl: driver?.avatar_url?.trim() || metadataAvatar?.trim() || null,
    };
  }

  return (
    <ImmersiveMap
      realPaths={realPaths}
      realLineTraces={realLineTraces}
      dashboardLines={dashboardLines}
      viewer={viewer}
    />
  );
}
