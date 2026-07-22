"use client";

import {
  Activity,
  AlertCircle,
  AlertTriangle,
  Archive,
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  BusFront,
  ChevronLeft,
  ChevronRight,
  CircleDot,
  Copy,
  ExternalLink,
  Map as MapIcon,
  MapPin,
  MoreHorizontal,
  Network,
  PauseCircle,
  Pencil,
  Plus,
  RefreshCw,
  Route,
  Search,
  Split,
  TrainFront,
  Trash2,
  Upload,
} from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ChangeEvent,
  type MouseEvent,
} from "react";
import { useNetwork } from "@/components/network/network-provider";
import { Button } from "@/components/ui/button";
import { createClient } from "@/lib/supabase/client";
import { useCustomRegulationLines } from "@/hooks/use-custom-regulation-lines";
import { useRegulationDashboard } from "@/hooks/use-regulation-dashboard";
import type { RegulationLine } from "@/lib/regulation-mock-data";
import { isCustomRegulationLine } from "@/lib/regulation-custom-line";

type LifecycleStatus = "active" | "inactive" | "preparation" | "archived";
type OperatingState = "normal" | "delay" | "disrupted" | "interrupted";
type DisplayState = OperatingState | "inactive" | "preparation";
type QuickFilter = "all" | "bus" | "tram" | "other" | "active" | "disrupted";
type Density = "comfortable" | "compact";
type SortKey =
  | "line"
  | "mode"
  | "state"
  | "vehicles"
  | "drivers"
  | "punctuality"
  | "incidents"
  | "updated";

interface DepotOption {
  code: string;
  label: string;
}

interface DirectoryLine {
  id: string;
  routeId: string;
  shortName: string;
  name: string;
  origin: string;
  destination: string;
  color: string;
  mode: string;
  modeKey: string;
  depotCodes: string[];
  lifecycle: LifecycleStatus;
  operatingState: OperatingState;
  displayState: DisplayState;
  vehicles: number | null;
  drivers: number | null;
  punctuality: number | null;
  incidents: number;
  updatedAt: string | null;
  directions: number;
  variants: number;
  hasAssociations: boolean;
  canMutate: boolean;
  sourceLine: RegulationLine;
}

const LIFECYCLE_LABELS: Record<LifecycleStatus, string> = {
  active: "Active",
  inactive: "Inactive",
  preparation: "En préparation",
  archived: "Archivée",
};

const STATE_LABELS: Record<DisplayState, string> = {
  normal: "Normal",
  delay: "Retard",
  disrupted: "Perturbée",
  interrupted: "Interrompue",
  inactive: "Inactive",
  preparation: "En préparation",
};

const STATE_ORDER: Record<DisplayState, number> = {
  interrupted: 0,
  disrupted: 1,
  delay: 2,
  normal: 3,
  preparation: 4,
  inactive: 5,
};

function modeKey(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "-");
}

function isBusMode(value: string): boolean {
  return value.toLowerCase().includes("bus");
}

function isTramMode(value: string): boolean {
  return value.toLowerCase().includes("tram");
}

function lifecycleOf(line: RegulationLine): LifecycleStatus {
  if (line.lifecycleStatus) return line.lifecycleStatus;
  if (line.editorState?.status === "draft" || line.editorState?.status === "validation") {
    return "preparation";
  }
  return "active";
}

function operatingStateOf(line: RegulationLine): OperatingState {
  if (line.status === "critique") return "interrupted";
  if (line.incidentCount > 0) return "disrupted";
  if (line.status === "perturbe" || line.avgDelay >= 2) return "delay";
  return "normal";
}

function variantInfo(line: RegulationLine): { directions: number; variants: number } {
  const editor = line.editorState;
  if (!editor) return { directions: 0, variants: 0 };
  const directions = Number(editor.pointsAller.length > 0) + Number(editor.pointsRetour.length > 0);
  const variants =
    editor.branchesAller.length +
    editor.branchesRetour.length +
    editor.originLegsAller.length +
    editor.originLegsRetour.length;
  return { directions, variants };
}

function compareNullableNumber(a: number | null, b: number | null): number {
  if (a === null && b === null) return 0;
  if (a === null) return 1;
  if (b === null) return -1;
  return a - b;
}

