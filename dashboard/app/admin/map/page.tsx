import type { Metadata } from "next";
import { AdminGlobalMapPage } from "@/components/admin/admin-studio-pages";

export const metadata: Metadata = {
  title: "Carte globale — Aule Studio",
};

export default function AdminMapPage() {
  return <AdminGlobalMapPage />;
}
