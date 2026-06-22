"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { RegulationKpiBar } from "@/components/dashboard/regulation-kpi-bar";
import { LinesPanel } from "@/components/dashboard/lines-panel";
import { LineDetailHeader } from "@/components/dashboard/line-detail-header";
import { LineInfoEditModal } from "@/components/dashboard/line-info-edit-modal";
import { OperationalTimeline } from "@/components/dashboard/operational-timeline";
import { TimelineLegend } from "@/components/dashboard/timeline-legend";
import { LineEditorWorkspace } from "@/components/dashboard/line-editor/line-editor-workspace";
import { useRegulationDashboard } from "@/hooks/use-regulation-dashboard";
import { useCustomRegulationLines } from "@/hooks/use-custom-regulation-lines";
import { applyEditedStops } from "@/lib/regulation-stop-edits";
import {
  applyLineInfoUpdate,
  isCustomRegulationLine,
  loadLineInfoOverrides,
  saveLineInfoOverrides,
  type NewLineInput,
} from "@/lib/regulation-custom-line";
import {
  regulationStopsFromEditor,
  saveLineEditorDraft,
} from "@/lib/line-editor-persistence";
import type { LineEditorState } from "@/lib/line-editor-types";
import type { RegulationLine, RegulationStop } from "@/lib/regulation-mock-data";

