import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { AccountSettings } from "@/components/account/account-settings";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  title: "Mon compte — Aule Pro",
  description: "Gérez votre profil, votre accès et le cycle de vie de votre compte Aule.",
};

export default async function AccountPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const [{ data: profile }, { data: memberships }] = await Promise.all([
    supabase
      .from("user_profiles")
      .select("display_name, role")
      .eq("id", user.id)
      .maybeSingle(),
    supabase
      .from("network_memberships")
      .select("membership_role")
      .eq("user_id", user.id)
      .in("membership_role", ["owner", "admin"]),
  ]);

  return (
    <AccountSettings
      displayName={profile?.display_name?.trim() || user.email || "Utilisateur Aule"}
      email={user.email || ""}
      role={profile?.role || "passenger"}
      createdAt={user.created_at}
      managedNetworkCount={memberships?.length ?? 0}
    />
  );
}
