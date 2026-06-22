import { Suspense } from "react";
import { VehiclePageContent } from "@/components/dashboard/vehicle-page-content";

interface PageProps {
  params: Promise<{ vehicleId: string }>;
}

export default async function VehicleDetailPage({ params }: PageProps) {
  const { vehicleId } = await params;

  return (
    <Suspense>
      <VehiclePageContent vehicleId={decodeURIComponent(vehicleId)} />
    </Suspense>
  );
}
