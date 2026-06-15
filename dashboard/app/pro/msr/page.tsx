import type { Metadata } from "next";
import Link from "next/link";
import { Shield } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ProFeatureList, ProHero } from "@/components/pro/pro-sections";

export const metadata: Metadata = {
  title: "Missions sécurité réseau — Aule Pro",
  description:
    "Planification et suivi des patrouilles MSR par secteur et zone de contrôle pour les réseaux de transport.",
};

const features = [
  {
    title: "Zones de contrôle",
    description:
      "Définissez des secteurs par buffer GTFS ou polygone personnalisé pour organiser les patrouilles.",
  },
  {
    title: "Planification des missions",
    description:
      "Créez et assignez des missions MSR avec horaires, secteurs et objectifs clairs.",
  },
  {
    title: "Suivi terrain en direct",
    description:
      "Visualisez la position des agents MSR et l'avancement de leurs missions sur la carte.",
  },
  {
    title: "Remontées certifiées",
    description:
      "Les agents terrain remontent des informations fiables qui alimentent l'info-voyageur.",
  },
  {
    title: "Retour dépôt",
    description:
      "Planification automatique du retour dépôt avec suivi de fin de mission.",
  },
  {
    title: "Historique et reporting",
    description:
      "Consultez l'historique des missions et générez des rapports d'activité par secteur.",
  },
];

export default function MsrPage() {
  return (
    <>
      <ProHero
        icon={Shield}
        title="Missions sécurité réseau"
        description="Organisez et suivez les patrouilles MSR. Des remontées terrain certifiées pour une information voyageur fiable."
      />
      <section className="section-padding">
        <div className="section-container">
          <ProFeatureList features={features} />
          <div className="mt-12 text-center">
            <Button asChild size="lg">
              <Link href="/login">Accéder aux missions MSR</Link>
            </Button>
          </div>
        </div>
      </section>
    </>
  );
}
