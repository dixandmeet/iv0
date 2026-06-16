import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DashboardShell } from "@/components/layout/dashboard-shell";

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
  const role = profile?.role ?? "regulator";

  return (
    <DashboardShell displayName={displayName} role={role}>
      {children}
    </DashboardShell>
  );
}
