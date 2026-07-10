import type { Metadata } from "next";
import { RoleWorkspace, proWorkspaces } from "@/components/pro/ecosystem-prototypes";

export const metadata: Metadata = {
  title: "Espace conducteur — Aule Pro",
  description:
    "Cockpit conducteur Aule Pro avec prise de service, planning, véhicule, navigation, messagerie, signalements et échanges.",
};

export default function ConducteurPage() {
  return <RoleWorkspace workspace={proWorkspaces[0]} />;
}
