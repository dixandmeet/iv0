import type { Metadata } from "next";
import Link from "next/link";
import { Monitor } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ProFeatureList, ProHero } from "@/components/pro/pro-sections";

export const metadata: Metadata = {
  title: "Poste de contrôle — Aule Pro",
  description:
    "Supervision flotte, incidents et régulation en temps réel pour les régulateurs de réseaux de transport.",
};

const features = [
  {
    title: "Cartographie réseau temps réel",
    description:
      "Visualisez l'ensemble du réseau avec positions véhicules, lignes et arrêts sur une carte interactive.",
  },
  {
    title: "Suivi de flotte",
    description:
      "Monitoring des véhicules en service avec statuts, retards et données de position certifiées.",
  },
  {
    title: "Gestion des incidents",
    description:
      "Création, suivi et résolution des incidents avec remontée automatique vers l'info-voyageur.",
  },
  {
    title: "Régulation active",
    description:
      "Outils de régulation pour ajuster les services et communiquer avec les équipes terrain.",
  },
  {
    title: "Tableaux de bord",
    description:
      "Indicateurs clés de performance : ponctualité, charge, perturbations et qualité de service.",
  },
  {
    title: "Multi-sources de données",
    description:
      "Agrégation des positions conducteurs, communautaires et flux opérateur avec score de fiabilité.",
  },
];

export default function RegulateurPage() {
  return (
    <>
      <ProHero
        icon={Monitor}
        title="Poste de contrôle"
        description="Le centre névralgique de l'exploitation. Supervisez la flotte, gérez les incidents et régulez le réseau en temps réel."
      />
      <section className="section-padding">
        <div className="section-container">
          <ProFeatureList features={features} />
          <div className="mt-12 text-center">
            <Button asChild size="lg">
              <Link href="/login">Accéder au poste de contrôle</Link>
            </Button>
          </div>
        </div>
      </section>
    </>
  );
}
