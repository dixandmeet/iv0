import type { Metadata } from "next";
import Link from "next/link";
import { Settings } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ProFeatureList, ProHero } from "@/components/pro/pro-sections";

export const metadata: Metadata = {
  title: "Administration réseau — Aule Pro",
  description:
    "Configuration réseau, gestion des utilisateurs, rôles et paramètres d'exploitation pour les administrateurs.",
};

const features = [
  {
    title: "Configuration réseau",
    description:
      "Paramétrez les lignes, arrêts, horaires et données GTFS de votre réseau de transport.",
  },
  {
    title: "Gestion des utilisateurs",
    description:
      "Créez et gérez les comptes conducteurs, agents MSR, régulateurs et superviseurs.",
  },
  {
    title: "Rôles et permissions",
    description:
      "6 rôles métier avec droits granulaires : passager, conducteur, MSR, superviseur, régulateur, admin.",
  },
  {
    title: "Paramètres d'exploitation",
    description:
      "Configurez les seuils d'alerte, règles de fiabilité et paramètres de notification.",
  },
  {
    title: "Intégrations",
    description:
      "Connectez vos flux opérateur, API temps réel et sources de données externes.",
  },
  {
    title: "Audit et logs",
    description:
      "Traçabilité complète des actions administratives et modifications de configuration.",
  },
];

export default function AdminPage() {
  return (
    <>
      <ProHero
        icon={Settings}
        title="Administration réseau"
        description="Pilotez la configuration de votre réseau, gérez les accès et supervisez l'ensemble de la plateforme Aule Pro."
      />
      <section className="section-padding">
        <div className="section-container">
          <ProFeatureList features={features} />
          <div className="mt-12 text-center">
            <Button asChild size="lg">
              <Link href="/login">Accéder à l&apos;administration</Link>
            </Button>
          </div>
        </div>
      </section>
    </>
  );
}
