"use client";

import type * as React from "react";
import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  AlertCircle,
  Check,
  Loader2,
  Plus,
  Save,
  Search,
  Trash2,
} from "lucide-react";
import { PERMISSIONS, type Permission } from "@/lib/access/permissions";
import { PROFILE_META, PROFILES, type Profile } from "@/lib/access/profiles";
import { cn } from "@/lib/utils";

type Resource = {
  id: string;
  resource_type: string;
  name: string;
  status: string;
  network_id: string | null;
  depot_id: string | null;
  owner_user_id: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
};

type AdminRole = {
  id: string;
  role_key: string;
  label: string;
  description: string | null;
  permissions: string[];
  restrictions: Record<string, unknown>;
  scope: Record<string, unknown>;
  is_system: boolean;
};

type UserProfileRow = {
  id: string;
  display_name: string | null;
  role: string;
};

type Assignment = {
  id: string;
  user_id: string;
  profile_key: string;
  context: Record<string, unknown>;
  is_active: boolean;
};

type Override = {
  id: string;
  user_id: string;
  permission: string;
  granted: boolean;
};

type AuditLog = {
  id: string;
  action: string;
  resource_type: string;
  resource_id: string | null;
  created_at: string;
};

type AdminState = {
  resources: Resource[];
  roles: AdminRole[];
  users: UserProfileRow[];
  assignments: Assignment[];
  overrides: Override[];
  auditLogs: AuditLog[];
  warnings?: string[];
};

const RESOURCE_TYPES = [
  "network",
  "depot",
  "line",
  "stop",
  "station",
  "vehicle",
  "traveler",
  "driver",
  "controller",
  "operations_agent",
  "vtc_driver",
  "merchant",
  "product",
  "order",
  "promotion",
  "delivery",
  "incident",
  "mission",
  "announcement",
  "integration",
  "api_key",
  "storage_bucket",
  "monitor",
] as const;

const STAFF_ROLES = [
  "passenger",
  "driver",
  "msr_agent",
  "msr_supervisor",
  "regulator",
  "admin",
] as const;

export type AdminManagementView = "resources" | "users" | "roles" | "audit" | "settings";

const emptyResource = {
  id: "",
  resource_type: "network",
  name: "",
  status: "active",
  network_id: "",
  depot_id: "",
  owner_user_id: "",
  metadata: "{}",
};

const emptyRole = {
  id: "",
  role_key: "",
  label: "",
  description: "",
  permissions: [] as string[],
  restrictions: "{}",
  scope: "{}",
  is_system: false,
};

