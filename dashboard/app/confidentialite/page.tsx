import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/legal-page";

export const metadata: Metadata = {
  title: "Confidentialité",
  description: "Politique de confidentialité et de protection des données personnelles d'Aule.",
  alternates: { canonical: "/confidentialite" },
};

export default function PrivacyPage() {
  return (
    <LegalPage
      eyebrow="Données personnelles"
      title="Politique de confidentialité"
      description="Cette politique explique quelles données Aule traite, pourquoi, pendant combien de temps et comment exercer vos droits."
      sections={[
        {
          title: "Responsable du traitement",
          body: "Aule est responsable des traitements décrits sur cette page. Vous pouvez joindre le responsable de la protection des données à contact@aule.fr pour toute question ou demande relative à vos données personnelles.",
        },
        {
          title: "Données traitées",
          body: "Selon les services utilisés, Aule traite un identifiant aléatoire d'installation, les données de compte et d'authentification (notamment l'adresse e-mail et, s'il est fourni, le nom), les favoris, les contributions et réactions, les demandes adressées au support, les données techniques de sécurité, ainsi que la position lorsque vous activez volontairement la géolocalisation. Les espaces professionnels traitent également les informations nécessaires à l'exploitation du réseau et à la gestion des habilitations.",
        },
        {
          title: "Finalités et bases légales",
          body: "Les données servent à fournir la carte, les itinéraires, les alertes, les comptes et le support (exécution du service), à sécuriser la plateforme et prévenir les abus (intérêt légitime), à respecter les obligations légales, et, uniquement après votre choix, à utiliser la géolocalisation ou les fonctions optionnelles qui nécessitent votre consentement. Aule ne vend pas vos données et ne les utilise pas à des fins de publicité ciblée.",
        },
        {
          title: "Géolocalisation",
          body: "Dans l'application mobile, la position sert à afficher les arrêts proches et à proposer « Ma position » comme point de départ. Si vous activez séparément le partage communautaire, des événements de position pseudonymisés sont envoyés pendant l'utilisation de l'application afin d'améliorer l'information en temps réel ; leurs coordonnées brutes sont supprimées dès qu'elles ont plus de quinze minutes. La version 1.0 n'accède pas à la position en arrière-plan. Sur le site, la position peut centrer la carte et adapter les services de proximité, mais n'est pas rattachée à votre compte. Vous pouvez refuser ou retirer l'autorisation dans les réglages de l'appareil ou du navigateur, et Aule reste utilisable sans géolocalisation.",
        },
        {
          title: "Destinataires et sous-traitants",
          body: "L'accès est limité aux personnes habilitées chez Aule et, selon le service, aux opérateurs de transport concernés. Les prestataires techniques strictement nécessaires peuvent recevoir certaines données : hébergement et authentification Supabase, cartographie OpenStreetMap/CARTO, géocodage Nominatim et météo Open-Meteo. Ils interviennent uniquement pour fournir leur service et selon leurs propres garanties de protection des données.",
        },
        {
          title: "Durées de conservation",
          body: "Les données de compte sont conservées pendant la vie du compte puis supprimées à votre demande ou, à défaut, supprimées ou anonymisées au plus tard trois ans après la dernière activité, sauf obligation légale. Les coordonnées brutes du partage communautaire sont supprimées dès qu'elles ont plus de quinze minutes. Les demandes de support sont conservées trois ans après leur clôture et les journaux techniques et de sécurité au maximum douze mois. Les préférences locales restent sur votre appareil jusqu'à leur suppression. Les durées plus courtes annoncées dans une fonctionnalité particulière prévalent.",
        },
        {
          title: "Vos droits RGPD",
          body: "Vous disposez des droits d'accès, de rectification, d'effacement, de limitation, d'opposition et, lorsque cela s'applique, de portabilité. Vous pouvez retirer votre consentement à tout moment, sans remettre en cause les traitements antérieurs. Pour supprimer un compte, utilisez le lien prévu dans l'application ou la page aule.fr/suppression-compte. Vous pouvez aussi écrire à contact@aule.fr ; une vérification d'identité peut être demandée. Aule répond en principe sous un mois. Vous pouvez enfin déposer une réclamation auprès de la CNIL (cnil.fr).",
        },
        {
          title: "Sécurité et transferts",
          body: "Aule applique des mesures de contrôle d'accès, de chiffrement des échanges, de journalisation et de limitation de conservation. Si un prestataire traite des données hors de l'Espace économique européen, Aule exige un mécanisme reconnu par le RGPD, notamment une décision d'adéquation ou les clauses contractuelles types de la Commission européenne.",
        },
      ]}
    />
  );
}
