import type { Metadata } from "next";
import { RoleWorkspace, proWorkspaces } from "@/components/pro/ecosystem-prototypes";

export const metadata: Metadata = {
  title: "Espace contrôleur — Aule Pro",
  description:
    "Cockpit contrôleur Aule Pro pour missions, carte, contrôles, procès-verbaux, équipe, planning et statistiques personnelles.",
};

export default function ControleurPage() {
  return <RoleWorkspace workspace={proWorkspaces[1]} />;
}
