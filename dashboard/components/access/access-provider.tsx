"use client";

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import type { Permission } from "@/lib/access/permissions";
import { isProfile, type Profile } from "@/lib/access/profiles";
import { getNavGroups, resolvePermissions, type NavGroup } from "@/lib/access/resolve";
import type { Surface } from "@/lib/access/modules";

/** Profil sur lequel la navigation est focalisée. `all` = tous cumulés. */
export type ProfileFocus = Profile | "all";

const FOCUS_STORAGE_KEY = "aulepro-profile-focus";

interface AccessContextValue {
  profiles: Profile[];
  permissions: Set<Permission>;
  surface: Surface;
  can: (permission: Permission) => boolean;
  hasProfile: (profile: Profile) => boolean;
  /** Sections de nav visibles, filtrées selon le focus courant. */
  navGroups: NavGroup[];
  focus: ProfileFocus;
  setFocus: (focus: ProfileFocus) => void;
}

const AccessContext = createContext<AccessContextValue | null>(null);

interface AccessProviderProps {
  profiles: Profile[];
  /** Permissions effectives, résolues côté serveur (sérialisées en tableau). */
  permissions: Permission[];
  surface?: Surface;
  children: ReactNode;
}

export function AccessProvider({
  profiles,
  permissions,
  surface = "web",
  children,
}: AccessProviderProps) {
  const [focus, setFocusState] = useState<ProfileFocus>("all");

  // Restaure le focus persisté, en le validant contre les profils réels.
  useEffect(() => {
    const stored = localStorage.getItem(FOCUS_STORAGE_KEY);
    if (stored && isProfile(stored) && profiles.includes(stored)) {
      setFocusState(stored);
    }
  }, [profiles]);

  function setFocus(next: ProfileFocus) {
    setFocusState(next);
    try {
      if (next === "all") localStorage.removeItem(FOCUS_STORAGE_KEY);
      else localStorage.setItem(FOCUS_STORAGE_KEY, next);
    } catch {
      // stockage indisponible (mode privé, quota) — le focus reste en mémoire
    }
  }

  const value = useMemo<AccessContextValue>(() => {
    const permSet = new Set(permissions);
    // Focus « all » : permissions serveur complètes (overrides inclus).
    // Focus sur un profil : on filtre la nav sur les permissions par défaut de
    // ce profil (le droit d'accès `can` reste, lui, sur l'ensemble complet).
    const navPerms =
      focus === "all" ? permSet : resolvePermissions([focus]);
    return {
      profiles,
      permissions: permSet,
      surface,
      can: (permission) => permSet.has(permission),
      hasProfile: (profile) => profiles.includes(profile),
      navGroups: getNavGroups(navPerms, surface),
      focus,
      setFocus,
    };
  }, [profiles, permissions, surface, focus]);

  return (
    <AccessContext.Provider value={value}>{children}</AccessContext.Provider>
  );
}

export function useAccess(): AccessContextValue {
  const ctx = useContext(AccessContext);
  if (!ctx) {
    throw new Error("useAccess doit être utilisé dans un <AccessProvider>");
  }
  return ctx;
}

export function usePermissions(): Set<Permission> {
  return useAccess().permissions;
}

export function useProfiles(): Profile[] {
  return useAccess().profiles;
}

/** Rend ses enfants uniquement si la permission est accordée. */
export function Can({
  permission,
  fallback = null,
  children,
}: {
  permission: Permission;
  fallback?: ReactNode;
  children: ReactNode;
}) {
  const { can } = useAccess();
  return <>{can(permission) ? children : fallback}</>;
}
