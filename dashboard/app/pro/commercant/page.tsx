import type { Metadata } from "next";
import { RoleWorkspace, proWorkspaces } from "@/components/pro/ecosystem-prototypes";

export const metadata: Metadata = {
  title: "Espace commerçant — Aule Pro",
  description:
    "Interface commerçant Aule Pro inspirée Shopify pour boutique, produits, commandes, promotions, horaires, livraisons, statistiques, avis et employés.",
};

export default function CommercantPage() {
  return <RoleWorkspace workspace={proWorkspaces[4]} />;
}
