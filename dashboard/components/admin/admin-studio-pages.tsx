import type * as React from "react";
import Link from "next/link";
import {
  AlertTriangle,
  ArrowRight,
  Bell,
  BusFront,
  CheckCircle2,
  CircleDashed,
  Database,
  Filter,
  Flag,
  Map,
  MapPin,
  Plus,
  Route,
  Search,
  Settings,
  TramFront,
  UsersRound,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { loadAdminStudioUser, loadAdminStudioUsers } from "@/lib/admin-studio-users";
import { AdminUserDetailEditor } from "./admin-user-detail-editor";
import { AdminUsersDirectory } from "./admin-users-directory";
import { StudioMapWorkspace, StudioMobilityMap } from "./admin-studio-map";
import {
  marketplaceRows,
  proProfiles,
  settingsSections,
  studioConfigurationChecklist,
  studioNetworks,
  studioQuickAccess,
  transportDataGroups,
  travelerChecks,
  type StudioStatus,
} from "./admin-studio-data";

export function AdminStudioHome() {
  const naolib = studioNetworks[0];

  return (
    <main className="admin-app-content">
      <StudioPageHeader
        eyebrow="Vue d'ensemble"
        title="Aule Studio"
        description="Pilotage des réseaux, des applications et des données de mobilité."
        action={
          <Link href="/admin/networks" className="admin-primary-btn">
            <Plus className="h-4 w-4" />
            Ajouter un réseau
          </Link>
        }
      />

      <section className="grid gap-4 xl:grid-cols-[minmax(0,1.08fr)_minmax(360px,.92fr)]">
        <StudioPanel
          title="Réseaux"
          description="Le réseau est l'entité principale. Naolib est visible aujourd'hui, l'interface est prête pour la suite."
          action={<Link href="/admin/networks" className="admin-panel-link">Tout voir</Link>}
        >
          <div className="grid gap-3 lg:grid-cols-2">
            <NetworkCard network={naolib} prominent />
            <article className="rounded-lg border border-dashed border-white/15 bg-white/[0.025] p-4">
              <div className="flex h-full min-h-64 flex-col justify-between gap-4">
                <div>
                  <div className="flex h-10 w-10 items-center justify-center rounded-lg border border-blue-400/25 bg-blue-500/10 text-blue-100">
                    <Plus className="h-5 w-5" />
                  </div>
                  <h3 className="mt-4 text-lg font-bold text-white">Ajouter un réseau</h3>
                  <p className="mt-2 text-sm leading-6 text-slate-400">
                    Préparer un réseau en attente, en configuration ou désactivé sans mélanger ses
                    données avec Naolib.
                  </p>
                </div>
                <Link href="/admin/networks" className="admin-secondary-btn w-fit">
                  Créer la fiche
                </Link>
              </div>
            </article>
          </div>
        </StudioPanel>

        <StudioPanel
          title="État de configuration"
          description="Checklist de lancement, orientée données et expérience produit."
        >
          <ConfigurationChecklist compact />
        </StudioPanel>
      </section>

      <section className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_380px]">
        <StudioPanel
          title="Carte globale"
          description="Vue centrée sur Nantes/Naolib : lignes, arrêts, véhicules et signaux terrain."
          action={<Link href="/admin/map" className="admin-panel-link">Ouvrir la carte</Link>}
        >
          <StudioMobilityMap />
        </StudioPanel>

        <StudioPanel title="Accès rapides" description="Entrées directes vers les opérations utiles au lancement.">
          <div className="grid gap-2">
            {studioQuickAccess.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="flex min-h-12 items-center gap-3 rounded-lg border border-white/10 bg-white/[0.035] px-3 text-sm font-semibold text-slate-200 transition hover:border-blue-400/30 hover:bg-white/[0.06]"
              >
                <item.icon className="h-4 w-4 text-blue-200" />
                <span className="min-w-0 flex-1">{item.label}</span>
                <ArrowRight className="h-4 w-4 text-slate-500" />
              </Link>
            ))}
          </div>
        </StudioPanel>
      </section>
    </main>
  );
}

