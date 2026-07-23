"use client";

import { useEffect, useRef } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { FleetMap, type FleetMapHandle } from "@/components/map/fleet-map";
import { VehicleDetailPanel } from "@/components/dashboard/vehicle-detail-panel";
import { OperationalTimeline } from "@/components/dashboard/operational-timeline";
import { VehicleTravelerComments } from "@/components/dashboard/vehicle-traveler-comments";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { useVehiclePage } from "@/hooks/use-vehicle-page";
import { Button } from "@/components/ui/button";
import { ListSkeleton } from "@/components/ui/empty-state";
import { demoDataEnabled } from "@/lib/demo-mode";

interface VehiclePageContentProps {
  vehicleId: string;
}

export function VehiclePageContent({ vehicleId }: VehiclePageContentProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const mapRef = useRef<FleetMapHandle>(null);

  const service = searchParams.get("service");
  const lineShortName = searchParams.get("line");
  const delayParam = searchParams.get("delay");
  const isDemoQuery = demoDataEnabled && searchParams.get("demo") === "1";
  const delayMin =
    delayParam != null && !Number.isNaN(Number(delayParam)) ? Number(delayParam) : 0;

  const {
    mapVehicle,
    displayLine,
    topology,
    timelineStops,
    driver,
    comments,
    incidents,
    isLive,
    isDemo: isDemoMode,
    loading,
    timelineLoading,
    error,
    lastUpdated,
    refresh,
    serviceLabel,
    fleetOnRoute,
  } = useVehiclePage({
    vehicleId,
    lineShortName,
    service,
    isDemo: isDemoQuery,
    delayMin,
  });

  useEffect(() => {
    if (!mapVehicle) return;
    mapRef.current?.flyToVehicle(mapVehicle.id);
  }, [mapVehicle?.geom.coordinates[0], mapVehicle?.geom.coordinates[1], mapVehicle?.id]);

  const title = serviceLabel;

  return (
    <main className="dashboard-main-column vehicle-page">
      {error && <ErrorBanner message={error} onRetry={refresh} />}

      <div className="vehicle-page-header">
        <Button variant="ghost" size="sm" className="h-8 gap-1.5 px-2" asChild>
          <Link href="/dashboard">
            <ArrowLeft className="h-4 w-4" />
            Retour
          </Link>
        </Button>
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-xl font-semibold">Fiche véhicule · {title}</h1>
          <p className="text-sm text-muted-foreground">
            Géolocalisation temps réel, plan de ligne et retours voyageurs.
          </p>
        </div>
        <div className="flex shrink-0 items-center gap-2">
          {isLive ? (
            <span className="regulation-live-badge">Temps réel</span>
          ) : isDemoMode ? (
            <span className="regulation-demo-badge">Données de démo</span>
          ) : null}
          {lastUpdated && (
            <span className="text-xs text-[#64748B]">
              MAJ {lastUpdated.toLocaleTimeString("fr-FR")}
            </span>
          )}
        </div>
      </div>

      {loading && !mapVehicle ? (
        <div className="p-6">
          <ListSkeleton rows={8} />
        </div>
      ) : !mapVehicle || !displayLine ? (
        <div className="flex flex-1 flex-col items-center justify-center gap-3 p-8">
          <p className="text-sm text-[#94A3B8]">Véhicule introuvable ou hors ligne.</p>
          <Button variant="outline" size="sm" asChild>
            <Link href="/dashboard">Retour au plan de ligne</Link>
          </Button>
        </div>
      ) : (
        <>
          <div className="vehicle-page-tracking">
            <div className="vehicle-page-map">
              <FleetMap
                ref={mapRef}
                fleet={mapVehicle ? [mapVehicle] : []}
                incidents={incidents}
                selectedVehicleId={mapVehicle.id}
                onSelectVehicle={() => {}}
                compact
              />
            </div>
            <div className="vehicle-page-line-plan">
              {displayLine.stops.length >= 2 ? (
                <OperationalTimeline
                  line={displayLine}
                  fleet={fleetOnRoute}
                  timelineStops={timelineStops}
                  topology={topology}
                  loading={timelineLoading}
                  focusVehicleId={vehicleId}
                  embedded
                  allowDemo={isDemoMode}
                />
              ) : timelineLoading ? (
                <div className="flex h-full items-center justify-center p-6">
                  <p className="text-sm text-[#94A3B8]">Chargement du plan de ligne…</p>
                </div>
              ) : (
                <div className="flex h-full items-center justify-center p-6">
                  <p className="text-sm text-[#94A3B8]">Plan de ligne indisponible.</p>
                </div>
              )}
            </div>
          </div>

          <div className="vehicle-page-panels">
            <div className="vehicle-page-detail">
              <VehicleDetailPanel
                vehicle={mapVehicle}
                driver={driver}
                onCenter={() => mapRef.current?.flyToVehicle(mapVehicle.id)}
                onClose={() => router.push("/dashboard")}
                showClose={false}
              />
            </div>
            <VehicleTravelerComments comments={comments} />
          </div>
        </>
      )}
    </main>
  );
}
