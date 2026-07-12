"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { Eye, Filter, RotateCcw, Search } from "lucide-react";
import type { AdminStudioUser } from "@/lib/admin-studio-users";
import { cn } from "@/lib/utils";

type Filters = {
  query: string;
  network: string;
  profile: string;
  depot: string;
  authorization: string;
  status: string;
};

const emptyFilters: Filters = {
  query: "",
  network: "",
  profile: "",
  depot: "",
  authorization: "",
  status: "",
};

function normalize(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("fr")
    .trim();
}

function emailWithoutAlias(email: string) {
  const [localPart, domain] = email.split("@");
  if (!localPart || !domain) return email;
  return `${localPart.split("+")[0]}@${domain}`;
}

function uniqueValues(users: readonly AdminStudioUser[], field: keyof AdminStudioUser) {
  return [...new Set(users.map((user) => user[field]).filter((value): value is string => typeof value === "string" && value !== "-" && Boolean(value.trim())))]
    .sort((a, b) => a.localeCompare(b, "fr"));
}

export function AdminUsersDirectory({ users }: { users: readonly AdminStudioUser[] }) {
  const [filters, setFilters] = useState<Filters>(emptyFilters);

  const options = useMemo(() => ({
    networks: uniqueValues(users, "network"),
    profiles: uniqueValues(users, "profile"),
    depots: uniqueValues(users, "depot"),
    authorizations: uniqueValues(users, "authorizations"),
    statuses: uniqueValues(users, "status"),
  }), [users]);

  const filteredUsers = useMemo(() => {
    const query = normalize(filters.query);
    return users.filter((user) => {
      const searchable = normalize([
        user.name,
        user.email,
        emailWithoutAlias(user.email),
        user.profile,
        user.role,
        user.userKind,
        user.network,
        user.depot,
        user.authorizations,
        user.status,
        ...user.apps,
        ...user.permissions,
      ].join(" "));

      return (!query || searchable.includes(query))
        && (!filters.network || user.network === filters.network)
        && (!filters.profile || user.profile === filters.profile)
        && (!filters.depot || user.depot === filters.depot)
        && (!filters.authorization || user.authorizations === filters.authorization)
        && (!filters.status || user.status === filters.status);
    });
  }, [filters, users]);

  const hasFilters = Object.values(filters).some(Boolean);

  function updateFilter(field: keyof Filters, value: string) {
    setFilters((current) => ({ ...current, [field]: value }));
  }

  return (
    <>
      <section className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          <label className="admin-filter-field xl:col-span-2">
            <span className="sr-only">Rechercher un utilisateur</span>
            <Search className="admin-filter-icon" />
            <input
              className="admin-filter-input"
              type="search"
              placeholder="Recherche nom, email, réseau, profil…"
              value={filters.query}
              onChange={(event) => updateFilter("query", event.target.value)}
            />
          </label>
          <FilterSelect label="Réseau" value={filters.network} options={options.networks} onChange={(value) => updateFilter("network", value)} />
          <FilterSelect label="Type de profil" value={filters.profile} options={options.profiles} onChange={(value) => updateFilter("profile", value)} />
          <FilterSelect label="Dépôt" value={filters.depot} options={options.depots} onChange={(value) => updateFilter("depot", value)} />
          <FilterSelect label="Habilitation" value={filters.authorization} options={options.authorizations} onChange={(value) => updateFilter("authorization", value)} />
          <FilterSelect label="Statut" value={filters.status} options={options.statuses} onChange={(value) => updateFilter("status", value)} />
          <div className="flex items-center justify-between gap-3">
            <span className="text-xs font-semibold text-slate-400" aria-live="polite">
              {filteredUsers.length} résultat{filteredUsers.length !== 1 ? "s" : ""}
            </span>
            {hasFilters ? (
              <button className="admin-secondary-btn h-9 px-3" type="button" onClick={() => setFilters(emptyFilters)}>
                <RotateCcw className="h-3.5 w-3.5" />
                Effacer
              </button>
            ) : null}
          </div>
        </div>
      </section>

      <article className="rounded-lg border border-white/10 bg-white/[0.035]">
        <div className="flex min-h-16 flex-wrap items-center justify-between gap-3 border-b border-white/10 px-4 py-3">
          <div>
            <h2 className="text-sm font-bold text-white">Liste des utilisateurs</h2>
            <p className="mt-1 text-xs text-slate-500">Les profils Pro ne sont pas des administrateurs plateforme.</p>
          </div>
          <span className="rounded-full border border-blue-400/20 bg-blue-500/10 px-2.5 py-1 text-xs font-semibold text-blue-100">
            {filteredUsers.length} / {users.length}
          </span>
        </div>

        {filteredUsers.length ? (
          <div className="admin-table-scroll">
            <table className="admin-table admin-users-table">
              <thead>
                <tr>
                  <th>Nom</th><th>Email</th><th>Type de profil</th><th>Réseau</th><th>Dépôt</th>
                  <th>Habilitations</th><th>Statut</th><th>Dernière connexion</th><th>Inscription</th><th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredUsers.map((user) => (
                  <tr key={user.id}>
                    <td className="font-semibold text-white"><span className="block max-w-[210px] truncate">{user.name}</span></td>
                    <td><span className="block max-w-[230px] truncate text-slate-200">{user.email}</span></td>
                    <td><span className="block text-slate-200">{user.profile}</span><span className="text-xs text-slate-500">{user.userKind}</span></td>
                    <td>{user.network}</td>
                    <td>{user.depot}</td>
                    <td>{user.authorizations}</td>
                    <td><UserStatus label={user.status} /></td>
                    <td>{user.lastLogin}</td>
                    <td>{user.createdAt}</td>
                    <td>
                      <Link className="admin-secondary-btn h-8 px-3" href={`/admin/users/${user.id}`} aria-label={`Ouvrir ${user.name}`}>
                        <Eye className="h-3.5 w-3.5" /> Ouvrir
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="grid min-h-56 place-items-center p-6 text-center">
            <div>
              <div className="mx-auto grid h-10 w-10 place-items-center rounded-lg bg-white/[0.05] text-slate-400"><Search className="h-5 w-5" /></div>
              <h3 className="mt-3 text-sm font-bold text-white">Aucun utilisateur trouvé</h3>
              <p className="mt-1 text-sm text-slate-500">Modifie les critères ou efface les filtres.</p>
              <button className="admin-secondary-btn mx-auto mt-4" type="button" onClick={() => setFilters(emptyFilters)}>
                <RotateCcw className="h-4 w-4" /> Réinitialiser les filtres
              </button>
            </div>
          </div>
        )}
      </article>
    </>
  );
}

function FilterSelect({ label, value, options, onChange }: { label: string; value: string; options: string[]; onChange: (value: string) => void }) {
  return (
    <label className="admin-filter-field">
      <span className="sr-only">{label}</span>
      <Filter className="admin-filter-icon" />
      <select className="admin-filter-input appearance-none" value={value} onChange={(event) => onChange(event.target.value)}>
        <option value="">{label}</option>
        {options.map((option) => <option key={option} value={option}>{option}</option>)}
      </select>
    </label>
  );
}

function UserStatus({ label }: { label: string }) {
  return (
    <span className={cn(
      "inline-flex rounded-full border px-2.5 py-1 text-xs font-semibold",
      label === "Actif" && "border-emerald-400/30 bg-emerald-500/10 text-emerald-100",
      ["À vérifier", "En attente"].includes(label) && "border-amber-400/30 bg-amber-500/10 text-amber-100",
      label === "Suspendu" && "border-rose-400/30 bg-rose-500/10 text-rose-100",
      !["Actif", "À vérifier", "En attente", "Suspendu"].includes(label) && "border-white/10 bg-white/[0.04] text-slate-300",
    )}>{label}</span>
  );
}
