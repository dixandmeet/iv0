import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DashboardNav } from "@/components/layout/dashboard-nav";
import { SignOutButton } from "@/components/layout/sign-out-button";

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

  const displayName = profile?.display_name ?? user.email ?? "Exploitant";
  const role = profile?.role ?? "—";

  return (
    <div className="dashboard-shell">
      <header className="dashboard-header">
        <div>
          <strong>Aule</strong>
          <span className="muted" style={{ marginLeft: 12 }}>
            Poste de contrôle
          </span>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
          <span className="muted">
            {displayName} · {role}
          </span>
          <SignOutButton />
        </div>
      </header>

      <aside className="dashboard-sidebar">
        <DashboardNav />
        <p className="section-title">Régulateur</p>
        <p className="muted" style={{ fontSize: 12, lineHeight: 1.5 }}>
          Flotte live, conducteurs certifiés et incidents réseau en temps réel.
        </p>
      </aside>

      {children}
    </div>
  );
}
