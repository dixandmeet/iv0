import type { Metadata } from "next";
import { AdminNetworkDetailPage } from "@/components/admin/admin-studio-pages";

export const metadata: Metadata = {
  title: "Détail réseau — Aule Studio",
};

export default async function NetworkDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <AdminNetworkDetailPage networkId={id} />;
}
