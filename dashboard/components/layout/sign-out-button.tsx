"use client";

import { createClient } from "@/lib/supabase/client";

export function SignOutButton() {
  async function signOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    window.location.href = "/login";
  }

  return (
    <button
      type="button"
      onClick={signOut}
      style={{
        background: "transparent",
        border: "1px solid var(--border)",
        color: "var(--text)",
        padding: "6px 12px",
        borderRadius: 8,
        cursor: "pointer",
      }}
    >
      Déconnexion
    </button>
  );
}
