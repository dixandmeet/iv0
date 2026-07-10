import type { Metadata } from "next";
import { AdminProAppPage } from "@/components/admin/admin-studio-pages";

export const metadata: Metadata = {
  title: "Aule Pro — Aule Studio",
};

export default function AuleProPage() {
  return <AdminProAppPage />;
}
