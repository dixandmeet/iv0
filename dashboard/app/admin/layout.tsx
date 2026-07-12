import { redirect } from "next/navigation";
import { AdminShell } from "@/components/admin/admin-shell";
import { loadAccess } from "@/lib/access/server";
import { createClient } from "@/lib/supabase/server";
import type { StaffRole } from "@/lib/types";

const adminProfiles = new Set(["admin", "platform_admin", "super_admin"]);

export default async function AdminRootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login?mode=pro&next=/admin");
  }

  const { data: profile } = await supabase
    .from("user_profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();
  const role = (profile?.role ?? "passenger") as StaffRole;
  const { profiles } = await loadAccess(supabase, user.id, role);
  const hasAdminAccess = role === "admin" || profiles.some((item) => adminProfiles.has(item));

  if (!hasAdminAccess) {
    redirect("/login?mode=pro&error=unauthorized");
  }

  return <AdminShell>{children}</AdminShell>;
}
