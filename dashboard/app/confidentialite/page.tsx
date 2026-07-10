import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/legal-page";

export const metadata: Metadata = {
  title: "Confidentialité — Aule",
  description: "Les principes de confidentialite et de protection des donnees personnelles chez Aule.",
};

export default function PrivacyPage() {
  return (
    <LegalPage
      eyebrow="Données personnelles"
      title="Confidentialité"
      description="Aule limite la collecte de donnees aux informations utiles au fonctionnement du service et a l'amelioration de l'experience."
      sections={[
        {
          title: "Données utilisées",
          body: "Selon les fonctionnalites activees, Aule peut utiliser des donnees de compte, de preferences, de position approximative ou precise, et des informations liees aux trajets.",
        },
        {
          title: "Géolocalisation",
          body: "La position est utilisee pour centrer la carte, proposer des transports proches et ameliorer les itineraires. Elle peut etre refusee ou retiree depuis les reglages du navigateur ou de l'appareil.",
        },
        {
          title: "Vos choix",
          body: "Vous pouvez demander l'acces, la correction ou la suppression de vos donnees en contactant Aule a l'adresse indiquee sur cette page.",
        },
      ]}
    />
  );
}
