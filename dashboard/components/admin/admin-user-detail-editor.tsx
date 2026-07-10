"use client";

import { useEffect, useMemo, useState } from "react";
import { Check, Pencil, RotateCcw, Save } from "lucide-react";
import { cn } from "@/lib/utils";

type EditableUser = {
  id: string;
  name: string;
  email: string;
  profile: string;
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

export function AdminUserDetailEditor({ user }: { user: EditableUser }) {
  const initialForm = useMemo(() => toForm(user), [user]);
  const [form, setForm] = useState<UserForm>(initialForm);
  const [savedUser, setSavedUser] = useState<EditableUser>(user);
  const [isEditing, setIsEditing] = useState(false);
  const [savedAt, setSavedAt] = useState<string | null>(null);

  useEffect(() => {
    const stored = window.localStorage.getItem(storageKey(user.id));
    if (!stored) return;
    try {
      const parsed = JSON.parse(stored) as EditableUser;
      // Chargement d'une édition locale après hydratation pour éviter un mismatch SSR/client.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setSavedUser(parsed);
      setForm(toForm(parsed));
    } catch {
      window.localStorage.removeItem(storageKey(user.id));
    }
  }, [user.id]);

  const currentApps = splitList(form.apps);
  const currentPermissions = splitList(form.permissions);

  function updateField(field: keyof UserForm, value: string) {
    setForm((current) => ({ ...current, [field]: value }));
  }

  function save() {
    const nextUser = fromForm(form);
    setSavedUser(nextUser);
    window.localStorage.setItem(storageKey(user.id), JSON.stringify(nextUser));
    setSavedAt(new Intl.DateTimeFormat("fr-FR", { hour: "2-digit", minute: "2-digit" }).format(new Date()));
    setIsEditing(false);
  }

  function reset() {
    window.localStorage.removeItem(storageKey(user.id));
    setForm(initialForm);
    setSavedUser(user);
    setSavedAt(null);
    setIsEditing(false);
  }

  return (
    <>
      <article className="rounded-lg border border-white/10 bg-white/[0.035]">
        <div className="flex min-h-16 flex-wrap items-center justify-between gap-3 border-b border-white/10 px-4 py-3">
          <div>
            <h2 className="text-sm font-bold text-white">Identité et rattachement</h2>
            <p className="mt-1 text-xs text-slate-500">
              {savedAt ? `Dernière modification locale à ${savedAt}` : "Informations complètes du compte"}
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <button className="admin-secondary-btn h-9 px-3" type="button" onClick={() => setIsEditing((value) => !value)}>
              <Pencil className="h-3.5 w-3.5" />
              {isEditing ? "Voir" : "Modifier"}
            </button>
            <button className="admin-secondary-btn h-9 px-3" type="button" onClick={reset}>
              <RotateCcw className="h-3.5 w-3.5" />
              Réinitialiser
            </button>
            {isEditing ? (
              <button className="admin-primary-btn h-9 px-3" type="button" onClick={save}>
                <Save className="h-3.5 w-3.5" />
                Enregistrer
              </button>
            ) : null}
          </div>
        </div>

        <div className="p-4">
          {isEditing ? (
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Nom" value={form.name} onChange={(value) => updateField("name", value)} />
              <Field label="Adresse email" type="email" value={form.email} onChange={(value) => updateField("email", value)} />
              <Field label="Profil" value={form.profile} onChange={(value) => updateField("profile", value)} />
              <Field label="Type" value={form.userKind} onChange={(value) => updateField("userKind", value)} />
              <Field label="Réseau rattaché" value={form.network} onChange={(value) => updateField("network", value)} />
              <Field label="Dépôt" value={form.depot} onChange={(value) => updateField("depot", value)} />
              <Field label="Habilitations" value={form.authorizations} onChange={(value) => updateField("authorizations", value)} />
              <label className="grid gap-1.5">
                <span className="text-xs font-semibold text-slate-500">Statut</span>
                <select className="admin-input" value={form.status} onChange={(event) => updateField("status", event.target.value)}>
                  <option>Actif</option>
                  <option>À vérifier</option>
                  <option>En attente</option>
                  <option>Suspendu</option>
                </select>
              </label>
              <Field label="Dernière connexion" value={form.lastLogin} onChange={(value) => updateField("lastLogin", value)} />
              <Field label="Inscription" value={form.createdAt} onChange={(value) => updateField("createdAt", value)} />
              <TextareaField label="Applications accessibles" value={form.apps} onChange={(value) => updateField("apps", value)} />
              <TextareaField label="Permissions" value={form.permissions} onChange={(value) => updateField("permissions", value)} />
            </div>
          ) : (
            <dl className="grid gap-3 sm:grid-cols-2">
              {[
                ["Nom", savedUser.name],
                ["Adresse email", savedUser.email],
                ["Profil", savedUser.profile],
                ["Type", savedUser.userKind],
                ["Réseau rattaché", savedUser.network],
                ["Dépôt", savedUser.depot],
                ["Habilitations", savedUser.authorizations],
                ["Statut", savedUser.status],
                ["Dernière connexion", savedUser.lastLogin],
                ["Inscription", savedUser.createdAt],
              ].map(([label, value]) => (
                <div key={label} className="rounded-lg border border-white/10 bg-black/15 p-3">
                  <dt className="text-xs text-slate-500">{label}</dt>
                  <dd className="mt-1 text-sm font-semibold text-white">{value}</dd>
                </div>
              ))}
            </dl>
          )}
        </div>
      </article>

      <article className="rounded-lg border border-white/10 bg-white/[0.035]">
        <div className="border-b border-white/10 px-4 py-3">
          <h2 className="text-sm font-bold text-white">Applications accessibles</h2>
        </div>
        <div className="p-4">
          <div className="flex flex-wrap gap-2">
            {appOptions.map((app) => (
              <span
                key={app}
                className={cn(
                  "inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-semibold",
                  currentApps.includes(app)
                    ? "border-emerald-400/25 bg-emerald-500/10 text-emerald-100"
                    : "border-white/10 bg-white/[0.03] text-slate-500",
                )}
              >
                {currentApps.includes(app) ? <Check className="h-3 w-3" /> : null}
                {app}
              </span>
            ))}
          </div>
          <p className="mt-4 text-sm leading-6 text-slate-400">
            Modifie la liste des applications dans le champ d&apos;édition avec des valeurs séparées par des virgules.
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