export function AdminNetworksPage() {
  return (
    <main className="admin-app-content">
      <StudioPageHeader
        eyebrow="Réseaux"
        title="Réseaux inscrits"
        description="Tous les réseaux rattachés à Aule Studio, avec leur contexte produit et leurs modules actifs."
        action={
          <Link href="/admin/networks" className="admin-primary-btn">
            <Plus className="h-4 w-4" />
            Ajouter un réseau
          </Link>
        }
      />
      <FilterBar
        fields={["Recherche réseau, ville ou pays", "Statut", "Ville", "Modules activés"]}
      />
      <section className="grid gap-4 xl:grid-cols-2">
        {studioNetworks.map((network) => (
          <NetworkCard key={network.id} network={network} />
        ))}
      </section>
    </main>
  );
}

export function AdminNetworkDetailPage({ networkId }: { networkId: string }) {
  const network =
    studioNetworks.find((item) => item.id === networkId) ?? studioNetworks[0];

  return (
    <main className="admin-app-content">
      <section className="rounded-lg border border-white/10 bg-white/[0.035] p-5">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-blue-200">
              Réseau
            </p>
            <div className="mt-2 flex flex-wrap items-center gap-3">
              <h1 className="text-3xl font-bold tracking-tight text-white">{network.name}</h1>
              <StatusPill label={network.status} />
            </div>
            <p className="mt-2 text-sm text-slate-400">
              {network.city} · {network.country} · Dernière synchronisation : {network.lastSync}
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Link href="/admin/settings" className="admin-secondary-btn">
              <Settings className="h-4 w-4" />
              Configurer
            </Link>
            <Link href="/admin/map" className="admin-primary-btn">
              <Map className="h-4 w-4" />
              Ouvrir la carte
            </Link>
          </div>
        </div>
        <StudioTabs
          items={[
            "Vue réseau",
            "Carte",
            "Utilisateurs",
            "Lignes",
            "Arrêts",
            "Véhicules",
            "Données GTFS",
            "Applications",
            "Marketplace",
            "Logs",
          ]}
        />
      </section>

      <section className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_420px]">
        <div className="space-y-4">
          <StudioPanel title="Résumé du réseau" description={network.description}>
            <NetworkStats network={network} />
          </StudioPanel>
          <StudioPanel title="Carte du réseau" description="Aperçu opérationnel centré sur Nantes.">
            <StudioMobilityMap dense />
          </StudioPanel>
        </div>
        <div className="space-y-4">
          <StudioPanel title="État de configuration">
            <ConfigurationChecklist compact />
          </StudioPanel>
          <StudioPanel title="Dernières activités">
            <Timeline
              rows={[
                ["20:42", "Synchronisation GTFS vérifiée."],
                ["19:44", "Agent exploitation connecté sur Aule Pro."],
                ["18:12", "Signalement terrain classé en attention."],
              ]}
            />
          </StudioPanel>
          <StudioPanel title="Problèmes à corriger">
            <IssueList
              rows={[
                "Véhicules temps réel en attente de prise de service conducteur.",
                "Notifications réseau à finaliser avant lancement public.",
                "Contexte dépôt à compléter pour certains profils Pro.",
              ]}
            />
          </StudioPanel>
        </div>
      </section>
    </main>
  );
}

export async function AdminUsersStudioPage() {
  const { users, source, warning } = await loadAdminStudioUsers();
  const activeUsers = users.filter((user) => user.status === "Actif").length;
  const proUsers = users.filter((user) => user.userKind === "Utilisateur Pro").length;
  const internalAdmins = users.filter((user) => user.userKind === "Admin interne").length;

  return (
    <main className="admin-app-content">
      <StudioPageHeader
        eyebrow="Utilisateurs"
        title="Utilisateurs par réseau et contexte"
        description="Chaque compte doit montrer clairement son réseau, son profil, ses habilitations et son périmètre applicatif."
      />

      <div className="flex flex-wrap items-center gap-2">
        <StatusPill label={source === "supabase" ? "Source Supabase" : "Source démo"} status={source === "supabase" ? "done" : "attention"} />
        {warning ? <span className="text-xs text-amber-200">{warning}</span> : null}
      </div>

      <section className="grid gap-3 md:grid-cols-3">
        <UserSummaryCard
          label="Comptes visibles"
          value={String(users.length)}
          detail="Tous rattachés à un contexte"
        />
        <UserSummaryCard
          label="Profils Pro"
          value={String(proUsers)}
          detail="Conducteur, contrôle, exploitation, commerce"
        />
        <UserSummaryCard
          label="Admins Studio"
          value={String(internalAdmins)}
          detail={`${activeUsers} comptes actifs au total`}
        />
      </section>

      <AdminUsersDirectory users={users} />
    </main>
  );
}

