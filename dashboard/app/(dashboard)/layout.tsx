import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DashboardNav } from "@/components/layout/dashboard-nav";
import { DashboardLogo } from "@/components/layout/dashboard-logo";
import { DashboardUserCard } from "@/components/layout/dashboard-user-card";

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
    <div className="dashboard-shell dark">
      <aside className="dashboard-sidebar">
        <DashboardLogo />
        <DashboardNav />
        <div className="dashboard-sidebar-footer">
          <DashboardUserCard displayName={displayName} role={role} />
        </div>
      </aside>

      <div className="dashboard-content">{children}</div>
    </div>
  );
}
