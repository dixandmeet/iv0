import { Suspense } from "react";
import { DriversPageContent } from "@/components/drivers/drivers-page-content";

export default function ConducteursPage() {
  return (
    <Suspense>
      <DriversPageContent />
    </Suspense>
  );
}
