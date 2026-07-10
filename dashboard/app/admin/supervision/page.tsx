import type { Metadata } from "next";
import { AdminOperationsPage } from "@/components/admin/admin-section-pages";

export const metadata: Metadata = {
  title: "Supervision — Aule Studio",
};

export default function SupervisionPage() {
  return <AdminOperationsPage title="Supervision" mode="supervision" />;
}