function formatUpdatedAt(value: string | null): string {
  if (!value) return "Indisponible";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Indisponible";
  const seconds = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000));
  if (seconds < 60) return "À l’instant";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `Il y a ${minutes} min`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `Il y a ${hours} h`;
  return new Intl.DateTimeFormat("fr-FR", { day: "2-digit", month: "short", year: "numeric" }).format(date);
}

function StateBadge({ state }: { state: DisplayState }) {
  return (
    <span className={`lines-state-badge lines-state-badge--${state}`}>
      <span className="lines-state-dot" />
      {STATE_LABELS[state]}
    </span>
  );
}

function SortButton({
  label,
  column,
  active,
  direction,
  onSort,
}: {
  label: string;
  column: SortKey;
  active: boolean;
  direction: "asc" | "desc";
  onSort: (column: SortKey) => void;
}) {
  const Icon = active ? (direction === "asc" ? ArrowUp : ArrowDown) : ArrowUpDown;
  return (
    <button type="button" className="lines-sort-button" onClick={() => onSort(column)}>
      {label}
      <Icon className="h-3.5 w-3.5" />
    </button>
  );
}

export function LinesPageContent() {
  const router = useRouter();
  const { network, canManage } = useNetwork();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const {
    customLines,
    ready: customReady,
    addLine,
    deleteLine,
    updateLineLifecycle,
    refresh: refreshCustomLines,
  } = useCustomRegulationLines();
  const {
    lines: networkLines,
    fleet,
    drivers,
    loading: operationsLoading,
    driversLoading,
    error: operationsError,
    lastUpdated,
    refresh: refreshOperations,
    refreshDrivers,
  } = useRegulationDashboard(null);

  const [configuredDepots, setConfiguredDepots] = useState<DepotOption[]>([]);
  const [search, setSearch] = useState("");
  const [modeFilter, setModeFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState<LifecycleStatus | "all">("all");
  const [stateFilter, setStateFilter] = useState<OperatingState | "all">("all");
  const [depotFilter, setDepotFilter] = useState("all");
  const [incidentsOnly, setIncidentsOnly] = useState(false);
  const [quickFilter, setQuickFilter] = useState<QuickFilter>("all");
  const [sortKey, setSortKey] = useState<SortKey>("line");
  const [sortDirection, setSortDirection] = useState<"asc" | "desc">("asc");
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(25);
  const [density, setDensity] = useState<Density>("comfortable");
  const [importing, setImporting] = useState(false);
  const [notice, setNotice] = useState<{ kind: "success" | "error"; message: string } | null>(null);
  const [actionBusy, setActionBusy] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createClient();
    void supabase
      .from("network_depots")
      .select("code, name")
      .eq("network_id", network.id)
      .order("name")
      .then(({ data }) => {
        setConfiguredDepots(
          (data ?? []).map((depot) => ({ code: String(depot.code), label: String(depot.name) })),
        );
      });
  }, [network.id]);

  const directoryLines = useMemo<DirectoryLine[]>(() => {
    const fleetRouteIds = new Set(fleet.map((vehicle) => vehicle.route_id));
    const liveDriversByRoute = new Map<string, number>();
    for (const driver of drivers) {
      if (!driver.route_id || (driver.status !== "active" && driver.status !== "paused")) continue;
      liveDriversByRoute.set(driver.route_id, (liveDriversByRoute.get(driver.route_id) ?? 0) + 1);
    }

    const grouped = new Map<string, { line: RegulationLine; depots: Set<string> }>();
    for (const line of [...customLines, ...networkLines]) {
      const commercialId = line.routeId || line.id;
      const existing = grouped.get(commercialId);
      if (existing) {
        if (line.depotCode) existing.depots.add(line.depotCode);
        continue;
      }
      grouped.set(commercialId, {
        line,
        depots: new Set(line.depotCode ? [line.depotCode] : []),
      });
    }

    return Array.from(grouped.values()).map(({ line, depots }) => {
      const routeId = line.routeId || line.id;
      const realtimeAvailable = fleetRouteIds.has(routeId) || liveDriversByRoute.has(routeId);
      const lifecycle = lifecycleOf(line);
      const operatingState = operatingStateOf(line);
      const displayState: DisplayState =
        lifecycle === "preparation"
          ? "preparation"
          : lifecycle === "inactive" || lifecycle === "archived"
            ? "inactive"
            : operatingState;
      const variants = variantInfo(line);
      return {
        id: line.id,
        routeId,
        shortName: line.shortName,
        name: line.editorState?.name?.trim() || "",
        origin: line.origin,
        destination: line.destination,
        color: line.lineColor,
        mode: line.transportType,
        modeKey: modeKey(line.transportType),
        depotCodes: Array.from(depots),
        lifecycle,
        operatingState,
        displayState,
        vehicles: realtimeAvailable ? line.vehicleCount : null,
        drivers: realtimeAvailable ? (liveDriversByRoute.get(routeId) ?? 0) : null,
        punctuality: realtimeAvailable ? line.punctuality : null,
        incidents: line.incidentCount,
        updatedAt: line.updatedAt ?? (realtimeAvailable ? lastUpdated?.toISOString() ?? null : null),
        directions: variants.directions,
        variants: variants.variants,
        hasAssociations:
          line.stopCount > 0 || line.vehicleCount > 0 || line.incidentCount > 0 || Boolean(line.editorState),
        canMutate: isCustomRegulationLine(line.id),
        sourceLine: line,
      };
    });
  }, [customLines, networkLines, fleet, drivers, lastUpdated]);

  const modeOptions = useMemo(() => {
    const values = new Map<string, string>();
    for (const line of directoryLines) values.set(line.modeKey, line.mode);
    return Array.from(values, ([value, label]) => ({ value, label })).sort((a, b) =>
      a.label.localeCompare(b.label, "fr"),
    );
  }, [directoryLines]);

  const depotOptions = useMemo(() => {
    const values = new Map(configuredDepots.map((depot) => [depot.code, depot.label]));
    for (const line of directoryLines) {
      for (const code of line.depotCodes) {
        if (!values.has(code)) values.set(code, code === "NETWORK" ? network.name : code);
      }
    }
    return Array.from(values, ([code, label]) => ({ code, label })).sort((a, b) =>
      a.label.localeCompare(b.label, "fr"),
    );
  }, [configuredDepots, directoryLines, network.name]);

  const depotLabels = useMemo(
    () => new Map(depotOptions.map((depot) => [depot.code, depot.label])),
    [depotOptions],
  );

  const kpis = useMemo(() => ({
    all: directoryLines.length,
    bus: directoryLines.filter((line) => isBusMode(line.mode)).length,
    tram: directoryLines.filter((line) => isTramMode(line.mode)).length,
    other: directoryLines.filter((line) => !isBusMode(line.mode) && !isTramMode(line.mode)).length,
    active: directoryLines.filter((line) => line.lifecycle === "active").length,
    disrupted: directoryLines.filter(
      (line) => line.operatingState !== "normal" && line.lifecycle === "active",
    ).length,
  }), [directoryLines]);

  const filteredLines = useMemo(() => {
    const query = search.trim().toLocaleLowerCase("fr");
    return directoryLines.filter((line) => {
      if (query) {
        const haystack = `${line.shortName} ${line.name} ${line.origin} ${line.destination}`.toLocaleLowerCase("fr");
        if (!haystack.includes(query)) return false;
      }
      if (modeFilter !== "all" && line.modeKey !== modeFilter) return false;
      if (statusFilter !== "all" && line.lifecycle !== statusFilter) return false;
      if (stateFilter !== "all" && line.operatingState !== stateFilter) return false;
      if (depotFilter !== "all" && !line.depotCodes.includes(depotFilter)) return false;
      if (incidentsOnly && line.incidents === 0) return false;
      if (quickFilter === "bus" && !isBusMode(line.mode)) return false;
      if (quickFilter === "tram" && !isTramMode(line.mode)) return false;
      if (quickFilter === "other" && (isBusMode(line.mode) || isTramMode(line.mode))) return false;
      if (quickFilter === "active" && line.lifecycle !== "active") return false;
      if (quickFilter === "disrupted" && (line.operatingState === "normal" || line.lifecycle !== "active")) return false;
      return true;
    });
  }, [directoryLines, search, modeFilter, statusFilter, stateFilter, depotFilter, incidentsOnly, quickFilter]);

  const sortedLines = useMemo(() => {
    const sorted = [...filteredLines].sort((a, b) => {
      switch (sortKey) {
        case "mode":
          return a.mode.localeCompare(b.mode, "fr");
        case "state":
          return STATE_ORDER[a.displayState] - STATE_ORDER[b.displayState];
        case "vehicles":
          return compareNullableNumber(a.vehicles, b.vehicles);
        case "drivers":
          return compareNullableNumber(a.drivers, b.drivers);
        case "punctuality":
          return compareNullableNumber(a.punctuality, b.punctuality);
        case "incidents":
          return a.incidents - b.incidents;
        case "updated":
          return (a.updatedAt ? new Date(a.updatedAt).getTime() : Number.MAX_SAFE_INTEGER) -
            (b.updatedAt ? new Date(b.updatedAt).getTime() : Number.MAX_SAFE_INTEGER);
        default:
          return a.shortName.localeCompare(b.shortName, "fr", { numeric: true });
      }
    });
    return sortDirection === "asc" ? sorted : sorted.reverse();
  }, [filteredLines, sortKey, sortDirection]);

  const totalPages = Math.max(1, Math.ceil(sortedLines.length / pageSize));
  const safePage = Math.min(page, totalPages - 1);
  const visibleLines = sortedLines.slice(safePage * pageSize, (safePage + 1) * pageSize);
  const loading = operationsLoading || driversLoading || !customReady;
  const loadError = operationsError;
  const hasActiveFilters =
    search.length > 0 || modeFilter !== "all" || statusFilter !== "all" || stateFilter !== "all" ||
    depotFilter !== "all" || incidentsOnly || quickFilter !== "all";

  const resetFilters = useCallback(() => {
    setSearch("");
    setModeFilter("all");
    setStatusFilter("all");
    setStateFilter("all");
    setDepotFilter("all");
    setIncidentsOnly(false);
    setQuickFilter("all");
    setPage(0);
  }, []);

  const refreshAll = useCallback(async () => {
    await Promise.all([refreshCustomLines(), refreshOperations(), refreshDrivers()]);
  }, [refreshCustomLines, refreshOperations, refreshDrivers]);

  const handleSort = (column: SortKey) => {
    if (sortKey === column) setSortDirection((direction) => direction === "asc" ? "desc" : "asc");
    else {
      setSortKey(column);
      setSortDirection("asc");
    }
  };

  const handleQuickFilter = (filter: QuickFilter) => {
    if (filter === "all") resetFilters();
    else {
      setQuickFilter(filter);
      setModeFilter("all");
      setPage(0);
    }
  };

  const handleImport = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    setImporting(true);
    setNotice(null);
    try {
      const form = new FormData();
      form.append("file", file);
      const response = await fetch("/api/network/gtfs-import", { method: "POST", body: form });
      const payload = await response.json() as { error?: string; routeCount?: number };
      if (!response.ok) throw new Error(payload.error || "Import GTFS impossible");
      await refreshAll();
      setNotice({
        kind: "success",
        message: `${payload.routeCount ?? 0} ligne${payload.routeCount === 1 ? "" : "s"} importée${payload.routeCount === 1 ? "" : "s"} avec succès.`,
      });
    } catch (error) {
      setNotice({ kind: "error", message: error instanceof Error ? error.message : "Import GTFS impossible" });
    } finally {
      setImporting(false);
    }
  };

  const stopRowEvent = (event: MouseEvent) => event.stopPropagation();

  const handleDuplicate = async (line: DirectoryLine) => {
    if (!canManage) return;
    setActionBusy(line.id);
    setNotice(null);
    try {
      const existing = new Set(directoryLines.map((item) => item.shortName.toLocaleLowerCase("fr")));
      let suffix = 1;
      let shortName = `${line.shortName} copie`;
      while (existing.has(shortName.toLocaleLowerCase("fr"))) {
        suffix += 1;
        shortName = `${line.shortName} copie ${suffix}`;
      }
      const duplicated = await addLine({
        shortName,
        origin: line.origin,
        destination: line.destination,
        transportType: isTramMode(line.mode) ? "tram" : line.mode.toLowerCase().includes("bateau") || line.mode.toLowerCase().includes("nav") ? "boat" : "bus",
        depotCode: line.depotCodes[0] ?? "NETWORK",
      });
      router.push(`/dashboard/lignes/${encodeURIComponent(duplicated.id)}`);
    } catch (error) {
      setNotice({ kind: "error", message: error instanceof Error ? error.message : "Duplication impossible" });
    } finally {
      setActionBusy(null);
    }
  };

  const handleLifecycle = async (line: DirectoryLine, lifecycle: LifecycleStatus) => {
    if (!canManage || !line.canMutate) {
      setNotice({ kind: "error", message: "Cette ligne issue du catalogue de référence ne peut pas être modifiée ici." });
      return;
    }
    setActionBusy(line.id);
    try {
      await updateLineLifecycle(line.id, lifecycle);
      setNotice({
        kind: "success",
        message: lifecycle === "archived" ? `La ligne ${line.shortName} a été archivée.` : `La ligne ${line.shortName} a été désactivée.`,
      });
    } catch (error) {
      setNotice({ kind: "error", message: error instanceof Error ? error.message : "Modification impossible" });
    } finally {
      setActionBusy(null);
    }
  };

  const handleDelete = async (line: DirectoryLine) => {
    if (!canManage || !line.canMutate) {
      setNotice({ kind: "error", message: "Cette ligne issue du catalogue de référence ne peut pas être supprimée." });
      return;
    }
    if (line.hasAssociations) {
      const archiveInstead = window.confirm(
        `La ligne ${line.shortName} possède des véhicules, arrêts, courses, horaires ou d’autres données associées. Sa suppression directe est bloquée. Voulez-vous l’archiver à la place ?`,
      );
      if (archiveInstead) await handleLifecycle(line, "archived");
      return;
    }
    if (!window.confirm(`Supprimer définitivement la ligne ${line.shortName} ? Cette action est irréversible.`)) return;
    setActionBusy(line.id);
    try {
      await deleteLine(line.id);
      setNotice({ kind: "success", message: `La ligne ${line.shortName} a été supprimée.` });
    } finally {
      setActionBusy(null);
    }
  };

  const quickCards: Array<{
    key: QuickFilter;
    label: string;
    value: number;
    icon: typeof Route;
    tone: string;
  }> = [
    { key: "all", label: "Total lignes", value: kpis.all, icon: Route, tone: "blue" },
    { key: "bus", label: "Lignes de bus", value: kpis.bus, icon: BusFront, tone: "cyan" },
    { key: "tram", label: "Lignes de tramway", value: kpis.tram, icon: TrainFront, tone: "violet" },
    { key: "other", label: "Autres modes", value: kpis.other, icon: Network, tone: "slate" },
    { key: "active", label: "Lignes actives", value: kpis.active, icon: Activity, tone: "green" },
    { key: "disrupted", label: "Lignes perturbées", value: kpis.disrupted, icon: AlertTriangle, tone: "amber" },
  ];

  return (
    <main className="lines-page">
      <header className="lines-page-header">
        <div>
          <h1>Lignes</h1>
          <p>Consultez et gérez l’ensemble des lignes du réseau.</p>
        </div>
        <div className="lines-page-actions">
          <input
            ref={fileInputRef}
            type="file"
            accept=".zip,application/zip"
            hidden
            onChange={handleImport}
          />
          <Button
            variant="outline"
            className="lines-secondary-button"
            disabled={!canManage || importing}
            onClick={() => fileInputRef.current?.click()}
          >
            {importing ? <RefreshCw className="animate-spin" /> : <Upload />}
            {importing ? "Import en cours…" : "Importer un GTFS"}
          </Button>
          <Button asChild className="lines-primary-button">
            <Link href="/dashboard/lignes/nouvelle" aria-disabled={!canManage}>
              <Plus />
              Créer une ligne
            </Link>
          </Button>
        </div>
      </header>

      {notice && (
        <div className={`lines-notice lines-notice--${notice.kind}`} role="status">
          {notice.kind === "error" ? <AlertCircle /> : <CircleDot />}
          <span>{notice.message}</span>
          <button type="button" onClick={() => setNotice(null)} aria-label="Fermer">×</button>
        </div>
      )}

      <section className="lines-kpi-grid" aria-label="Filtres rapides">
        {quickCards.map(({ key, label, value, icon: Icon, tone }) => (
          <button
            key={key}
            type="button"
            className={`lines-kpi-card lines-kpi-card--${tone}${quickFilter === key ? " active" : ""}`}
            aria-pressed={quickFilter === key}
            onClick={() => handleQuickFilter(key)}
          >
            <span className="lines-kpi-icon"><Icon /></span>
            <span className="lines-kpi-copy">
              <strong>{loading ? "…" : value.toLocaleString("fr-FR")}</strong>
              <span>{label}</span>
            </span>
          </button>
        ))}
      </section>

      <section className="lines-filters" aria-label="Recherche et filtres">
        <label className="lines-search-field">
          <Search />
          <span className="sr-only">Rechercher une ligne</span>
          <input
            type="search"
            value={search}
            onChange={(event) => { setSearch(event.target.value); setPage(0); }}
            placeholder="Rechercher par numéro, nom ou terminus..."
          />
        </label>
        <select value={modeFilter} onChange={(event) => { setModeFilter(event.target.value); setQuickFilter("all"); setPage(0); }} aria-label="Filtrer par mode">
          <option value="all">Tous les modes</option>
          {modeOptions.map((mode) => <option key={mode.value} value={mode.value}>{mode.label}</option>)}
        </select>
        <select value={statusFilter} onChange={(event) => { setStatusFilter(event.target.value as LifecycleStatus | "all"); setPage(0); }} aria-label="Filtrer par statut">
          <option value="all">Tous les statuts</option>
          {(Object.keys(LIFECYCLE_LABELS) as LifecycleStatus[]).map((status) => (
            <option key={status} value={status}>{LIFECYCLE_LABELS[status]}</option>
          ))}
        </select>
        <select value={stateFilter} onChange={(event) => { setStateFilter(event.target.value as OperatingState | "all"); setPage(0); }} aria-label="Filtrer par état d’exploitation">
          <option value="all">Tous les états</option>
          <option value="normal">Normal</option>
          <option value="delay">Retard</option>
          <option value="disrupted">Perturbée</option>
          <option value="interrupted">Interrompue</option>
        </select>
        <select value={depotFilter} onChange={(event) => { setDepotFilter(event.target.value); setPage(0); }} aria-label="Filtrer par dépôt ou centre d’exploitation">
          <option value="all">Tous les dépôts</option>
          {depotOptions.map((depot) => <option key={depot.code} value={depot.code}>{depot.label}</option>)}
        </select>
        <label className={`lines-incident-toggle${incidentsOnly ? " active" : ""}`}>
          <input type="checkbox" checked={incidentsOnly} onChange={(event) => { setIncidentsOnly(event.target.checked); setPage(0); }} />
          <AlertTriangle />
          Avec incidents
        </label>
        <button type="button" className="lines-reset-button" onClick={resetFilters} disabled={!hasActiveFilters}>
          <RefreshCw />
          Réinitialiser
        </button>
      </section>

      <section className={`lines-table-card lines-table-card--${density}`}>
        {loadError && directoryLines.length > 0 && (
          <div className="lines-inline-error">
            <AlertCircle />
            <span>Certaines données n’ont pas pu être actualisées : {loadError}</span>
            <button type="button" onClick={() => void refreshAll()}>Réessayer</button>
          </div>
        )}

        <div className="lines-results-bar">
          <div>
            <strong>{filteredLines.length.toLocaleString("fr-FR")}</strong> résultat{filteredLines.length === 1 ? "" : "s"}
            {hasActiveFilters && <span> sur {directoryLines.length.toLocaleString("fr-FR")}</span>}
          </div>
          <span>Réseau · {network.name}</span>
        </div>

        <div className="lines-table-scroll">
          <table className="lines-table">
            <thead>
              <tr>
                <th><SortButton label="Ligne" column="line" active={sortKey === "line"} direction={sortDirection} onSort={handleSort} /></th>
                <th>Nom et terminus</th>
                <th><SortButton label="Mode" column="mode" active={sortKey === "mode"} direction={sortDirection} onSort={handleSort} /></th>
                <th><SortButton label="État d’exploitation" column="state" active={sortKey === "state"} direction={sortDirection} onSort={handleSort} /></th>
                <th><SortButton label="Véhicules en ligne" column="vehicles" active={sortKey === "vehicles"} direction={sortDirection} onSort={handleSort} /></th>
                <th><SortButton label="Conducteurs connectés" column="drivers" active={sortKey === "drivers"} direction={sortDirection} onSort={handleSort} /></th>
                <th><SortButton label="Ponctualité" column="punctuality" active={sortKey === "punctuality"} direction={sortDirection} onSort={handleSort} /></th>
                <th><SortButton label="Incidents ouverts" column="incidents" active={sortKey === "incidents"} direction={sortDirection} onSort={handleSort} /></th>
                <th><SortButton label="Dernière mise à jour" column="updated" active={sortKey === "updated"} direction={sortDirection} onSort={handleSort} /></th>
                <th className="lines-actions-heading">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && directoryLines.length === 0 ? (
                Array.from({ length: 8 }).map((_, index) => (
                  <tr key={index} className="lines-skeleton-row">
                    {Array.from({ length: 10 }).map((__, cell) => <td key={cell}><span /></td>)}
                  </tr>
                ))
              ) : visibleLines.map((line) => {
                const detailHref = `/dashboard/lignes/${encodeURIComponent(line.id)}`;
                return (
                  <tr
                    key={line.id}
                    className="lines-data-row"
                    role="link"
                    tabIndex={0}
                    onClick={() => router.push(detailHref)}
                    onKeyDown={(event) => {
                      if (event.key === "Enter" || event.key === " ") router.push(detailHref);
                    }}
                  >
                    <td>
                      <span className="lines-line-chip" style={{ backgroundColor: line.color }}>
                        {line.shortName}
                      </span>
                    </td>
                    <td>
                      <div className="lines-name-cell">
                        {line.name && <strong>{line.name}</strong>}
                        <span className={line.name ? "lines-termini-secondary" : "lines-termini-primary"}>
                          {line.origin} ↔ {line.destination}
                        </span>
                        {line.variants > 0 && (
                          <small>{line.directions || 2} directions · {line.variants} variante{line.variants > 1 ? "s" : ""}</small>
                        )}
                        {line.depotCodes.length > 0 && (
                          <small>{line.depotCodes.map((code) => depotLabels.get(code) ?? code).join(" · ")}</small>
                        )}
                      </div>
                    </td>
                    <td><span className="lines-mode-badge">{line.mode}</span></td>
                    <td><StateBadge state={line.displayState} /></td>
                    <td>
                      {line.vehicles === null ? <span className="lines-unavailable">Aucune donnée temps réel</span> : <strong className="lines-metric">{line.vehicles}</strong>}
                    </td>
                    <td>
                      {line.drivers === null ? <span className="lines-unavailable">Aucune donnée temps réel</span> : <strong className="lines-metric">{line.drivers}</strong>}
                    </td>
                    <td>
                      {line.punctuality === null ? <span className="lines-unavailable">Indisponible</span> : <span className="lines-punctuality">{Math.round(line.punctuality)} %</span>}
                    </td>
                    <td>
                      <span className={`lines-incident-count${line.incidents > 0 ? " active" : ""}`}>
                        {line.incidents > 0 && <AlertTriangle />}
                        {line.incidents} ouvert{line.incidents === 1 ? "" : "s"}
                      </span>
                    </td>
                    <td><span className={line.updatedAt ? "lines-updated" : "lines-unavailable"}>{formatUpdatedAt(line.updatedAt)}</span></td>
                    <td className="lines-actions-cell" onClick={stopRowEvent} onKeyDown={(event) => event.stopPropagation()}>
                      <details className="lines-action-menu">
                        <summary aria-label={`Actions pour la ligne ${line.shortName}`}><MoreHorizontal /></summary>
                        <div className="lines-action-popover">
                          <Link href={detailHref}><ExternalLink />Voir la fiche</Link>
                          <Link href={`/carte-immersive?line=${encodeURIComponent(line.routeId)}`}><MapIcon />Voir sur la carte</Link>
                          <Link href={`${detailHref}?tab=plan`}><Route />Voir le plan de ligne</Link>
                          <Link href={`${detailHref}?edit=1`}><Pencil />Modifier la ligne</Link>
                          <Link href={`${detailHref}?tab=stops`}><MapPin />Gérer les arrêts</Link>
                          <Link href={`${detailHref}?tab=directions`}><Split />Gérer les directions</Link>
                          <button type="button" disabled={!canManage || actionBusy === line.id} onClick={() => void handleDuplicate(line)}><Copy />Dupliquer</button>
                          <span className="lines-action-separator" />
                          <button type="button" disabled={!canManage || actionBusy === line.id} onClick={() => void handleLifecycle(line, "inactive")}><PauseCircle />Désactiver</button>
                          <button type="button" disabled={!canManage || actionBusy === line.id} onClick={() => void handleLifecycle(line, "archived")}><Archive />Archiver</button>
                          <button type="button" className="danger" disabled={!canManage || actionBusy === line.id} onClick={() => void handleDelete(line)}><Trash2 />Supprimer</button>
                        </div>
                      </details>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>

          {!loading && loadError && directoryLines.length === 0 && (
            <div className="lines-table-state">
              <AlertCircle />
              <h2>Impossible de charger les lignes</h2>
              <p>{loadError}</p>
              <Button variant="outline" onClick={() => void refreshAll()}><RefreshCw />Réessayer</Button>
            </div>
          )}
          {!loading && !loadError && directoryLines.length === 0 && (
            <div className="lines-table-state">
              <Route />
              <h2>Ce réseau ne contient aucune ligne</h2>
              <p>Importez un fichier GTFS ou créez la première ligne du réseau.</p>
              {canManage && <Button asChild><Link href="/dashboard/lignes/nouvelle"><Plus />Créer une ligne</Link></Button>}
            </div>
          )}
          {!loading && directoryLines.length > 0 && filteredLines.length === 0 && (
            <div className="lines-table-state">
              <Search />
              <h2>Aucun résultat</h2>
              <p>Aucune ligne ne correspond à votre recherche ou aux filtres sélectionnés.</p>
              <Button variant="outline" onClick={resetFilters}><RefreshCw />Réinitialiser les filtres</Button>
            </div>
          )}
        </div>

        <footer className="lines-table-footer">
          <div className="lines-footer-total">
            {sortedLines.length === 0 ? "0 résultat" : `${safePage * pageSize + 1}–${Math.min((safePage + 1) * pageSize, sortedLines.length)} sur ${sortedLines.length}`}
          </div>
          <div className="lines-footer-controls">
            <label>
              Lignes par page
              <select value={pageSize} onChange={(event) => { setPageSize(Number(event.target.value)); setPage(0); }}>
                {[10, 25, 50, 100].map((size) => <option key={size} value={size}>{size}</option>)}
              </select>
            </label>
            <div className="lines-density-control" aria-label="Densité du tableau">
              <span>Densité</span>
              <button type="button" className={density === "comfortable" ? "active" : ""} onClick={() => setDensity("comfortable")}>Confortable</button>
              <button type="button" className={density === "compact" ? "active" : ""} onClick={() => setDensity("compact")}>Compact</button>
            </div>
            <div className="lines-pagination">
              <button type="button" aria-label="Page précédente" disabled={safePage === 0} onClick={() => setPage(Math.max(0, safePage - 1))}><ChevronLeft /></button>
              <span>Page {safePage + 1} sur {totalPages}</span>
              <button type="button" aria-label="Page suivante" disabled={safePage + 1 >= totalPages} onClick={() => setPage(Math.min(totalPages - 1, safePage + 1))}><ChevronRight /></button>
            </div>
          </div>
        </footer>
      </section>
    </main>
  );
}
