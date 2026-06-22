import { Suspense } from "react";
import { StopCreatePageContent } from "@/components/stops/stop-create-page-content";

interface PageProps {
  params: Promise<{ stationId: string }>;
}

export default async function StopCreatePage({ params }: PageProps) {
  const { stationId } = await params;
  return (
    <Suspense>
      <StopCreatePageContent stationId={stationId} />
    </Suspense>
  );
}
