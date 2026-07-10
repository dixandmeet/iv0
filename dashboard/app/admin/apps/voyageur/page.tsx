import type { Metadata } from "next";
import { AdminTravelerAppPage } from "@/components/admin/admin-studio-pages";

export const metadata: Metadata = {
  title: "Aule Voyageur — Aule Studio",
};

export default function AuleVoyageurPage() {
  return <AdminTravelerAppPage />;
}
