"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import {
  AlertTriangle,
  CalendarDays,
  Check,
  CircleUserRound,
  Loader2,
  LockKeyhole,
  Mail,
  Network,
  PauseCircle,
  ShieldCheck,
  Trash2,
  X,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";

type AccountAction = "deactivate" | "delete";

interface AccountSettingsProps {
  displayName: string;
  email: string;
  role: string;
  createdAt: string;
  managedNetworkCount: number;
}

const ROLE_LABELS: Record<string, string> = {
  passenger: "Voyageur",
  driver: "Conducteur",
  msr_agent: "Agent MSR",
  msr_supervisor: "Superviseur MSR",
  regulator: "Régulateur",
  admin: "Administrateur",
};

const ACTION_COPY = {
  deactivate: {
    title: "Désactiver mon compte",
    phrase: "DESACTIVER",
    button: "Confirmer la désactivation",
    pending: "Désactivation…",
    description:
      "Votre accès sera immédiatement suspendu sur tous vos appareils. Vos données et contributions seront conservées pour permettre une réactivation par un administrateur.",
  },
  delete: {
    title: "Supprimer définitivement mon compte",
    phrase: "SUPPRIMER",
    button: "Supprimer définitivement",
    pending: "Suppression…",
    description:
      "Cette action est irréversible. Votre identité de connexion, votre profil et vos préférences personnelles seront supprimés. Certaines contributions opérationnelles pourront être conservées sans votre identité pour assurer la traçabilité du service.",
  },
} satisfies Record<AccountAction, {
  title: string;
  phrase: string;
  button: string;
  pending: string;
  description: string;
}>;

function formatDate(date: string) {
  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  }).format(new Date(date));
}

function initials(name: string) {
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();
}

export function AccountSettings({
  displayName,
  email,
  role,
  createdAt,
  managedNetworkCount,
}: AccountSettingsProps) {
  const [action, setAction] = useState<AccountAction | null>(null);

  return (
    <main className="h-full overflow-y-auto bg-[#050b16] text-white">
      <div className="mx-auto w-full max-w-5xl px-6 py-8 sm:px-8 lg:py-12">
        <div className="mb-8">
          <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-blue-400">
            Paramètres personnels
          </p>
          <h1 className="mt-2 text-3xl font-bold tracking-tight">Mon compte</h1>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-400">
            Consultez vos informations et gérez l’accès à votre compte Aule Pro.
          </p>
        </div>

        <section className="overflow-hidden rounded-2xl border border-white/10 bg-[#0a1425] shadow-2xl shadow-black/10">
          <div className="flex flex-col gap-5 border-b border-white/10 p-6 sm:flex-row sm:items-center">
            <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl border border-blue-500/30 bg-blue-500/15 text-lg font-bold text-blue-300">
              {initials(displayName)}
            </div>
            <div className="min-w-0 flex-1">
              <h2 className="truncate text-xl font-semibold">{displayName}</h2>
              <p className="mt-1 text-sm text-slate-400">{ROLE_LABELS[role] ?? role}</p>
            </div>
            <span className="inline-flex w-fit items-center gap-2 rounded-full border border-emerald-500/20 bg-emerald-500/10 px-3 py-1.5 text-xs font-medium text-emerald-300">
              <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
              Compte actif
            </span>
          </div>

          <div className="grid gap-px bg-white/10 sm:grid-cols-2">
            <InfoCell icon={Mail} label="Adresse e-mail" value={email} />
            <InfoCell icon={CircleUserRound} label="Profil" value={ROLE_LABELS[role] ?? role} />
            <InfoCell icon={CalendarDays} label="Membre depuis" value={formatDate(createdAt)} />
            <InfoCell
              icon={Network}
              label="Réseaux administrés"
              value={String(managedNetworkCount)}
            />
          </div>
        </section>

        <section className="mt-6 rounded-2xl border border-white/10 bg-[#0a1425] p-6">
          <div className="flex items-start gap-3">
            <div className="mt-0.5 rounded-xl bg-blue-500/10 p-2.5 text-blue-300">
              <ShieldCheck className="h-5 w-5" />
            </div>
            <div>
              <h2 className="font-semibold">Avant de modifier votre accès</h2>
              <p className="mt-1 text-sm leading-6 text-slate-400">
                Téléchargez les données dont vous avez besoin et transférez vos responsabilités réseau. Une action sera refusée si vous êtes le dernier administrateur d’un espace.
              </p>
              <Link
                href="/confidentialite"
                className="mt-3 inline-flex text-sm font-medium text-blue-400 transition hover:text-blue-300"
              >
                Consulter notre politique de confidentialité
              </Link>
            </div>
          </div>
        </section>

        <section className="mt-6 rounded-2xl border border-red-500/20 bg-red-950/10 p-6">
          <div className="mb-5">
            <p className="text-[11px] font-bold uppercase tracking-[0.16em] text-red-400">
              Zone sensible
            </p>
            <h2 className="mt-1 text-lg font-semibold">Cycle de vie du compte</h2>
          </div>

          <div className="divide-y divide-white/10">
            <DangerRow
              icon={PauseCircle}
              title="Désactiver le compte"
              description="Suspendez votre accès sans supprimer vos données. Une réactivation nécessitera l’intervention d’un administrateur."
              button="Désactiver"
              onClick={() => setAction("deactivate")}
            />
            <DangerRow
              icon={Trash2}
              title="Supprimer le compte"
              description="Supprimez définitivement votre accès et vos données personnelles associées. Cette action ne peut pas être annulée."
              button="Supprimer"
              destructive
              onClick={() => setAction("delete")}
            />
          </div>
        </section>
      </div>

      {action && (
        <AccountActionDialog
          action={action}
          email={email}
          managedNetworkCount={managedNetworkCount}
          onClose={() => setAction(null)}
        />
      )}
    </main>
  );
}

