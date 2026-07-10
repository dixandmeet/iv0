import Link from "next/link";
import {
  BellRing,
  Bike,
  Boxes,
  BriefcaseBusiness,
  BusFront,
  CarTaxiFront,
  CheckCircle2,
  ChevronRight,
  ClipboardCheck,
  Command,
  Database,
  Gauge,
  History,
  LineChart,
  LockKeyhole,
  MonitorCog,
  Navigation,
  Radio,
  Route,
  ShoppingBag,
  SlidersHorizontal,
  Smartphone,
  Store,
  Truck,
  Users,
  type LucideIcon,
} from "lucide-react";
import { cn } from "@/lib/utils";

type Metric = {
  label: string;
  value: string;
  delta: string;
  tone?: "blue" | "green" | "amber" | "red" | "violet";
};

type WorkItem = {
  title: string;
  detail: string;
  status: string;
  tone?: "blue" | "green" | "amber" | "red" | "violet";
};

type WorkspacePrototype = {
  key: string;
  href: string;
  title: string;
  eyebrow: string;
  description: string;
  icon: LucideIcon;
  accent: string;
  nav: string[];
  metrics: Metric[];
  focusTitle: string;
  focusSubtitle: string;
  focusItems: WorkItem[];
  activity: WorkItem[];
  permissions: string[];
  forbidden: string[];
};

const toneClasses = {
  blue: "border-blue-400/25 bg-blue-500/10 text-blue-100",
  green: "border-emerald-400/25 bg-emerald-500/10 text-emerald-100",
  amber: "border-amber-400/25 bg-amber-500/10 text-amber-100",
  red: "border-red-400/25 bg-red-500/10 text-red-100",
  violet: "border-violet-400/25 bg-violet-500/10 text-violet-100",
};

