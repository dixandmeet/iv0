import type { Metadata } from "next";
import { CreateLinePage } from "@/components/dashboard/create-line-page";

export const metadata: Metadata = {
  title: "Créer une ligne | Aule",
};

export default function NewLinePage() {
  return <CreateLinePage />;
}
