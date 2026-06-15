"use client";

import { useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useIncidentsData } from "@/hooks/use-incidents-data";
import { useGtfsData } from "@/hooks/use-gtfs-data";
import type { IncidentSeverityFilter, IncidentStatusFilter } from "@/hooks/use-incidents-data";
import { FleetMap, type FleetMapHandle } from "@/components/map/fleet-map";
import { IncidentsPanel } from "@/components/incidents/incidents-panel";
import { IncidentDetailPanel } from "@/components/incidents/incident-detail-panel";
import { IncidentCreateForm } from "@/components/incidents/incident-create-form";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

const STATUS_OPTIONS: { value: IncidentStatusFilter; label: string }[] = [
  { value: "all", label: "Tous" },
  { value: "open", label: "Ouverts" },
  { value: "acknowledged", label: "Acquittés" },
  { value: "in_progress", label: "En cours" },
  { value: "resolved", label: "Résolus" },
  { value: "closed", label: "Clôturés" },
];

const SEVERITY_OPTIONS: { value: IncidentSeverityFilter; label: string }[] = [
  { value: "all", label: "Toutes sévérités" },
  { value: "info", label: "Info" },
  { value: "warning", label: "Alerte" },
  { value: "critical", label: "Critique" },
];

export function IncidentsPageContent() {
  const searchParams = useSearchParams();
  const defaultRoute = searchParams.get("route") ?? "";
  const showCreate = searchParams.get("create") === "1";

  const [statusFilter, setStatusFilter] = useState<IncidentStatusFilter>("all");
  const [severityFilter, setSeverityFilter] =
    useState<IncidentSeverityFilter>("all");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const mapRef = useRef<FleetMapHandle>(null);

  const { incidents, loading, error, refresh } = useIncidentsData({
    statusFilter,
    severityFilter,
  });
  const { routes } = useGtfsData();

  const selectedIncident = incidents.find((i) => i.id === selectedId) ?? null;

  const handleSelect = (id: string | null) => {
    setSelectedId(id);
    if (id) mapRef.current?.flyToIncident(id);
  };

  return (
    <main
      className="flex flex-col overflow-hidden"
      style={{ gridColumn: "2 / -1" }}
    >
      {error && <ErrorBanner message={error} onRetry={refresh} />}

      <div className="flex items-center justify-between border-b border-border px-6 py-4">
        <div>
          <h1 className="text-xl font-semibold">Incidents réseau</h1>
          <p className="text-sm text-muted-foreground">
            Création, suivi et résolution des incidents opérationnels.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge variant="secondary">{incidents.length} incident(s)</Badge>
          <IncidentCreateForm
            routes={routes}
            defaultRouteId={defaultRoute}
            onCreated={() => refresh()}
          />
        </div>
      </div>

      {showCreate && (
        <div className="border-b border-border px-6 py-3">
          <p className="text-xs text-muted-foreground">
            Création rapide depuis la fiche véhicule — utilisez le bouton ci-dessus.
          </p>
        </div>
      )}

      <div className="flex flex-wrap gap-2 border-b border-border px-6 py-3">
        <span className="self-center text-xs text-muted-foreground">Statut :</span>
        {STATUS_OPTIONS.map((opt) => (
          <Button
            key={opt.value}
            variant={statusFilter === opt.value ? "default" : "outline"}
            size="sm"
            className="h-7 text-xs"
            onClick={() => setStatusFilter(opt.value)}
          >
            {opt.label}
          </Button>
        ))}
      </div>

      <div className="flex flex-wrap gap-2 border-b border-border px-6 py-3">
        <span className="self-center text-xs text-muted-foreground">Sévérité :</span>
        {SEVERITY_OPTIONS.map((opt) => (
          <Button
            key={opt.value}
            variant={severityFilter === opt.value ? "default" : "outline"}
            size="sm"
            className="h-7 text-xs"
            onClick={() => setSeverityFilter(opt.value)}
          >
            {opt.label}
          </Button>
        ))}
      </div>

      <div className="grid min-h-0 flex-1 grid-cols-1 lg:grid-cols-2">
        <div className="min-h-[300px] border-b border-border lg:border-b-0 lg:border-r">
          <FleetMap
            ref={mapRef}
            fleet={[]}
            incidents={incidents}
            selectedIncidentId={selectedId}
            onSelectIncident={handleSelect}
            incidentsOnly
          />
        </div>
        <div className="overflow-auto p-4">
          {selectedIncident && (
            <IncidentDetailPanel
              incident={selectedIncident}
              onClose={() => setSelectedId(null)}
              onUpdated={refresh}
              onCenter={() => mapRef.current?.flyToIncident(selectedIncident.id)}
            />
          )}
          <IncidentsPanel
            incidents={incidents}
            selectedId={selectedId}
            onSelect={handleSelect}
            loading={loading}
            showViewAll={false}
          />
        </div>
      </div>
    </main>
  );
}