function InfoCell({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof Mail;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-center gap-3 bg-[#0a1425] p-5">
      <Icon className="h-4 w-4 shrink-0 text-slate-500" />
      <div className="min-w-0">
        <p className="text-[11px] font-semibold uppercase tracking-wider text-slate-500">{label}</p>
        <p className="mt-1 truncate text-sm text-slate-200">{value}</p>
      </div>
    </div>
  );
}

function DangerRow({
  icon: Icon,
  title,
  description,
  button,
  destructive = false,
  onClick,
}: {
  icon: typeof Trash2;
  title: string;
  description: string;
  button: string;
  destructive?: boolean;
  onClick: () => void;
}) {
  return (
    <div className="flex flex-col gap-4 py-5 first:pt-0 last:pb-0 sm:flex-row sm:items-center">
      <div className="flex min-w-0 flex-1 gap-3">
        <Icon className="mt-0.5 h-5 w-5 shrink-0 text-red-400" />
        <div>
          <h3 className="text-sm font-semibold text-slate-100">{title}</h3>
          <p className="mt-1 max-w-2xl text-xs leading-5 text-slate-400">{description}</p>
        </div>
      </div>
      <button
        type="button"
        onClick={onClick}
        className={destructive
          ? "h-10 rounded-xl bg-red-600 px-4 text-sm font-semibold text-white transition hover:bg-red-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-400"
          : "h-10 rounded-xl border border-red-500/30 bg-red-500/10 px-4 text-sm font-semibold text-red-300 transition hover:bg-red-500/20 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-400"}
      >
        {button}
      </button>
    </div>
  );
}

function AccountActionDialog({
  action,
  email,
  managedNetworkCount,
  onClose,
}: {
  action: AccountAction;
  email: string;
  managedNetworkCount: number;
  onClose: () => void;
}) {
  const copy = ACTION_COPY[action];
  const [confirmationEmail, setConfirmationEmail] = useState("");
  const [confirmationPhrase, setConfirmationPhrase] = useState("");
  const [accepted, setAccepted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const canSubmit =
    confirmationEmail.trim().toLowerCase() === email.toLowerCase() &&
    confirmationPhrase.trim() === copy.phrase &&
    accepted &&
    !loading;

  useEffect(() => {
    closeButtonRef.current?.focus();
    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape" && !loading) onClose();
    }
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [loading, onClose]);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!canSubmit) return;

    setLoading(true);
    setError(null);

    try {
      const response = await fetch("/api/account", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action,
          confirmationEmail: confirmationEmail.trim(),
          confirmationPhrase: confirmationPhrase.trim(),
          accepted,
        }),
      });
      const payload = (await response.json()) as { error?: string };
      if (!response.ok) throw new Error(payload.error || "L’action n’a pas pu être effectuée.");

      const supabase = createClient();
      await supabase.auth.signOut({ scope: "local" });
      window.location.replace(`/login?account=${action === "delete" ? "deleted" : "deactivated"}`);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Une erreur inattendue est survenue.");
      setLoading(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/75 p-4 backdrop-blur-sm"
      role="presentation"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !loading) onClose();
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="account-dialog-title"
        className="max-h-[92vh] w-full max-w-lg overflow-y-auto rounded-2xl border border-white/10 bg-[#0b1424] shadow-2xl shadow-black/60"
      >
        <div className="flex items-start gap-4 border-b border-white/10 p-6">
          <div className="rounded-xl border border-red-500/20 bg-red-500/10 p-2.5 text-red-400">
            <AlertTriangle className="h-5 w-5" />
          </div>
          <div className="min-w-0 flex-1">
            <h2 id="account-dialog-title" className="text-lg font-semibold text-white">
              {copy.title}
            </h2>
            <p className="mt-2 text-sm leading-6 text-slate-400">{copy.description}</p>
          </div>
          <button
            ref={closeButtonRef}
            type="button"
            onClick={onClose}
            disabled={loading}
            aria-label="Fermer"
            className="rounded-lg p-1.5 text-slate-500 transition hover:bg-white/5 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-400 disabled:opacity-50"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <form onSubmit={submit} className="space-y-5 p-6">
          {managedNetworkCount > 0 && (
            <div className="flex gap-3 rounded-xl border border-amber-500/25 bg-amber-500/10 p-4 text-amber-100">
              <Network className="mt-0.5 h-4 w-4 shrink-0 text-amber-400" />
              <p className="text-xs leading-5">
                Vous administrez {managedNetworkCount} réseau{managedNetworkCount > 1 ? "x" : ""}. L’action sera bloquée si l’un d’eux n’a aucun autre administrateur.
              </p>
            </div>
          )}

          <div>
            <label htmlFor="confirmation-email" className="text-xs font-medium text-slate-300">
              Confirmez votre adresse e-mail
            </label>
            <input
              id="confirmation-email"
              type="email"
              autoComplete="email"
              value={confirmationEmail}
              onChange={(event) => setConfirmationEmail(event.target.value)}
              placeholder={email}
              disabled={loading}
              className="mt-2 h-11 w-full rounded-xl border border-white/10 bg-black/20 px-3 text-sm text-white outline-none transition placeholder:text-slate-600 focus:border-blue-400/60 focus:ring-2 focus:ring-blue-500/15 disabled:opacity-50"
            />
          </div>

          <div>
            <label htmlFor="confirmation-phrase" className="text-xs font-medium text-slate-300">
              Saisissez <span className="font-bold text-white">{copy.phrase}</span> pour continuer
            </label>
            <input
              id="confirmation-phrase"
              type="text"
              autoComplete="off"
              value={confirmationPhrase}
              onChange={(event) => setConfirmationPhrase(event.target.value)}
              disabled={loading}
              className="mt-2 h-11 w-full rounded-xl border border-white/10 bg-black/20 px-3 text-sm text-white outline-none transition focus:border-blue-400/60 focus:ring-2 focus:ring-blue-500/15 disabled:opacity-50"
            />
          </div>

          <label className="flex cursor-pointer items-start gap-3 rounded-xl border border-white/10 bg-white/[0.025] p-4">
            <span className={`mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded border transition ${accepted ? "border-red-500 bg-red-500 text-white" : "border-slate-600 bg-transparent"}`}>
              {accepted && <Check className="h-3.5 w-3.5" />}
            </span>
            <input
              type="checkbox"
              checked={accepted}
              onChange={(event) => setAccepted(event.target.checked)}
              disabled={loading}
              className="sr-only"
            />
            <span className="text-xs leading-5 text-slate-300">
              Je comprends les conséquences de cette action et confirme avoir transféré mes responsabilités nécessaires.
            </span>
          </label>

          {error && (
            <div role="alert" className="flex gap-2 rounded-xl border border-red-500/25 bg-red-500/10 p-3 text-xs leading-5 text-red-200">
              <LockKeyhole className="mt-0.5 h-4 w-4 shrink-0" />
              {error}
            </div>
          )}

          <div className="flex flex-col-reverse gap-3 pt-1 sm:flex-row sm:justify-end">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="h-11 rounded-xl border border-white/10 px-5 text-sm font-semibold text-slate-300 transition hover:bg-white/5 disabled:opacity-50"
            >
              Annuler
            </button>
            <button
              type="submit"
              disabled={!canSubmit}
              className="inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-red-600 px-5 text-sm font-semibold text-white transition hover:bg-red-500 disabled:cursor-not-allowed disabled:opacity-40"
            >
              {loading && <Loader2 className="h-4 w-4 animate-spin" />}
              {loading ? copy.pending : copy.button}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
