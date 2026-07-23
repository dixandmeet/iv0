"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
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
import { useNetwork } from "@/components/network/network-provider";
import { applyEditedStops } from "@/lib/regulation-stop-edits";
import {
  applyLineInfoUpdate,
  isCustomRegulationLine,
  loadLineInfoOverrides,
  type NewLineInput,
} from "@/lib/regulation-custom-line";
import {
  applyEditorStateToRegulationLine,
  loadLineEditorDraft,
  regulationStopsFromEditor,
  saveLineEditorDraft,
} from "@/lib/line-editor-persistence";
import { regenerateLineEditorState } from "@/lib/line-regeneration";
import {
  syncPublishedLineTrace,
  unpublishLineTrace,
} from "@/lib/line-editor-immersive-sync";
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
  const { schemaReady } = useNetwork();
  const {
    customLines,
    ready: customLinesReady,
    updateLineStops,
    updateLineFromEditor,
    updateLineInfo,
    persistLine,
  } = useCustomRegulationLines();
  const migratedDraftRef = useRef<Set<string>>(new Set());
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

  // Row serveur (network_lines) pour cette ligne, s'il existe. Une ligne GTFS
  // éditée devient un override serveur porté par le même id composite.
  const catalogLine = useMemo(
    () => customLines.find((line) => line.id === lineId) ?? null,
    [customLines, lineId],
  );

  const selectedLine = useMemo((): RegulationLine | null => {
    if (catalogLine) return catalogLine;

    const networkLineExists = networkLines.some((line) => line.id === lineId);
    return networkLineExists ? networkSelectedLine : null;
  }, [catalogLine, lineId, networkLines, networkSelectedLine]);

  const displayLine = useMemo(() => {
    if (!selectedLine) return null;
    // Dès qu'une version serveur existe, elle fait foi : on n'empile plus les
    // overrides localStorage (source de vérité unique, cohérente entre supports).
    if (catalogLine) return catalogLine;

    // Ligne GTFS pas encore migrée : on applique l'éventuel override d'infos
    // local le temps que la migration serveur s'exécute.
    let line = selectedLine;
    if (!isCustomRegulationLine(lineId)) {
      const override = lineInfoOverrides[lineId];
      if (override) line = applyLineInfoUpdate(line, override);
    }
    return line;
  }, [selectedLine, catalogLine, lineId, lineInfoOverrides]);

  // Persiste une édition de ligne réseau GTFS côté Supabase et republie le
  // tracé partagé (carte immersive + mobile) dès qu'une géométrie existe.
  const persistGtfsEdit = useCallback(
    async (updated: RegulationLine, editorState?: LineEditorState | null) => {
      await persistLine(updated, editorState);
      const state = editorState ?? updated.editorState ?? null;
      if (state) {
        await syncPublishedLineTrace(state);
      }
    },
    [persistLine],
  );

  // Migration one-shot : à la première ouverture d'une ligne GTFS déjà éditée
  // localement (brouillon d'éditeur ou override d'infos) mais absente du
  // serveur, on pousse cette édition dans Supabase pour la rendre commune à
  // tous les supports. La version du premier poste qui charge fait foi.
  useEffect(() => {
    if (!schemaReady || !customLinesReady) return;
    if (isCustomRegulationLine(lineId)) return;
    if (catalogLine) return;
    if (migratedDraftRef.current.has(lineId)) return;
    if (!selectedLine) return;

    const draft = loadLineEditorDraft(lineId);
    const infoOverride = loadLineInfoOverrides()[lineId];
    if (!draft && !infoOverride) return;

    migratedDraftRef.current.add(lineId);
    let updated = selectedLine;
    if (draft) updated = applyEditorStateToRegulationLine(selectedLine, draft);
    if (infoOverride) updated = applyLineInfoUpdate(updated, infoOverride);
    void persistGtfsEdit(updated, draft ?? null);
  }, [
    schemaReady,
    customLinesReady,
    lineId,
    catalogLine,
    selectedLine,
    persistGtfsEdit,
  ]);

  const handleStopsChange = useCallback(
    (stops: RegulationStop[]) => {
      if (isCustomRegulationLine(lineId)) {
        void updateLineStops(lineId, stops);
        return;
      }
      const base = displayLine ?? selectedLine;
      if (!base) return;
      // Édition d'arrêts (frise) : on persiste le plan côté serveur en
      // conservant l'éventuelle géométrie de l'éditeur (pas de republication).
      const updated = applyEditedStops(base, stops);
      void persistLine(updated);
    },
    [lineId, updateLineStops, displayLine, selectedLine, persistLine],
  );

  const handleDeleteAllStops = useCallback(() => {
    if (isCustomRegulationLine(lineId)) {
      void updateLineStops(lineId, []);
      return;
    }
    const base = displayLine ?? selectedLine;
    if (!base) return;
    // Remise à zéro : plan vidé, géométrie éditeur effacée et tracé partagé
    // dépublié (carte immersive + mobile).
    const cleared = applyEditedStops({ ...base, editorState: null }, []);
    void (async () => {
      await persistLine(cleared, null);
      await unpublishLineTrace(base.shortName);
    })();
  }, [lineId, updateLineStops, displayLine, selectedLine, persistLine]);

  const handleEditorPersist = useCallback(
    async (persistedLineId: string, editorState: LineEditorState) => {
      setEditorStateOverride({ lineId: persistedLineId, state: editorState });
      setSelectedVariantId(null);
      saveLineEditorDraft(persistedLineId, editorState);

      // Ligne custom déjà au catalogue : chemin RPC dédié existant.
      if (isCustomRegulationLine(persistedLineId)) {
        await updateLineFromEditor(persistedLineId, editorState);
        await syncPublishedLineTrace(editorState);
        return;
      }

      // Ligne réseau GTFS : matérialise/actualise l'override serveur + tracé.
      const baseLine =
        customLines.find((line) => line.id === persistedLineId) ??
        networkLines.find((line) => line.id === persistedLineId) ??
        selectedLine;
      if (!baseLine) return;
      const updated = applyEditorStateToRegulationLine(baseLine, editorState);
      await persistGtfsEdit(updated, editorState);
    },
    [
      customLines,
      networkLines,
      selectedLine,
      updateLineFromEditor,
      persistGtfsEdit,
    ],
  );

  const handleLineInfoSave = useCallback(
    (input: NewLineInput) => {
      if (isCustomRegulationLine(lineId)) {
        void updateLineInfo(lineId, input);
        return;
      }
      const base = displayLine ?? selectedLine;
      if (!base) return;
      // Modification d'infos : persistée côté serveur, géométrie préservée.
      const updated = applyLineInfoUpdate(base, input);
      const previousShortName = base.shortName;
      const renamed = previousShortName !== updated.shortName;
      // Le tracé partagé est indexé par shortName : à un renommage, on aligne
      // l'état éditeur, on retire l'ancienne clé et on republie sous la neuve,
      // sinon l'ancien tracé resterait orphelin pour la carte et le mobile.
      const editorState = updated.editorState
        ? { ...updated.editorState, shortName: updated.shortName }
        : null;

      void (async () => {
        await persistLine({ ...updated, editorState }, editorState);
        if (!renamed) return;
        await unpublishLineTrace(previousShortName);
        if (editorState) await syncPublishedLineTrace(editorState);
      })();
    },
    [lineId, updateLineInfo, displayLine, selectedLine, persistLine],
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
        await syncPublishedLineTrace(regeneratedState);
      } else {
        // Ligne réseau GTFS : régénération persistée côté serveur (plan + infos
        // dérivés de l'état régénéré) et tracé republié pour tous les supports.
        saveLineEditorDraft(lineId, regeneratedState);
        const updated = applyEditorStateToRegulationLine(
          displayLine,
          regeneratedState,
        );
        await persistGtfsEdit(updated, regeneratedState);
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
    persistGtfsEdit,
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
              onDeleteAllStops={handleDeleteAllStops}
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
              onDeleteAllStops={handleDeleteAllStops}
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
