import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/legal-page";

export const metadata: Metadata = {
  title: "Centre d'aide — Aule",
  description: "Retrouvez les informations essentielles pour utiliser Aule et contacter l'equipe.",
};

export default function HelpPage() {
  return (
    <LegalPage
      eyebrow="Support"
      title="Centre d'aide"
      description="Les questions essentielles pour comprendre Aule, signaler un probleme ou contacter l'equipe."
      sections={[
        {
          title: "Utiliser Aule",
          body: "Aule rassemble la carte interactive, les itineraires, le suivi temps reel, les alertes et les services utiles autour de vos trajets.",
        },
        {
          title: "Signaler un probleme",
          body: "Pour un probleme de compte, de localisation, d'itineraire ou de donnee transport, contactez l'equipe avec le plus de contexte possible.",
        },
        {
          title: "Aule Pro",
          body: "Les espaces professionnels sont reserves aux profils autorises : conducteurs, regulateurs, exploitation, controle et administration.",
        },
      ]}
    />
  );
}
