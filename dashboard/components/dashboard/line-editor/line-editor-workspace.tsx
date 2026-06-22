"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { LayoutPanelLeft, Map, PanelLeftClose } from "lucide-react";
import type { RegulationLine } from "@/lib/regulation-mock-data";
import { loadLineEditorDraft } from "@/lib/line-editor-persistence";
import type { RegisteredStop } from "@/lib/registered-stops";
import type { LineEditorState } from "@/lib/line-editor-types";
import { lineEditorFromRegulationLine, isStopType } from "@/lib/line-editor-utils";
import { collectTerminiLabels, findPointInEditor } from "@/lib/line-editor-branches";
import { useLineEditor } from "@/hooks/use-line-editor";
import { LineEditorHeader } from "./line-editor-header";
import { LineEditorMap, type LineEditorMapHandle } from "./line-editor-map";
import { LineEditorSidebar } from "./line-editor-sidebar";
import { LineEditorPlan } from "./line-editor-plan";
import { LineEditorGuideModal } from "./line-editor-guide-modal";

interface LineEditorWorkspaceProps {
  line?: RegulationLine | null;
  onBack: () => void;
  onPersist?: (lineId: string, state: LineEditorState) => void;
}

function buildInitialEditorState(line: RegulationLine): LineEditorState {
  return loadLineEditorDraft(line.id) ?? lineEditorFromRegulationLine(line);
}

