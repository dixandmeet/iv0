import type { Metadata } from "next";
import { AdminUserDetailPage } from "@/components/admin/admin-studio-pages";

export const metadata: Metadata = {
  title: "Détail utilisateur — Aule Studio",
};

export const dynamic = "force-dynamic";

export default async function UserDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <AdminUserDetailPage userId={id} />;
}
