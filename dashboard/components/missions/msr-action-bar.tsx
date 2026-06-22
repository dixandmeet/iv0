"use client";

import {
  History,
  Map,
  Plus,
  RefreshCw,
  Search,
  SlidersHorizontal,
  UserPlus,
  UsersRound,
} from "lucide-react";
import type { ControlPlanStatus } from "@/lib/control-plans/types";
import type { MsrDisplayStatus } from "@/lib/msr-mock-data";
import { MSR_ZONES } from "@/lib/msr-mock-data";
import { useMsrResources } from "@/hooks/use-msr-resources";
import type { MsrWorkspaceTab } from "./msr-workspace-tabs";

export interface MsrFilters {
  status: MsrDisplayStatus | "all";
  teamId: string;
  zoneId: string;
  date: string;
}

export interface PlanFilters {
  status: ControlPlanStatus | "all";
  date: string;
}

interface MsrActionBarProps {
  mode: MsrWorkspaceTab;
  search: string;
  onSearchChange: (v: string) => void;
  missionFilters?: MsrFilters;
  onMissionFiltersChange?: (f: MsrFilters) => void;
  planFilters?: PlanFilters;
  onPlanFiltersChange?: (f: PlanFilters) => void;
  showFilters: boolean;
  onToggleFilters: () => void;
  onRefresh: () => void;
  onPrimaryAction: () => void;
  onAddAgent: () => void;
  onCreateTeam: () => void;
}

export function MsrActionBar({
  mode,
  search,
  onSearchChange,
  missionFilters,
  onMissionFiltersChange,
  planFilters,
  onPlanFiltersChange,
  showFilters,
  onToggleFilters,
  onRefresh,
  onPrimaryAction,
  onAddAgent,
  onCreateTeam,
}: MsrActionBarProps) {
  const { teams } = useMsrResources();
  const primaryLabel =
    mode === "plans" ? "Créer un plan de contrôle" : "Nouvelle mission";

  return (
    <div className="msr-action-section">
      <div className="msr-action-bar">
        <button
          type="button"
          className="msr-btn msr-btn--primary"
          onClick={onPrimaryAction}
        >
          <Plus className="h-4 w-4" />
          {primaryLabel}
        </button>
        <button type="button" className="msr-btn msr-btn--outline" onClick={onAddAgent}>
          <UserPlus className="h-4 w-4" />
          Ajouter un agent
        </button>
        <button type="button" className="msr-btn msr-btn--purple" onClick={onCreateTeam}>
          <UsersRound className="h-4 w-4" />
          Créer une équipe
        </button>
        <button type="button" className="msr-btn msr-btn--outline">
          <Map className="h-4 w-4" />
          Carte des zones
        </button>
        <button type="button" className="msr-btn msr-btn--outline">
          <History className="h-4 w-4" />
          Historique
        </button>

        <div className="msr-action-bar-right">
          <div className="msr-search">
            <Search className="msr-search-icon h-4 w-4" />
            <input
              type="search"
              placeholder="Rechercher..."
              value={search}
              onChange={(e) => onSearchChange(e.target.value)}
              className="msr-search-input"
            />
          </div>
          <button
            type="button"
            className={`msr-btn msr-btn--outline msr-btn--sm${showFilters ? " msr-btn--active" : ""}`}
            onClick={onToggleFilters}
          >
            <SlidersHorizontal className="h-4 w-4" />
            Filtres
          </button>
          <button
            type="button"
            className="msr-btn msr-btn--icon"
            onClick={onRefresh}
            aria-label="Actualiser"
          >
            <RefreshCw className="h-4 w-4" />
          </button>
        </div>
      </div>

      {showFilters && mode === "missions" && missionFilters && onMissionFiltersChange && (
        <div className="msr-filters-panel">
          <div className="msr-filter-field">
            <label htmlFor="msr-filter-status">Statut</label>
            <select
              id="msr-filter-status"
              value={missionFilters.status}
              onChange={(e) =>
                onMissionFiltersChange({
                  ...missionFilters,
                  status: e.target.value as MsrFilters["status"],
                })
              }
            >
              <option value="all">Tous</option>
              <option value="in_progress">En cours</option>
              <option value="planned">Planifiée</option>
              <option value="completed">Terminée</option>
            </select>
          </div>
          <div className="msr-filter-field">
            <label htmlFor="msr-filter-team">Équipe</label>
            <select
              id="msr-filter-team"
              value={missionFilters.teamId}
              onChange={(e) =>
                onMissionFiltersChange({ ...missionFilters, teamId: e.target.value })
              }
            >
              <option value="all">Toutes</option>
              {teams.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
          </div>
          <div className="msr-filter-field">
            <label htmlFor="msr-filter-zone">Zone</label>
            <select
              id="msr-filter-zone"
              value={missionFilters.zoneId}
              onChange={(e) =>
                onMissionFiltersChange({ ...missionFilters, zoneId: e.target.value })
              }
            >
              <option value="all">Toutes</option>
              {MSR_ZONES.map((z) => (
                <option key={z.id} value={z.id}>
                  {z.teamName}
                </option>
              ))}
            </select>
          </div>
          <div className="msr-filter-field">
            <label htmlFor="msr-filter-date">Date</label>
            <input
              id="msr-filter-date"
              type="date"
              value={missionFilters.date}
              onChange={(e) =>
                onMissionFiltersChange({ ...missionFilters, date: e.target.value })
              }
            />
          </div>
        </div>
      )}

      {showFilters && mode === "plans" && planFilters && onPlanFiltersChange && (
        <div className="msr-filters-panel">
          <div className="msr-filter-field">
            <label htmlFor="plan-filter-status">Statut</label>
            <select
              id="plan-filter-status"
              value={planFilters.status}
              onChange={(e) =>
                onPlanFiltersChange({
                  ...planFilters,
                  status: e.target.value as PlanFilters["status"],
                })
              }
            >
              <option value="all">Tous</option>
              <option value="draft">Brouillon</option>
              <option value="active">Actif</option>
              <option value="completed">Terminé</option>
              <option value="suspended">Suspendu</option>
            </select>
          </div>
          <div className="msr-filter-field">
            <label htmlFor="plan-filter-date">Date</label>
            <input
              id="plan-filter-date"
              type="date"
              value={planFilters.date}
              onChange={(e) =>
                onPlanFiltersChange({ ...planFilters, date: e.target.value })
              }
            />
          </div>
        </div>
      )}
    </div>
  );
}

export const DEFAULT_MSR_FILTERS: MsrFilters = {
  status: "all",
  teamId: "all",
  zoneId: "all",
  date: "",
};

export const DEFAULT_PLAN_FILTERS: PlanFilters = {
  status: "all",
  date: "",
};
