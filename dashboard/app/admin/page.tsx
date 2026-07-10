import type { Metadata } from "next";
import { AdminStudioHome } from "@/components/admin/admin-studio-pages";

export const metadata: Metadata = {
  title: "Aule Studio — Vue d'ensemble",
  description:
    "Pilotage des réseaux, des applications et des données de mobilité Aule.",
};

export default function AdminPage() {
  return <AdminStudioHome />;
}
