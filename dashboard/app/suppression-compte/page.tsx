import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/legal-page";

export const metadata: Metadata = {
  title: "Suppression de compte",
  description: "Demander la suppression d'un compte Aule et des données associées.",
  alternates: { canonical: "/suppression-compte" },
};

const requestUrl =
  "mailto:contact@aule.fr?subject=Suppression%20de%20mon%20compte%20Aule";

export default function AccountDeletionPage() {
  return (
    <LegalPage
      eyebrow="Contrôle de vos données"
      title="Supprimer votre compte Aule"
      description="Vous pouvez demander à tout moment la suppression de votre compte Aule et des données qui lui sont associées."
      sections={[
        {
          title: "Envoyer votre demande",
          body: (
            <>
              Écrivez depuis l&apos;adresse liée à votre compte en indiquant
              « Suppression de mon compte Aule » dans l&apos;objet. N&apos;envoyez
              jamais votre mot de passe. {" "}
              <a
                className="font-semibold text-[#33bfa3] underline underline-offset-4 hover:text-white"
                href={requestUrl}
              >
                Envoyer la demande à contact@aule.fr
              </a>
              .
            </>
          ),
        },
        {
          title: "Vérification et délai",
          body: "Aule vérifie que la demande provient bien du titulaire du compte. La suppression est ensuite traitée dans les meilleurs délais et au plus tard sous un mois, sauf demande complexe ou obligation légale particulière.",
        },
        {
          title: "Données supprimées",
          body: "Le compte, le profil, les favoris synchronisés et les autres données directement rattachées au compte sont supprimés. Les contributions déjà publiées peuvent être anonymisées lorsqu'elles doivent rester compréhensibles dans un fil public. Les coordonnées de localisation brutes sont purgées automatiquement sous quinze minutes.",
        },
        {
          title: "Conservation limitée",
          body: "Certaines informations peuvent être conservées uniquement lorsque la loi l'impose ou pour prévenir la fraude et assurer la sécurité du service. Elles sont alors isolées, limitées au strict nécessaire et supprimées à l'issue de la durée applicable.",
        },
      ]}
    />
  );
}
