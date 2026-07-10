import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { StaffRole } from "@/lib/types";
import { isPermission, type Permission } from "./permissions";
import { isProfile, profilesFromStaffRole, type Profile } from "./profiles";
import { resolvePermissions, type PermissionOverride } from "./resolve";

export interface AccessState {
  profiles: Profile[];
  permissions: Permission[];
}

/**
 * Charge l'accès effectif d'un utilisateur côté serveur.
 *
 * Résilient à l'état de la base : si `profile_assignments` existe et contient
 * des profils actifs, on les utilise (+ overrides) ; sinon on retombe sur le
 * pont `user_profiles.role`. Le code fonctionne donc identiquement avant et
 * après l'application de la migration multi-profils.
 */
export async function loadAccess(
  supabase: SupabaseClient,
  userId: string,
  role: StaffRole,
): Promise<AccessState> {
  const { data: rows, error } = await supabase
    .from("profile_assignments")
    .select("profile_key")
    .eq("user_id", userId)
    .eq("is_active", true);

  // Table absente (migration pas encore appliquée) ou aucun profil : on dérive
  // du role unique.
  if (error || !rows || rows.length === 0) {
    const profiles = profilesFromStaffRole(role);
    return { profiles, permissions: [...resolvePermissions(profiles)] };
  }

  const profiles = rows
    .map((r) => r.profile_key)
    .filter((k): k is Profile => typeof k === "string" && isProfile(k));

  const overrides = await loadOverrides(supabase, userId);

  return {
    profiles,
    permissions: [...resolvePermissions(profiles, overrides)],
  };
}

async function loadOverrides(
  supabase: SupabaseClient,
  userId: string,
): Promise<PermissionOverride[]> {
  const { data, error } = await supabase
    .from("user_permission_overrides")
    .select("permission, granted")
    .eq("user_id", userId);

  if (error || !data) return [];

  return data
    .filter(
      (o): o is { permission: string; granted: boolean } =>
        typeof o.permission === "string" && isPermission(o.permission),
    )
    .map((o) => ({
      permission: o.permission as Permission,
      granted: Boolean(o.granted),
    }));
}
