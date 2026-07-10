import type { Metadata } from "next";
import { AdminControlCenter } from "@/components/admin/admin-control-center";

export const metadata: Metadata = {
  title: "Permissions — Aule Studio",
};

export default function AdminPermissionsPage() {
  return <AdminControlCenter view="roles" />;
}
