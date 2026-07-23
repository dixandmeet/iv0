import type { Metadata } from "next";
import { LineOperationsPage } from "@/components/dashboard/line-operations-page";

export const metadata: Metadata = {
  title: "Fiche ligne | Aule",
};

interface LinePageProps {
  params: Promise<{ lineId: string }>;
}

export default async function LinePage({ params }: LinePageProps) {
  const { lineId } = await params;
  return <LineOperationsPage lineId={lineId} />;
}
