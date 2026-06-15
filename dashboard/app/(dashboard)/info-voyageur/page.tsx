import { Suspense } from "react";
import { InfoVoyageurPageContent } from "@/components/info-voyageur/info-voyageur-page-content";

export default function InfoVoyageurPage() {
  return (
    <Suspense>
      <InfoVoyageurPageContent />
    </Suspense>
  );
}
