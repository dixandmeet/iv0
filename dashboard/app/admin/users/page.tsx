import type { Metadata } from "next";
import { AdminUsersStudioPage } from "@/components/admin/admin-studio-pages";

export const metadata: Metadata = {
  title: "Utilisateurs — Aule Studio",
};

export const dynamic = "force-dynamic";

export default function AdminUsersPage() {
  return <AdminUsersStudioPage />;
}
