import type { Metadata } from "next";
import { AdminMarketplaceStudioPage } from "@/components/admin/admin-studio-pages";

export const metadata: Metadata = {
  title: "Marketplace — Aule Studio",
};

export default function MarketplacePage() {
  return <AdminMarketplaceStudioPage />;
}
