"use client";

import type * as React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  AppWindow,
  Bell,
  ChevronRight,
  CircleUserRound,
  Cog,
  Database,
  FileClock,
  Home,
  Layers3,
  Map,
  Search,
  Settings,
  ShoppingBag,
  UserCog,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";

const mainNav = [
  { href: "/admin", label: "Vue d'ensemble", icon: Home },
  { href: "/admin/networks", label: "Réseaux", icon: Layers3 },
  { href: "/admin/map", label: "Carte globale", icon: Map },
  { href: "/admin/users", label: "Utilisateurs", icon: UserCog },
  { href: "/admin/transport-data", label: "Données transport", icon: Database },
  { href: "/admin/apps/voyageur", label: "Aule Voyageur", icon: CircleUserRound },
  { href: "/admin/apps/pro", label: "Aule Pro", icon: Activity },
  { href: "/admin/marketplace", label: "Marketplace", icon: ShoppingBag },
  { href: "/admin/settings", label: "Configuration", icon: AppWindow },
  { href: "/admin/logs", label: "Logs", icon: FileClock },
] as const;

const secondaryNav = [
  { href: "/admin/permissions", label: "RBAC avancé", icon: Settings },
  { href: "/admin/account", label: "Mon compte", icon: CircleUserRound },
] as const;

export function AdminShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [displayName, setDisplayName] = useState<string | null>(null);
  const [authenticated, setAuthenticated] = useState<boolean | null>(null);
  const [lastSyncedAt, setLastSyncedAt] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    const supabase = createClient();
    const syncTimeTimer = window.setTimeout(() => {
      if (alive) setLastSyncedAt(new Date().toLocaleTimeString("fr-FR"));
    }, 0);

    async function loadSession() {
      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (!alive) return;
      if (!user) {
        setAuthenticated(false);
        setDisplayName(null);
        return;
      }

      const { data: profile } = await supabase
        .from("user_profiles")
        .select("display_name")
        .eq("id", user.id)
        .maybeSingle();

      if (!alive) return;
      setAuthenticated(true);
      setDisplayName(profile?.display_name || user.email || "Administrateur");
    }

    void loadSession();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(() => {
      void loadSession();
    });

    return () => {
      alive = false;
      window.clearTimeout(syncTimeTimer);
      subscription.unsubscribe();
    };
  }, []);

  const initials = useMemo(() => {
    const source = displayName ?? "AD";
    return source
      .split(/[ @._-]+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase())
      .join("") || "AD";
  }, [displayName]);

  const loginHref = `/login?mode=pro&next=${encodeURIComponent(pathname)}`;

  return (
    <div className="admin-app-shell">
      <aside className="admin-app-sidebar">
        <Link href="/admin" className="admin-app-brand">
          <span className="admin-app-brand-mark">A</span>
          <span>
            <span className="admin-app-brand-title">Aule Studio</span>
            <span className="admin-app-brand-subtitle">Mobilité & réseaux</span>
          </span>
        </Link>

        <nav className="admin-app-nav" aria-label="Navigation Aule Studio">
          {mainNav.map((item) => (
            <AdminNavLink
              key={item.href}
              href={item.href}
              icon={item.icon}
              label={item.label}
              active={isNavActive(pathname, item.href)}
            />
          ))}
        </nav>

        <div className="admin-app-nav-secondary">
          {secondaryNav.map((item) => (
            <AdminNavLink
              key={item.href}
              href={item.href}
              icon={item.icon}
              label={item.label}
              active={isNavActive(pathname, item.href)}
            />
          ))}
        </div>

        <div className="admin-app-health-card">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-300">Réseau pilote</span>
            <span className="h-2 w-2 rounded-full bg-emerald-400 shadow-[0_0_18px_rgba(52,211,153,0.9)]" />
          </div>
          <div className="admin-app-health-card-content">
            <p className="text-2xl font-bold leading-none text-white">Naolib</p>
            <p className="mt-1 text-xs text-emerald-100/65">Nantes · actif</p>
          </div>
        </div>
      </aside>

      <div className="admin-app-main">
        <header className="admin-app-header">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-blue-200">
              Aule Studio
            </p>
            <h1 className="mt-1 text-2xl font-bold tracking-tight text-white">
              {authenticated === false
                ? "Connexion requise"
                : `Bonjour ${displayName?.split(" ")[0] ?? "Admin"}`}
            </h1>
            <p className="mt-1 text-xs text-slate-500">
              Pilotage des réseaux, des applications et des données de mobilité · {lastSyncedAt ?? "—"}
            </p>
          </div>
          <div className="admin-app-header-actions">
            <div className="admin-app-search">
              <Search className="h-4 w-4 text-slate-500" />
              <input placeholder="Rechercher réseau, utilisateur, ligne, arrêt, véhicule, commerce..." />
            </div>
            <button className="admin-app-icon-btn" type="button" aria-label="Notifications">
              <Bell className="h-4 w-4" />
            </button>
            <button className="admin-app-icon-btn" type="button" aria-label="Configuration">
              <Cog className="h-4 w-4" />
            </button>
            {authenticated === false ? (
              <Link href={loginHref} className="admin-app-login-btn">
                Connexion
              </Link>
            ) : (
              <button className="admin-app-profile-btn" type="button">
                {initials}
              </button>
            )}
          </div>
        </header>

        {children}
      </div>
    </div>
  );
}

