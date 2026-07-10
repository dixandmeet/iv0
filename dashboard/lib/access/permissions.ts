/**
 * Catalogue des permissions Aule Pro.
 *
 * Une permission = un droit atomique sur une fonctionnalité. Elle est
 * VOLONTAIREMENT indépendante du profil : un profil accorde un ensemble de
 * permissions par défaut (voir `profiles.ts`), mais on peut en accorder ou en
 * révoquer une individuellement (overrides). Ajouter une fonctionnalité = une
 * nouvelle permission ici, jamais un `if (role === ...)` disséminé dans l'UI.
 *
 * Convention de nommage : `domaine.action`.
 */
export const PERMISSIONS = [
  // ── Core (socle commun, potentiellement accessible à tous) ────────────────
  "core.dashboard",
  "core.map",
  "core.notifications",
  "core.messaging",
  "core.profile",

  // ── Aule Voyageur ─────────────────────────────────────────────────────────
  "traveler.routes",
  "traveler.schedules",
  "traveler.alerts",
  "traveler.commerce_orders",
  "traveler.vtc_booking",
  "traveler.deliveries",

  // ── Transport · Conducteur ────────────────────────────────────────────────
  "driver.take_service", // prise de service (NFC / manuel / OCR)
  "driver.geolocation", // partage GPS pendant le service
  "driver.assistant", // assistant de conduite (avance/retard, prochain arrêt)
  "driver.incident_report", // déclaration d'incident
  "driver.rosters", // roulements (services, vacances, coupures, repos)
  "driver.services",
  "driver.vehicle",
  "driver.network_info",
  "driver.service_exchange", // échange de service
  "driver.history", // historique services / véhicules

  // ── Transport · Contrôleur ────────────────────────────────────────────────
  "control.missions",
  "control.map_ops", // carte opérationnelle (collègues, véhicules, incidents)
  "control.controls", // créer contrôle / fraude / incident
  "control.penalties",
  "control.team",
  "control.personal_stats",
  "control.validation", // valider début / fin de mission
  "control.history",

  // ── Transport · Exploitation / Régulateur ─────────────────────────────────
  "ops.network_view", // vue réseau temps réel
  "ops.fleet_tracking", // suivi véhicules / équipes
  "ops.missions_manage", // créer / piloter les missions
  "ops.announcements", // annonces & info voyageur
  "ops.disruptions",
  "ops.notifications",
  "ops.incidents",
  "ops.teams",
  "ops.stats",

  // ── Transport à la demande · Chauffeur VTC ────────────────────────────────
  "vtc.rides",
  "vtc.availability",
  "vtc.history",
  "vtc.earnings",
  "vtc.schedule",
  "vtc.stats",
  "vtc.messaging",

  // ── Transport · Maîtrise / Dépôt / Ligne ──────────────────────────────────
  "supervision.services_manage", // créer services / équipes / missions
  "supervision.validate_service", // valider prises de service & missions
  "supervision.agents_manage", // gérer agents
  "supervision.habilitations", // gérer habilitations
  "supervision.stats",

  // ── Commerce · Commerçant ─────────────────────────────────────────────────
  "commerce.catalog", // catalogue produits (catégories, photos, prix, dispo)
  "commerce.store",
  "commerce.orders", // commandes (accepter/refuser/préparer/remettre)
  "commerce.promotions",
  "commerce.hours",
  "commerce.deliveries",
  "commerce.reviews",
  "commerce.employees",
  "commerce.stats",

  // ── Aule Admin · Plateforme interne ───────────────────────────────────────
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

  // ── Communauté (transverse) ───────────────────────────────────────────────
  "community.discussions",
  "community.reports", // signalements
] as const;

export type Permission = (typeof PERMISSIONS)[number];

const PERMISSION_SET = new Set<string>(PERMISSIONS);

export function isPermission(value: string): value is Permission {
  return PERMISSION_SET.has(value);
}
