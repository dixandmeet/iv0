"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { AlertCircle, ArrowLeft, CheckCircle2 } from "lucide-react";
import { ErrorBanner } from "@/components/dashboard/error-banner";
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
  loadLineEditorDraft,
  regulationStopsFromEditor,
  saveLineEditorDraft,
} from "@/lib/line-editor-persistence";
import { regenerateLineEditorState } from "@/lib/line-regeneration";
import { syncPublishedLineTrace } from "@/lib/line-editor-immersive-sync";
import type { LineEditorState } from "@/lib/line-editor-types";
import type { RegulationLine, RegulationStop } from "@/lib/regulation-mock-data";

interface LineOperationsPageProps {
  lineId: string;
}

function decodeLineIdParam(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

export function LineOperationsPage({ lineId: rawLineId }: LineOperationsPageProps) {
  const lineId = useMemo(() => decodeLineIdParam(rawLineId), [rawLineId]);
  const {
    customLines,
    ready: customLinesReady,
    updateLineStops,
    updateLineFromEditor,
    updateLineInfo,
  } = useCustomRegulationLines();
  const [editedStops, setEditedStops] = useState<RegulationStop[] | null>(null);
  const [lineInfoOverrides, setLineInfoOverrides] = useState<
    Record<string, NewLineInput>
  >({});
  const [lineInfoEditOpen, setLineInfoEditOpen] = useState(false);
  const [editorOpen, setEditorOpen] = useState(false);
  const [editorStateOverride, setEditorStateOverride] = useState<{
    lineId: string;
    state: LineEditorState;
  } | null>(null);
  const [selectedVariantId, setSelectedVariantId] = useState<string | null>(null);
  const [regenerating, setRegenerating] = useState(false);
  const [regenerationNotice, setRegenerationNotice] = useState<{
    kind: "success" | "error";
    text: string;
  } | null>(null);

  const selectedVariantByLine = useMemo(
    () => (selectedVariantId ? { [lineId]: selectedVariantId } : {}),
    [lineId, selectedVariantId],
  );

  const savedEditorState = useMemo(() => {
    if (editorStateOverride?.lineId === lineId) {
      return editorStateOverride.state;
    }
    return (
      customLines.find((line) => line.id === lineId)?.editorState ??
      loadLineEditorDraft(lineId)
    );
  }, [customLines, editorStateOverride, lineId]);

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
  } = useRegulationDashboard(
    lineId,
    selectedVariantByLine,
    savedEditorState,
  );

  useEffect(() => {
    setLineInfoOverrides(loadLineInfoOverrides());
  }, []);

  const selectedLine = useMemo((): RegulationLine | null => {
    const custom = customLines.find((line) => line.id === lineId);
    if (custom) return custom;

    const networkLineExists = networkLines.some((line) => line.id === lineId);
    return networkLineExists ? networkSelectedLine : null;
  }, [customLines, lineId, networkLines, networkSelectedLine]);

  const displayLine = useMemo(() => {
    if (!selectedLine) return null;
    let line = editedStops
      ? applyEditedStops(selectedLine, editedStops)
      : selectedLine;
    if (!isCustomRegulationLine(lineId)) {
      const override = lineInfoOverrides[lineId];
      if (override) line = applyLineInfoUpdate(line, override);
    }
    return line;
  }, [selectedLine, editedStops, lineId, lineInfoOverrides]);

  const handleStopsChange = useCallback(
    (stops: RegulationStop[]) => {
      if (isCustomRegulationLine(lineId)) {
        void updateLineStops(lineId, stops);
        return;
      }
      setEditedStops(stops);
    },
    [lineId, updateLineStops],
  );

  const handleEditorPersist = useCallback(
    async (persistedLineId: string, editorState: LineEditorState) => {
      setEditorStateOverride({ lineId: persistedLineId, state: editorState });
      setSelectedVariantId(null);
      saveLineEditorDraft(persistedLineId, editorState);

      const catalogLine = customLines.find((line) => line.id === persistedLineId);
      if (catalogLine) {
        await updateLineFromEditor(persistedLineId, editorState);
        return;
      }

      const baseLine =
        networkLines.find((line) => line.id === persistedLineId) ?? selectedLine;
      const stops = regulationStopsFromEditor(
        editorState,
        baseLine?.stops ?? [],
      );
      setEditedStops(stops);
    },
    [customLines, networkLines, selectedLine, updateLineFromEditor],
  );

  const handleLineInfoSave = useCallback(
    (input: NewLineInput) => {
      if (isCustomRegulationLine(lineId)) {
        void updateLineInfo(lineId, input);
        return;
      }

      setLineInfoOverrides((previous) => {
        const next = { ...previous, [lineId]: input };
        saveLineInfoOverrides(next);
        return next;
      });
    },
    [lineId, updateLineInfo],
  );

  const handleRegenerate = useCallback(async () => {
    if (!displayLine || timelineStops.length < 2 || regenerating) return;

    setRegenerating(true);
    setRegenerationNotice(null);

    try {
      const previousState =
        displayLine.editorState ?? loadLineEditorDraft(lineId);
      const regeneratedState = await regenerateLineEditorState(
        displayLine,
        timelineStops,
        previousState,
      );
      const regeneratedStops = regulationStopsFromEditor(
        regeneratedState,
        displayLine.stops,
      );

      if (isCustomRegulationLine(lineId)) {
        await updateLineFromEditor(lineId, regeneratedState);
      } else {
        saveLineEditorDraft(lineId, regeneratedState);
        setEditedStops(regeneratedStops);

        const origin = regeneratedStops[0]?.name ?? displayLine.origin;
        const destination =
          regeneratedStops[regeneratedStops.length - 1]?.name ??
          displayLine.destination;
        setLineInfoOverrides((previous) => {
          const current = previous[lineId];
          const next = {
            ...previous,
            [lineId]: {
              shortName: current?.shortName ?? displayLine.shortName,
              origin,
              destination,
              transportType:
                current?.transportType ??
                (displayLine.transportType.toLowerCase().includes("tram")
                  ? "tram"
                  : displayLine.transportType.toLowerCase().includes("nav") ||
                      displayLine.transportType.toLowerCase().includes("bateau")
                    ? "boat"
                    : "bus"),
              depotCode: current?.depotCode ?? displayLine.depotCode,
            },
          };
          saveLineInfoOverrides(next);
          return next;
        });
      }

      if (regeneratedState.status === "published") {
        await syncPublishedLineTrace(regeneratedState);
      }

      setEditorStateOverride({ lineId, state: regeneratedState });
      setSelectedVariantId(null);

      setRegenerationNotice({
        kind: "success",
        text: `${regeneratedStops.length} arrêts et le tracé aller-retour ont été mis à jour.`,
      });
    } catch (regenerationError) {
      setRegenerationNotice({
        kind: "error",
        text:
          regenerationError instanceof Error
            ? regenerationError.message
            : "Impossible de régénérer la ligne.",
      });
    } finally {
      setRegenerating(false);
    }
  }, [
    displayLine,
    lineId,
    regenerating,
    timelineStops,
    updateLineFromEditor,
  ]);

  if (editorOpen) {
    return (
      <div className="regulation-line-page regulation-line-page--editor">
        <LineEditorWorkspace
          line={displayLine}
          onBack={() => setEditorOpen(false)}
          onPersist={handleEditorPersist}
        />
      </div>
    );
  }

  // Le catalogue contient un ancien plan de repli. Ne pas l'afficher pendant
  // que la topologie actuelle est encore en cours de résolution.
  const pageLoading = loading || !customLinesReady || timelineLoading;

  return (
    <div className="regulation-line-page">
      <div className="regulation-line-page-backbar">
        <Link href="/dashboard/lignes" className="regulation-line-page-backlink">
          <ArrowLeft className="h-4 w-4" />
          Toutes les lignes
        </Link>
      </div>

      <main className="regulation-main">
        {error && (
          <div className="px-4 pt-2">
            <ErrorBanner message={error} onRetry={refresh} />
          </div>
        )}

        {regenerationNotice && (
          <div
            className={`regulation-line-regeneration-notice regulation-line-regeneration-notice--${regenerationNotice.kind}`}
            role={regenerationNotice.kind === "error" ? "alert" : "status"}
          >
            {regenerationNotice.kind === "success" ? (
              <CheckCircle2 className="h-4 w-4" />
            ) : (
              <AlertCircle className="h-4 w-4" />
            )}
            {regenerationNotice.text}
          </div>
        )}

        {pageLoading ? (
          <div className="flex flex-1 items-center justify-center p-8">
            <p className="text-sm text-[#94A3B8]">Chargement de la ligne…</p>
          </div>
        ) : !displayLine ? (
          <div className="flex flex-1 flex-col items-center justify-center gap-4 p-8 text-center">
            <h1 className="text-lg font-semibold text-white">Ligne introuvable</h1>
            <p className="text-sm text-[#94A3B8]">
              Cette ligne n’existe pas ou n’est plus disponible sur ce réseau.
            </p>
            <Link
              href="/dashboard/lignes"
              className="rounded-xl bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-500"
            >
              Retour aux lignes
            </Link>
          </div>
        ) : displayLine.stops.length > 0 ? (
          <>
            <LineDetailHeader
              line={displayLine}
              topology={topology}
              onOpenEditor={() => setEditorOpen(true)}
              onEditLineInfo={() => setLineInfoEditOpen(true)}
              onRegenerate={() => void handleRegenerate()}
              isRegenerating={regenerating}
              regenerationDisabled={timelineLoading || timelineStops.length < 2}
            />
            <OperationalTimeline
              line={displayLine}
              fleet={fleetOnRoute}
              timelineStops={timelineStops}
              topology={topology}
              activeVariantId={selectedVariantId}
              onVariantChange={setSelectedVariantId}
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
              onRegenerate={() => void handleRegenerate()}
              isRegenerating={regenerating}
              regenerationDisabled={timelineLoading || timelineStops.length < 2}
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
    </div>
  );
}
