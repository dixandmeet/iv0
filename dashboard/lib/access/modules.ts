import {
  AlertTriangle,
  BadgeCheck,
  BarChart3,
  ClipboardCheck,
  ClipboardList,
  Coins,
  Compass,
  CarTaxiFront,
  History,
  LayoutDashboard,
  MapPin,
  Megaphone,
  MessageSquare,
  Navigation,
  NfcIcon,
  Package,
  Radio,
  Repeat2,
  Route,
  ScrollText,
  Settings,
  ShieldAlert,
  ShoppingBag,
  Store,
  Tags,
  Users,
  WalletCards,
  type LucideIcon,
} from "lucide-react";
import type { Permission } from "./permissions";

/** Surfaces d'exécution. Un module peut cibler l'une, l'autre ou les deux. */
export type Surface = "web" | "mobile";

/**
 * Groupes de navigation, alignés sur l'arborescence du brief.
 * L'ordre définit l'ordre d'affichage des sections dans la nav.
 */
export const MODULE_GROUPS = [
  "core",
  "transport",
  "commerce",
  "community",
] as const;
export type ModuleGroup = (typeof MODULE_GROUPS)[number];

export const MODULE_GROUP_LABELS: Record<ModuleGroup, string> = {
  core: "Espace",
  transport: "Transport",
  commerce: "Commerce",
  community: "Communauté",
};

export interface AppModule {
  id: string;
  label: string;
  group: ModuleGroup;
  icon: LucideIcon;
  /** Permission requise pour voir/activer le module. */
  requires: Permission;
  /** Surfaces sur lesquelles le module est pertinent. */
  surfaces: Surface[];
  /** Route (web). Absent => module pas encore implémenté sur cette surface. */
  route?: string;
  /**
   * `ready` : écran existant, affiché dans la nav.
   * `planned` : déclaré dans l'architecture mais pas encore livré ; documenté,
   * non rendu dans la nav.
   */
  status: "ready" | "planned";
}

/**
 * Registre unique des modules. Source de vérité de la navigation : la nav est
 * calculée à partir d'ici (permissions × surface), jamais codée en dur.
 *
 * Ajouter un écran = une entrée ici. Aucune modification du shell ni de la nav.
 */
