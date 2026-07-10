import type { Metadata } from "next";
import { AdminLogsStudioPage } from "@/components/admin/admin-studio-pages";

export const metadata: Metadata = {
  title: "Logs — Aule Studio",
};

export default function AdminLogsPage() {
  return <AdminLogsStudioPage />;
}
