"use client";

import { LogOut } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

interface SignOutButtonProps {
  collapsed?: boolean;
  variant?: "default" | "icon";
}

export function SignOutButton({
  collapsed = false,
  variant = "default",
}: SignOutButtonProps) {
  async function signOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    window.location.href = "/";
  }

  if (variant === "icon") {
    return (
      <button
        type="button"
        className="regulation-action-btn"
        onClick={signOut}
        aria-label="Déconnexion"
      >
        <LogOut className="h-[18px] w-[18px]" />
      </button>
    );
  }

  return (
    <button
      type="button"
      onClick={signOut}
      className={`dashboard-sign-out-btn${collapsed ? " dashboard-sign-out-btn--collapsed" : ""}`}
      title={collapsed ? "Déconnexion" : undefined}
      aria-label="Déconnexion"
    >
      <LogOut className="h-[18px] w-[18px] shrink-0" strokeWidth={1.5} />
      {!collapsed && <span className="truncate">Déconnexion</span>}
    </button>
  );
}
