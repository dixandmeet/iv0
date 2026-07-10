import type { Metadata } from "next";
import { EcosystemOverview } from "@/components/pro/ecosystem-prototypes";

export const metadata: Metadata = {
  title: "Aule Pro — Écosystème métier et permissions",
  description:
    "Maquettes haute fidélité des applications Aule Voyageur, Aule Pro et Aule Admin avec séparation stricte des rôles et permissions.",
};

export default function ProPage() {
  return <EcosystemOverview />;
}
