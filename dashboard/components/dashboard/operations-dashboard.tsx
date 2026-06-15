"use client";

import { useCallback, useMemo, useRef, useState } from "react";
import { useOperationsData } from "@/hooks/use-operations-data";
import { useDriversData } from "@/hooks/use-drivers-data";
import { useGtfsData } from "@/hooks/use-gtfs-data";
import { FleetMap, type FleetMapHandle } from "@/components/map/fleet-map";
import { FleetPanel } from "@/components/fleet/fleet-panel";
import { IncidentsPanel } from "@/components/incidents/incidents-panel";
import { IncidentDetailPanel } from "@/components/incidents/incident-detail-panel";
import { KpiBar } from "@/components/dashboard/kpi-bar";
import { AlertsBanner } from "@/components/dashboard/alerts-banner";
import { VehicleDetailPanel } from "@/components/dashboard/vehicle-detail-panel";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { computeOperationalAlerts } from "@/lib/alerts";
import type { OperationalAlert } from "@/lib/types";

export function OperationsDashboard() {
  const { fleet, incidents, loading, error, lastUpdated, refresh } =
    useOperationsData();
  const { drivers } = useDriversData();
  const { stops } = useGtfsData();

  const [selectedVehicleId, setSelectedVehicleId] = useState<string | null>(null);
  const [selectedIncidentId, setSelectedIncidentId] = useState<string | null>(null);
  const [routeFilter, setRouteFilter] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [bannerDismissed, setBannerDismissed] = useState(false);
  const mapRef = useRef<FleetMapHandle>(null);

  const alerts = useMemo(
    () => computeOperationalAlerts(fleet, incidents, drivers),
    [fleet, incidents, drivers],
  );

  const activeRoutes = useMemo(
    () => [...new Set(fleet.map((v) => v.route_id))].sort(),
    [fleet],
  );

  const selectedVehicle = fleet.find((v) => v.id === selectedVehicleId) ?? null;
  const selectedIncident =
    incidents.find((i) => i.id === selectedIncidentId) ?? null;

  const linkedDriver = selectedVehicle?.driver_session_id
    ? drivers.find((d) => d.id === selectedVehicle.driver_session_id)
    : drivers.find(
        (d) =>
          d.route_id === selectedVehicle?.route_id &&
          (d.status === "active" || d.status === "paused"),
      );

  const connectedDrivers = drivers.filter(
    (d) => d.status === "active" || d.status === "paused",
  ).length;

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

  const handleAlertSelect = useCallback(
    (alert: OperationalAlert) => {
      if (alert.vehicle_id) {
        handleSelectVehicle(alert.vehicle_id);
        mapRef.current?.flyToVehicle(alert.vehicle_id);
      } else if (alert.incident_id) {
        handleSelectIncident(alert.incident_id);
        mapRef.current?.flyToIncident(alert.incident_id);
      }
    },
    [handleSelectVehicle, handleSelectIncident],
  );

  return (
    <>
      <div className="dashboard-map flex flex-col">
        {error && <ErrorBanner message={error} onRetry={refresh} />}
        <KpiBar
          fleet={fleet}
          incidents={incidents}
          connectedDrivers={connectedDrivers}
          alertCount={alerts.length}
          loading={loading}
          lastUpdated={lastUpdated}
        />
        {!bannerDismissed && alerts.length > 0 && (
          <AlertsBanner
            alerts={alerts}
            onSelectAlert={handleAlertSelect}
            onDismiss={() => setBannerDismissed(true)}
          />
        )}
        <div className="relative min-h-0 flex-1">
          <FleetMap
            ref={mapRef}
            fleet={fleet}
            incidents={incidents}
            stops={stops}
            selectedVehicleId={selectedVehicleId}
            selectedIncidentId={selectedIncidentId}
            onSelectVehicle={handleSelectVehicle}
            onSelectIncident={handleSelectIncident}
            routeFilter={routeFilter}
            showStops
          />
        </div>
      </div>
      <aside className="dashboard-panel p-4">
        <FleetPanel
          fleet={fleet}
          selectedId={selectedVehicleId}
          onSelect={handleSelectVehicle}
          loading={loading}
          routeFilter={routeFilter}
          onRouteFilterChange={setRouteFilter}
          routes={activeRoutes}
          searchQuery={searchQuery}
          onSearchChange={setSearchQuery}
        />
        {selectedVehicle && (
          <VehicleDetailPanel
            vehicle={selectedVehicle}
            driver={linkedDriver}
            onCenter={handleCenterVehicle}
            onClose={() => setSelectedVehicleId(null)}
          />
        )}
        {selectedIncident && (
          <IncidentDetailPanel
            incident={selectedIncident}
            onClose={() => setSelectedIncidentId(null)}
            onUpdated={refresh}
            onCenter={() => mapRef.current?.flyToIncident(selectedIncident.id)}
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
