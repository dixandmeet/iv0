import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/legal-page";

export const metadata: Metadata = {
  title: "Cookies",
  description: "Comprendre les cookies et stockages locaux utilisés par Aule.",
  alternates: { canonical: "/cookies" },
};

export default function CookiesPage() {
  return (
    <LegalPage
      eyebrow="Préférences"
      title="Cookies"
      description="Aule utilise uniquement les cookies et stockages locaux nécessaires au fonctionnement, à la sécurité et aux choix de l'utilisateur."
      sections={[
        {
          title: "Cookies strictement nécessaires",
          body: "Les cookies d'authentification maintiennent une session sécurisée dans les espaces connectés. Ils sont indispensables au service demandé et ne nécessitent pas de consentement préalable. Leur durée est limitée à la session ou à la durée de connexion choisie.",
        },
        {
          title: "Préférences locales",
          body: "Le thème, certains réglages d'interface et votre choix relatif à la géolocalisation peuvent être mémorisés dans le stockage local du navigateur. Ils restent sur votre appareil jusqu'à leur suppression ou leur remplacement par un nouveau choix.",
        },
        {
          title: "Mesure d'audience et publicité",
          body: "À la date de mise à jour de cette page, Aule ne dépose aucun cookie publicitaire et n'utilise aucun outil de suivi d'audience tiers sur la landing. Si cela change, la présente page sera mise à jour et un consentement sera demandé lorsque la loi l'exige.",
        },
        {
          title: "Services externes",
          body: "La carte, la météo et le géocodage s'appuient sur des services externes susceptibles de recevoir des informations techniques comme l'adresse IP ou la zone demandée. Aule ne leur transmet pas d'identifiant publicitaire.",
        },
        {
          title: "Gérer ou supprimer les données",
          body: "Vous pouvez effacer les cookies et données locales depuis les réglages de votre navigateur, bloquer les stockages non essentiels et retirer l'autorisation de géolocalisation à tout moment. La connexion et certaines préférences devront alors être reconfigurées.",
        },
      ]}
    />
  );
}