export function AdminControlCenter({
  view = "resources",
}: {
  view?: AdminManagementView;
}) {
  const [state, setState] = useState<AdminState | null>(null);
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [errorStatus, setErrorStatus] = useState<number | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [resourceForm, setResourceForm] = useState(emptyResource);
  const [roleForm, setRoleForm] = useState(emptyRole);
  const [selectedUserId, setSelectedUserId] = useState("");
  const [profileToAssign, setProfileToAssign] = useState<Profile>("driver");
  const [permissionToOverride, setPermissionToOverride] =
    useState<Permission>("core.dashboard");
  const pathname = usePathname();

  async function load() {
    setLoading(true);
    setError(null);
    setErrorStatus(null);
    const res = await fetch("/api/admin/control-center", { cache: "no-store" });
    const json = await res.json();
    if (!res.ok) {
      setError(json.setupRequired ? `${json.error} ${json.setupRequired}` : json.error);
      setErrorStatus(res.status);
      setState(null);
    } else {
      setState(json);
      setSelectedUserId((current) => current || json.users?.[0]?.id || "");
    }
    setLoading(false);
  }

  useEffect(() => {
    void load();
  }, []);

  async function mutate(action: string, payload: Record<string, unknown>) {
    setSaving(true);
    setError(null);
    setErrorStatus(null);
    setNotice(null);
    const res = await fetch("/api/admin/control-center", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action, ...payload }),
    });
    const json = await res.json();
    if (!res.ok) {
      setError(json.error ?? "Action impossible");
      setErrorStatus(res.status);
    } else {
      setNotice("Modification enregistrée");
      await load();
    }
    setSaving(false);
    return res.ok;
  }

  const selectedUser = state?.users.find((u) => u.id === selectedUserId) ?? null;
  const filteredResources = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!state) return [];
    return state.resources.filter((resource) => {
      if (!q) return true;
      return `${resource.name} ${resource.resource_type} ${resource.status}`
        .toLowerCase()
        .includes(q);
    });
  }, [query, state]);

  const userAssignments = state?.assignments.filter(
    (assignment) => assignment.user_id === selectedUserId && assignment.is_active,
  ) ?? [];
  const userOverrides = state?.overrides.filter(
    (override) => override.user_id === selectedUserId,
  ) ?? [];

  return (
    <main className="admin-app-content">
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-blue-200">
          {viewTitle(view).eyebrow}
        </p>
        <h2 className="mt-2 text-3xl font-bold tracking-tight text-white">
          {viewTitle(view).title}
        </h2>
        <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-400">
          {viewTitle(view).description}
        </p>
      </div>

        {error && errorStatus !== 401 && <Message tone="error" text={error} />}
        {notice && <Message tone="success" text={notice} />}
        {state?.warnings?.map((warning) => (
          <Message key={warning} tone="warning" text={warning} />
        ))}

        {loading ? (
          <div className="mt-8 flex items-center gap-3 rounded-lg border border-white/10 bg-white/[0.035] p-5 text-slate-300">
            <Loader2 className="h-5 w-5 animate-spin" />
            Chargement du centre de contrôle...
          </div>
        ) : null}

        {!loading && errorStatus === 401 && (
          <AuthRequiredCard returnTo={pathname} />
        )}

        {!loading && state && (view === "resources" || view === "settings") && (
          <section className="mt-5 grid gap-4 lg:grid-cols-[390px_minmax(0,1fr)]">
            <Panel title={resourceForm.id ? "Modifier une ressource" : "Créer une ressource"}>
              <form
                className="space-y-3"
                onSubmit={async (event) => {
                  event.preventDefault();
                  const ok = await mutate("upsertResource", { resource: resourceForm });
                  if (ok) setResourceForm(emptyResource);
                }}
              >
                <Field label="Type">
                  <select
                    className="admin-input"
                    value={resourceForm.resource_type}
                    onChange={(e) =>
                      setResourceForm((form) => ({ ...form, resource_type: e.target.value }))
                    }
                  >
                    {RESOURCE_TYPES.map((type) => (
                      <option key={type} value={type}>
                        {type}
                      </option>
                    ))}
                  </select>
                </Field>
                <Field label="Nom">
                  <input
                    className="admin-input"
                    value={resourceForm.name}
                    onChange={(e) =>
                      setResourceForm((form) => ({ ...form, name: e.target.value }))
                    }
                    placeholder="Ex. Réseau Nantes, Dépôt Dalby, Boutique Paul"
                  />
                </Field>
                <div className="grid grid-cols-2 gap-3">
                  <Field label="Statut">
                    <input
                      className="admin-input"
                      value={resourceForm.status}
                      onChange={(e) =>
                        setResourceForm((form) => ({ ...form, status: e.target.value }))
                      }
                    />
                  </Field>
                  <Field label="Propriétaire">
                    <select
                      className="admin-input"
                      value={resourceForm.owner_user_id}
                      onChange={(e) =>
                        setResourceForm((form) => ({ ...form, owner_user_id: e.target.value }))
                      }
                    >
                      <option value="">Aucun</option>
                      {state.users.map((user) => (
                        <option key={user.id} value={user.id}>
                          {user.display_name || user.id}
                        </option>
                      ))}
                    </select>
                  </Field>
                </div>
                <Field label="Métadonnées JSON">
                  <textarea
                    className="admin-input min-h-28 font-mono text-xs"
                    value={resourceForm.metadata}
                    onChange={(e) =>
                      setResourceForm((form) => ({ ...form, metadata: e.target.value }))
                    }
                  />
                </Field>
                <div className="flex gap-2">
                  <SubmitButton saving={saving} label="Enregistrer" />
                  {resourceForm.id && (
                    <button
                      type="button"
                      className="admin-secondary-btn"
                      onClick={() => setResourceForm(emptyResource)}
                    >
                      Annuler
                    </button>
                  )}
                </div>
              </form>
            </Panel>

            <Panel
              title="Catalogue administrable"
              action={
                <div className="relative w-full max-w-xs">
                  <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-500" />
                  <input
                    className="admin-input pl-9"
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder="Rechercher"
                  />
                </div>
              }
            >
              <div className="overflow-x-auto">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Type</th>
                      <th>Nom</th>
                      <th>Statut</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredResources.map((resource) => (
                      <tr key={resource.id}>
                        <td>{resource.resource_type}</td>
                        <td className="font-semibold text-white">{resource.name}</td>
                        <td>{resource.status}</td>
                        <td>
                          <div className="flex gap-2">
                            <button
                              className="admin-secondary-btn h-8 px-3"
                              type="button"
                              onClick={() =>
                                setResourceForm({
                                  id: resource.id,
                                  resource_type: resource.resource_type,
                                  name: resource.name,
                                  status: resource.status,
                                  network_id: resource.network_id ?? "",
                                  depot_id: resource.depot_id ?? "",
                                  owner_user_id: resource.owner_user_id ?? "",
                                  metadata: JSON.stringify(resource.metadata ?? {}, null, 2),
                                })
                              }
                            >
                              Modifier
                            </button>
                            <button
                              className="admin-danger-btn h-8 px-3"
                              type="button"
                              onClick={() => mutate("deleteResource", { id: resource.id })}
                            >
                              <Trash2 className="h-3.5 w-3.5" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                    {filteredResources.length === 0 && (
                      <tr>
                        <td colSpan={4}>Aucune ressource. Créez le premier réseau, dépôt, véhicule, commerce ou module.</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </Panel>
          </section>
        )}

        {!loading && state && view === "users" && (
          <section className="mt-5 grid gap-4 lg:grid-cols-[360px_minmax(0,1fr)]">
            <Panel title="Utilisateurs">
              <div className="space-y-2">
                {state.users.map((user) => (
                  <button
                    key={user.id}
                    className={cn(
                      "w-full rounded-lg border px-3 py-3 text-left text-sm transition",
                      selectedUserId === user.id
                        ? "border-blue-400/40 bg-blue-500/15 text-white"
                        : "border-white/10 bg-white/[0.03] text-slate-300 hover:bg-white/[0.06]",
                    )}
                    onClick={() => setSelectedUserId(user.id)}
                    type="button"
                  >
                    <span className="block font-semibold">{user.display_name || "Sans nom"}</span>
                    <span className="text-xs text-slate-500">{user.role} · {user.id.slice(0, 8)}</span>
                  </button>
                ))}
              </div>
            </Panel>

            <Panel title={selectedUser ? `Accès de ${selectedUser.display_name || selectedUser.id}` : "Accès utilisateur"}>
              {selectedUser ? (
                <div className="grid gap-5 xl:grid-cols-2">
                  <form
                    className="space-y-3"
                    onSubmit={(event) => {
                      event.preventDefault();
                      const data = new FormData(event.currentTarget);
                      mutate("updateUser", {
                        userId: selectedUser.id,
                        displayName: String(data.get("displayName") ?? ""),
                        role: String(data.get("role") ?? selectedUser.role),
                      });
                    }}
                  >
                    <h3 className="text-sm font-semibold text-white">Identité</h3>
                    <Field label="Nom affiché">
                      <input
                        className="admin-input"
                        name="displayName"
                        defaultValue={selectedUser.display_name ?? ""}
                      />
                    </Field>
                    <Field label="Rôle legacy">
                      <select className="admin-input" name="role" defaultValue={selectedUser.role}>
                        {STAFF_ROLES.map((role) => (
                          <option key={role} value={role}>
                            {role}
                          </option>
                        ))}
                      </select>
                    </Field>
                    <SubmitButton saving={saving} label="Mettre à jour" />
                  </form>

                  <div className="space-y-4">
                    <div>
                      <h3 className="text-sm font-semibold text-white">Profils actifs</h3>
                      <div className="mt-2 flex flex-wrap gap-2">
                        {userAssignments.map((assignment) => (
                          <button
                            key={assignment.id}
                            className="inline-flex items-center gap-2 rounded-full border border-emerald-400/25 bg-emerald-500/10 px-3 py-1 text-xs font-semibold text-emerald-100"
                            type="button"
                            onClick={() => mutate("removeProfile", { id: assignment.id })}
                            title="Désactiver ce profil"
                          >
                            {PROFILE_META[assignment.profile_key as Profile]?.label ?? assignment.profile_key}
                            <Trash2 className="h-3 w-3" />
                          </button>
                        ))}
                        {userAssignments.length === 0 && (
                          <span className="text-sm text-slate-500">Aucun profil actif</span>
                        )}
                      </div>
                    </div>

                    <div className="grid gap-2 sm:grid-cols-[1fr_auto]">
                      <select
                        className="admin-input"
                        value={profileToAssign}
                        onChange={(e) => setProfileToAssign(e.target.value as Profile)}
                      >
                        {PROFILES.map((profile) => (
                          <option key={profile} value={profile}>
                            {PROFILE_META[profile].label}
                          </option>
                        ))}
                      </select>
                      <button
                        className="admin-primary-btn"
                        type="button"
                        onClick={() =>
                          mutate("assignProfile", {
                            userId: selectedUser.id,
                            profileKey: profileToAssign,
                            context: {},
                          })
                        }
                      >
                        <Plus className="h-4 w-4" />
                        Assigner
                      </button>
                    </div>

                    <div>
                      <h3 className="text-sm font-semibold text-white">Overrides permission</h3>
                      <div className="mt-2 grid gap-2 sm:grid-cols-[1fr_auto_auto]">
                        <select
                          className="admin-input"
                          value={permissionToOverride}
                          onChange={(e) => setPermissionToOverride(e.target.value as Permission)}
                        >
                          {PERMISSIONS.map((permission) => (
                            <option key={permission} value={permission}>
                              {permission}
                            </option>
                          ))}
                        </select>
                        <button
                          className="admin-primary-btn"
                          type="button"
                          onClick={() =>
                            mutate("setPermissionOverride", {
                              userId: selectedUser.id,
                              permission: permissionToOverride,
                              granted: true,
                            })
                          }
                        >
                          Accorder
                        </button>
                        <button
                          className="admin-danger-btn"
                          type="button"
                          onClick={() =>
                            mutate("setPermissionOverride", {
                              userId: selectedUser.id,
                              permission: permissionToOverride,
                              granted: false,
                            })
                          }
                        >
                          Révoquer
                        </button>
                      </div>
                      <div className="mt-3 flex flex-wrap gap-2">
                        {userOverrides.map((override) => (
                          <button
                            key={override.id}
                            className={cn(
                              "rounded-full border px-3 py-1 text-xs font-semibold",
                              override.granted
                                ? "border-blue-400/25 bg-blue-500/10 text-blue-100"
                                : "border-red-400/25 bg-red-500/10 text-red-100",
                            )}
                            type="button"
                            onClick={() =>
                              mutate("setPermissionOverride", {
                                userId: selectedUser.id,
                                permission: override.permission,
                                granted: null,
                              })
                            }
                          >
                            {override.granted ? "+" : "-"} {override.permission}
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              ) : (
                <p className="text-sm text-slate-500">Sélectionnez un utilisateur.</p>
              )}
            </Panel>
          </section>
        )}

        {!loading && state && view === "roles" && (
          <section className="mt-5 grid gap-4 lg:grid-cols-[390px_minmax(0,1fr)]">
            <Panel title={roleForm.id ? "Modifier un rôle" : "Créer un rôle"}>
              <RoleForm
                form={roleForm}
                setForm={setRoleForm}
                saving={saving}
                onSubmit={async () => {
                  const ok = await mutate("upsertRole", { role: roleForm });
                  if (ok) setRoleForm(emptyRole);
                }}
              />
            </Panel>
            <Panel title="Matrice des rôles">
              <div className="overflow-x-auto">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Rôle</th>
                      <th>Permissions</th>
                      <th>Portée</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {state.roles.map((role) => (
                      <tr key={role.id}>
                        <td>
                          <span className="font-semibold text-white">{role.label}</span>
                          <span className="block text-xs text-slate-500">{role.role_key}</span>
                        </td>
                        <td>{role.permissions.length}</td>
                        <td className="font-mono text-xs">{JSON.stringify(role.scope)}</td>
                        <td>
                          <div className="flex gap-2">
                            <button
                              className="admin-secondary-btn h-8 px-3"
                              type="button"
                              onClick={() =>
                                setRoleForm({
                                  id: role.id,
                                  role_key: role.role_key,
                                  label: role.label,
                                  description: role.description ?? "",
                                  permissions: role.permissions,
                                  restrictions: JSON.stringify(role.restrictions ?? {}, null, 2),
                                  scope: JSON.stringify(role.scope ?? {}, null, 2),
                                  is_system: role.is_system,
                                })
                              }
                            >
                              Modifier
                            </button>
                            {!role.is_system && (
                              <button
                                className="admin-danger-btn h-8 px-3"
                                type="button"
                                onClick={() => mutate("deleteRole", { id: role.id })}
                              >
                                <Trash2 className="h-3.5 w-3.5" />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Panel>
          </section>
        )}

        {!loading && state && view === "audit" && (
          <Panel title="Journal d'audit">
            <div className="overflow-x-auto">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Action</th>
                    <th>Type</th>
                    <th>Ressource</th>
                  </tr>
                </thead>
                <tbody>
                  {state.auditLogs.map((log) => (
                    <tr key={log.id}>
                      <td>{new Date(log.created_at).toLocaleString("fr-FR")}</td>
                      <td className="font-semibold text-white">{log.action}</td>
                      <td>{log.resource_type}</td>
                      <td className="font-mono text-xs">{log.resource_id ?? "-"}</td>
                    </tr>
                  ))}
                  {state.auditLogs.length === 0 && (
                    <tr>
                      <td colSpan={4}>Aucune action enregistrée.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </Panel>
        )}
    </main>
  );
}

function viewTitle(view: AdminManagementView) {
  switch (view) {
    case "users":
      return {
        eyebrow: "Utilisateurs",
        title: "Gestion des utilisateurs et accès",
        description:
          "Administrez les comptes, profils métier, rôles legacy et permissions spécifiques.",
      };
    case "roles":
      return {
        eyebrow: "Administration",
        title: "Permissions et rôles",
        description:
          "Configurez la matrice RBAC, les restrictions et les portées sans modifier le code.",
      };
    case "audit":
      return {
        eyebrow: "Logs",
        title: "Journal d'audit",
        description:
          "Suivez les actions administratives, modifications de permissions et changements de ressources.",
      };
    case "settings":
      return {
        eyebrow: "Paramètres",
        title: "Centre de configuration",
        description:
          "Gérez les modules plateforme, API, réseaux, stockage, marketplace, sécurité et intégrations.",
      };
    default:
      return {
        eyebrow: "Ressources",
        title: "Ressources administrables",
        description:
          "Créez et modifiez réseaux, dépôts, lignes, véhicules, boutiques, incidents, missions et intégrations.",
      };
  }
}

function AuthRequiredCard({ returnTo }: { returnTo: string }) {
  return (
    <section className="mt-6 max-w-2xl rounded-lg border border-blue-400/20 bg-blue-500/10 p-5">
      <h3 className="text-lg font-bold text-white">Connexion administrateur requise</h3>
      <p className="mt-2 text-sm leading-6 text-slate-300">
        La table utilisateurs est protégée par Supabase. Connectez-vous avec un compte
        administrateur Aule pour charger les utilisateurs, profils, rôles et permissions.
      </p>
      <div className="mt-4 flex flex-wrap gap-2">
        <Link
          className="admin-primary-btn"
          href={`/login?mode=pro&next=${encodeURIComponent(returnTo)}`}
        >
          Se connecter
        </Link>
        <Link className="admin-secondary-btn" href="/admin">
          Retour au dashboard
        </Link>
      </div>
    </section>
  );
}

function RoleForm({
  form,
  setForm,
  saving,
  onSubmit,
}: {
  form: typeof emptyRole;
  setForm: React.Dispatch<React.SetStateAction<typeof emptyRole>>;
  saving: boolean;
  onSubmit: () => void;
}) {
  return (
    <form
      className="space-y-3"
      onSubmit={(event) => {
        event.preventDefault();
        onSubmit();
      }}
    >
      <Field label="Clé">
        <input
          className="admin-input"
          value={form.role_key}
          onChange={(e) => setForm((f) => ({ ...f, role_key: e.target.value }))}
          placeholder="ex. dispatcher_night"
        />
      </Field>
      <Field label="Libellé">
        <input
          className="admin-input"
          value={form.label}
          onChange={(e) => setForm((f) => ({ ...f, label: e.target.value }))}
        />
      </Field>
      <Field label="Description">
        <textarea
          className="admin-input min-h-20"
          value={form.description}
          onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
        />
      </Field>
      <div className="max-h-56 space-y-1 overflow-auto rounded-lg border border-white/10 bg-black/20 p-2">
        {PERMISSIONS.map((permission) => (
          <label
            key={permission}
            className="flex cursor-pointer items-center gap-2 rounded-md px-2 py-1 text-xs text-slate-300 hover:bg-white/[0.05]"
          >
            <input
              type="checkbox"
              checked={form.permissions.includes(permission)}
              onChange={(e) =>
                setForm((f) => ({
                  ...f,
                  permissions: e.target.checked
                    ? [...f.permissions, permission]
                    : f.permissions.filter((p) => p !== permission),
                }))
              }
            />
            {permission}
          </label>
        ))}
      </div>
      <Field label="Restrictions JSON">
        <textarea
          className="admin-input min-h-20 font-mono text-xs"
          value={form.restrictions}
          onChange={(e) => setForm((f) => ({ ...f, restrictions: e.target.value }))}
        />
      </Field>
      <Field label="Portée JSON">
        <textarea
          className="admin-input min-h-20 font-mono text-xs"
          value={form.scope}
          onChange={(e) => setForm((f) => ({ ...f, scope: e.target.value }))}
        />
      </Field>
      <div className="flex gap-2">
        <SubmitButton saving={saving} label="Enregistrer le rôle" />
        {form.id && (
          <button className="admin-secondary-btn" type="button" onClick={() => setForm(emptyRole)}>
            Annuler
          </button>
        )}
      </div>
    </form>
  );
}

function Panel({
  title,
  action,
  children,
}: {
  title: string;
  action?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-lg border border-white/10 bg-white/[0.035]">
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-white/10 px-4 py-3">
        <h2 className="text-sm font-semibold text-white">{title}</h2>
        {action}
      </div>
      <div className="p-4">{children}</div>
    </section>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1 block text-xs font-semibold text-slate-400">{label}</span>
      {children}
    </label>
  );
}

function SubmitButton({ saving, label }: { saving: boolean; label: string }) {
  return (
    <button className="admin-primary-btn" disabled={saving} type="submit">
      {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
      {label}
    </button>
  );
}

function Message({ tone, text }: { tone: "error" | "success" | "warning"; text: string }) {
  return (
    <div
      className={cn(
        "mt-4 flex items-start gap-2 rounded-lg border px-4 py-3 text-sm",
        tone === "error" && "border-red-400/25 bg-red-500/10 text-red-100",
        tone === "success" && "border-emerald-400/25 bg-emerald-500/10 text-emerald-100",
        tone === "warning" && "border-amber-400/25 bg-amber-500/10 text-amber-100",
      )}
    >
      {tone === "success" ? <Check className="h-4 w-4" /> : <AlertCircle className="h-4 w-4" />}
      <span>{text}</span>
    </div>
  );
}
