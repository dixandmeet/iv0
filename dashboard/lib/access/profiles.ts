import type { Permission } from "./permissions";
import type { StaffRole } from "@/lib/types";

/**
 * Profils métier Aule Pro. Un utilisateur peut en cumuler plusieurs
 * (ex: `driver` + `merchant`). Les modules et permissions se cumulent alors
 * automatiquement — voir `resolvePermissions`.
 *
 * Pour ajouter un profil futur (chauffeur scolaire, conducteur ferroviaire,
 * inspecteur, opérateur réseau…) : ajouter une clé ici + son entrée dans
 * `PROFILE_PERMISSIONS` + `PROFILE_META`. Aucune autre modification requise.
 */
export const PROFILES = [
  "driver", // Conducteur / Chauffeur
  "vtc", // Chauffeur VTC
  "controller", // Contrôleur
  "operations", // Agent exploitation / Régulateur
  "supervisor", // Agent maîtrise / Dépôt / Ligne
  "merchant", // Commerçant
  "platform_admin", // Équipe interne Aule
  "super_admin", // Super-administrateur (toutes permissions)
  "admin", // Compatibilité legacy : super-administrateur
] as const;

export type Profile = (typeof PROFILES)[number];

export interface ProfileMeta {
  key: Profile;
  label: string;
  /** Groupe fonctionnel, aligné sur l'arborescence des modules. */
  domain: "transport" | "commerce";
}

export const PROFILE_META: Record<Profile, ProfileMeta> = {
  driver: { key: "driver", label: "Conducteur", domain: "transport" },
  vtc: { key: "vtc", label: "Chauffeur VTC", domain: "transport" },
  controller: { key: "controller", label: "Contrôleur", domain: "transport" },
  operations: {
    key: "operations",
    label: "Exploitation / Régulateur",
    domain: "transport",
  },
  supervisor: {
    key: "supervisor",
    label: "Agent de maîtrise",
    domain: "transport",
  },
  merchant: { key: "merchant", label: "Commerçant", domain: "commerce" },
  platform_admin: {
    key: "platform_admin",
    label: "Administrateur Aule",
    domain: "transport",
  },
  super_admin: {
    key: "super_admin",
    label: "Super administrateur",
    domain: "transport",
  },
  admin: { key: "admin", label: "Administrateur legacy", domain: "transport" },
};

/** Permissions Core accordées à tout utilisateur professionnel authentifié. */
export const CORE_PERMISSIONS: Permission[] = [
  "core.dashboard",
  "core.map",
  "core.notifications",
  "core.messaging",
  "core.profile",
  "community.discussions",
  "community.reports",
];

/**
 * Permissions accordées PAR DÉFAUT par chaque profil (hors Core, ajouté
 * partout). Modifiable individuellement via des overrides utilisateur.
 */
export const PROFILE_PERMISSIONS: Record<Profile, Permission[]> = {
  driver: [
    "driver.take_service",
    "driver.geolocation",
    "driver.assistant",
    "driver.incident_report",
    "driver.rosters",
    "driver.services",
    "driver.vehicle",
    "driver.network_info",
    "driver.service_exchange",
    "driver.history",
  ],
  vtc: [
    "vtc.rides",
    "vtc.availability",
    "vtc.history",
    "vtc.earnings",
    "vtc.schedule",
    "vtc.stats",
    "vtc.messaging",
  ],
  controller: [
    "control.missions",
    "control.map_ops",
    "control.controls",
    "control.penalties",
    "control.team",
    "control.personal_stats",
    "control.validation",
    "control.history",
    "ops.incidents",
  ],
  operations: [
    "ops.network_view",
    "ops.fleet_tracking",
    "ops.missions_manage",
    "ops.announcements",
    "ops.disruptions",
    "ops.notifications",
    "ops.incidents",
    "ops.teams",
    "ops.stats",
    "control.map_ops",
  ],
  supervisor: [
    "supervision.services_manage",
    "supervision.validate_service",
    "supervision.agents_manage",
    "supervision.habilitations",
    "supervision.stats",
    "ops.fleet_tracking",
    "ops.announcements",
    "ops.incidents",
    "ops.teams",
  ],
  merchant: [
    "commerce.store",
    "commerce.catalog",
    "commerce.orders",
    "commerce.promotions",
    "commerce.hours",
    "commerce.deliveries",
    "commerce.reviews",
    "commerce.employees",
    "commerce.stats",
  ],
  platform_admin: [
    "admin.dashboard",
    "admin.supervision",
    "admin.networks",
    "admin.users",
    "admin.marketplace",
    "admin.analytics",
    "admin.permissions",
    "admin.roles",
    "admin.apis",
    "admin.logs",
    "admin.backups",
    "admin.communications",
    "admin.storage",
    "admin.monitoring",
    "admin.integrations",
  ],
  super_admin: [], // rempli dynamiquement : super_admin a toutes les permissions
  admin: [], // legacy rempli dynamiquement
};

export function isProfile(value: string): value is Profile {
  return (PROFILES as readonly string[]).includes(value);
}

/**
 * Pont temporaire : tant que la base ne stocke qu'un `role` unique
 * (`user_profiles.role`), on en dérive la liste de profils. À remplacer par la
 * lecture de `profile_assignments` une fois la migration DB effectuée.
 */
export function profilesFromStaffRole(role: StaffRole): Profile[] {
  switch (role) {
    case "driver":
      return ["driver"];
    case "msr_agent":
      return ["controller"];
    case "msr_supervisor":
      return ["supervisor"];
    case "regulator":
      return ["operations"];
    case "admin":
      return ["super_admin"];
    case "passenger":
    default:
      return [];
  }
}
