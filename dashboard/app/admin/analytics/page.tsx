import type { Metadata } from "next";
import { AdminOperationsPage } from "@/components/admin/admin-section-pages";

export const metadata: Metadata = {
  title: "Analytics — Aule Studio",
};

export default function AnalyticsPage() {
  return <AdminOperationsPage title="Analytics" mode="analytics" />;
}
