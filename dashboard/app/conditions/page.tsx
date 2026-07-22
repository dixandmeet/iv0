import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/legal-page";

export const metadata: Metadata = {
  title: "Conditions d'utilisation",
  description: "Conditions d'utilisation des services Aule et Aule Pro.",
  alternates: { canonical: "/conditions" },
};

export default function TermsPage() {
  return (
    <LegalPage
      eyebrow="Cadre d'utilisation"
      title="Conditions d'utilisation"
      description="Ces conditions encadrent l'accès à la landing, aux services voyageurs et aux espaces professionnels Aule."
      sections={[
        {
          title: "Objet du service",
          body: "Aule fournit de l'information voyageurs, des outils de préparation de trajet et une plateforme SAEIV destinée aux professionnels du transport. Le réseau de Nantes est présenté comme pilote. Les services signalés « prochainement » ou « bientôt disponible » ne font pas partie du service actuellement accessible.",
        },
        {
          title: "Information voyageurs",
          body: "Les horaires, positions, itinéraires et perturbations peuvent provenir d'opérateurs ou de fournisseurs tiers. Ils sont fournis à titre informatif et peuvent être incomplets, retardés ou indisponibles. Pour une décision critique, vérifiez les informations auprès de l'opérateur de transport concerné.",
        },
        {
          title: "Comptes et espaces professionnels",
          body: "L'accès à Aule Pro et au dashboard est réservé aux personnes autorisées. Chaque utilisateur doit fournir des informations exactes, préserver la confidentialité de ses identifiants et signaler sans délai toute utilisation non autorisée de son compte.",
        },
        {
          title: "Usages interdits",
          body: "Il est interdit de contourner les contrôles d'accès, perturber le service, extraire massivement les données, introduire un contenu malveillant, usurper une identité ou publier un signalement illicite, trompeur ou portant atteinte aux droits d'un tiers.",
        },
        {
          title: "Disponibilité",
          body: "Aule s'efforce de maintenir un service fiable, sans garantir une disponibilité continue. Des interruptions peuvent intervenir pour maintenance, sécurité, évolution du produit ou défaillance d'un service tiers. Les fonctionnalités pilotes peuvent évoluer avant leur ouverture générale.",
        },
        {
          title: "Propriété intellectuelle",
          body: "La marque, l'interface, les textes, logiciels et éléments visuels propres à Aule sont protégés. Les données et fonds cartographiques restent soumis aux droits et licences de leurs producteurs respectifs, notamment OpenStreetMap et les opérateurs de transport.",
        },
        {
          title: "Responsabilité",
          body: "Aule ne remplace ni les consignes des opérateurs ni les informations de sécurité sur le terrain. Dans les limites permises par la loi, Aule n'est pas responsable des décisions prises sur la seule base d'une donnée tierce, d'une indisponibilité temporaire ou d'un usage contraire aux présentes conditions.",
        },
        {
          title: "Contact et évolution",
          body: "Pour toute question, écrivez à contact@aule.fr. Les conditions peuvent évoluer pour refléter le service ou la réglementation ; la date de mise à jour figurant en bas de page fait foi. Le droit français s'applique, sous réserve des règles impératives protégeant les consommateurs.",
        },
      ]}
    />
  );
}