export const proWorkspaces: WorkspacePrototype[] = [
  {
    key: "conducteur",
    href: "/pro/conducteur",
    title: "Espace conducteur",
    eyebrow: "Aule Pro terrain",
    description:
      "Une console de service réduite à l'essentiel: prise de service, véhicule, navigation, messages et échanges, sans accès aux paramètres réseau.",
    icon: BusFront,
    accent: "#3b82f6",
    nav: [
      "Prise de service",
      "Planning",
      "Services",
      "Véhicule",
      "Navigation",
      "Messagerie",
      "Signalements",
      "Échanges",
      "Infos réseau",
      "Historique",
      "Profil",
    ],
    metrics: [
      { label: "Service", value: "C6-142", delta: "départ 07:42", tone: "blue" },
      { label: "Ponctualité", value: "+1 min", delta: "dans la tolérance", tone: "green" },
      { label: "Véhicule", value: "Bus 418", delta: "batterie 82%", tone: "blue" },
      { label: "Alertes", value: "2", delta: "sur le parcours", tone: "amber" },
    ],
    focusTitle: "Assistant de conduite",
    focusSubtitle: "Ligne C6 · Gare Sud vers Chantrerie",
    focusItems: [
      { title: "Prochain arrêt", detail: "Commerce · correspondances T1, C1, 12", status: "480 m", tone: "blue" },
      { title: "Consigne active", detail: "Maintenir 35 km/h jusqu'à Duchesse Anne", status: "OK", tone: "green" },
      { title: "Signalement voyageur", detail: "Forte affluence déclarée à Bouffay", status: "à confirmer", tone: "amber" },
    ],
    activity: [
      { title: "Prise de service validée", detail: "GPS + dépôt Dalby", status: "07:31", tone: "green" },
      { title: "Message exploitation", detail: "Déviation mineure après 09:15", status: "lu", tone: "blue" },
      { title: "Échange demandé", detail: "Service C6-188 vendredi", status: "en attente", tone: "amber" },
    ],
    permissions: ["service personnel", "véhicule affecté", "navigation", "messagerie", "signalements"],
    forbidden: ["paramètres réseau", "gestion conducteurs", "analytics globales", "rôles"],
  },
  {
    key: "controleur",
    href: "/pro/controleur",
    title: "Espace contrôleur",
    eyebrow: "Aule Pro contrôle",
    description:
      "Missions, carte opérationnelle, contrôles, procès-verbaux et coordination d'équipe dans une interface mobile-first.",
    icon: ClipboardCheck,
    accent: "#22c55e",
    nav: [
      "Missions",
      "Carte",
      "Contrôles",
      "Procès-verbaux",
      "Discussion",
      "Équipe",
      "Signalements",
      "Planning",
      "Historique",
      "Stats perso",
    ],
    metrics: [
      { label: "Mission", value: "M-204", delta: "secteur centre", tone: "green" },
      { label: "Contrôles", value: "68", delta: "+12 ce matin", tone: "blue" },
      { label: "PV", value: "5", delta: "2 à finaliser", tone: "amber" },
      { label: "Équipe", value: "4/4", delta: "tous en ligne", tone: "green" },
    ],
    focusTitle: "Mission active",
    focusSubtitle: "Commerce · Bouffay · Hôtel Dieu",
    focusItems: [
      { title: "Point de rencontre", detail: "Quai A, validation chef d'équipe", status: "08:20", tone: "green" },
      { title: "Contrôle renforcé", detail: "Flux élevé sur T1 vers Beaujoire", status: "priorité", tone: "amber" },
      { title: "PV numérique", detail: "Signature et envoi sécurisé", status: "prêt", tone: "blue" },
    ],
    activity: [
      { title: "Zone mise à jour", detail: "Buffer GTFS étendu à Commerce", status: "08:03", tone: "blue" },
      { title: "Signalement clos", detail: "Incivilité T2, équipe sur place", status: "07:58", tone: "green" },
      { title: "Renfort disponible", detail: "Binôme 12 à 6 minutes", status: "live", tone: "green" },
    ],
    permissions: ["missions", "contrôles", "PV", "discussion équipe", "stats personnelles"],
    forbidden: ["paramètres Aule", "produits commerçants", "création réseaux", "exports globaux"],
  },
  {
    key: "exploitation",
    href: "/pro/exploitation",
    title: "Centre d'exploitation",
    eyebrow: "Aule Pro opérations",
    description:
      "Supervision temps réel pour les agents de maîtrise et d'exploitation: véhicules, incidents, équipes, info voyageurs et notifications.",
    icon: MonitorCog,
    accent: "#60a5fa",
    nav: [
      "Véhicules",
      "Carte temps réel",
      "Info voyageurs",
      "Perturbations",
      "Notifications",
      "Missions",
      "Équipes",
      "Incidents",
      "Statistiques",
    ],
    metrics: [
      { label: "Véhicules", value: "184", delta: "172 en service", tone: "blue" },
      { label: "Incidents", value: "7", delta: "2 critiques", tone: "red" },
      { label: "Info publiée", value: "14", delta: "3 programmées", tone: "green" },
      { label: "Ponctualité", value: "91%", delta: "+3 pts", tone: "green" },
    ],
    focusTitle: "Carte réseau temps réel",
    focusSubtitle: "Bus · Tram · VTC · incidents · missions",
    focusItems: [
      { title: "Perturbation T1", detail: "Obstacle voie entre Commerce et Duchesse Anne", status: "critique", tone: "red" },
      { title: "Notification prête", detail: "Voyageurs impactés sur C6 et T1", status: "12 420", tone: "amber" },
      { title: "Mission créée", detail: "Équipe MSR vers Commerce", status: "assignée", tone: "green" },
    ],
    activity: [
      { title: "Bus 418 repris", detail: "Retard ramené de +8 à +3", status: "live", tone: "green" },
      { title: "Annonce voyageurs", detail: "Déviation C6 publiée", status: "08:14", tone: "blue" },
      { title: "Incident escaladé", detail: "Maintenance tram informée", status: "08:11", tone: "red" },
    ],
    permissions: ["flotte", "incidents", "missions", "info voyageurs", "stats opérationnelles"],
    forbidden: ["facturation Aule", "rôles globaux", "stockage", "sauvegardes"],
  },
  {
    key: "vtc",
    href: "/pro/vtc",
    title: "Espace chauffeur VTC",
    eyebrow: "Aule Pro mobilité à la demande",
    description:
      "Courses, disponibilités, planning, revenus et messagerie pour les chauffeurs VTC connectés à l'écosystème Aule.",
    icon: CarTaxiFront,
    accent: "#a78bfa",
    nav: [
      "Courses",
      "Disponibilités",
      "Historique",
      "Revenus",
      "Planning",
      "Statistiques",
      "Messagerie",
      "Profil",
    ],
    metrics: [
      { label: "Courses", value: "9", delta: "2 réservées", tone: "violet" },
      { label: "Revenus", value: "186 €", delta: "+24 €", tone: "green" },
      { label: "Disponibilité", value: "Actif", delta: "zone centre", tone: "green" },
      { label: "Note", value: "4,9", delta: "128 avis", tone: "blue" },
    ],
    focusTitle: "Course en approche",
    focusSubtitle: "Nantes Gare Sud vers Trentemoult",
    focusItems: [
      { title: "Client", detail: "Arrivée estimée dans 4 minutes", status: "confirmé", tone: "green" },
      { title: "Itinéraire", detail: "Trafic fluide via Quai de la Fosse", status: "18 min", tone: "blue" },
      { title: "Paiement", detail: "Carte enregistrée, préautorisation OK", status: "sécurisé", tone: "violet" },
    ],
    activity: [
      { title: "Course terminée", detail: "Aéroport vers Commerce", status: "34 €", tone: "green" },
      { title: "Créneau ouvert", detail: "18:00-22:30", status: "publié", tone: "blue" },
      { title: "Message client", detail: "Besoin siège enfant", status: "à lire", tone: "amber" },
    ],
    permissions: ["courses", "disponibilités", "revenus", "planning", "messagerie"],
    forbidden: ["bus", "missions MSR", "incidents réseau", "paramètres système"],
  },
  {
    key: "commercant",
    href: "/pro/commercant",
    title: "Espace commerçant",
    eyebrow: "Aule Pro commerce",
    description:
      "Un cockpit de boutique inspiré Shopify: produits, catégories, commandes, promotions, horaires, livraisons, avis et employés.",
    icon: Store,
    accent: "#f59e0b",
    nav: [
      "Boutique",
      "Produits",
      "Catégories",
      "Commandes",
      "Promotions",
      "Horaires",
      "Livraisons",
      "Statistiques",
      "Avis",
      "Employés",
    ],
    metrics: [
      { label: "Commandes", value: "42", delta: "8 à préparer", tone: "amber" },
      { label: "CA jour", value: "1 284 €", delta: "+18%", tone: "green" },
      { label: "Produits", value: "126", delta: "7 masqués", tone: "blue" },
      { label: "Avis", value: "4,8", delta: "312 notes", tone: "green" },
    ],
    focusTitle: "Commandes boutique",
    focusSubtitle: "Préparation · retrait · livraison",
    focusItems: [
      { title: "Commande #A-1842", detail: "Menu midi x2, retrait station Commerce", status: "12 min", tone: "amber" },
      { title: "Promotion active", detail: "-15% sur paniers avant 11:30", status: "live", tone: "green" },
      { title: "Livraison", detail: "Coursier disponible à 650 m", status: "assigner", tone: "blue" },
    ],
    activity: [
      { title: "Produit publié", detail: "Formule végétarienne", status: "08:05", tone: "green" },
      { title: "Avis reçu", detail: "5 étoiles, commande #A-1811", status: "nouveau", tone: "blue" },
      { title: "Stock faible", detail: "Boissons fraîches", status: "alerte", tone: "amber" },
    ],
    permissions: ["boutique", "produits", "commandes", "promotions", "employés"],
    forbidden: ["bus", "conducteurs", "missions", "incidents", "autres commerçants"],
  },
];

