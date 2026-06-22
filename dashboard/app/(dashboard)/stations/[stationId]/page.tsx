import { Suspense } from "react";
import { StationEditPageContent } from "@/components/stations/station-edit-page-content";

interface PageProps {
  params: Promise<{ stationId: string }>;
}

export default async function StationDetailPage({ params }: PageProps) {
  const { stationId } = await params;
  return (
    <Suspense>
      <StationEditPageContent stationId={stationId} />
    </Suspense>
  );
}
