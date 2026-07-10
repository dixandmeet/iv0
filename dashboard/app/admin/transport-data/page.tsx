import type { Metadata } from "next";
import { AdminTransportDataPage } from "@/components/admin/admin-studio-pages";

export const metadata: Metadata = {
  title: "Données transport — Aule Studio",
};

export default function TransportDataPage() {
  return <AdminTransportDataPage />;
}
