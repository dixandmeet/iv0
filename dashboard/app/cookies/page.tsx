import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/legal-page";

export const metadata: Metadata = {
  title: "Cookies — Aule",
  description: "Comprendre les cookies et stockages locaux utilises par Aule.",
};

export default function CookiesPage() {
  return (
    <LegalPage
      eyebrow="Préférences"
      title="Cookies"
      description="Aule utilise des stockages techniques pour faire fonctionner l'interface et memoriser certains choix utilisateur."
      sections={[
        {
          title: "Stockage nécessaire",
          body: "Des informations locales peuvent etre conservees pour la session, le theme, la connexion, la securite ou le consentement a certaines fonctionnalites.",
        },
        {
          title: "Géolocalisation",
          body: "Le choix lie a la geolocalisation peut etre memorise afin d'eviter de redemander la meme autorisation a chaque visite.",
        },
        {
          title: "Gestion",
          body: "Vous pouvez supprimer les cookies et donnees locales depuis les reglages de votre navigateur. Certaines fonctionnalites devront alors etre reconfigurees.",
        },
      ]}
    />
  );
}
