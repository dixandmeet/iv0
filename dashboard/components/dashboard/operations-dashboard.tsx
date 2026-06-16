"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { RegulationKpiBar } from "@/components/dashboard/regulation-kpi-bar";
import { LinesPanel } from "@/components/dashboard/lines-panel";
import { LineDetailHeader } from "@/components/dashboard/line-detail-header";
import { OperationalTimeline } from "@/components/dashboard/operational-timeline";
import { TimelineLegend } from "@/components/dashboard/timeline-legend";
import { useRegulationDashboard } from "@/hooks/use-regulation-dashboard";
import { applyEditedStops } from "@/lib/regulation-stop-edits";
import type { RegulationStop } from "@/lib/regulation-mock-data";

export function OperationsDashboard() {
  const [selectedLineId, setSelectedLineId] = useState<string | null>(null);
  const [editedStopsByLine, setEditedStopsByLine] = useState<
    Record<string, RegulationStop[]>
  >({});

  const {
    lines,
    selectedLine,
    loading,
    timelineLoading,
    error,
    lastUpdated,
    refresh,
    kpis,
    alerts,
  } = useRegulationDashboard(selectedLineId);

  const defaultLineId = useMemo(
    () =>
      lines.find((line) => line.vehicleCount > 0)?.id ??
      lines[0]?.id ??
      null,
    [lines],
  );

  useEffect(() => {
    if (selectedLineId == null && defaultLineId) {
      setSelectedLineId(defaultLineId);
    }
  }, [selectedLineId, defaultLineId]);

  const activeLineId = selectedLineId ?? defaultLineId;

  const displayLine = useMemo(() => {
    if (!selectedLine) return null;
    const edited = activeLineId ? editedStopsByLine[activeLineId] : undefined;
    if (!edited) return selectedLine;
    return applyEditedStops(selectedLine, edited);
  }, [selectedLine, activeLineId, editedStopsByLine]);

  const handleStopsChange = useCallback(
    (stops: RegulationStop[]) => {
      if (!activeLineId) return;
      setEditedStopsByLine((prev) => ({ ...prev, [activeLineId]: stops }));
    },
    [activeLineId],
  );

  return (
    <div className="regulation-workspace">
      <RegulationKpiBar
        onRefresh={refresh}
        loading={loading}
        kpis={kpis}
        alertCount={alerts.length}
      />

      <LinesPanel
        lines={lines}
        selectedLineId={activeLineId ?? ""}
        onSelectLine={setSelectedLineId}
        loading={loading}
      />

      <main className="regulation-main">
        {error && (
          <div className="px-4 pt-2">
            <ErrorBanner message={error} onRetry={refresh} />
          </div>
        )}

        {!displayLine || loading ? (
          <div className="flex flex-1 items-center justify-center p-8">
            <p className="text-sm text-[#94A3B8]">Chargement du réseau…</p>
          </div>
        ) : displayLine.stops.length > 0 ? (
          <>
            <LineDetailHeader line={displayLine} />
            <OperationalTimeline
              line={displayLine}
              loading={timelineLoading}
              onStopsChange={handleStopsChange}
            />
          </>
        ) : timelineLoading ? (
          <div className="flex flex-1 items-center justify-center p-8">
            <p className="text-sm text-[#94A3B8]">
              Construction de la frise pour la ligne {displayLine.shortName}…
            </p>
          </div>
        ) : (
          <div className="flex flex-1 flex-col items-center justify-center gap-3 p-8">
            <LineDetailHeader line={displayLine} />
            <p className="text-sm text-[#94A3B8]">
              {displayLine.vehicleCount === 0
                ? "Aucun véhicule en circulation sur cette ligne."
                : "Impossible de reconstruire la frise — tracé GTFS indisponible."}
            </p>
          </div>
        )}
      </main>

      <TimelineLegend lastUpdated={lastUpdated} onRefresh={refresh} />
    </div>
  );
}
