import type { Metadata } from "next";
import { AdminNetworksPage as AdminNetworksStudioPage } from "@/components/admin/admin-studio-pages";

export const metadata: Metadata = {
  title: "Réseaux — Aule Studio",
};

export default function AdminNetworksPage() {
  return <AdminNetworksPageContent />;
}

function AdminNetworksPageContent() {
  return <AdminNetworksStudioPage />;
}
