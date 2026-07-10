import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { AccessProvider } from "@/components/access/access-provider";
import { loadAccess } from "@/lib/access/server";
import type { StaffRole } from "@/lib/types";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("user_profiles")
    .select("display_name, role")
    .eq("id", user.id)
    .maybeSingle();

  const displayName = profile?.display_name ?? user.email ?? "Régulateur test";
  const role = (profile?.role ?? "regulator") as StaffRole;

  // Accès multi-profils résolu côté serveur : lit profile_assignments +
  // overrides, avec repli sur le pont `role` tant que la migration n'est pas
  // appliquée. Les permissions sont figées avant d'être passées au client.
  const { profiles, permissions } = await loadAccess(supabase, user.id, role);

  return (
    <AccessProvider profiles={profiles} permissions={permissions} surface="web">
      <DashboardShell displayName={displayName} role={role}>
        {children}
      </DashboardShell>
    </AccessProvider>
  );
}
