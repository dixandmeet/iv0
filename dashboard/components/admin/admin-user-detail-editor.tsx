"use client";

import { useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import Link from "next/link";
import {
  Activity,
  AlertCircle,
  Building2,
  Check,
  KeyRound,
  LoaderCircle,
  Mail,
  Pencil,
  RotateCcw,
  Save,
  ShieldCheck,
  UserRound,
} from "lucide-react";
import { cn } from "@/lib/utils";

type EditableUser = {
  id: string;
  name: string;
  email: string;
  profile: string;
  role: string;
  userKind: string;
  network: string;
  depot: string;
  authorizations: string;
  status: string;
  lastLogin: string;
  createdAt: string;
  apps: readonly string[];
  permissions: readonly string[];
};

type UserForm = Omit<EditableUser, "apps" | "permissions"> & {
  apps: string;
  permissions: string;
};

const appOptions = ["Voyageur", "Pro", "Admin interne"] as const;

const roleOptions = [
  { value: "passenger", label: "Voyageur" },
  { value: "driver", label: "Conducteur" },
  { value: "msr_agent", label: "Contrôleur" },
  { value: "msr_supervisor", label: "Agent de maîtrise" },
  { value: "regulator", label: "Régulateur / exploitation" },
  { value: "admin", label: "Administrateur" },
] as const;

function roleLabel(role: string) {
  return roleOptions.find((option) => option.value === role)?.label ?? role;
}

function toForm(user: EditableUser): UserForm {
  return {
    ...user,
    apps: user.apps.join(", "),
    permissions: user.permissions.join(", "),
  };
}

function fromForm(form: UserForm): EditableUser {
  return {
    ...form,
    apps: splitList(form.apps),
    permissions: splitList(form.permissions),
  };
}

function splitList(value: string) {
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function storageKey(userId: string) {
  return `aule-studio-user:${userId}`;
}

export function AdminUserDetailEditor({
  user,
  source,
  loginHref,
}: {
  user: EditableUser;
  source: "supabase" | "demo";
  loginHref: string;
}) {
  const initialForm = useMemo(() => toForm(user), [user]);
  const [form, setForm] = useState<UserForm>(initialForm);
  const [savedUser, setSavedUser] = useState<EditableUser>(user);
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [loginRequired, setLoginRequired] = useState(false);
  const [savedAt, setSavedAt] = useState<string | null>(null);

  useEffect(() => {
    const stored = window.localStorage.getItem(storageKey(user.id));
    if (!stored) return;
    try {
      const parsed = JSON.parse(stored) as EditableUser;
      const hydratedUser = {
        ...user,
        ...parsed,
        role: source === "supabase" ? user.role : parsed.role ?? user.role,
      };
      // Chargement d'une édition locale après hydratation pour éviter un mismatch SSR/client.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setSavedUser(hydratedUser);
      setForm(toForm(hydratedUser));
    } catch {
      window.localStorage.removeItem(storageKey(user.id));
    }
  }, [source, user]);

  const currentApps = splitList(form.apps);
  const currentPermissions = splitList(form.permissions);

  function updateField(field: keyof UserForm, value: string) {
    setForm((current) => ({ ...current, [field]: value }));
  }

  function toggleApp(app: (typeof appOptions)[number]) {
    const apps = new Set(splitList(form.apps));
    if (apps.has(app)) apps.delete(app);
    else apps.add(app);
    updateField("apps", [...apps].join(", "));
  }

  async function save() {
    setIsSaving(true);
    setSaveError(null);
    setLoginRequired(false);

    if (source === "supabase") {
      try {
        const response = await fetch("/api/admin/control-center", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            action: "updateUser",
            userId: user.id,
            displayName: form.name,
            role: form.role,
          }),
        });
        const payload = (await response.json()) as { error?: string; loginRequired?: boolean };
        if (response.status === 401 || payload.loginRequired) setLoginRequired(true);
        if (!response.ok) throw new Error(payload.error || "La mise à jour du rôle a échoué.");
      } catch (error) {
        setSaveError(error instanceof Error ? error.message : "La mise à jour du rôle a échoué.");
        setIsSaving(false);
        return;
      }
    }

    const nextUser = fromForm(form);
    setSavedUser(nextUser);
    window.localStorage.setItem(storageKey(user.id), JSON.stringify(nextUser));
    setSavedAt(new Intl.DateTimeFormat("fr-FR", { hour: "2-digit", minute: "2-digit" }).format(new Date()));
    setIsEditing(false);
    setIsSaving(false);
  }

  function cancelEditing() {
    setForm(toForm(savedUser));
    setSaveError(null);
    setLoginRequired(false);
    setIsEditing(false);
  }

  function resetDraft() {
    setForm(toForm(savedUser));
    setSaveError(null);
    setLoginRequired(false);
  }

  return (
    <>
      <article className="rounded-lg border border-white/10 bg-white/[0.035]">
        <div className="border-b border-white/10 bg-gradient-to-r from-blue-500/10 via-cyan-400/[0.06] to-transparent p-4 sm:p-5">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div className="flex min-w-0 items-center gap-3.5">
              <div className="grid h-12 w-12 shrink-0 place-items-center rounded-lg border border-blue-300/20 bg-blue-500/15 text-sm font-bold text-blue-100">
                {savedUser.name.split(" ").map((part) => part[0]).join("").slice(0, 2).toUpperCase()}
              </div>
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <h2 className="truncate text-base font-bold text-white">{savedUser.name}</h2>
                  <span className="rounded-full border border-emerald-400/20 bg-emerald-500/10 px-2 py-0.5 text-[11px] font-semibold text-emerald-100">
                    {savedUser.status}
                  </span>
                </div>
                <p className="mt-1 flex items-center gap-1.5 truncate text-xs text-slate-400">
                  <Mail className="h-3.5 w-3.5 shrink-0" />
                  {savedUser.email}
                </p>
                <p className="mt-1 text-xs font-semibold text-blue-200">{roleLabel(savedUser.role)}</p>
              </div>
            </div>
            <div className="flex flex-wrap gap-2">
              <button className="admin-secondary-btn h-9 px-3" type="button" onClick={() => isEditing ? cancelEditing() : setIsEditing(true)}>
                <Pencil className="h-3.5 w-3.5" />
                {isEditing ? "Annuler" : "Modifier"}
              </button>
              {isEditing ? (
                <>
                  <button className="admin-secondary-btn h-9 px-3" type="button" onClick={resetDraft}>
                    <RotateCcw className="h-3.5 w-3.5" />
                    Rétablir
                  </button>
                  <button className="admin-primary-btn h-9 px-3" type="button" onClick={save} disabled={isSaving}>
                    {isSaving ? <LoaderCircle className="h-3.5 w-3.5 animate-spin" /> : <Save className="h-3.5 w-3.5" />}
                    {isSaving ? "Enregistrement…" : "Enregistrer"}
                  </button>
                </>
              ) : null}
            </div>
          </div>
          <p className="mt-3 text-xs text-slate-500">
            {savedAt ? `Dernière modification à ${savedAt}` : "Compte utilisateur et périmètre d’accès"}
          </p>
        </div>

        <div className="p-4 sm:p-5">
          {saveError ? (
            <div className="mb-4 flex flex-wrap items-center gap-2 rounded-lg border border-rose-400/20 bg-rose-500/10 px-3 py-2.5 text-sm text-rose-100" role="alert">
              <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
              <span className="min-w-0 flex-1">{saveError}</span>
              {loginRequired ? (
                <Link className="admin-primary-btn h-8 px-3" href={loginHref}>
                  Se reconnecter
                </Link>
              ) : null}
            </div>
          ) : null}
          {isEditing ? (
            <div className="space-y-5">
              <EditorSection icon={<UserRound className="h-4 w-4" />} title="Identité" description="Informations principales du compte">
                <Field label="Nom" value={form.name} onChange={(value) => updateField("name", value)} />
                <Field label="Adresse email" type="email" value={form.email} onChange={(value) => updateField("email", value)} />
              </EditorSection>
              <EditorSection icon={<ShieldCheck className="h-4 w-4" />} title="Rôle et accès" description="Le rôle pilote les droits hérités dans Aule">
                <label className="grid gap-1.5">
                  <span className="text-xs font-semibold text-slate-500">Rôle utilisateur</span>
                  <select className="admin-input" value={form.role} onChange={(event) => updateField("role", event.target.value)}>
                    {roleOptions.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
                  </select>
                  <span className="text-[11px] leading-4 text-slate-500">Enregistré dans le profil utilisateur et tracé dans les journaux d’audit.</span>
                </label>
                <Field label="Profil métier" value={form.profile} onChange={(value) => updateField("profile", value)} />
                <Field label="Type de compte" value={form.userKind} onChange={(value) => updateField("userKind", value)} />
                <Field label="Habilitations" value={form.authorizations} onChange={(value) => updateField("authorizations", value)} />
              </EditorSection>
              <EditorSection icon={<Building2 className="h-4 w-4" />} title="Rattachement" description="Périmètre réseau et dépôt de référence">
                <Field label="Réseau rattaché" value={form.network} onChange={(value) => updateField("network", value)} />
                <Field label="Dépôt" value={form.depot} onChange={(value) => updateField("depot", value)} />
              </EditorSection>
              <EditorSection icon={<Activity className="h-4 w-4" />} title="État du compte" description="Cycle de vie et activité récente">
                <label className="grid gap-1.5">
                  <span className="text-xs font-semibold text-slate-500">Statut</span>
                  <select className="admin-input" value={form.status} onChange={(event) => updateField("status", event.target.value)}>
                    <option>Actif</option><option>À vérifier</option><option>En attente</option><option>Suspendu</option>
                  </select>
                </label>
                <Field label="Dernière connexion" value={form.lastLogin} onChange={(value) => updateField("lastLogin", value)} />
                <Field label="Inscription" value={form.createdAt} onChange={(value) => updateField("createdAt", value)} />
                <TextareaField label="Permissions spécifiques" value={form.permissions} onChange={(value) => updateField("permissions", value)} />
              </EditorSection>
            </div>
          ) : (
            <div className="grid gap-4 2xl:grid-cols-2">
              <InfoSection icon={<UserRound className="h-4 w-4" />} title="Identité" rows={[["Nom", savedUser.name], ["Adresse email", savedUser.email], ["Type de compte", savedUser.userKind]]} />
              <InfoSection icon={<ShieldCheck className="h-4 w-4" />} title="Rôle et accès" accent rows={[["Rôle utilisateur", roleLabel(savedUser.role)], ["Profil métier", savedUser.profile], ["Habilitations", savedUser.authorizations]]} />
              <InfoSection icon={<Building2 className="h-4 w-4" />} title="Rattachement" rows={[["Réseau", savedUser.network], ["Dépôt", savedUser.depot]]} />
              <InfoSection icon={<Activity className="h-4 w-4" />} title="Activité du compte" rows={[["Statut", savedUser.status], ["Dernière connexion", savedUser.lastLogin], ["Inscription", savedUser.createdAt]]} />
            </div>
          )}
        </div>
      </article>

      <article className="rounded-lg border border-white/10 bg-white/[0.035]">
        <div className="border-b border-white/10 px-4 py-3">
          <div className="flex items-center gap-2">
            <KeyRound className="h-4 w-4 text-blue-300" />
            <h2 className="text-sm font-bold text-white">Applications accessibles</h2>
          </div>
        </div>
        <div className="p-4">
          <div className="flex flex-wrap gap-2">
            {appOptions.map((app) => (
              <button
                key={app}
                type="button"
                disabled={!isEditing}
                onClick={() => toggleApp(app)}
                aria-pressed={currentApps.includes(app)}
                className={cn(
                  "inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-semibold transition disabled:cursor-default",
                  currentApps.includes(app)
                    ? "border-emerald-400/25 bg-emerald-500/10 text-emerald-100"
                    : "border-white/10 bg-white/[0.03] text-slate-500",
                  isEditing && "hover:border-blue-300/30 hover:text-white",
                )}
              >
                {currentApps.includes(app) ? <Check className="h-3 w-3" /> : null}
                {app}
              </button>
            ))}
          </div>
          <p className="mt-4 text-sm leading-6 text-slate-400">
            {isEditing ? "Sélectionne directement les espaces accessibles à cet utilisateur." : "Passe en modification pour ajuster les espaces accessibles."}
          </p>
        </div>
      </article>

      <section className="grid gap-4 xl:col-span-2 xl:grid-cols-3">
        <article className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
          <h2 className="text-sm font-bold text-white">Permissions</h2>
          <div className="mt-4 flex flex-wrap gap-2">
            {currentPermissions.map((permission) => (
              <span key={permission} className="rounded-full border border-white/10 bg-white/[0.04] px-3 py-1 text-xs font-semibold text-slate-200">
                {permission}
              </span>
            ))}
          </div>
        </article>

        <article className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
          <h2 className="text-sm font-bold text-white">Historique d&apos;activité</h2>
          <div className="mt-4 space-y-4">
            {[
              [savedUser.lastLogin, "Dernière session vérifiée."],
              ["Hier", "Contexte réseau relu."],
              [savedUser.createdAt, "Compte rattaché à Aule."],
            ].map(([time, text]) => (
              <div key={`${time}-${text}`} className="flex gap-3">
                <span className="mt-1 min-w-20 text-xs font-semibold text-blue-200">{time}</span>
                <div className="min-w-0 border-l border-white/10 pl-3">
                  <p className="text-sm text-slate-200">{text}</p>
                </div>
              </div>
            ))}
          </div>
        </article>

        <article className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
          <h2 className="text-sm font-bold text-white">Position et appareils</h2>
          <div className="mt-4 space-y-2">
            {[
              "Dernière position masquée si non applicable ou non autorisée.",
              `Contact principal : ${savedUser.email}`,
              `Périmètre courant : ${savedUser.network} · ${savedUser.depot}`,
            ].map((row) => (
              <div key={row} className="rounded-lg border border-amber-400/20 bg-amber-500/10 px-3 py-2 text-sm text-amber-100">
                {row}
              </div>
            ))}
          </div>
        </article>
      </section>
    </>
  );
}

