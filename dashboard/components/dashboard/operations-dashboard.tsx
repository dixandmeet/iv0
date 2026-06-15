"use client";

import { useCallback, useRef, useState } from "react";
import { useOperationsData } from "@/hooks/use-operations-data";
import { FleetMap, type FleetMapHandle } from "@/components/map/fleet-map";
import { FleetPanel } from "@/components/fleet/fleet-panel";
import { IncidentsPanel } from "@/components/incidents/incidents-panel";
import { KpiBar } from "@/components/dashboard/kpi-bar";
import { VehicleDetailPanel } from "@/components/dashboard/vehicle-detail-panel";
import { ErrorBanner } from "@/components/dashboard/error-banner";

export function OperationsDashboard() {
  const { fleet, incidents, loading, error, lastUpdated, refresh } =
    useOperationsData();
  const [selectedVehicleId, setSelectedVehicleId] = useState<string | null>(null);
  const [selectedIncidentId, setSelectedIncidentId] = useState<string | null>(null);
  const mapRef = useRef<FleetMapHandle>(null);

  const selectedVehicle = fleet.find((v) => v.id === selectedVehicleId) ?? null;

  const handleSelectVehicle = useCallback((id: string | null) => {
    setSelectedVehicleId(id);
    if (id) setSelectedIncidentId(null);
  }, []);

  const handleSelectIncident = useCallback((id: string | null) => {
    setSelectedIncidentId(id);
    if (id) setSelectedVehicleId(null);
  }, []);

  const handleCenterVehicle = useCallback(() => {
    if (selectedVehicleId) {
      mapRef.current?.flyToVehicle(selectedVehicleId);
    }
  }, [selectedVehicleId]);

  return (
    <>
      <div className="dashboard-map flex flex-col">
        {error && <ErrorBanner message={error} onRetry={refresh} />}
        <KpiBar
          fleet={fleet}
          incidents={incidents}
          loading={loading}
          lastUpdated={lastUpdated}
        />
        <div className="relative min-h-0 flex-1">
          <FleetMap
            ref={mapRef}
            fleet={fleet}
            incidents={incidents}
            selectedVehicleId={selectedVehicleId}
            selectedIncidentId={selectedIncidentId}
            onSelectVehicle={handleSelectVehicle}
            onSelectIncident={handleSelectIncident}
          />
        </div>
      </div>
      <aside className="dashboard-panel p-4">
        <FleetPanel
          fleet={fleet}
          selectedId={selectedVehicleId}
          onSelect={handleSelectVehicle}
          loading={loading}
        />
        {selectedVehicle && (
          <VehicleDetailPanel
            vehicle={selectedVehicle}
            onCenter={handleCenterVehicle}
            onClose={() => setSelectedVehicleId(null)}
          />
        )}
        <IncidentsPanel
          incidents={incidents}
          selectedId={selectedIncidentId}
          onSelect={handleSelectIncident}
          loading={loading}
        />
      </aside>
    </>
  );
}
