import type { Metadata } from "next";
import { AdminSettingsStudioPage } from "@/components/admin/admin-studio-pages";

export const metadata: Metadata = {
  title: "Configuration — Aule Studio",
};

export default function AdminSettingsPage() {
  return <AdminSettingsStudioPage />;
}