export function LineEditorWorkspace({
  line,
  onBack,
  onPersist,
}: LineEditorWorkspaceProps) {
  const lineIdRef = useRef(line?.id);
  lineIdRef.current = line?.id;

  const handleAutoSave = useCallback(
    (editorState: LineEditorState) => {
      const lineId = lineIdRef.current;
      if (!lineId) return;
      onPersist?.(lineId, editorState);
    },
    [onPersist],
  );

  const editor = useLineEditor(
    line ? buildInitialEditorState(line) : undefined,
    { onAutoSave: handleAutoSave },
  );
  const mapRef = useRef<LineEditorMapHandle>(null);
  const [tracePickerActive, setTracePickerActive] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [planOpen, setPlanOpen] = useState(true);
  const [planWidth, setPlanWidth] = useState(300);
  const [guideOpen, setGuideOpen] = useState(false);
  const planResizeRef = useRef<{ startX: number; startW: number } | null>(null);

  const { state, activePoints, trunkPoints, trunkStops, activeBranches, activeOriginLegs, inactivePoints, selectedPoint, stops, stats } = editor;

  const termini = useMemo(
    () => collectTerminiLabels(trunkStops, activeBranches, activeOriginLegs),
    [trunkStops, activeBranches, activeOriginLegs],
  );

  const mapPoints = useMemo(() => {
    const branchPts = activeBranches.flatMap((b) => b.points);
    const originPts = activeOriginLegs.flatMap((l) => l.points);
    const ids = new Set(trunkPoints.map((p) => p.id));
    return [
      ...trunkPoints,
      ...originPts.filter((p) => !ids.has(p.id)),
      ...branchPts.filter((p) => !ids.has(p.id)),
    ];
  }, [trunkPoints, activeBranches, activeOriginLegs]);

  const routeSegments = useMemo(() => {
    const segments: typeof trunkPoints[] = [trunkPoints];
    for (const leg of activeOriginLegs) {
      const hub = trunkPoints.find((p) => p.id === leg.mergePointId);
      if (hub && leg.points.length > 0) {
        segments.push([...leg.points, hub]);
      }
    }
    for (const branch of activeBranches) {
      const hub = trunkPoints.find((p) => p.id === branch.forkPointId);
      if (hub && branch.points.length > 0) {
        segments.push([hub, ...branch.points]);
      }
    }
    return segments;
  }, [trunkPoints, activeOriginLegs, activeBranches]);

  const stopContext = useMemo(() => {
    if (!selectedPoint || !isStopType(selectedPoint.type) || !state.selectedPointId) {
      return null;
    }
    const located = findPointInEditor(state, state.selectedPointId);
    if (!located) return null;

    let contextStops: typeof trunkStops;
    if (located.originLegId) {
      const leg = activeOriginLegs.find((l) => l.id === located.originLegId);
      contextStops = leg?.points.filter((p) => isStopType(p.type)) ?? [];
    } else if (located.branchId) {
      const branch = activeBranches.find((b) => b.id === located.branchId);
      contextStops = branch?.points.filter((p) => isStopType(p.type)) ?? [];
    } else {
      contextStops = trunkStops;
    }

    const idx = contextStops.findIndex((s) => s.id === selectedPoint.id);
    if (idx < 0) return null;
    return { position: idx, total: contextStops.length };
  }, [selectedPoint, state, activeOriginLegs, activeBranches, trunkStops]);

  const handleSelectPoint = useCallback(
    (pointId: string) => {
      editor.selectPoint(pointId);
      mapRef.current?.flyToPoint(pointId);
    },
    [editor],
  );

  const handleSelectStop = useCallback(
    (pointId: string, branchId: string | null, originLegId: string | null) => {
      if (branchId) {
        editor.setActiveBranch(branchId);
      } else if (originLegId) {
        editor.setActiveOriginLeg(originLegId);
      } else {
        editor.setActiveBranch(null);
        editor.setActiveOriginLeg(null);
      }
      editor.selectPoint(pointId);
      mapRef.current?.flyToPoint(pointId);
    },
    [editor],
  );

  const handleAddStop = useCallback(
    (stopIndex: number) => {
      const newId = editor.addStopAt(stopIndex);
      if (newId) {
        requestAnimationFrame(() => mapRef.current?.flyToPoint(newId));
      }
    },
    [editor],
  );

  const handleAddStopAfterSelected = useCallback(() => {
    const newId = editor.addStopAfterSelected();
    if (newId) {
      requestAnimationFrame(() => mapRef.current?.flyToPoint(newId));
    }
  }, [editor]);

  const handleSelectRegisteredStop = useCallback(
    (stop: RegisteredStop) => {
      if (!selectedPoint) return;

      editor.updateStopDetails(selectedPoint.id, {
        name: stop.name,
        code: stop.code || selectedPoint.stop?.code || "",
        address: stop.address ?? selectedPoint.stop?.address ?? "",
        wheelchairAccessible:
          stop.wheelchairAccessible ?? selectedPoint.stop?.wheelchairAccessible ?? false,
      });

      if (stop.coordinates) {
        editor.commitPointMove(selectedPoint.id, stop.coordinates);
        mapRef.current?.flyToPoint(selectedPoint.id);
      }
    },
    [editor, selectedPoint],
  );

  const handleTraceSegmentTo = useCallback(
    async (targetPointId: string) => {
      if (!state.selectedPointId) return;
      const ok = await editor.traceSegmentTo(state.selectedPointId, targetPointId);
      if (ok) setTracePickerActive(false);
    },
    [editor, state.selectedPointId],
  );

  const handleStartTracePicker = useCallback(() => {
    if (selectedPoint?.type !== "passage") return;
    setTracePickerActive(true);
  }, [selectedPoint?.type]);

  const handleCancelTracePicker = useCallback(() => {
    setTracePickerActive(false);
  }, []);

  useEffect(() => {
    if (selectedPoint?.type !== "passage") {
      setTracePickerActive(false);
    }
  }, [selectedPoint?.id, selectedPoint?.type]);

  useEffect(() => {
    const onMove = (event: MouseEvent) => {
      if (!planResizeRef.current) return;
      const delta = event.clientX - planResizeRef.current.startX;
      const next = planResizeRef.current.startW + delta;
      setPlanWidth(Math.min(Math.max(220, next), 480));
    };
    const onUp = () => {
      planResizeRef.current = null;
      document.body.style.removeProperty("cursor");
      document.body.style.removeProperty("user-select");
    };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
    };
  }, []);

  const beginPlanResize = useCallback(
    (event: React.MouseEvent) => {
      event.preventDefault();
      planResizeRef.current = { startX: event.clientX, startW: planWidth };
      document.body.style.cursor = "col-resize";
      document.body.style.userSelect = "none";
    },
    [planWidth],
  );

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" && tracePickerActive) {
        e.preventDefault();
        setTracePickerActive(false);
        return;
      }
      if ((e.metaKey || e.ctrlKey) && e.key === "z") {
        e.preventDefault();
        if (e.shiftKey) editor.redo();
        else editor.undo();
      }
      if ((e.metaKey || e.ctrlKey) && e.key === "y") {
        e.preventDefault();
        editor.redo();
      }
      if (
        (e.key === "Delete" || e.key === "Backspace") &&
        state.selectedPointId &&
        !(e.target instanceof HTMLInputElement) &&
        !(e.target instanceof HTMLTextAreaElement) &&
        !(e.target instanceof HTMLSelectElement)
      ) {
        e.preventDefault();
        editor.deletePoint(state.selectedPointId);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [editor, state.selectedPointId, tracePickerActive]);

  const planProps = {
    trunkStops,
    allTrunkPoints: trunkPoints,
    branches: activeBranches,
    originLegs: activeOriginLegs,
    activeBranchId: state.activeBranchId,
    activeOriginLegId: state.activeOriginLegId,
    selectedPointId: state.selectedPointId,
    lineColor: state.color,
    onSelectStop: handleSelectStop,
    onReorder: editor.reorderStops,
    onAddStop: handleAddStop,
    onAddStopAfterSelected: handleAddStopAfterSelected,
    onAddBranch: editor.addBranchFromHub,
    onAddOriginLeg: editor.addOriginLegFromHub,
    onSelectBranch: editor.setActiveBranch,
    onSelectOriginLeg: editor.setActiveOriginLeg,
    onDeleteOriginLeg: editor.deleteOriginLeg,
    onUpdateOriginLegMeta: editor.updateOriginLegMeta,
  };

  return (
    <div className="line-editor-workspace">
      <LineEditorHeader
        state={state}
        stats={stats}
        termini={termini}
        canUndo={editor.canUndo}
        canRedo={editor.canRedo}
        lastSavedAt={editor.lastSavedAt}
        onUndo={editor.undo}
        onRedo={editor.redo}
        onPublish={editor.publishLine}
        onBack={onBack}
        onMetaChange={editor.updateLineMeta}
        onVoiceChange={editor.setActiveVoice}
        onOpenGuide={() => setGuideOpen(true)}
      />

      <LineEditorGuideModal open={guideOpen} onClose={() => setGuideOpen(false)} />

      <div className="line-editor-body">
        {planOpen ? (
          <>
            <div className="line-editor-plan-rail" style={{ width: planWidth }}>
              <LineEditorPlan {...planProps} />
            </div>
            <div
              className="line-editor-plan-resizer-v"
              role="separator"
              aria-orientation="vertical"
              aria-label="Redimensionner le plan de ligne"
              onMouseDown={beginPlanResize}
            />
          </>
        ) : (
          <button
            type="button"
            className="line-editor-plan-rail-collapsed"
            onClick={() => setPlanOpen(true)}
            title="Afficher le plan de ligne"
          >
            <PanelLeftClose className="h-4 w-4" />
          </button>
        )}

        <div className="line-editor-map-area">
          <div className="line-editor-view-toolbar">
            <button
              type="button"
              className={`line-editor-view-btn${planOpen ? " active" : ""}`}
              onClick={() => setPlanOpen((open) => !open)}
              title={planOpen ? "Masquer le plan" : "Afficher le plan"}
            >
              <PanelLeftClose className="h-3.5 w-3.5" />
              Plan
            </button>
            <button
              type="button"
              className={`line-editor-view-btn${sidebarOpen ? " active" : ""}`}
              onClick={() => setSidebarOpen((open) => !open)}
              title={sidebarOpen ? "Masquer le panneau" : "Afficher le panneau"}
            >
              <LayoutPanelLeft className="h-3.5 w-3.5" />
              Panneau
            </button>
            <button
              type="button"
              className="line-editor-view-btn line-editor-view-btn--focus"
              onClick={() => {
                setSidebarOpen(false);
                setPlanOpen(false);
              }}
              title="Plein écran carte"
            >
              <Map className="h-3.5 w-3.5" />
              Carte
            </button>
          </div>
          <LineEditorMap
            ref={mapRef}
            points={mapPoints}
            editingPoints={activePoints}
            routeSegments={routeSegments}
            referencePoints={inactivePoints}
            activeVoice={state.activeVoice}
            lineColor={state.color}
            selectedPointId={state.selectedPointId}
            tracing={editor.tracing}
            traceError={editor.traceError}
            canClearTrace={editor.hasPassagePoints}
            tracePickerActive={tracePickerActive}
            traceOriginId={tracePickerActive ? state.selectedPointId : null}
            onTraceRoute={() => void editor.traceItinerary()}
            onClearTrace={editor.clearRouteTrace}
            onAddPoint={editor.addPoint}
            onInsertPointAtSegment={editor.insertPointAtSegment}
            onSelectPoint={editor.selectPoint}
            onPickTraceTarget={(targetId) => void handleTraceSegmentTo(targetId)}
            onMovePoint={editor.movePoint}
            onCommitMove={editor.commitPointMove}
          />
        </div>

        {sidebarOpen && (
          <LineEditorSidebar
            selectedPoint={selectedPoint}
            passagePoints={editor.passagePoints}
            allPoints={activePoints}
            trunkStops={trunkStops}
            branches={activeBranches}
            originLegs={activeOriginLegs}
            activeBranchId={state.activeBranchId}
            activeOriginLegId={state.activeOriginLegId}
            stopPosition={stopContext?.position ?? null}
            totalStops={stopContext?.total ?? stops.length}
            onSelectPoint={handleSelectPoint}
            onUpdateType={(type) => {
              if (selectedPoint) editor.updatePointType(selectedPoint.id, type);
            }}
            onUpdateStop={(patch) => {
              if (selectedPoint) editor.updateStopDetails(selectedPoint.id, patch);
            }}
            onDelete={() => {
              if (selectedPoint) editor.deletePoint(selectedPoint.id);
            }}
            onDeletePoint={editor.deletePoint}
            onTransformToStop={() => {
              if (selectedPoint) editor.transformToStop(selectedPoint.id);
            }}
            onSetTerminus={(which) => {
              if (selectedPoint) editor.setAsTerminus(selectedPoint.id, which);
            }}
            onAddBranch={editor.addBranchFromHub}
            onAddOriginLeg={editor.addOriginLegFromHub}
            onAttachAsOriginLeg={editor.attachStopAsOriginLeg}
            onDeleteBranch={editor.deleteBranch}
            onDeleteOriginLeg={editor.deleteOriginLeg}
            onSelectBranch={editor.setActiveBranch}
            onSelectOriginLeg={editor.setActiveOriginLeg}
            onUpdateBranchMeta={editor.updateBranchMeta}
            onUpdateOriginLegMeta={editor.updateOriginLegMeta}
            onCommitCoordinates={(coordinates) => {
              if (!selectedPoint) return;
              editor.commitPointMove(selectedPoint.id, coordinates);
            }}
            onSelectRegisteredStop={handleSelectRegisteredStop}
            tracePickerActive={tracePickerActive}
            tracing={editor.tracing}
            onStartTracePicker={handleStartTracePicker}
            onCancelTracePicker={handleCancelTracePicker}
            onTraceSegmentTo={(targetId) => void handleTraceSegmentTo(targetId)}
          />
        )}
      </div>
    </div>
  );
}
