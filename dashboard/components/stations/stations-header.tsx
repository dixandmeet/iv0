"use client";

import { Download, Filter, Plus, Upload } from "lucide-react";
import { StationsSearchAutocomplete } from "@/components/stations/stations-search-autocomplete";
import { Button } from "@/components/ui/button";

interface StationsHeaderProps {
  search: string;
  onSearchChange: (value: string) => void;
  onSelectStation: (stationId: string, stationName: string) => void;
  onAdd: () => void;
  onImport: () => void;
  onExport: () => void;
  onToggleFilters: () => void;
  filtersOpen: boolean;
  canManage: boolean;
}

export function StationsHeader({
  search,
  onSearchChange,
  onSelectStation,
  onAdd,
  onImport,
  onExport,
  onToggleFilters,
  filtersOpen,
  canManage,
}: StationsHeaderProps) {
  return (
    <header className="stops-header">
      <div className="stops-header-top">
        <div>
          <h1 className="stops-title">Gestion des stations</h1>
          <p className="stops-subtitle">
            Lieux voyageurs regroupant un ou plusieurs arrêts physiques.
          </p>
        </div>
        <div className="stops-header-actions">
          <Button onClick={onAdd} className="stops-btn-primary" disabled={!canManage}>
            <Plus className="h-4 w-4" />
            Ajouter une station
          </Button>
          <Button variant="outline" onClick={onImport} className="stops-btn-secondary" disabled={!canManage}>
            <Upload className="h-4 w-4" />
            Importer
          </Button>
          <Button variant="outline" onClick={onExport} className="stops-btn-secondary">
            <Download className="h-4 w-4" />
            Exporter
          </Button>
          <Button
            variant="outline"
            onClick={onToggleFilters}
            className={`stops-btn-secondary${filtersOpen ? " stops-btn-secondary--active" : ""}`}
          >
            <Filter className="h-4 w-4" />
            Filtres
          </Button>
        </div>
      </div>
      <StationsSearchAutocomplete
        value={search}
        onChange={onSearchChange}
        onSelectStation={onSelectStation}
      />
    </header>
  );
}
