"use client";

import {
  AlertTriangle,
  Bus,
  MapPin,
  Pencil,
  Power,
} from "lucide-react";
import type { StopAuditEntry, StopDeparture, StopListItem, StopServingLine, NearbyStop } from "@/lib/stops-types";
import type { NetworkIncident } from "@/lib/types";
import { stopStatusColor, stopStatusLabel } from "@/lib/stops-types";
import { pointCoordinates } from "@/lib/geo";
import { stopDisambiguationLine } from "@/lib/stops-utils";
import { StopDetailMap } from "@/components/stops/stop-detail-map";
import { StopDetailTabs, type StopDetailTab } from "@/components/stops/stop-detail-tabs";
import { Button } from "@/components/ui/button";

interface StopDetailPanelProps {
  stop: StopListItem | null;
  lines: StopServingLine[];
  departures: StopDeparture[];
  incidents: NetworkIncident[];
  history: StopAuditEntry[];
  nearby: NearbyStop[];
  loading: boolean;
  activeTab: StopDetailTab;
  onTabChange: (tab: StopDetailTab) => void;
  onEdit: () => void;
  onDisable: () => void;
  onViewApproaching: () => void;
  onCreateDisruption: () => void;
  onRefresh: () => void;
}

export function StopDetailPanel({
  stop,
  lines,
  departures,
  incidents,
  history,
  nearby,
  loading,
  activeTab,
  onTabChange,
  onEdit,
  onDisable,
  onViewApproaching,
  onCreateDisruption,
  onRefresh,
}: StopDetailPanelProps) {
  if (!stop) {
    return (
      <div className="stops-detail-empty stops-glass-card">
        <div className="stops-detail-empty-icon">
          <MapPin className="h-10 w-10" />
        </div>
        <h2>Sélectionnez un arrêt</h2>
        <p>Choisissez un arrêt dans la liste pour afficher sa fiche détaillée.</p>
      </div>
    );
  }

  const coords = pointCoordinates(stop.geom);
  const displayName = stop.name ?? stop.station_name ?? stop.code;

  return (
    <div className="stops-detail-panel">
      <div className="stops-detail-header stops-glass-card">
        <div>
          <h2 className="stops-detail-name">{displayName}</h2>
          <p className="stops-detail-disambiguation">{stopDisambiguationLine(stop)}</p>
          <div className="stops-detail-meta">
            <span className="font-mono text-sm text-muted-foreground">{stop.code}</span>
            <span
              className="stops-status-badge"
              style={{
                backgroundColor: `${stopStatusColor(stop.status)}22`,
                color: stopStatusColor(stop.status),
              }}
            >
              {stopStatusLabel(stop.status)}
            </span>
          </div>
        </div>
        <div className="stops-detail-actions">
          <Button size="sm" variant="outline" onClick={onEdit}>
            <Pencil className="h-3.5 w-3.5" />
            Modifier
          </Button>
          <Button size="sm" variant="outline" onClick={onDisable}>
            <Power className="h-3.5 w-3.5" />
            Désactiver
          </Button>
          <Button size="sm" variant="outline" onClick={onViewApproaching}>
            <Bus className="h-3.5 w-3.5" />
            Véhicules en approche
          </Button>
          <Button size="sm" variant="outline" onClick={onCreateDisruption}>
            <AlertTriangle className="h-3.5 w-3.5" />
            Créer une perturbation
          </Button>
        </div>
      </div>

      <StopDetailMap
        coordinates={coords}
        stopName={displayName}
        nearby={nearby}
        lines={lines}
      />

      <StopDetailTabs
        activeTab={activeTab}
        onTabChange={onTabChange}
        stop={stop}
        lines={lines}
        departures={departures}
        incidents={incidents}
        history={history}
        coordinates={coords}
        onRefresh={onRefresh}
        loading={loading}
      />
    </div>
  );
}
