"use client";

import type { StationFilters, StationStatus } from "@/lib/stations-types";
import { STATION_STATUS_LABELS } from "@/lib/stations-types";
import { Label, Select } from "@/components/ui/label";
import { Button } from "@/components/ui/button";

interface StationsFiltersPanelProps {
  filters: StationFilters;
  onChange: (filters: StationFilters) => void;
  communes: string[];
  onClose: () => void;
}

export function StationsFiltersPanel({
  filters,
  onChange,
  communes,
  onClose,
}: StationsFiltersPanelProps) {
  return (
    <aside className="stops-filters-panel stops-glass-card">
      <div className="stops-filters-header">
        <h3>Filtres</h3>
        <Button variant="ghost" size="sm" onClick={onClose}>
          Fermer
        </Button>
      </div>
      <div className="stops-filters-body">
        <div className="space-y-1.5">
          <Label>Statut</Label>
          <Select
            value={filters.status}
            onChange={(e) =>
              onChange({ ...filters, status: e.target.value as StationStatus | "all" })
            }
          >
            <option value="all">Tous les statuts</option>
            {(Object.keys(STATION_STATUS_LABELS) as StationStatus[]).map((s) => (
              <option key={s} value={s}>
                {STATION_STATUS_LABELS[s]}
              </option>
            ))}
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label>Commune</Label>
          <Select
            value={filters.commune}
            onChange={(e) => onChange({ ...filters, commune: e.target.value })}
          >
            <option value="">Toutes les communes</option>
            {communes.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </Select>
        </div>
        <Button
          variant="outline"
          className="w-full"
          onClick={() => onChange({ status: "all", commune: "" })}
        >
          Réinitialiser
        </Button>
      </div>
    </aside>
  );
}
