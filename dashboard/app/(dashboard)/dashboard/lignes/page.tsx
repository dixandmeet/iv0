import type { Metadata } from "next";
import { LinesPageContent } from "@/components/lines/lines-page-content";

export const metadata: Metadata = {
  title: "Lignes | Aule",
};

export default function LinesPage() {
  return <LinesPageContent />;
}