export const MODULE_REGISTRY: AppModule[] = [
  // ── Core ──────────────────────────────────────────────────────────────────
  {
    id: "core.dashboard",
    label: "Tableau de bord",
    group: "core",
    icon: LayoutDashboard,
    requires: "core.dashboard",
    surfaces: ["web", "mobile"],
    route: "/dashboard",
    status: "ready",
  },
  {
    id: "core.map",
    label: "Carte temps réel",
    group: "core",
    icon: Compass,
    requires: "core.map",
    surfaces: ["web", "mobile"],
    route: "/carte-immersive",
    status: "ready",
  },
  {
    id: "core.messaging",
    label: "Messagerie",
    group: "core",
    icon: MessageSquare,
    requires: "core.messaging",
    surfaces: ["web", "mobile"],
    route: "/communication",
    status: "ready",
  },

  // ── Transport · Conducteur ─────────────────────────────────────────────────
  {
    id: "driver.take_service",
    label: "Prise de service",
    group: "transport",
    icon: NfcIcon,
    requires: "driver.take_service",
    surfaces: ["mobile"], // NFC / OCR : terrain uniquement
    status: "planned",
  },
  {
    id: "driver.assistant",
    label: "Assistant de conduite",
    group: "transport",
    icon: Navigation,
    requires: "driver.assistant",
    surfaces: ["mobile"],
    status: "planned",
  },
  {
    id: "driver.rosters",
    label: "Roulements",
    group: "transport",
    icon: ScrollText,
    requires: "driver.rosters",
    surfaces: ["web", "mobile"],
    status: "planned",
  },
  {
    id: "driver.service_exchange",
    label: "Échange de service",
    group: "transport",
    icon: Repeat2,
    requires: "driver.service_exchange",
    surfaces: ["web", "mobile"],
    status: "planned",
  },
  {
    id: "driver.history",
    label: "Historique",
    group: "transport",
    icon: History,
    requires: "driver.history",
    surfaces: ["web", "mobile"],
    status: "planned",
  },

  // ── Transport · Contrôleur ─────────────────────────────────────────────────
  {
    id: "control.missions",
    label: "Missions",
    group: "transport",
    icon: ClipboardList,
    requires: "control.missions",
    surfaces: ["web", "mobile"],
    route: "/missions",
    status: "ready",
  },
  {
    id: "control.map_ops",
    label: "Carte opérationnelle",
    group: "transport",
    icon: Radio,
    requires: "control.map_ops",
    surfaces: ["web", "mobile"],
    route: "/dashboard",
    status: "ready",
  },
  {
    id: "control.controls",
    label: "Contrôles",
    group: "transport",
    icon: ClipboardCheck,
    requires: "control.controls",
    surfaces: ["mobile"],
    status: "planned",
  },

  // ── Transport · Exploitation / Régulateur ──────────────────────────────────
  {
    id: "ops.network_view",
    label: "Lignes du réseau",
    group: "transport",
    icon: Radio,
    requires: "ops.network_view",
    surfaces: ["web"],
    route: "/dashboard",
    status: "ready",
  },
  {
    id: "ops.network_manage",
    label: "Configuration réseau",
    group: "transport",
    icon: Settings,
    requires: "ops.network_manage",
    surfaces: ["web"],
    route: "/configuration/reseau",
    status: "ready",
  },
  {
    id: "ops.lines",
    label: "Lignes",
    group: "transport",
    icon: Route,
    requires: "ops.fleet_tracking",
    surfaces: ["web"],
    route: "/dashboard/lignes",
    status: "ready",
  },
  {
    id: "ops.stations",
    label: "Arrêts",
    group: "transport",
    icon: MapPin,
    requires: "ops.fleet_tracking",
    surfaces: ["web"],
    route: "/arrets",
    status: "ready",
  },
  {
    id: "ops.alerts",
    label: "Alertes",
    group: "transport",
    icon: AlertTriangle,
    requires: "ops.fleet_tracking",
    surfaces: ["web"],
    route: "/alertes",
    status: "ready",
  },
  {
    id: "ops.incidents",
    label: "Incidents",
    group: "transport",
    icon: ShieldAlert,
    requires: "ops.fleet_tracking",
    surfaces: ["web", "mobile"],
    route: "/incidents",
    status: "ready",
  },
  {
    id: "ops.announcements",
    label: "Info voyageurs",
    group: "transport",
    icon: Megaphone,
    requires: "ops.announcements",
    surfaces: ["web"],
    route: "/info-voyageur",
    status: "ready",
  },
  {
    id: "ops.stats",
    label: "Reporting",
    group: "transport",
    icon: BarChart3,
    requires: "ops.stats",
    surfaces: ["web"],
    route: "/reporting",
    status: "ready",
  },

  // ── Transport à la demande · Chauffeur VTC ────────────────────────────────
  {
    id: "vtc.rides",
    label: "Courses",
    group: "transport",
    icon: CarTaxiFront,
    requires: "vtc.rides",
    surfaces: ["web", "mobile"],
    status: "planned",
  },
  {
    id: "vtc.availability",
    label: "Disponibilités",
    group: "transport",
    icon: BadgeCheck,
    requires: "vtc.availability",
    surfaces: ["web", "mobile"],
    status: "planned",
  },
  {
    id: "vtc.earnings",
    label: "Revenus",
    group: "transport",
    icon: WalletCards,
    requires: "vtc.earnings",
    surfaces: ["web", "mobile"],
    status: "planned",
  },
  {
    id: "vtc.stats",
    label: "Statistiques VTC",
    group: "transport",
    icon: BarChart3,
    requires: "vtc.stats",
    surfaces: ["web"],
    status: "planned",
  },

  // ── Transport · Maîtrise / Dépôt / Ligne ───────────────────────────────────
  {
    id: "supervision.agents",
    label: "Conducteurs",
    group: "transport",
    icon: Users,
    requires: "supervision.agents_manage",
    surfaces: ["web"],
    route: "/conducteurs",
    status: "ready",
  },
  {
    id: "supervision.stats",
    label: "Statistiques équipes",
    group: "transport",
    icon: BadgeCheck,
    requires: "supervision.stats",
    surfaces: ["web"],
    route: "/reporting",
    status: "ready",
  },

  // ── Commerce · Commerçant ──────────────────────────────────────────────────
  {
    id: "commerce.catalog",
    label: "Catalogue",
    group: "commerce",
    icon: Store,
    requires: "commerce.catalog",
    surfaces: ["web", "mobile"],
    status: "planned",
  },
  {
    id: "commerce.orders",
    label: "Commandes",
    group: "commerce",
    icon: ShoppingBag,
    requires: "commerce.orders",
    surfaces: ["web", "mobile"],
    status: "planned",
  },
  {
    id: "commerce.promotions",
    label: "Promotions",
    group: "commerce",
    icon: Tags,
    requires: "commerce.promotions",
    surfaces: ["web"],
    status: "planned",
  },
  {
    id: "commerce.stats",
    label: "Statistiques",
    group: "commerce",
    icon: Coins,
    requires: "commerce.stats",
    surfaces: ["web"],
    status: "planned",
  },

  // ── Communauté ─────────────────────────────────────────────────────────────
  {
    id: "community.discussions",
    label: "Discussions",
    group: "community",
    icon: MessageSquare,
    requires: "community.discussions",
    surfaces: ["web", "mobile"],
    route: "/communication",
    status: "ready",
  },
  {
    id: "community.reports",
    label: "Signalements",
    group: "community",
    icon: Package,
    requires: "community.reports",
    surfaces: ["web", "mobile"],
    route: "/incidents",
    status: "ready",
  },
];
