import type { Metadata } from "next";
import { AdminOperationsPage } from "@/components/admin/admin-section-pages";

export const metadata: Metadata = {
  title: "Mon compte — Aule Studio",
};

export default function AccountPage() {
  return <AdminOperationsPage title="Mon compte" mode="account" />;
}
