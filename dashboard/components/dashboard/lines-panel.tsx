"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Plus, Search, SlidersHorizontal, Trash2, X } from "lucide-react";
import { motion } from "framer-motion";
import { DEPOTS, depotLabel } from "@/lib/depot-lines";
import {
  ADD_LINE_DEPOT_OPTIONS,
  isCustomRegulationLine,
  type NewLineInput,
} from "@/lib/regulation-custom-line";
import {
  type NetworkMode,
  type RegulationLine,
  NETWORK_MODE_LABELS,
  formatDelayMinutes,
  lineStatusColor,
  lineStatusLabel,
  normalizeNetworkMode,
} from "@/lib/regulation-mock-data";

interface LinesPanelProps {
  lines: RegulationLine[];
  selectedLineId: string;
  onSelectLine: (lineId: string) => void;
  onAddLine?: (input: NewLineInput) => void;
  onDeleteLine?: (lineId: string) => void;
  loading?: boolean;
}

type ModeFilter = NetworkMode | "all";
type DepotFilter = "all" | string;

const NETWORK_FILTERS: Array<{ value: ModeFilter; label: string }> = [
  { value: "all", label: "Tous" },
  { value: "bus", label: NETWORK_MODE_LABELS.bus },
  { value: "tram", label: NETWORK_MODE_LABELS.tram },
  { value: "boat", label: NETWORK_MODE_LABELS.boat },
];

function matchesLineNumber(line: RegulationLine, lineNumber: string): boolean {
  const q = lineNumber.trim();
  if (!q) return true;
  const normalized = q.toLowerCase();
  return (
    line.shortName.toLowerCase() === normalized ||
    line.routeId.toLowerCase() === normalized ||
    line.id.toLowerCase() === normalized ||
    line.shortName.toLowerCase().startsWith(normalized)
  );
}