function UserSummaryCard({
  label,
  value,
  detail,
}: {
  label: string;
  value: string;
  detail: string;
}) {
  return (
    <article className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
      <p className="text-xs font-semibold uppercase tracking-[0.12em] text-slate-500">{label}</p>
      <p className="mt-2 text-2xl font-bold text-white">{value}</p>
      <p className="mt-1 text-xs leading-5 text-slate-400">{detail}</p>
    </article>
  );
}

export async function AdminUserDetailPage({ userId }: { userId: string }) {
  const { user, source, warning } = await loadAdminStudioUser(userId);

  return (
    <main className="admin-app-content">
      <StudioPageHeader
        eyebrow="Utilisateur"
        title={user.name}
        description={`${user.profile} · ${user.network} · ${user.userKind}`}
        action={<Link href="/admin/users" className="admin-secondary-btn">Retour utilisateurs</Link>}
      />
      <div className="flex flex-wrap items-center gap-2">
        <StatusPill label={source === "supabase" ? "Source Supabase" : "Source démo"} status={source === "supabase" ? "done" : "attention"} />
        {warning ? <span className="text-xs text-amber-200">{warning}</span> : null}
      </div>
      <section className="grid items-start gap-4 xl:grid-cols-[minmax(0,1fr)_380px]">
        <AdminUserDetailEditor
          user={user}
          source={source}
          loginHref={`/login?mode=pro&next=${encodeURIComponent(`/admin/users/${userId}`)}`}
        />
      </section>
    </main>
  );
}

export function AdminGlobalMapPage() {
  return (
    <main className="admin-app-content">
      <StudioPageHeader
        eyebrow="Carte globale"
        title="Carte mobilité"
        description="Sélectionner un réseau et inspecter véhicules, arrêts, lignes, commerces, VTC/taxis et incidents."
      />
      <StudioMapWorkspace />
    </main>
  );
}

export function AdminTransportDataPage() {
  return (
    <main className="admin-app-content">
      <StudioPageHeader
        eyebrow="Données transport"
        title="GTFS, lignes, arrêts et véhicules"
        description="Une page technique mais lisible pour gérer imports, correspondances et erreurs de données."
      />
      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {transportDataGroups.map((group) => (
          <article key={group.title} className="admin-business-card">
            <div className="flex items-center justify-between">
              <group.icon className="h-5 w-5 text-blue-200" />
              <span className="rounded-full border border-white/10 bg-white/[0.04] px-2 py-1 text-xs font-semibold text-slate-300">
                {group.status}
              </span>
            </div>
            <h2 className="mt-4 text-lg font-bold text-white">{group.title}</h2>
            <p className="mt-2 text-sm leading-6 text-slate-400">{group.detail}</p>
          </article>
        ))}
      </section>
      <StudioPanel title="Imports et erreurs" description="Aucune donnée n'est supprimée depuis cet écran. Les imports futurs doivent rester auditables.">
        <IssueList
          rows={[
            "Correspondances à contrôler sur les stations multi-lignes.",
            "Dépôts à normaliser pour les habilitations conducteur.",
            "Véhicules visibles seulement après activation géolocalisation Pro.",
          ]}
        />
      </StudioPanel>
    </main>
  );
}

export function AdminTravelerAppPage() {
  return (
    <main className="admin-app-content">
      <StudioPageHeader
        eyebrow="Aule Voyageur"
        title="Configuration de l'expérience voyageur"
        description="Priorité lancement : localisation, itinéraire, environnement, suivi véhicule et alertes trajet."
      />
      <section className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_420px]">
        <StudioPanel title="Aperçu carte voyageur">
          <StudioMobilityMap dense />
        </StudioPanel>
        <StudioPanel title="Checklist Voyageur">
          <StatusList rows={travelerChecks} />
        </StudioPanel>
      </section>
      <StudioPanel title="Données nécessaires et problèmes détectés">
        <div className="grid gap-3 md:grid-cols-3">
          <InfoTile icon={MapPin} title="Localisation" text="À valider navigateur/mobile avec autorisation explicite." />
          <InfoTile icon={Route} title="Itinéraire" text="Recherche disponible, dépend de la qualité des arrêts et horaires." />
          <InfoTile icon={Bell} title="Alertes" text="Notifications à finaliser pour les perturbations réseau." />
        </div>
      </StudioPanel>
    </main>
  );
}

