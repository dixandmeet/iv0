"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useStationsData } from "@/hooks/use-stations-data";
import { useStationDetail } from "@/hooks/use-station-detail";
import { useStationActions } from "@/hooks/use-station-actions";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { StationsHeader } from "@/components/stations/stations-header";
import { StationsFiltersPanel } from "@/components/stations/stations-filters-panel";
import { StationsListPanel } from "@/components/stations/stations-list-panel";
import { StationDetailPanel } from "@/components/stations/station-detail-panel";
import { StationFormModal } from "@/components/stations/station-form-modal";
import type { StationFormPayload } from "@/lib/stations-types";
import { useNetwork } from "@/components/network/network-provider";

export function StationsPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { canManage } = useNetwork();
  const {
    stations,
    loading,
    error,
    search,
    setSearch,
    filters,
    setFilters,
    page,
    setPage,
    totalCount,
    totalPages,
    communes,
    refresh,
  } = useStationsData();

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [formOpen, setFormOpen] = useState(false);

  const { detail, stopLines, stopDepartures, loading: detailLoading, refresh: refreshDetail } =
    useStationDetail(selectedId);
  const { createStation, disableStation, submitting, error: actionError } = useStationActions();

  useEffect(() => {
    const fromUrl = searchParams.get("station");
    if (fromUrl) {
      setSelectedId(fromUrl);
      return;
    }
    if (!selectedId && stations.length > 0) {
      setSelectedId(stations[0].id);
    }
  }, [stations, selectedId, searchParams]);

  const handleSearchChange = useCallback(
    (value: string) => {
      setSearch(value);
      setPage(0);
    },
    [setSearch, setPage],
  );

  const handleSelectStation = useCallback(
    (stationId: string, stationName: string) => {
      setSearch(stationName);
      setSelectedId(stationId);
      setPage(0);
    },
    [setSearch, setPage],
  );

  const handleDisable = async () => {
    if (!canManage || !selectedId || !confirm("Désactiver cette station ? Elle sera masquée côté voyageur.")) return;
    await disableStation(selectedId);
    await refresh();
    await refreshDetail();
  };

  const handleEditStation = () => {
    if (canManage && selectedId) router.push(`/stations/${selectedId}`);
  };

  const handleAddStop = () => {
    if (canManage && selectedId) router.push(`/stations/${selectedId}/arrets/nouveau`);
  };

  const handleFormSubmit = async (payload: StationFormPayload) => {
    if (!canManage) return;
    const id = await createStation(payload);
    await refresh();
    setSelectedId(id);
  };

  return (
    <main className="dashboard-panel stops-page">
      {error && <ErrorBanner message={error} onRetry={refresh} />}

      <StationsHeader
        search={search}
        onSearchChange={handleSearchChange}
        onSelectStation={handleSelectStation}
        onAdd={() => setFormOpen(true)}
        onImport={() => undefined}
        onExport={() => undefined}
        onToggleFilters={() => setFiltersOpen(!filtersOpen)}
        filtersOpen={filtersOpen}
        canManage={canManage}
      />

      <div className="stops-layout">
        {filtersOpen && (
          <StationsFiltersPanel
            filters={filters}
            onChange={(f) => {
              setFilters(f);
              setPage(0);
            }}
            communes={communes}
            onClose={() => setFiltersOpen(false)}
          />
        )}

        <StationsListPanel
          stations={stations}
          loading={loading}
          selectedId={selectedId}
          onSelect={setSelectedId}
          page={page}
          totalPages={totalPages}
          totalCount={totalCount}
          onPageChange={setPage}
        />

        <StationDetailPanel
          detail={detail}
          stopLines={stopLines}
          stopDepartures={stopDepartures}
          loading={detailLoading}
          onEditStation={handleEditStation}
          onDisableStation={handleDisable}
          onAddStop={handleAddStop}
          canManage={canManage}
        />
      </div>

      <StationFormModal
        open={formOpen}
        onClose={() => setFormOpen(false)}
        onSubmit={handleFormSubmit}
        submitting={submitting}
        communes={communes}
        error={actionError}
      />
    </main>
  );
}