export function OperationsDashboard() {
  const [selectedLineId, setSelectedLineId] = useState<string | null>(null);
  const { customLines, ready: customLinesReady, addLine, deleteLine, updateLineStops, updateLineFromEditor, updateLineInfo } =
    useCustomRegulationLines();
  const [editedStopsByLine, setEditedStopsByLine] = useState<
    Record<string, RegulationStop[]>
  >({});
  const [lineInfoOverrides, setLineInfoOverrides] = useState<
    Record<string, NewLineInput>
  >({});
  const [lineInfoEditOpen, setLineInfoEditOpen] = useState(false);
  const [editorOpen, setEditorOpen] = useState(false);
  const [selectedVariantByLine, setSelectedVariantByLine] = useState<
    Record<string, string>
  >({});

  const {
    lines: networkLines,
    selectedLine: networkSelectedLine,
    fleetOnRoute,
    topology,
    timelineStops,
    loading,
    timelineLoading,
    error,
    lastUpdated,
    refresh,
    kpis,
    alerts,
  } = useRegulationDashboard(selectedLineId, selectedVariantByLine);

  const lines = useMemo(
    () => [...customLines, ...networkLines],
    [customLines, networkLines],
  );

  const defaultLineId = useMemo(
    () =>
      lines.find((line) => line.vehicleCount > 0)?.id ??
      lines[0]?.id ??
      null,
    [lines],
  );

  useEffect(() => {
    setLineInfoOverrides(loadLineInfoOverrides());
  }, []);

  useEffect(() => {
    if (selectedLineId == null && defaultLineId) {
      setSelectedLineId(defaultLineId);
    }
  }, [selectedLineId, defaultLineId]);

  const activeLineId = selectedLineId ?? defaultLineId;

  const selectedLine = useMemo((): RegulationLine | null => {
    const custom = customLines.find((line) => line.id === activeLineId);
    if (custom) return custom;
    return networkSelectedLine;
  }, [customLines, activeLineId, networkSelectedLine]);

  const handleAddLine = useCallback(
    (input: NewLineInput) => {
      const line = addLine(input);
      setSelectedLineId(line.id);
    },
    [addLine],
  );

  const handleDeleteLine = useCallback(
    (lineId: string) => {
      deleteLine(lineId);
      setEditedStopsByLine((prev) => {
        const next = { ...prev };
        delete next[lineId];
        return next;
      });
      setSelectedLineId((current) => (current === lineId ? null : current));
    },
    [deleteLine],
  );

  const displayLine = useMemo(() => {
    if (!selectedLine) return null;
    let line = selectedLine;
    const edited = activeLineId ? editedStopsByLine[activeLineId] : undefined;
    if (edited) line = applyEditedStops(line, edited);
    if (activeLineId && !isCustomRegulationLine(activeLineId)) {
      const override = lineInfoOverrides[activeLineId];
      if (override) line = applyLineInfoUpdate(line, override);
    }
    return line;
  }, [selectedLine, activeLineId, editedStopsByLine, lineInfoOverrides]);

  const handleStopsChange = useCallback(
    (stops: RegulationStop[]) => {
      if (!activeLineId) return;
      if (isCustomRegulationLine(activeLineId)) {
        updateLineStops(activeLineId, stops);
        return;
      }
      setEditedStopsByLine((prev) => ({ ...prev, [activeLineId]: stops }));
    },
    [activeLineId, updateLineStops],
  );

  const handleEditorPersist = useCallback(
    (lineId: string, editorState: LineEditorState) => {
      saveLineEditorDraft(lineId, editorState);

      if (isCustomRegulationLine(lineId)) {
        updateLineFromEditor(lineId, editorState);
        return;
      }

      const baseLine =
        customLines.find((line) => line.id === lineId) ??
        networkLines.find((line) => line.id === lineId) ??
        selectedLine;
      const stops = regulationStopsFromEditor(
        editorState,
        baseLine?.stops ?? [],
      );
      setEditedStopsByLine((prev) => ({ ...prev, [lineId]: stops }));
    },
    [customLines, networkLines, selectedLine, updateLineFromEditor],
  );

  const handleLineInfoSave = useCallback(
    (input: NewLineInput) => {
      if (!activeLineId) return;

      if (isCustomRegulationLine(activeLineId)) {
        updateLineInfo(activeLineId, input);
        return;
      }

      setLineInfoOverrides((prev) => {
        const next = { ...prev, [activeLineId]: input };
        saveLineInfoOverrides(next);
        return next;
      });
    },
    [activeLineId, updateLineInfo],
  );

  return (
    <div className={`regulation-workspace${editorOpen ? " regulation-workspace--editor" : ""}`}>
      {!editorOpen && (
        <RegulationKpiBar
          onRefresh={refresh}
          loading={loading}
          kpis={kpis}
          alertCount={alerts.length}
        />
      )}

      {editorOpen ? (
        <LineEditorWorkspace
          line={displayLine}
          onBack={() => setEditorOpen(false)}
          onPersist={handleEditorPersist}
        />
      ) : (
        <>
          <LinesPanel
            lines={lines}
            selectedLineId={activeLineId ?? ""}
            onSelectLine={setSelectedLineId}
            onAddLine={handleAddLine}
            onDeleteLine={handleDeleteLine}
            loading={loading || !customLinesReady}
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
                <LineDetailHeader
                  line={displayLine}
                  topology={topology}
                  onOpenEditor={() => setEditorOpen(true)}
                  onEditLineInfo={() => setLineInfoEditOpen(true)}
                />
                <OperationalTimeline
                  line={displayLine}
                  fleet={fleetOnRoute}
                  timelineStops={timelineStops}
                  topology={topology}
                  activeVariantId={
                    activeLineId ? selectedVariantByLine[activeLineId] : null
                  }
                  onVariantChange={(variantId) => {
                    if (!activeLineId) return;
                    setSelectedVariantByLine((prev) => ({
                      ...prev,
                      [activeLineId]: variantId,
                    }));
                  }}
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
                <LineDetailHeader
                  line={displayLine}
                  topology={topology}
                  onOpenEditor={() => setEditorOpen(true)}
                  onEditLineInfo={() => setLineInfoEditOpen(true)}
                />
                <p className="text-sm text-[#94A3B8]">
                  {displayLine.vehicleCount === 0
                    ? "Aucun véhicule en circulation sur cette ligne."
                    : "Impossible de reconstruire la frise — tracé GTFS indisponible."}
                </p>
              </div>
            )}
          </main>

          <TimelineLegend lastUpdated={lastUpdated} onRefresh={refresh} />

          <LineInfoEditModal
            open={lineInfoEditOpen}
            line={displayLine}
            onClose={() => setLineInfoEditOpen(false)}
            onSubmit={handleLineInfoSave}
          />
        </>
      )}
    </div>
  );
}
