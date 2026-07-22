import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/legal-page";

export const metadata: Metadata = {
  title: "Contact",
  description: "Contacter l'équipe Aule pour le support, Aule Pro ou la protection des données.",
  alternates: { canonical: "/contact" },
};

export default function ContactPage() {
  return (
    <LegalPage
      eyebrow="Nous contacter"
      title="Contact"
      description="Une adresse unique liée au domaine officiel permet de joindre l'équipe Aule."
      sections={[
        {
          title: "Contact général et support",
          body: "Écrivez à contact@aule.fr. Pour faciliter le traitement, indiquez le service concerné, votre appareil ou navigateur et, si possible, les étapes permettant de reproduire le problème. N'envoyez jamais votre mot de passe.",
        },
        {
          title: "Aule Pro",
          body: "Pour une présentation du SAEIV, un accès professionnel ou un projet de déploiement réseau, précisez votre organisation, votre rôle et le périmètre envisagé dans votre message.",
        },
        {
          title: "Données personnelles",
          body: "Pour exercer un droit RGPD, utilisez la même adresse avec l'objet « Données personnelles ». Précisez le droit concerné et l'adresse liée à votre compte. Une vérification d'identité peut être demandée si nécessaire.",
        },
      ]}
    />
  );
}
