import type { Metadata } from "next";
import Link from "next/link";
import { BusFront } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ProFeatureList, ProHero } from "@/components/pro/pro-sections";

export const metadata: Metadata = {
  title: "Mode conducteur — Aule Pro",
  description:
    "Prise de service automatique par GPS, détection ligne et sens pour les conducteurs de réseaux de transport.",
};

const features = [
  {
    title: "Prise de service automatique",
    description:
      "Détection automatique de la ligne, du sens et du service par GPS dès le départ du dépôt.",
  },
  {
    title: "Zéro saisie manuelle",
    description:
      "Le conducteur se concentre sur la conduite : Aule identifie le contexte sans intervention.",
  },
  {
    title: "Position certifiée",
    description:
      "La position conducteur alimente directement le suivi temps réel pour les voyageurs.",
  },
  {
    title: "Interface simplifiée",
    description:
      "Écran dédié avec informations essentielles : ligne, prochains arrêts, alertes.",
  },
  {
    title: "Fin de service",
    description:
      "Clôture automatique de service à l'arrivée au dépôt ou terminus.",
  },
  {
    title: "Hors-ligne résilient",
    description:
      "Fonctionnement dégradé en cas de perte de connexion avec synchronisation au retour réseau.",
  },
];

export default function ConducteurPage() {
  return (
    <>
      <ProHero
        icon={BusFront}
        title="Mode conducteur"
        description="Une expérience terrain sans friction. Prise de service automatique et positions certifiées pour alimenter l'info-voyageur."
      />
      <section className="section-padding">
        <div className="section-container">
          <ProFeatureList features={features} />
          <div className="mt-12 text-center">
            <Button asChild size="lg">
              <Link href="/login">Télécharger l'app conducteur</Link>
            </Button>
          </div>
        </div>
      </section>
    </>
  );
}
