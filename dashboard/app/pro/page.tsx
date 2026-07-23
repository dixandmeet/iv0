import type { Metadata } from "next";
import Link from "next/link";
import {
  Activity,
  ArrowRight,
  BusFront,
  ChartNoAxesCombined,
  CircleCheck,
  MapPinned,
  RadioTower,
  ShieldCheck,
  UsersRound,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { ConsoleMap } from "@/components/pro/console-map";

export const metadata: Metadata = {
  title: "Aule Pro — SAEIV pour les réseaux de transport",
  description:
    "Aule Pro réunit supervision SAEIV, information voyageurs, exploitation et équipes terrain dans un dashboard sécurisé.",
  alternates: { canonical: "/pro" },
};

const features = [
  {
    icon: RadioTower,
    title: "Supervision temps réel",
    text: "Suivez la flotte, les lignes, les arrêts et les incidents depuis une vue opérationnelle commune.",
  },
  {
    icon: MapPinned,
    title: "Information voyageurs",
    text: "Centralisez perturbations, alertes et données réseau avant leur diffusion vers les voyageurs.",
  },
  {
    icon: ShieldCheck,
    title: "Missions terrain et MSR",
    text: "Préparez les missions, coordonnez les équipes et conservez un historique exploitable des opérations.",
  },
  {
    icon: BusFront,
    title: "Conducteurs et véhicules",
    text: "Reliez prises de service, affectations, positions et contexte de ligne aux outils du poste de contrôle.",
  },
  {
    icon: UsersRound,
    title: "Accès par rôle",
    text: "Isolez les données et fonctions selon les réseaux, dépôts, équipes et habilitations de chaque profil.",
  },
  {
    icon: ChartNoAxesCombined,
    title: "Pilotage et historique",
    text: "Retrouvez les événements du réseau, suivez l'activité et préparez les analyses d'exploitation.",
  },
] as const;

const stats = [
  { value: "1", label: "Réseau pilote actif", sub: "Nantes métropole" },
  { value: "6", label: "Modules opérationnels", sub: "Socle SAEIV" },
  { value: "24/7", label: "Vision temps réel", sub: "Flotte & incidents" },
  { value: "100%", label: "Accès cloisonné", sub: "Par rôle & dépôt" },
] as const;

const steps = [
  ["01", "Cadrage", "Réseau, dépôts, rôles, données disponibles et objectifs opérationnels."],
  ["02", "Intégration", "Configuration du tenant, imports transport, habilitations et règles de sécurité."],
  ["03", "Pilote", "Mise en situation avec un groupe limité, suivi des incidents et ajustements."],
  ["04", "Ouverture", "Accompagnement des équipes, supervision et évolution progressive du périmètre."],
] as const;

export default function ProPage() {
  return (
    <div className="text-white">
      {/* ── Hero ──────────────────────────────────────────── */}
      <section className="relative overflow-hidden border-b border-white/10 px-6 py-20 sm:py-28">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_80%_-10%,rgba(37,99,235,0.30),transparent_45%),radial-gradient(circle_at_5%_85%,rgba(125,247,192,0.14),transparent_42%)]" />
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/20 to-transparent" />

        <div className="relative mx-auto grid max-w-6xl items-center gap-14 lg:grid-cols-[1.05fr_0.95fr]">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full border border-[#7DF7C0]/25 bg-[#7DF7C0]/10 px-4 py-2 text-sm font-semibold text-[#a7fbd7]">
              <span className="relative flex h-2 w-2">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-[#7DF7C0] opacity-70" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-[#7DF7C0]" />
              </span>
              SAEIV · Réseau pilote à Nantes
            </div>

            <h1 className="mt-8 text-4xl font-bold leading-[1.05] tracking-tight sm:text-6xl">
              Le réseau, le terrain et l&apos;information voyageurs dans un même{" "}
              <span className="bg-gradient-to-r from-blue-400 to-[#7DF7C0] bg-clip-text text-transparent">
                poste de contrôle
              </span>
              .
            </h1>

            <p className="mt-6 max-w-xl text-lg leading-8 text-slate-300">
              Aule Pro est la plateforme SAEIV d&apos;Aule. Elle donne aux équipes
              d&apos;exploitation une vision commune du réseau et relie le dashboard aux
              usages terrain.
            </p>

            <div className="mt-9 flex flex-col gap-3 sm:flex-row">
              <Button asChild size="lg" className="bg-blue-600 text-white shadow-lg shadow-blue-600/25 hover:bg-blue-500">
                <Link href="/login">
                  Connexion au dashboard <ArrowRight className="h-4 w-4" />
                </Link>
              </Button>
              <Button asChild size="lg" variant="outline" className="border-white/15 bg-white/5 text-white hover:bg-white/10 hover:text-white">
                <a href="mailto:contact@aule.fr?subject=Demande%20de%20présentation%20Aule%20Pro">
                  Demander une présentation
                </a>
              </Button>
            </div>

            <p className="mt-6 flex items-center gap-2 text-sm text-slate-500">
              <ShieldCheck className="h-4 w-4 text-[#7DF7C0]/80" aria-hidden="true" />
              Accès sécurisé, cloisonné par réseau, dépôt et habilitation.
            </p>
          </div>

          <ConsolePreview />
        </div>
      </section>

      {/* ── Stats strip ───────────────────────────────────── */}
      <section className="border-b border-white/10 px-6 py-10">
        <div className="mx-auto grid max-w-6xl grid-cols-2 gap-x-6 gap-y-8 md:grid-cols-4">
          {stats.map(({ value, label, sub }) => (
            <div key={label} className="text-center md:text-left">
              <div className="text-3xl font-bold tracking-tight text-white sm:text-4xl">{value}</div>
              <div className="mt-1 text-sm font-semibold text-slate-200">{label}</div>
              <div className="text-xs text-slate-500">{sub}</div>
            </div>
          ))}
        </div>
      </section>

      {/* ── Features ──────────────────────────────────────── */}
      <section id="fonctionnalites" className="scroll-mt-32 px-6 py-20 sm:py-24">
        <div className="mx-auto max-w-6xl">
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-blue-300">Socle opérationnel</p>
          <h2 className="mt-4 max-w-3xl text-3xl font-bold sm:text-4xl">
            Les fonctions utiles à l&apos;exploitation, sans prototype métier public.
          </h2>
          <div className="mt-12 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {features.map(({ icon: Icon, title, text }) => (
              <article
                key={title}
                className="group relative overflow-hidden rounded-2xl border border-white/10 bg-white/[0.035] p-6 transition-all duration-300 hover:-translate-y-1 hover:border-blue-400/30 hover:bg-white/[0.06]"
              >
                <div className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-300 group-hover:opacity-100 bg-[radial-gradient(circle_at_top_right,rgba(37,99,235,0.16),transparent_60%)]" />
                <span className="relative inline-flex rounded-xl bg-gradient-to-br from-blue-500/20 to-[#7DF7C0]/10 p-3 text-blue-200 ring-1 ring-white/10">
                  <Icon className="h-5 w-5" aria-hidden="true" />
                </span>
                <h3 className="relative mt-5 text-lg font-bold">{title}</h3>
                <p className="relative mt-3 text-sm leading-7 text-slate-400">{text}</p>
              </article>
            ))}
          </div>
          <p className="mt-6 flex gap-3 rounded-2xl border border-amber-300/15 bg-amber-300/[0.06] p-5 text-sm leading-7 text-amber-100/80">
            <span className="mt-0.5 shrink-0 text-amber-300">›</span>
            Les modules commerces, livraison, VTC et taxis ne sont pas proposés à ce jour. Ils
            relèvent de la feuille de route et ne sont pas inclus dans le périmètre commercial actuel.
          </p>
        </div>
      </section>

      {/* ── Deployment ────────────────────────────────────── */}
      <section id="deploiement" className="scroll-mt-32 border-y border-white/10 bg-white/[0.025] px-6 py-20 sm:py-24">
        <div className="mx-auto grid max-w-6xl gap-12 lg:grid-cols-[0.9fr_1.1fr] lg:items-start">
          <div className="lg:sticky lg:top-28">
            <p className="text-sm font-bold uppercase tracking-[0.18em] text-[#7DF7C0]">Déploiement</p>
            <h2 className="mt-4 text-3xl font-bold sm:text-4xl">Un accompagnement adapté au réseau.</h2>
            <p className="mt-5 text-base leading-8 text-slate-400">
              Le périmètre, les sources de données et les profils sont cadrés avant l&apos;ouverture
              des accès. Le pilote permet ensuite de valider les usages avec les équipes.
            </p>
            <Button asChild variant="outline" className="mt-8 border-white/15 bg-white/5 text-white hover:bg-white/10 hover:text-white">
              <a href="mailto:contact@aule.fr?subject=Déploiement%20Aule%20Pro">
                Discuter du déploiement <ArrowRight className="h-4 w-4" />
              </a>
            </Button>
          </div>
          <ol className="relative grid gap-4 before:absolute before:left-[27px] before:top-8 before:bottom-8 before:w-px before:bg-white/10">
            {steps.map(([number, title, text]) => (
              <li key={number} className="relative flex gap-4 rounded-2xl border border-white/10 bg-[#07101f] p-5">
                <span className="z-10 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-blue-500/25 to-[#7DF7C0]/15 font-mono text-sm font-bold text-[#7DF7C0] ring-1 ring-white/10">
                  {number}
                </span>
                <div>
                  <h3 className="font-bold">{title}</h3>
                  <p className="mt-2 text-sm leading-6 text-slate-400">{text}</p>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* ── CTA ───────────────────────────────────────────── */}
      <section className="relative overflow-hidden px-6 py-24">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_50%_120%,rgba(37,99,235,0.22),transparent_55%)]" />
        <div className="relative mx-auto max-w-2xl text-center">
          <span className="inline-flex rounded-2xl bg-gradient-to-br from-blue-500/20 to-[#7DF7C0]/10 p-3 ring-1 ring-white/10">
            <CircleCheck className="h-8 w-8 text-[#7DF7C0]" aria-hidden="true" />
          </span>
          <h2 className="mt-6 text-3xl font-bold sm:text-4xl">Vous exploitez un réseau de transport&nbsp;?</h2>
          <p className="mx-auto mt-4 max-w-xl leading-7 text-slate-400">
            Présentez-nous votre contexte à contact@aule.fr ou connectez-vous si votre organisation
            dispose déjà d&apos;un espace.
          </p>
          <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
            <Button asChild size="lg" className="bg-blue-600 text-white shadow-lg shadow-blue-600/25 hover:bg-blue-500">
              <a href="mailto:contact@aule.fr?subject=Projet%20Aule%20Pro">Contacter Aule</a>
            </Button>
            <Button asChild size="lg" variant="outline" className="border-white/15 bg-white/5 text-white hover:bg-white/10 hover:text-white">
              <Link href="/login">Se connecter</Link>
            </Button>
          </div>
        </div>
      </section>
    </div>
  );
}