export const adminModules = [
  { title: "Dashboard", detail: "KPIs, carte, activité, alertes", icon: Gauge, tone: "blue" as const },
  { title: "Supervision", detail: "Bus, trams, VTC, taxis, incidents, missions", icon: Radio, tone: "green" as const },
  { title: "Réseaux", detail: "Dépôts, lignes, arrêts, véhicules, statistiques", icon: Route, tone: "blue" as const },
  { title: "Utilisateurs", detail: "Voyageurs, pros, admins, habilitations, appareils", icon: Users, tone: "violet" as const },
  { title: "Marketplace", detail: "Commerçants, produits, commandes, paiements", icon: ShoppingBag, tone: "amber" as const },
  { title: "Analytics", detail: "Graphiques, heatmaps, exports, comparaisons", icon: LineChart, tone: "green" as const },
  { title: "Administration", detail: "Permissions, API, logs, sauvegardes, monitoring", icon: SlidersHorizontal, tone: "red" as const },
];

const travelerFeatures = [
  { title: "Itinéraire", detail: "Recherche multimodale avec marche, bus, tram, VTC", icon: Route },
  { title: "Suivi véhicules", detail: "Positions en direct et estimation fiable", icon: Navigation },
  { title: "Alertes", detail: "Perturbations, arrivée et descente", icon: BellRing },
  { title: "Commerce", detail: "Commande locale, livraison et retrait station", icon: ShoppingBag },
  { title: "Taxi / VTC", detail: "Réservation et suivi de course", icon: CarTaxiFront },
  { title: "Livraisons", detail: "Suivi temps réel depuis l'app voyageur", icon: Truck },
];

