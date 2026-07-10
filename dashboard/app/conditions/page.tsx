import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/legal-page";

export const metadata: Metadata = {
  title: "Conditions d'utilisation — Aule",
  description: "Les conditions essentielles d'utilisation du service Aule.",
};

export default function TermsPage() {
  return (
    <LegalPage
      eyebrow="Cadre d'utilisation"
      title="Conditions d'utilisation"
      description="Ces conditions fixent les grands principes d'utilisation d'Aule pour les voyageurs et les professionnels."
      sections={[
        {
          title: "Accès au service",
          body: "Aule est propose aux voyageurs et aux professionnels autorises. Certaines fonctionnalites peuvent dependre d'un compte, d'un role ou d'un reseau pilote.",
        },
        {
          title: "Informations transport",
          body: "Les horaires, positions et alertes peuvent provenir de sources externes ou communautaires. Ils sont fournis pour aider a la decision et peuvent varier en temps reel.",
        },
        {
          title: "Usage responsable",
          body: "Chaque utilisateur s'engage a utiliser le service de maniere loyale, sans perturber la plateforme ni publier d'informations fausses, abusives ou sensibles.",
        },
      ]}
    />
  );
}