function InfoSection({
  icon,
  title,
  rows,
  accent = false,
}: {
  icon: ReactNode;
  title: string;
  rows: readonly (readonly [string, string])[];
  accent?: boolean;
}) {
  return (
    <section className={cn("rounded-lg border p-4", accent ? "border-blue-400/20 bg-blue-500/[0.06]" : "border-white/10 bg-black/10")}>
      <div className="flex items-center gap-2 text-sm font-bold text-white">
        <span className={cn("grid h-7 w-7 place-items-center rounded-md", accent ? "bg-blue-500/15 text-blue-200" : "bg-white/[0.05] text-slate-300")}>{icon}</span>
        <h3>{title}</h3>
      </div>
      <dl className="mt-4 divide-y divide-white/[0.07]">
        {rows.map(([label, value]) => (
          <div key={label} className="grid gap-1 py-2.5 first:pt-0 last:pb-0 sm:grid-cols-[minmax(110px,0.45fr)_1fr] sm:gap-4">
            <dt className="text-xs text-slate-500">{label}</dt>
            <dd className="min-w-0 break-words text-sm font-semibold text-slate-100 sm:text-right">{value || "—"}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}

function EditorSection({
  icon,
  title,
  description,
  children,
}: {
  icon: ReactNode;
  title: string;
  description: string;
  children: ReactNode;
}) {
  return (
    <section className="rounded-lg border border-white/10 bg-black/10 p-4">
      <div className="mb-4 flex items-center gap-3 border-b border-white/[0.07] pb-3">
        <span className="grid h-8 w-8 shrink-0 place-items-center rounded-md bg-blue-500/10 text-blue-200">{icon}</span>
        <div>
          <h3 className="text-sm font-bold text-white">{title}</h3>
          <p className="mt-0.5 text-xs text-slate-500">{description}</p>
        </div>
      </div>
      <div className="grid gap-3 sm:grid-cols-2">{children}</div>
    </section>
  );
}

function Field({
  label,
  value,
  onChange,
  type = "text",
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
}) {
  return (
    <label className="grid gap-1.5">
      <span className="text-xs font-semibold text-slate-500">{label}</span>
      <input className="admin-input" type={type} value={value} onChange={(event) => onChange(event.target.value)} />
    </label>
  );
}

function TextareaField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="grid gap-1.5 sm:col-span-2">
      <span className="text-xs font-semibold text-slate-500">{label}</span>
      <textarea className="admin-input min-h-24 resize-y" value={value} onChange={(event) => onChange(event.target.value)} />
    </label>
  );
}