export function EcosystemOverview() {
  return (
    <main className="min-h-screen bg-[#050b18] text-white">
      <section className="mx-auto grid w-full max-w-7xl gap-8 px-4 py-10 sm:px-6 lg:grid-cols-[1.05fr_0.95fr] lg:px-8 lg:py-14">
        <div className="flex min-h-[560px] flex-col justify-between rounded-lg border border-white/10 bg-white/[0.03] p-6 shadow-2xl shadow-black/30">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full border border-blue-400/25 bg-blue-500/10 px-3 py-1 text-xs font-semibold text-blue-100">
              <Command className="h-3.5 w-3.5" />
              Écosystème Aule
            </div>
            <h1 className="mt-6 max-w-3xl text-4xl font-bold tracking-tight text-white sm:text-6xl">
              Trois applications, un seul modèle d&apos;accès.
            </h1>
            <p className="mt-5 max-w-2xl text-base leading-7 text-slate-300 sm:text-lg">
              Aule Voyageur reste public, Aule Pro adapte son interface au métier connecté,
              et Aule Admin administre toute la plateforme depuis un back-office séparé.
            </p>
          </div>
          <div className="grid gap-3 sm:grid-cols-3">
            <AppPillar title="Aule Voyageur" detail="Grand public, zéro administration" icon={Smartphone} href="#voyageur" />
            <AppPillar title="Aule Pro" detail="Cinq espaces métier isolés" icon={BriefcaseBusiness} href="#pro" />
            <AppPillar title="Aule Admin" detail="Interne Aule uniquement" icon={LockKeyhole} href="/admin" />
          </div>
        </div>

        <TravelerPhone />
      </section>

      <section id="voyageur" className="mx-auto w-full max-w-7xl px-4 pb-12 sm:px-6 lg:px-8">
        <SectionHeader
          eyebrow="Aule Voyageur"
          title="Une expérience grand public sans back-office."
          description="Recherche, horaires, alertes, commandes, VTC, taxis et livraisons sont exposés comme des parcours utilisateur, jamais comme des outils d'administration."
        />
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {travelerFeatures.map((feature) => (
            <FeatureTile key={feature.title} {...feature} />
          ))}
        </div>
      </section>

      <section id="pro" className="mx-auto w-full max-w-7xl px-4 pb-14 sm:px-6 lg:px-8">
        <SectionHeader
          eyebrow="Aule Pro"
          title="Une application métier, cinq postes de travail."
          description="Le shell, les menus et les actions sont dérivés des permissions effectives: rôle, réseau, dépôt, métier, habilitations et overrides."
        />
        <div className="grid gap-4 lg:grid-cols-5">
          {proWorkspaces.map((workspace) => (
            <Link
              key={workspace.key}
              href={workspace.href}
              className="group rounded-lg border border-white/10 bg-white/[0.035] p-4 transition hover:-translate-y-0.5 hover:border-blue-300/40 hover:bg-white/[0.06]"
            >
              <workspace.icon className="h-5 w-5 text-blue-200" />
              <h3 className="mt-4 text-sm font-semibold text-white">{workspace.title}</h3>
              <p className="mt-2 min-h-[60px] text-xs leading-5 text-slate-400">
                {workspace.nav.slice(0, 5).join(" · ")}
              </p>
              <span className="mt-4 inline-flex items-center text-xs font-semibold text-blue-200">
                Ouvrir le cockpit
                <ChevronRight className="ml-1 h-3.5 w-3.5 transition group-hover:translate-x-0.5" />
              </span>
            </Link>
          ))}
        </div>
      </section>
    </main>
  );
}

