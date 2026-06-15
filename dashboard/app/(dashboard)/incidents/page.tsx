import { Suspense } from "react";
import { IncidentsPageContent } from "@/components/incidents/incidents-page-content";

export default function IncidentsPage() {
  return (
    <Suspense>
      <IncidentsPageContent />
    </Suspense>
  );
}
