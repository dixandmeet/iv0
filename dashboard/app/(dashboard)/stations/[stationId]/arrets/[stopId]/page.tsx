import { Suspense } from "react";
import { StopEditPageContent } from "@/components/stops/stop-edit-page-content";

interface PageProps {
  params: Promise<{ stationId: string; stopId: string }>;
}

export default async function StopEditPage({ params }: PageProps) {
  const { stationId, stopId } = await params;
  return (
    <Suspense>
      <StopEditPageContent stationId={stationId} stopId={stopId} />
    </Suspense>
  );
}
