import type * as React from "react";
import {
  AlertTriangle,
  BarChart3,
  Bell,
  BusFront,
  CheckCircle2,
  Clock3,
  CreditCard,
  Map,
  Package,
  Radio,
  ShoppingBag,
  Store,
  UserRound,
} from "lucide-react";

type SectionMode =
  | "supervision"
  | "exploitation"
  | "marketplace"
  | "analytics"
  | "account";

const sectionData = {
  supervision: {
    eyebrow: "Supervision",
    description: "Carte temps réel, flotte, incidents, signalements, missions et historique.",
    cards: [
      ["Bus suivis", "241", BusFront],
      ["Trams suivis", "77", Radio],
      ["Incidents ouverts", "3", AlertTriangle],
      ["Missions actives", "18", Map],
    ],
  },
  exploitation: {
    eyebrow: "Exploitation",
    description: "Information voyageurs, perturbations, notifications, équipes et opérations réseau.",
    cards: [
      ["Notifications envoyées", "12", Bell],
      ["Perturbations", "4", AlertTriangle],
      ["Équipes terrain", "28", UserRound],
      ["Services OK", "98%", CheckCircle2],
    ],
  },
  marketplace: {
    eyebrow: "Marketplace",
    description: "Commerçants, produits, commandes, paiements, livreurs et promotions.",
    cards: [
      ["Commandes en cours", "43", Package],
      ["Commerçants actifs", "52", Store],
      ["Paiements OK", "99.9%", CreditCard],
      ["Promotions", "8", ShoppingBag],
    ],
  },
  analytics: {
    eyebrow: "Analytics",
    description: "Graphiques, heatmaps, exports, comparaisons et historique plateforme.",
    cards: [
      ["Trajets analysés", "84k", BarChart3],
      ["Exports", "17", Package],
      ["Heatmaps", "6", Map],
      ["Dernière synchro", "20:42", Clock3],
    ],
  },
  account: {
    eyebrow: "Compte",
    description: "Profil administrateur, préférences, sessions et sécurité du compte.",
    cards: [
      ["Profil", "Kevin", UserRound],
      ["Sessions", "2", CheckCircle2],
      ["Notifications", "Actives", Bell],
      ["Sécurité", "OK", CheckCircle2],
    ],
  },
} satisfies Record<SectionMode, {
  eyebrow: string;
  description: string;
  cards: readonly [string, string, React.ComponentType<{ className?: string }>][];
}>;

export function AdminOperationsPage({
  title,
  mode,
}: {
  title: string;
  mode: SectionMode;
}) {
  const data = sectionData[mode];

  return (
    <main className="admin-app-content">
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-blue-200">
          {data.eyebrow}
        </p>
        <h2 className="mt-2 text-3xl font-bold tracking-tight text-white">{title}</h2>
        <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-400">
          {data.description}
        </p>
      </div>

      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {data.cards.map(([label, value, Icon]) => (
          <article key={label} className="admin-business-card">
            <Icon className="h-5 w-5 text-blue-200" />
            <p className="mt-4 text-xs font-semibold uppercase tracking-[0.14em] text-slate-500">
              {label}
            </p>
            <p className="mt-2 text-3xl font-bold tracking-tight text-white">{value}</p>
          </article>
        ))}
      </section>

      <section className="rounded-lg border border-white/10 bg-white/[0.035] p-5">
        <h3 className="text-sm font-semibold text-white">Espace opérationnel</h3>
        <p className="mt-2 text-sm leading-6 text-slate-400">
          Cette page sert de point d&apos;entrée dédié. Les prochains modules peuvent brancher
          ici les tables métier détaillées sans revenir à une navigation par onglets.
        </p>
      </section>
    </main>
  );
}