/** Aperçu stylisé du poste de contrôle (visuel décoratif, sans données réelles). */
function ConsolePreview() {
  return (
    <div className="relative">
      <div className="pointer-events-none absolute -inset-6 rounded-[2rem] bg-gradient-to-br from-blue-500/20 to-[#7DF7C0]/10 opacity-60 blur-2xl" />
      <div className="relative overflow-hidden rounded-2xl border border-white/10 bg-[#07101f]/90 shadow-2xl shadow-black/50 backdrop-blur">
        {/* barre de fenêtre */}
        <div className="flex items-center gap-2 border-b border-white/10 px-4 py-3">
          <span className="h-2.5 w-2.5 rounded-full bg-white/15" />
          <span className="h-2.5 w-2.5 rounded-full bg-white/15" />
          <span className="h-2.5 w-2.5 rounded-full bg-white/15" />
          <span className="ml-3 text-xs font-medium text-slate-400">Poste de contrôle · Temps réel</span>
          <span className="ml-auto inline-flex items-center gap-1.5 rounded-full bg-[#7DF7C0]/10 px-2 py-0.5 text-[10px] font-semibold text-[#7DF7C0]">
            <span className="h-1.5 w-1.5 rounded-full bg-[#7DF7C0]" /> LIVE
          </span>
        </div>

        <div className="grid grid-cols-[1.4fr_1fr] gap-3 p-3">
          {/* zone carte — vraie carte MapLibre */}
          <div className="relative h-56 overflow-hidden rounded-xl border border-white/10 bg-[#0a1628]">
            <ConsoleMap />
            <div className="pointer-events-none absolute bottom-2 left-2 rounded-md bg-black/50 px-2 py-1 text-[10px] font-medium text-slate-200 backdrop-blur">
              12 véhicules en ligne
            </div>
          </div>

          {/* colonne KPI + feed */}
          <div className="flex flex-col gap-3">
            <div className="grid grid-cols-2 gap-2">
              <MiniKpi label="Ponctualité" value="94%" tone="teal" />
              <MiniKpi label="Incidents" value="2" tone="amber" />
            </div>
            <div className="flex-1 rounded-xl border border-white/10 bg-white/[0.02] p-3">
              <div className="text-[10px] font-semibold uppercase tracking-wider text-slate-500">Fil terrain</div>
              <ul className="mt-2 space-y-2">
                <FeedRow dot="#7DF7C0" label="Prise de service" meta="L2 · Dépôt BLX" />
                <FeedRow dot="#3b82f6" label="Mission MSR ouverte" meta="Équipe contrôle" />
                <FeedRow dot="#f59e0b" label="Perturbation signalée" meta="Arrêt Commerce" />
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function MiniKpi({ label, value, tone }: { label: string; value: string; tone: "teal" | "amber" }) {
  const color = tone === "teal" ? "text-[#7DF7C0]" : "text-amber-400";
  return (
    <div className="rounded-xl border border-white/10 bg-white/[0.02] p-3">
      <div className="text-[10px] font-medium text-slate-500">{label}</div>
      <div className={`mt-1 text-xl font-bold ${color}`}>{value}</div>
    </div>
  );
}

function FeedRow({ dot, label, meta }: { dot: string; label: string; meta: string }) {
  return (
    <li className="flex items-center gap-2.5">
      <span className="h-2 w-2 shrink-0 rounded-full" style={{ backgroundColor: dot }} />
      <div className="min-w-0">
        <div className="truncate text-xs font-medium text-slate-200">{label}</div>
        <div className="truncate text-[10px] text-slate-500">{meta}</div>
      </div>
    </li>
  );
}