export function RoleWorkspace({ workspace }: { workspace: WorkspacePrototype }) {
  const Icon = workspace.icon;

  return (
    <main className="min-h-screen bg-[#050b18] text-white">
      <section className="mx-auto w-full max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-white/10 pb-5">
          <div className="flex items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-lg border border-white/10 bg-white/[0.05]">
              <Icon className="h-5 w-5" style={{ color: workspace.accent }} />
            </div>
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">
                {workspace.eyebrow}
              </p>
              <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">{workspace.title}</h1>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <StatusPill label="Permissions actives" tone="green" />
            <StatusPill label="Réseau TAN · Dépôt Dalby" tone="blue" />
          </div>
        </div>

        <p className="mt-5 max-w-3xl text-sm leading-6 text-slate-300 sm:text-base">
          {workspace.description}
        </p>

        <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {workspace.metrics.map((metric) => (
            <MetricCard key={metric.label} metric={metric} />
          ))}
        </div>

        <div className="mt-6 grid gap-4 lg:grid-cols-[230px_minmax(0,1fr)_310px]">
          <aside className="rounded-lg border border-white/10 bg-white/[0.035] p-3">
            <p className="px-2 pb-2 text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">
              Navigation métier
            </p>
            <div className="space-y-1">
              {workspace.nav.map((item, index) => (
                <button
                  key={item}
                  className={cn(
                    "flex h-9 w-full items-center justify-between rounded-lg px-3 text-left text-sm transition",
                    index === 0
                      ? "bg-blue-500/15 text-white"
                      : "text-slate-400 hover:bg-white/[0.05] hover:text-white",
                  )}
                  type="button"
                >
                  <span className="truncate">{item}</span>
                  {index === 0 && <CheckCircle2 className="h-3.5 w-3.5 text-blue-200" />}
                </button>
              ))}
            </div>
          </aside>

          <section className="min-h-[560px] rounded-lg border border-white/10 bg-[#071122]">
            <div className="flex items-center justify-between border-b border-white/10 px-4 py-3">
              <div>
                <h2 className="text-sm font-semibold text-white">{workspace.focusTitle}</h2>
                <p className="text-xs text-slate-400">{workspace.focusSubtitle}</p>
              </div>
              <div className="flex gap-1.5">
                <span className="h-2.5 w-2.5 rounded-full bg-red-400" />
                <span className="h-2.5 w-2.5 rounded-full bg-amber-400" />
                <span className="h-2.5 w-2.5 rounded-full bg-emerald-400" />
              </div>
            </div>
            <OperationalCanvas accent={workspace.accent} />
            <div className="grid gap-3 border-t border-white/10 p-4 md:grid-cols-3">
              {workspace.focusItems.map((item) => (
                <WorkItemCard key={item.title} item={item} />
              ))}
            </div>
          </section>

          <aside className="space-y-4">
            <Panel title="Activité temps réel">
              <div className="space-y-3">
                {workspace.activity.map((item) => (
                  <TimelineItem key={item.title} item={item} />
                ))}
              </div>
            </Panel>

            <Panel title="Accès autorisés">
              <div className="flex flex-wrap gap-2">
                {workspace.permissions.map((permission) => (
                  <StatusPill key={permission} label={permission} tone="green" />
                ))}
              </div>
            </Panel>

            <Panel title="Masqué pour ce métier">
              <div className="flex flex-wrap gap-2">
                {workspace.forbidden.map((permission) => (
                  <StatusPill key={permission} label={permission} tone="red" />
                ))}
              </div>
            </Panel>
          </aside>
        </div>
      </section>
    </main>
  );
}

