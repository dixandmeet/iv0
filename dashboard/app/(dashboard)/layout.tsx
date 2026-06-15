import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DashboardNav } from "@/components/layout/dashboard-nav";
import { SignOutButton } from "@/components/layout/sign-out-button";
import { ThemeToggle } from "@/components/theme-toggle";
import { Badge } from "@/components/ui/badge";

const ROLE_VARIANT: Record<string, "default" | "secondary" | "realtime" | "pilot"> = {
  admin: "default",
  regulator: "pilot",
  msr_supervisor: "realtime",
};

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
  const roleVariant = ROLE_VARIANT[role] ?? "secondary";

  return (
    <div className="dashboard-shell">
      <header className="dashboard-header">
        <div className="flex items-center gap-3">
          <strong className="text-base">Aule</strong>
          <span className="text-sm text-muted-foreground">Poste de contrôle</span>
        </div>
        <div className="flex items-center gap-3">
          <span className="hidden text-sm text-muted-foreground sm:inline">
            {displayName}
          </span>
          <Badge variant={roleVariant}>{role}</Badge>
          <ThemeToggle />
          <SignOutButton />
        </div>
      </header>

      <aside className="dashboard-sidebar">
        <DashboardNav />
        <p className="section-title">Régulateur</p>
        <p className="text-xs leading-relaxed text-muted-foreground">
          Flotte live, conducteurs certifiés et incidents réseau en temps réel.
        </p>
      </aside>

      {children}
    </div>
  );
}