export function LinesPanel({
  lines,
  selectedLineId,
  onSelectLine,
  onAddLine,
  onDeleteLine,
  loading,
}: LinesPanelProps) {
  const [search, setSearch] = useState("");
  const [showFilters, setShowFilters] = useState(false);
  const [showAddForm, setShowAddForm] = useState(false);
  const [modeFilter, setModeFilter] = useState<ModeFilter>("all");
  const [depotFilter, setDepotFilter] = useState<DepotFilter>("all");
  const [lineNumber, setLineNumber] = useState("");
  const [newShortName, setNewShortName] = useState("");
  const [newOrigin, setNewOrigin] = useState("");
  const [newDestination, setNewDestination] = useState("");
  const [newTransportType, setNewTransportType] = useState<NetworkMode>("bus");
  const [newDepotCode, setNewDepotCode] = useState(DEPOTS[0]?.code ?? "BLX");
  const lineNumberRef = useRef<HTMLInputElement>(null);
  const shortNameRef = useRef<HTMLInputElement>(null);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();

    return lines.filter((line) => {
      if (depotFilter !== "all" && line.depotCode !== depotFilter) {
        return false;
      }
      if (modeFilter !== "all" && normalizeNetworkMode(line.transportType) !== modeFilter) {
        return false;
      }
      if (lineNumber.trim() && !matchesLineNumber(line, lineNumber)) {
        return false;
      }
      if (!q) return true;
      return (
        line.shortName.toLowerCase().includes(q) ||
        line.origin.toLowerCase().includes(q) ||
        line.destination.toLowerCase().includes(q)
      );
    });
  }, [lines, search, modeFilter, depotFilter, lineNumber]);

  const activeFilterCount =
    (modeFilter !== "all" ? 1 : 0) +
    (depotFilter !== "all" ? 1 : 0) +
    (lineNumber.trim() ? 1 : 0);

  const goToLine = () => {
    const exact = lines.find(
      (line) =>
        line.shortName.toLowerCase() === lineNumber.trim().toLowerCase() ||
        line.routeId.toLowerCase() === lineNumber.trim().toLowerCase(),
    );
    const match = exact ?? filtered[0];
    if (match) onSelectLine(match.id);
  };

  useEffect(() => {
    if (showFilters) {
      requestAnimationFrame(() => lineNumberRef.current?.focus());
    }
  }, [showFilters]);

  useEffect(() => {
    if (showAddForm) {
      requestAnimationFrame(() => shortNameRef.current?.focus());
    }
  }, [showAddForm]);

  const canAddLine =
    newShortName.trim().length > 0 &&
    newOrigin.trim().length > 0 &&
    newDestination.trim().length > 0;

  const resetAddForm = () => {
    setNewShortName("");
    setNewOrigin("");
    setNewDestination("");
    setNewTransportType("bus");
    setNewDepotCode(DEPOTS[0]?.code ?? "BLX");
  };

  const submitAddLine = () => {
    if (!onAddLine || !canAddLine) return;
    onAddLine({
      shortName: newShortName.trim(),
      origin: newOrigin.trim(),
      destination: newDestination.trim(),
      transportType: newTransportType,
      depotCode: newDepotCode,
    });
    resetAddForm();
    setShowAddForm(false);
    setShowFilters(false);
  };

  const clearFilters = () => {
    setModeFilter("all");
    setDepotFilter("all");
    setLineNumber("");
  };

  return (
    <aside className="regulation-lines-panel">
      <div className="regulation-lines-search">
        <div className="regulation-search-input">
          <Search className="h-4 w-4 text-[#94A3B8]" />
          <input
            type="search"
            placeholder="Rechercher une ligne…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <button
          type="button"
          className={`regulation-filter-btn${showFilters ? " active" : ""}${
            activeFilterCount > 0 ? " has-filters" : ""
          }`}
          onClick={() => {
            setShowFilters((open) => !open);
            if (!showFilters) setShowAddForm(false);
          }}
        >
          <SlidersHorizontal className="h-4 w-4" />
          Filtres
          {activeFilterCount > 0 && (
            <span className="regulation-filter-count">{activeFilterCount}</span>
          )}
        </button>
        {onAddLine && (
          <button
            type="button"
            className={`regulation-add-line-btn${showAddForm ? " active" : ""}`}
            onClick={() => {
              setShowAddForm((open) => !open);
              if (!showAddForm) setShowFilters(false);
            }}
            aria-label="Ajouter une ligne"
            title="Ajouter une ligne"
          >
            <Plus className="h-4 w-4" />
          </button>
        )}
      </div>

      {showAddForm && onAddLine && (
        <div className="regulation-add-line-panel">
          <div className="regulation-filters-header">
            <span className="regulation-filters-title">Nouvelle ligne</span>
            <button
              type="button"
              className="regulation-filters-clear"
              onClick={() => {
                setShowAddForm(false);
                resetAddForm();
              }}
            >
              <X className="h-3 w-3" />
              Annuler
            </button>
          </div>

          <p className="regulation-filters-label">N° de ligne</p>
          <input
            ref={shortNameRef}
            type="text"
            className="regulation-line-number-input w-full"
            placeholder="Ex. 99, Z1…"
            value={newShortName}
            onChange={(e) => setNewShortName(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") submitAddLine();
            }}
          />

          <p className="regulation-filters-label">Origine</p>
          <input
            type="text"
            className="regulation-line-number-input w-full"
            placeholder="Terminus de départ"
            value={newOrigin}
            onChange={(e) => setNewOrigin(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") submitAddLine();
            }}
          />

          <p className="regulation-filters-label">Destination</p>
          <input
            type="text"
            className="regulation-line-number-input w-full"
            placeholder="Terminus d'arrivée"
            value={newDestination}
            onChange={(e) => setNewDestination(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") submitAddLine();
            }}
          />

          <p className="regulation-filters-label">Réseau</p>
          <div className="regulation-network-chips">
            {(
              [
                { value: "bus" as const, label: NETWORK_MODE_LABELS.bus },
                { value: "tram" as const, label: NETWORK_MODE_LABELS.tram },
                { value: "boat" as const, label: NETWORK_MODE_LABELS.boat },
              ] as const
            ).map(({ value, label }) => (
              <button
                key={value}
                type="button"
                className={`regulation-network-chip${newTransportType === value ? " active" : ""}`}
                onClick={() => setNewTransportType(value)}
              >
                {label}
              </button>
            ))}
          </div>

          <p className="regulation-filters-label">Dépôt</p>
          <div className="regulation-network-chips">
            {ADD_LINE_DEPOT_OPTIONS.map((depot) => (
              <button
                key={depot.code}
                type="button"
                className={`regulation-network-chip${newDepotCode === depot.code ? " active" : ""}`}
                onClick={() => setNewDepotCode(depot.code)}
              >
                {depot.label}
              </button>
            ))}
          </div>

          <button
            type="button"
            className="regulation-add-line-submit"
            disabled={!canAddLine}
            onClick={submitAddLine}
          >
            <Plus className="h-4 w-4" />
            Créer la ligne
          </button>
        </div>
      )}

      {showFilters && (
        <div className="regulation-filters-panel">
          <div className="regulation-filters-header">
            <span className="regulation-filters-title">Filtrer les lignes</span>
            {activeFilterCount > 0 && (
              <button
                type="button"
                className="regulation-filters-clear"
                onClick={clearFilters}
              >
                <X className="h-3 w-3" />
                Effacer
              </button>
            )}
          </div>

          <p className="regulation-filters-label">Dépôt</p>
          <div className="regulation-network-chips">
            <button
              type="button"
              className={`regulation-network-chip${depotFilter === "all" ? " active" : ""}`}
              onClick={() => setDepotFilter("all")}
            >
              Tous
            </button>
            {DEPOTS.map((depot) => (
              <button
                key={depot.code}
                type="button"
                className={`regulation-network-chip${depotFilter === depot.code ? " active" : ""}`}
                onClick={() => setDepotFilter(depot.code)}
              >
                {depot.name}
              </button>
            ))}
            <button
              type="button"
              className={`regulation-network-chip${depotFilter === "TRAM" ? " active" : ""}`}
              onClick={() => setDepotFilter("TRAM")}
            >
              Tramway
            </button>
            <button
              type="button"
              className={`regulation-network-chip${depotFilter === "NAV" ? " active" : ""}`}
              onClick={() => setDepotFilter("NAV")}
            >
              Navibus
            </button>
          </div>

          <p className="regulation-filters-label">Réseau</p>
          <div className="regulation-network-chips">
            {NETWORK_FILTERS.map(({ value, label }) => (
              <button
                key={value}
                type="button"
                className={`regulation-network-chip${modeFilter === value ? " active" : ""}`}
                onClick={() => setModeFilter(value)}
              >
                {label}
              </button>
            ))}
          </div>

          <p className="regulation-filters-label">N° de ligne</p>
          <div className="regulation-line-number-row">
            <input
              ref={lineNumberRef}
              type="text"
              className="regulation-line-number-input"
              placeholder="Ex. 10, C1, 23…"
              value={lineNumber}
              onChange={(e) => setLineNumber(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") goToLine();
              }}
            />
            <button
              type="button"
              className="regulation-line-go-btn"
              disabled={!lineNumber.trim()}
              onClick={goToLine}
            >
              Aller
            </button>
          </div>
        </div>
      )}

      <p className="regulation-lines-count">
        {loading
          ? "Chargement…"
          : `${filtered.length} / ${lines.length} lignes · BLX, TTX, SHX, Tram, Navibus`}
      </p>

      <div className="regulation-lines-list">
        {loading && lines.length === 0 ? (
          <p className="px-2 text-sm text-[#94A3B8]">Chargement des lignes…</p>
        ) : filtered.length === 0 ? (
          <p className="px-2 text-sm text-[#94A3B8]">
            Aucune ligne ne correspond aux filtres.
          </p>
        ) : (
          filtered.map((line) => {
            const selected = line.id === selectedLineId;
            const canDelete = onDeleteLine && isCustomRegulationLine(line.id);
            return (
              <motion.div
                key={line.id}
                className="regulation-line-item-row"
                whileHover={{ scale: 1.005 }}
                whileTap={{ scale: 0.995 }}
              >
                <button
                  type="button"
                  className={`regulation-line-item${selected ? " selected" : ""}`}
                  onClick={() => onSelectLine(line.id)}
                >
                  <div
                    className="regulation-line-badge"
                    style={{ backgroundColor: line.lineColor }}
                  >
                    {line.shortName}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium text-white">
                      {line.origin} ↔ {line.destination}
                    </p>
                    <div className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-[11px]">
                      <span className="text-[#64748B]">{depotLabel(line.depotCode)}</span>
                      <span className="text-[#64748B]">{line.transportType}</span>
                      <span
                        className="flex items-center gap-1"
                        style={{ color: lineStatusColor(line.status) }}
                      >
                        <span
                          className="h-1.5 w-1.5 rounded-full"
                          style={{ backgroundColor: lineStatusColor(line.status) }}
                        />
                        {lineStatusLabel(line.status)}
                      </span>
                      <span className="text-[#94A3B8]">{line.vehicleCount} véhicules</span>
                      <span className="text-[#94A3B8]">
                        {formatDelayMinutes(line.avgDelay)}
                      </span>
                      <span className="text-[#94A3B8]">
                        {line.incidentCount} incident{line.incidentCount !== 1 ? "s" : ""}
                      </span>
                    </div>
                  </div>
                </button>
                {canDelete && (
                  <button
                    type="button"
                    className="regulation-line-delete-btn"
                    onClick={() => onDeleteLine(line.id)}
                    aria-label={`Supprimer la ligne ${line.shortName}`}
                    title="Supprimer la ligne"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                )}
              </motion.div>
            );
          })
        )}
      </div>
    </aside>
  );
}