export function AdminPrototype() {
  const rows = [
    ["Conducteur", "Réseau + dépôt + service", "Aucun paramètre réseau", "driver.*"],
    ["Contrôleur", "Missions + équipe", "Stats personnelles uniquement", "control.*"],
    ["Exploitation", "Réseau + dépôt + habilitations", "Pas de paramètres globaux Aule", "ops.*"],
    ["Commerçant", "Boutique propriétaire", "Aucune donnée transport", "commerce.*"],
    ["Admin Aule", "Plateforme", "Journalisation complète", "admin.*"],
  ];

  return (
    <main className="min-h-screen bg-[#050b18] text-white">
      <section className="mx-auto w-full max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
        <div className="grid gap-6 lg:grid-cols-[1fr_360px]">
          <div className="rounded-lg border border-white/10 bg-white/[0.035] p-6">
            <div className="inline-flex items-center gap-2 rounded-full border border-red-400/25 bg-red-500/10 px-3 py-1 text-xs font-semibold text-red-100">
              <LockKeyhole className="h-3.5 w-3.5" />
              Interne Aule uniquement
            </div>
            <h1 className="mt-5 max-w-3xl text-4xl font-bold tracking-tight sm:text-5xl">
              Aule Admin pilote toute la plateforme.
            </h1>
            <p className="mt-4 max-w-2xl text-base leading-7 text-slate-300">
              Cette application est indépendante d&apos;Aule Pro. Elle centralise supervision,
              réseaux, utilisateurs, marketplace, analytics, permissions, intégrations et audit.
            </p>
          </div>
          <div className="rounded-lg border border-white/10 bg-[#071122] p-5">
            <p className="text-sm font-semibold text-white">État plateforme</p>
            <div className="mt-4 grid grid-cols-2 gap-3">
              <MetricCard metric={{ label: "Réseaux", value: "18", delta: "3 pilotes", tone: "blue" }} />
              <MetricCard metric={{ label: "Utilisateurs", value: "284k", delta: "+12%", tone: "green" }} />
              <MetricCard metric={{ label: "Alertes", value: "27", delta: "4 critiques", tone: "red" }} />
              <MetricCard metric={{ label: "Uptime", value: "99,98%", delta: "30 jours", tone: "green" }} />
            </div>
          </div>
        </div>

        <div className="mt-6 grid gap-4 lg:grid-cols-7">
          {adminModules.map((module) => (
            <div
              key={module.title}
              className="rounded-lg border border-white/10 bg-white/[0.035] p-4"
            >
              <module.icon className="h-5 w-5 text-blue-200" />
              <h2 className="mt-4 text-sm font-semibold">{module.title}</h2>
              <p className="mt-2 text-xs leading-5 text-slate-400">{module.detail}</p>
            </div>
          ))}
        </div>

        <div className="mt-6 grid gap-4 lg:grid-cols-[1fr_360px]">
          <section className="rounded-lg border border-white/10 bg-[#071122]">
            <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
              <div>
                <h2 className="text-sm font-semibold">Matrice RBAC configurable</h2>
                <p className="text-xs text-slate-400">
                  Les droits sont composés par rôle, réseau, dépôt, métier, habilitations et permissions spécifiques.
                </p>
              </div>
              <StatusPill label="Aucun rôle codé en dur" tone="green" />
            </div>
            <div className="overflow-x-auto">
              <table className="w-full min-w-[720px] text-left text-sm">
                <thead className="border-b border-white/10 text-xs uppercase tracking-[0.14em] text-slate-500">
                  <tr>
                    <th className="px-5 py-3">Profil</th>
                    <th className="px-5 py-3">Portée</th>
                    <th className="px-5 py-3">Restriction</th>
                    <th className="px-5 py-3">Permissions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/10">
                  {rows.map((row) => (
                    <tr key={row[0]}>
                      {row.map((cell, index) => (
                        <td
                          key={cell}
                          className={cn(
                            "px-5 py-4 text-slate-300",
                            index === 0 && "font-semibold text-white",
                          )}
                        >
                          {cell}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <aside className="space-y-4">
            <Panel title="Administration système">
              <IconList
                items={[
                  ["API & intégrations", Database],
                  ["Emails, SMS, push", BellRing],
                  ["Logs & audit", History],
                  ["Backups & stockage", Boxes],
                  ["Monitoring", Gauge],
                ]}
              />
            </Panel>
            <Panel title="Sécurité">
              <div className="space-y-2">
                <StatusPill label="Permissions héritées visibles" tone="blue" />
                <StatusPill label="Overrides auditables" tone="green" />
                <StatusPill label="Séparation Pro/Admin stricte" tone="red" />
              </div>
            </Panel>
          </aside>
        </div>
      </section>
    </main>
  );
}

function TravelerPhone() {
  return (
    <div className="rounded-lg border border-white/10 bg-[#071122] p-4 shadow-2xl shadow-black/30">
      <div className="mx-auto max-w-[360px] rounded-[32px] border border-white/15 bg-black p-3">
        <div className="overflow-hidden rounded-[24px] bg-[#091426]">
          <div className="flex items-center justify-between border-b border-white/10 px-4 py-3 text-xs text-slate-400">
            <span>09:41</span>
            <span>Aule Voyageur</span>
          </div>
          <div className="p-4">
            <div className="rounded-lg bg-white px-4 py-3 text-sm font-semibold text-slate-950">
              Commerce vers Gare Sud
            </div>
            <div className="mt-4 h-56 rounded-lg border border-white/10 bg-[#10213b] p-4">
              <div className="relative h-full overflow-hidden rounded-lg bg-[#0b172a]">
                <div className="absolute left-8 top-5 h-44 w-1 rounded-full bg-blue-400" />
                <div className="absolute left-8 top-14 h-20 w-20 rounded-full border border-emerald-400/60" />
                <div className="absolute left-[5.9rem] top-20 flex h-9 w-9 items-center justify-center rounded-lg bg-blue-500 text-white">
                  <BusFront className="h-4 w-4" />
                </div>
                <div className="absolute bottom-5 right-4 rounded-lg bg-white/10 px-3 py-2 text-xs">
                  arrivée dans <strong className="text-white">4 min</strong>
                </div>
              </div>
            </div>
            <div className="mt-4 grid grid-cols-3 gap-2 text-center text-xs text-slate-300">
              <MiniAction icon={Route} label="Trajet" />
              <MiniAction icon={ShoppingBag} label="Commander" />
              <MiniAction icon={CarTaxiFront} label="VTC" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function OperationalCanvas({ accent }: { accent: string }) {
  const markers: { left: string; top: string; icon: LucideIcon }[] = [
    { left: "18%", top: "34%", icon: BusFront },
    { left: "44%", top: "48%", icon: CarTaxiFront },
    { left: "68%", top: "26%", icon: Truck },
    { left: "76%", top: "64%", icon: Bike },
  ];

  return (
    <div className="relative h-[340px] overflow-hidden bg-[#091426]">
      <div className="absolute inset-0 opacity-40 [background-image:linear-gradient(rgba(255,255,255,.08)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,.08)_1px,transparent_1px)] [background-size:42px_42px]" />
      <div className="absolute left-[8%] top-[18%] h-1 w-[82%] rotate-[-8deg] rounded-full" style={{ backgroundColor: accent }} />
      <div className="absolute left-[18%] top-[72%] h-1 w-[62%] rotate-[16deg] rounded-full bg-emerald-400" />
      <div className="absolute left-[42%] top-[12%] h-[75%] w-1 rotate-[5deg] rounded-full bg-amber-400" />
      {markers.map(({ left, top, icon: MarkerIcon }, index) => {
        return (
          <div
            key={`${left}-${top}`}
            className="absolute flex h-10 w-10 items-center justify-center rounded-lg border border-white/15 bg-white/10 shadow-lg shadow-black/30 backdrop-blur"
            style={{ left, top }}
          >
            <MarkerIcon className="h-5 w-5 text-white" />
            {index === 0 && <span className="absolute -right-1 -top-1 h-3 w-3 rounded-full bg-emerald-400 ring-4 ring-emerald-400/20" />}
          </div>
        );
      })}
      <div className="absolute right-4 top-4 rounded-lg border border-white/10 bg-black/30 px-3 py-2 text-xs text-slate-300 backdrop-blur">
        Carte active · temps réel
      </div>
    </div>
  );
}

function SectionHeader({
  eyebrow,
  title,
  description,
}: {
  eyebrow: string;
  title: string;
  description: string;
}) {
  return (
    <div className="mb-5">
      <p className="text-xs font-semibold uppercase tracking-[0.18em] text-blue-200">{eyebrow}</p>
      <h2 className="mt-2 text-2xl font-bold tracking-tight text-white sm:text-3xl">{title}</h2>
      <p className="mt-3 max-w-3xl text-sm leading-6 text-slate-400">{description}</p>
    </div>
  );
}

function AppPillar({
  title,
  detail,
  icon: Icon,
  href,
}: {
  title: string;
  detail: string;
  icon: LucideIcon;
  href: string;
}) {
  return (
    <Link href={href} className="rounded-lg border border-white/10 bg-white/[0.04] p-4 transition hover:bg-white/[0.07]">
      <Icon className="h-5 w-5 text-blue-200" />
      <h2 className="mt-3 text-sm font-semibold">{title}</h2>
      <p className="mt-1 text-xs leading-5 text-slate-400">{detail}</p>
    </Link>
  );
}

function FeatureTile({
  title,
  detail,
  icon: Icon,
}: {
  title: string;
  detail: string;
  icon: LucideIcon;
}) {
  return (
    <div className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
      <Icon className="h-5 w-5 text-blue-200" />
      <h3 className="mt-4 text-sm font-semibold">{title}</h3>
      <p className="mt-2 text-xs leading-5 text-slate-400">{detail}</p>
    </div>
  );
}

function MetricCard({ metric }: { metric: Metric }) {
  return (
    <div className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
      <p className="text-xs text-slate-400">{metric.label}</p>
      <div className="mt-2 flex items-end justify-between gap-3">
        <p className="text-2xl font-bold tracking-tight text-white">{metric.value}</p>
        <StatusPill label={metric.delta} tone={metric.tone ?? "blue"} />
      </div>
    </div>
  );
}

function WorkItemCard({ item }: { item: WorkItem }) {
  return (
    <div className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
      <div className="flex items-start justify-between gap-3">
        <h3 className="text-sm font-semibold text-white">{item.title}</h3>
        <StatusPill label={item.status} tone={item.tone ?? "blue"} />
      </div>
      <p className="mt-2 text-xs leading-5 text-slate-400">{item.detail}</p>
    </div>
  );
}

function TimelineItem({ item }: { item: WorkItem }) {
  return (
    <div className="flex gap-3">
      <span className="mt-1 h-2 w-2 shrink-0 rounded-full bg-blue-300" />
      <div className="min-w-0 flex-1">
        <div className="flex items-center justify-between gap-2">
          <p className="truncate text-sm font-medium text-white">{item.title}</p>
          <span className="shrink-0 text-xs text-slate-500">{item.status}</span>
        </div>
        <p className="mt-1 text-xs leading-5 text-slate-400">{item.detail}</p>
      </div>
    </div>
  );
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
      <h2 className="mb-3 text-sm font-semibold text-white">{title}</h2>
      {children}
    </section>
  );
}

function StatusPill({
  label,
  tone = "blue",
}: {
  label: string;
  tone?: "blue" | "green" | "amber" | "red" | "violet";
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border px-2 py-1 text-[11px] font-semibold leading-none",
        toneClasses[tone],
      )}
    >
      {label}
    </span>
  );
}

function MiniAction({ icon: Icon, label }: { icon: LucideIcon; label: string }) {
  return (
    <div className="rounded-lg border border-white/10 bg-white/[0.05] p-2">
      <Icon className="mx-auto h-4 w-4 text-blue-200" />
      <p className="mt-1">{label}</p>
    </div>
  );
}

function IconList({ items }: { items: [string, LucideIcon][] }) {
  return (
    <div className="space-y-2">
      {items.map(([label, Icon]) => (
        <div key={label} className="flex items-center gap-2 text-sm text-slate-300">
          <Icon className="h-4 w-4 text-blue-200" />
          <span>{label}</span>
        </div>
      ))}
    </div>
  );
}