export function AdminProAppPage() {
  return (
    <main className="admin-app-content">
      <StudioPageHeader
        eyebrow="Aule Pro"
        title="Espaces métiers Pro"
        description="Les profils Pro appartiennent à leur réseau et ne deviennent jamais administrateurs plateforme par défaut."
      />
      <section className="grid gap-4 xl:grid-cols-2">
        {proProfiles.map((profile) => (
          <StudioPanel key={profile.title} title={profile.title} description={profile.goal}>
            <TagList items={profile.features} />
          </StudioPanel>
        ))}
      </section>
    </main>
  );
}

export function AdminMarketplaceStudioPage() {
  return (
    <main className="admin-app-content">
      <StudioPageHeader
        eyebrow="Marketplace"
        title="Marketplace globale Aule Studio"
        description="Gestion globale par réseau. Cette page est distincte de l'espace commerçant Aule Pro."
      />
      <StudioPanel title="Commerçants par réseau">
        <div className="overflow-x-auto">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Réseau</th>
                <th>Commerce</th>
                <th>Statut</th>
                <th>Commandes globales</th>
                <th>Catégorie</th>
                <th>Problème</th>
              </tr>
            </thead>
            <tbody>
              {marketplaceRows.map(([network, merchant, status, orders, category, issue]) => (
                <tr key={`${network}-${merchant}`}>
                  <td>{network}</td>
                  <td className="font-semibold text-white">{merchant}</td>
                  <td><StatusPill label={status} /></td>
                  <td>{orders}</td>
                  <td>{category}</td>
                  <td>{issue}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </StudioPanel>
    </main>
  );
}

export function AdminSettingsStudioPage() {
  return (
    <main className="admin-app-content">
      <StudioPageHeader
        eyebrow="Configuration"
        title="Configuration Studio"
        description="RBAC, modules, notifications, sécurité et intégrations, avec permissions dépendantes du rôle, du réseau et du contexte."
      />
      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {settingsSections.map(([title, text, Icon]) => (
          <article key={title} className="admin-config-card">
            <Icon className="h-5 w-5 text-blue-200" />
            <h3>{title}</h3>
            <p>{text}</p>
            <button className="admin-secondary-btn h-9 px-3" type="button">
              Configurer
            </button>
          </article>
        ))}
      </section>
      <StudioPanel title="Règles RBAC préparées">
        <IssueList
          rows={[
            "Aule Studio est réservé aux profils internes Aule.",
            "Aule Pro est réservé aux profils métiers rattachés à un réseau.",
            "Aule Voyageur est réservé aux voyageurs.",
            "Un rôle peut exister dans plusieurs contextes, mais ses permissions dépendent du réseau et du dépôt.",
            "Conducteur Naolib BLX, commerçant Naolib et super admin Aule restent trois périmètres différents.",
          ]}
        />
      </StudioPanel>
    </main>
  );
}

export function AdminLogsStudioPage() {
  return (
    <main className="admin-app-content">
      <StudioPageHeader
        eyebrow="Logs"
        title="Journal Studio"
        description="Suivi des imports, changements de configuration, permissions et signaux réseau."
      />
      <StudioPanel title="Activité récente">
        <Timeline
          rows={[
            ["20:42", "Vérification données GTFS Naolib."],
            ["20:31", "Session admin interne ouverte."],
            ["19:44", "Connexion agent exploitation Naolib."],
            ["18:12", "Signalement terrain classé en attention."],
          ]}
        />
      </StudioPanel>
    </main>
  );
}

function StudioPageHeader({
  eyebrow,
  title,
  description,
  action,
}: {
  eyebrow: string;
  title: string;
  description: string;
  action?: React.ReactNode;
}) {
  return (
    <section className="flex flex-wrap items-end justify-between gap-4">
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-blue-200">
          {eyebrow}
        </p>
        <h1 className="mt-2 text-3xl font-bold tracking-tight text-white">{title}</h1>
        <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-400">{description}</p>
      </div>
      {action}
    </section>
  );
}

function StudioPanel({
  title,
  description,
  action,
  children,
}: {
  title: string;
  description?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-lg border border-white/10 bg-white/[0.035]">
      <div className="flex flex-wrap items-start justify-between gap-3 border-b border-white/10 px-4 py-3">
        <div>
          <h2 className="text-sm font-semibold text-white">{title}</h2>
          {description && <p className="mt-1 text-xs leading-5 text-slate-500">{description}</p>}
        </div>
        {action}
      </div>
      <div className="p-4">{children}</div>
    </section>
  );
}

function NetworkCard({
  network,
  prominent,
}: {
  network: (typeof studioNetworks)[number];
  prominent?: boolean;
}) {
  return (
    <article className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <h3 className="text-xl font-bold text-white">{network.name}</h3>
            <StatusPill label={network.status} />
          </div>
          <p className="mt-1 text-sm text-slate-400">{network.city} · {network.country}</p>
        </div>
        <Link href={`/admin/networks/${network.id}`} className="admin-secondary-btn h-9 px-3">
          Ouvrir
        </Link>
      </div>
      <div className={cn("mt-4 grid gap-3", prominent ? "sm:grid-cols-2" : "sm:grid-cols-4")}>
        <Stat label="Modes" value={network.mode} icon={TramFront} />
        <Stat label="GTFS" value={network.gtfsStatus} icon={Database} />
        <Stat label="Utilisateurs" value={formatNumber(network.users)} icon={UsersRound} />
        <Stat label="Lignes" value={formatNumber(network.lines)} icon={Route} />
        <Stat label="Arrêts" value={formatNumber(network.stops)} icon={Flag} />
        <Stat label="Véhicules" value={formatNumber(network.vehicles)} icon={BusFront} />
      </div>
      <div className="mt-4 flex flex-wrap gap-2">
        {network.modules.map((module) => (
          <span key={module} className="rounded-full border border-blue-400/20 bg-blue-500/10 px-2.5 py-1 text-xs font-semibold text-blue-100">
            {module}
          </span>
        ))}
      </div>
      <p className="mt-4 text-xs text-slate-500">
        Dernière activité : {network.lastActivity}
      </p>
    </article>
  );
}

function NetworkStats({ network }: { network: (typeof studioNetworks)[number] }) {
  return (
    <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
      <Stat label="Utilisateurs rattachés" value={formatNumber(network.users)} icon={UsersRound} />
      <Stat label="Lignes" value={formatNumber(network.lines)} icon={Route} />
      <Stat label="Arrêts" value={formatNumber(network.stops)} icon={Flag} />
      <Stat label="Véhicules connus" value={formatNumber(network.vehicles)} icon={BusFront} />
    </div>
  );
}

function Stat({
  label,
  value,
  icon: Icon,
}: {
  label: string;
  value: string;
  icon: React.ComponentType<{ className?: string }>;
}) {
  return (
    <div className="rounded-lg border border-white/10 bg-black/15 p-3">
      <Icon className="h-4 w-4 text-blue-200" />
      <p className="mt-2 text-xs text-slate-500">{label}</p>
      <p className="mt-1 text-sm font-bold text-white">{value}</p>
    </div>
  );
}

function ConfigurationChecklist({ compact }: { compact?: boolean }) {
  return (
    <div className={cn("grid gap-2", !compact && "md:grid-cols-2")}>
      {studioConfigurationChecklist.map((item) => (
        <div key={item.label} className="rounded-lg border border-white/10 bg-black/15 p-3">
          <div className="flex items-start gap-3">
            <StatusIcon status={item.status} />
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h3 className="text-sm font-semibold text-white">{item.label}</h3>
                <StatusPill label={statusLabel(item.status)} status={item.status} />
              </div>
              <p className="mt-1 text-xs leading-5 text-slate-500">{item.description}</p>
              <Link href={item.href} className="mt-2 inline-flex text-xs font-semibold text-blue-200 hover:text-blue-100">
                {item.action}
              </Link>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

function FilterBar({ fields }: { fields: string[] }) {
  return (
    <section className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        {fields.map((field, index) => (
          <label
            key={field}
            className={cn("admin-filter-field", index === 0 && "xl:col-span-2")}
          >
            <span className="sr-only">{field}</span>
            {index === 0 ? (
              <Search className="admin-filter-icon" />
            ) : (
              <Filter className="admin-filter-icon" />
            )}
            <input className="admin-filter-input" placeholder={field} />
          </label>
        ))}
      </div>
    </section>
  );
}

function StatusList({ rows }: { rows: readonly (readonly [string, string, string])[] }) {
  return (
    <div className="space-y-2">
      {rows.map(([label, status, text]) => (
        <div key={label} className="rounded-lg border border-white/10 bg-black/15 p-3">
          <div className="flex items-start gap-3">
            <StatusIcon status={status as StudioStatus} />
            <div>
              <h3 className="text-sm font-semibold text-white">{label}</h3>
              <p className="mt-1 text-xs leading-5 text-slate-500">{text}</p>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

function InfoTile({
  icon: Icon,
  title,
  text,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  text: string;
}) {
  return (
    <div className="rounded-lg border border-white/10 bg-black/15 p-4">
      <Icon className="h-5 w-5 text-blue-200" />
      <h3 className="mt-3 text-sm font-bold text-white">{title}</h3>
      <p className="mt-2 text-sm leading-6 text-slate-400">{text}</p>
    </div>
  );
}

function TagList({ items }: { items: readonly string[] }) {
  return (
    <div className="flex flex-wrap gap-2">
      {items.map((item) => (
        <span key={item} className="rounded-full border border-white/10 bg-white/[0.04] px-3 py-1 text-xs font-semibold text-slate-200">
          {item}
        </span>
      ))}
    </div>
  );
}

function IssueList({ rows }: { rows: readonly string[] }) {
  return (
    <div className="space-y-2">
      {rows.map((row) => (
        <div key={row} className="flex items-start gap-2 rounded-lg border border-amber-400/20 bg-amber-500/10 px-3 py-2 text-sm text-amber-100">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <span>{row}</span>
        </div>
      ))}
    </div>
  );
}

function Timeline({ rows }: { rows: readonly (readonly [string, string])[] }) {
  return (
    <div className="space-y-4">
      {rows.map(([time, text]) => (
        <div key={`${time}-${text}`} className="flex gap-3">
          <span className="mt-1 min-w-12 text-xs font-semibold text-blue-200">{time}</span>
          <div className="min-w-0 border-l border-white/10 pl-3">
            <p className="text-sm text-slate-200">{text}</p>
          </div>
        </div>
      ))}
    </div>
  );
}

function StudioTabs({ items }: { items: readonly string[] }) {
  return (
    <div className="mt-5 flex gap-2 overflow-x-auto">
      {items.map((item, index) => (
        <button
          key={item}
          className={cn(
            "h-9 shrink-0 rounded-lg border px-3 text-xs font-semibold",
            index === 0
              ? "border-blue-400/30 bg-blue-500/15 text-blue-100"
              : "border-white/10 bg-white/[0.035] text-slate-400",
          )}
          type="button"
        >
          {item}
        </button>
      ))}
    </div>
  );
}

function StatusIcon({ status }: { status: StudioStatus }) {
  if (status === "done") return <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-emerald-300" />;
  if (status === "attention") return <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-amber-300" />;
  return <CircleDashed className="mt-0.5 h-4 w-4 shrink-0 text-slate-500" />;
}

function StatusPill({ label, status }: { label: string; status?: StudioStatus }) {
  const derived = status ?? deriveStatus(label);
  return (
    <span
      className={cn(
        "inline-flex rounded-full border px-2.5 py-1 text-xs font-semibold",
        derived === "done" && "border-emerald-400/25 bg-emerald-500/10 text-emerald-100",
        derived === "attention" && "border-amber-400/25 bg-amber-500/10 text-amber-100",
        derived === "todo" && "border-slate-400/20 bg-slate-500/10 text-slate-300",
      )}
    >
      {label}
    </span>
  );
}

function deriveStatus(label: string): StudioStatus {
  const normalized = label.toLowerCase();
  if (normalized.includes("actif") || normalized.includes("import") || normalized.includes("aucun")) {
    return "done";
  }
  if (normalized.includes("attente") || normalized.includes("configuration") || normalized.includes("vérifier")) {
    return "attention";
  }
  return "todo";
}

function statusLabel(status: StudioStatus) {
  if (status === "done") return "Terminé";
  if (status === "attention") return "Attention";
  return "À faire";
}

function formatNumber(value: number) {
  return new Intl.NumberFormat("fr-FR").format(value);
}