function isNavActive(pathname: string, href: string) {
  if (href === "/admin") return pathname === href;
  return pathname === href || pathname.startsWith(`${href}/`);
}

function AdminNavLink({
  href,
  label,
  icon: Icon,
  active,
}: {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  active: boolean;
}) {
  return (
    <Link href={href} className={cn("admin-app-nav-link", active && "active")}>
      <Icon className="h-4 w-4" />
      <span>{label}</span>
      {active && <ChevronRight className="ml-auto h-4 w-4 text-blue-200" />}
    </Link>
  );
}

export const adminQuickActions = [
  { label: "Nouveau réseau", href: "/admin/networks", icon: Layers3 },
  { label: "Ajouter un utilisateur", href: "/admin/users", icon: UserCog },
  { label: "Envoyer une notification", href: "/admin/exploitation", icon: Bell },
  { label: "Créer une perturbation", href: "/admin/supervision", icon: Activity },
  { label: "Ajouter un commerçant", href: "/admin/marketplace", icon: ShoppingBag },
  { label: "Import GTFS", href: "/admin/networks", icon: Database },
] as const;

export const adminConfigModules = [
  "Plateforme",
  "Réseaux",
  "API",
  "Permissions",
  "Emails",
  "Notifications",
  "Stockage",
  "Paiements",
  "Marketplace",
  "Transport",
  "IA",
  "Sécurité",
  "Logs",
  "Sauvegardes",
] as const;

export const adminUserSegments = [
  { label: "Conducteurs", value: "2 841", href: "/admin/users?segment=drivers" },
  { label: "Contrôleurs", value: "214", href: "/admin/users?segment=controllers" },
  { label: "Voyageurs", value: "18 241", href: "/admin/users?segment=travelers" },
  { label: "Commerçants", value: "52", href: "/admin/users?segment=merchants" },
  { label: "Agents exploitation", value: "74", href: "/admin/users?segment=operations" },
] as const;

export const adminHealthServices = [
  ["API", "ok"],
  ["Supabase", "ok"],
  ["Temps réel", "ok"],
  ["Notifications", "ok"],
  ["Paiements", "ok"],
  ["IA", "warn"],
  ["Stockage", "ok"],
] as const;

export const adminAttentionItems = [
  "3 signalements",
  "1 commerçant désactivé",
  "2 utilisateurs bloqués",
  "1 API indisponible",
] as const;

export const adminActivity = [
  ["19:34", "Kevin vient de prendre son service."],
  ["19:32", "Nouvelle boutique créée"],
  ["19:28", "Notification envoyée"],
  ["19:12", "Nouveau conducteur validé"],
] as const;

export const adminBusinessMetrics = [
  { label: "Plateforme opérationnelle", value: "99,98 %", detail: "disponibilité", tone: "green" },
  { label: "Utilisateurs", value: "12 487", detail: "+231 aujourd'hui", tone: "blue" },
  { label: "Véhicules suivis", value: "318", detail: "Bus 241 · Trams 77", tone: "blue" },
  { label: "Commandes", value: "43", detail: "en cours", tone: "amber" },
  { label: "Incidents", value: "3", detail: "ouverts", tone: "red" },
  { label: "Notifications", value: "12", detail: "envoyées aujourd'hui", tone: "violet" },
] as const;
