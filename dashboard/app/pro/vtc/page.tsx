import type { Metadata } from "next";
import { RoleWorkspace, proWorkspaces } from "@/components/pro/ecosystem-prototypes";

export const metadata: Metadata = {
  title: "Espace chauffeur VTC — Aule Pro",
  description:
    "Cockpit VTC Aule Pro pour courses, disponibilités, historique, revenus, planning, statistiques, messagerie et profil.",
};

export default function VtcPage() {
  return <RoleWorkspace workspace={proWorkspaces[3]} />;
}
