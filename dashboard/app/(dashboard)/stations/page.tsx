import { Suspense } from "react";
import { StationsPageContent } from "@/components/stations/stations-page-content";

export default function StationsPage() {
  return (
    <Suspense>
      <StationsPageContent />
    </Suspense>
  );
}
