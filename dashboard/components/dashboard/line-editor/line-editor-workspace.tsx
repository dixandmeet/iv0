"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Box,
  BusFront,
  Check,
  CircleDot,
  Eye,
  EyeOff,
  Flag,
  LayoutPanelLeft,
  Map,
  MapPinPlus,
  MousePointer2,
  Redo2,
  Route,
  Ruler,
  Satellite,
  Signpost,
  Sparkles,
  TrafficCone,
  Trash2,
  Undo2,
} from "lucide-react";
import type { RegulationLine } from "@/lib/regulation-mock-data";
import { loadLineEditorDraft } from "@/lib/line-editor-persistence";
import type { RegisteredStop } from "@/lib/registered-stops";
import type { LineEditorState, PointType } from "@/lib/line-editor-types";
import {
  formatDistance,
  haversineKm,
  lineEditorFromRegulationLine,
  isStopType,
} from "@/lib/line-editor-utils";
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
  onPersist?: (lineId: string, state: LineEditorState) => void | Promise<void>;
}

function buildInitialEditorState(line: RegulationLine): LineEditorState {
  return line.editorState ?? loadLineEditorDraft(line.id) ?? lineEditorFromRegulationLine(line);
}

type WorkMode = "trace" | "stops" | "gps" | "signage" | "preview";
type EditorTool = "select" | "stop" | "terminus" | "hub" | "gps" | "measure";

const WORK_MODES: Array<{ id: WorkMode; label: string }> = [
  { id: "trace", label: "Tracé" },
  { id: "stops", label: "Arrêts" },
  { id: "gps", label: "Points GPS" },
  { id: "signage", label: "Signalétique" },
  { id: "preview", label: "Aperçu voyageur" },
];

function ToolButton({
  icon: Icon,
  label,
  active = false,
  disabled = false,
  danger = false,
  onClick,
}: {
  icon: typeof Map;
  label: string;
  active?: boolean;
  disabled?: boolean;
  danger?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      className={`line-editor-floating-tool${active ? " active" : ""}${danger ? " danger" : ""}`}
      title={label}
      aria-label={label}
      aria-pressed={active}
      disabled={disabled}
      onClick={onClick}
    >
      <Icon className="h-[17px] w-[17px]" />
      <span>{label}</span>
    </button>
  );
}

export function LineEditorWorkspace({
  line,
  onBack,
  onPersist,
}: LineEditorWorkspaceProps) {
  const handleAutoSave = useCallback(
    async (editorState: LineEditorState) => {
      const lineId = line?.id;
      if (!lineId) return;
      await onPersist?.(lineId, editorState);
    },
    [line?.id, onPersist],
  );

  const editor = useLineEditor(
    line ? buildInitialEditorState(line) : undefined,
    { onAutoSave: handleAutoSave },
  );
  const mapRef = useRef<LineEditorMapHandle>(null);
  const [tracePickerActive, setTracePickerActive] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [planOpen, setPlanOpen] = useState(true);
  const [planWidth, setPlanWidth] = useState(220);
  const [guideOpen, setGuideOpen] = useState(false);
  const [workMode, setWorkMode] = useState<WorkMode>("trace");
  const [activeTool, setActiveTool] = useState<EditorTool>("select");
  const [showQuality, setShowQuality] = useState(false);
  const [measureStart, setMeasureStart] = useState<[number, number] | null>(null);
  const [measurementKm, setMeasurementKm] = useState<number | null>(null);
  const [mapLayers, setMapLayers] = useState({
    satellite: false,
    panels: true,
    traffic: false,
    gps: true,
    view3D: true,
  });
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
      setPlanWidth(Math.min(Math.max(190, next), 320));
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
    showPassagePoints: mapLayers.gps && workMode !== "preview",
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

  const passageCount = activePoints.filter((point) => point.type === "passage").length;
  const turnCount = Math.max(activePoints.length - 2, 0);
  const duplicatePointCount = useMemo(() => {
    const seen = new Set<string>();
    let duplicates = 0;
    for (const point of activePoints) {
      const key = `${point.coordinates[0].toFixed(6)}:${point.coordinates[1].toFixed(6)}`;
      if (seen.has(key)) duplicates += 1;
      seen.add(key);
    }
    return duplicates;
  }, [activePoints]);
  const hasLongSegment = useMemo(
    () =>
      activePoints.some((point, index) =>
        index === 0
          ? false
          : haversineKm(activePoints[index - 1].coordinates, point.coordinates) > 2.5,
      ),
    [activePoints],
  );
  const allStopsConnected = stops.length >= 2 && activePoints.length >= stops.length;
  const qualityScore = Math.max(
    72,
    100 - (allStopsConnected ? 0 : 14) - duplicatePointCount * 8 - (hasLongSegment ? 5 : 0),
  );

  const handleMapCanvasClick = useCallback(
    (coordinates: [number, number]) => {
      if (activeTool === "select") {
        editor.selectPoint(null);
        return;
      }
      if (activeTool === "measure") {
        if (!measureStart) {
          setMeasureStart(coordinates);
          setMeasurementKm(null);
        } else {
          setMeasurementKm(haversineKm(measureStart, coordinates));
          setMeasureStart(null);
        }
        return;
      }
      let type: PointType = "passage";
      if (activeTool === "stop") type = "stop";
      if (activeTool === "hub") type = "hub";
      if (activeTool === "terminus") {
        type = stops.some((stop) => stop.type === "terminus_start")
          ? "terminus_end"
          : "terminus_start";
      }
      editor.addPoint(coordinates, type);
      setActiveTool("select");
    },
    [activeTool, editor, measureStart, stops],
  );

  const changeWorkMode = useCallback((mode: WorkMode) => {
    setWorkMode(mode);
    setActiveTool(mode === "stops" ? "stop" : mode === "gps" ? "gps" : "select");
  }, []);

  const toggleLayer = (layer: "satellite" | "panels" | "traffic" | "gps") => {
    setMapLayers((current) => ({ ...current, [layer]: !current[layer] }));
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
        saveStatus={editor.saveStatus}
        saveError={editor.saveError}
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
        {planOpen && (
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
        )}

        <div className="line-editor-map-area">
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
            showPassagePoints={mapLayers.gps && workMode !== "preview"}
            onAddPoint={handleMapCanvasClick}
            onInsertPointAtSegment={editor.insertPointAtSegment}
            onSelectPoint={editor.selectPoint}
            onPickTraceTarget={(targetId) => void handleTraceSegmentTo(targetId)}
            onCommitMove={editor.commitPointMove}
          />

          <div className="line-editor-mode-switcher" role="tablist" aria-label="Mode de travail">
            {WORK_MODES.map((mode) => (
              <button
                key={mode.id}
                type="button"
                role="tab"
                aria-selected={workMode === mode.id}
                className={workMode === mode.id ? "active" : ""}
                onClick={() => changeWorkMode(mode.id)}
              >
                {mode.label}
              </button>
            ))}
          </div>

          <div className="line-editor-map-layers" aria-label="Affichage de la carte">
            <button
              type="button"
              className={!mapLayers.satellite ? "active" : ""}
              onClick={() => setMapLayers((current) => ({ ...current, satellite: false }))}
            >
              <Map className="h-3.5 w-3.5" />
              Plan
            </button>
            <button
              type="button"
              className={mapLayers.satellite ? "active" : ""}
              onClick={() => toggleLayer("satellite")}
            >
              <Satellite className="h-3.5 w-3.5" />
              Satellite
            </button>
            <button
              type="button"
              className={mapLayers.view3D ? "active" : ""}
              onClick={() => {
                mapRef.current?.toggle3D();
                setMapLayers((current) => ({ ...current, view3D: !current.view3D }));
              }}
            >
              <Box className="h-3.5 w-3.5" />
              3D
            </button>
            <button
              type="button"
              className={mapLayers.panels ? "active" : ""}
              onClick={() => toggleLayer("panels")}
            >
              <Signpost className="h-3.5 w-3.5" />
              Panneaux
            </button>
            <button
              type="button"
              className={mapLayers.traffic ? "active" : ""}
              onClick={() => toggleLayer("traffic")}
            >
              <TrafficCone className="h-3.5 w-3.5" />
              Trafic
            </button>
            <button
              type="button"
              className={mapLayers.gps ? "active" : ""}
              onClick={() => toggleLayer("gps")}
              title={mapLayers.gps ? "Masquer les points de passage" : "Afficher les points de passage"}
              aria-label={mapLayers.gps ? "Masquer les points de passage" : "Afficher les points de passage"}
            >
              {mapLayers.gps ? (
                <Eye className="h-3.5 w-3.5" />
              ) : (
                <EyeOff className="h-3.5 w-3.5" />
              )}
              Passages
            </button>
            <button
              type="button"
              className="danger"
              onClick={editor.clearRouteTrace}
              disabled={!editor.hasPassagePoints}
              title="Supprimer uniquement les points de passage"
              aria-label="Supprimer uniquement les points de passage"
            >
              <Trash2 className="h-3.5 w-3.5" />
              Tout retirer
            </button>
          </div>

          <div
            className={`line-editor-floating-tools${workMode === "preview" ? " is-hidden" : ""}`}
            aria-label="Outils d’édition"
          >
            <ToolButton
              icon={MousePointer2}
              label="Sélection et déplacement"
              active={activeTool === "select"}
              onClick={() => setActiveTool("select")}
            />
            {(workMode === "trace" || workMode === "stops") && (
              <>
                <ToolButton
                  icon={MapPinPlus}
                  label="Ajouter un arrêt"
                  active={activeTool === "stop"}
                  onClick={() => setActiveTool("stop")}
                />
                <ToolButton
                  icon={Flag}
                  label="Ajouter un terminus"
                  active={activeTool === "terminus"}
                  onClick={() => setActiveTool("terminus")}
                />
                <ToolButton
                  icon={BusFront}
                  label="Ajouter un pôle"
                  active={activeTool === "hub"}
                  onClick={() => setActiveTool("hub")}
                />
              </>
            )}
            {(workMode === "trace" || workMode === "gps") && (
              <ToolButton
                icon={CircleDot}
                label="Ajouter un point GPS"
                active={activeTool === "gps"}
                onClick={() => setActiveTool("gps")}
              />
            )}
            <span className="line-editor-tool-separator" />
            {workMode === "trace" && (
              <ToolButton
                icon={Sparkles}
                label="Tracer automatiquement"
                disabled={editor.tracing || activePoints.length < 2}
                onClick={() => void editor.traceItinerary()}
              />
            )}
            <ToolButton
              icon={Ruler}
              label="Mesurer"
              active={activeTool === "measure"}
              onClick={() => {
                setMeasureStart(null);
                setMeasurementKm(null);
                setActiveTool("measure");
              }}
            />
            <ToolButton
              icon={Trash2}
              label="Supprimer la sélection"
              danger
              disabled={!selectedPoint}
              onClick={() => selectedPoint && editor.deletePoint(selectedPoint.id)}
            />
            <span className="line-editor-tool-separator" />
            <ToolButton icon={Undo2} label="Annuler" disabled={!editor.canUndo} onClick={editor.undo} />
            <ToolButton icon={Redo2} label="Rétablir" disabled={!editor.canRedo} onClick={editor.redo} />
          </div>

          {activeTool === "measure" && (
            <div className="line-editor-measurement">
              <Ruler className="h-3.5 w-3.5" />
              {measureStart
                ? "Cliquez sur le point d’arrivée"
                : measurementKm != null
                  ? measurementKm < 1
                    ? `${Math.round(measurementKm * 1000)} m`
                    : `${measurementKm.toFixed(2)} km`
                  : "Cliquez sur le point de départ"}
            </div>
          )}

          {!planOpen && (
            <button
              type="button"
              className="line-editor-floating-panel-toggle line-editor-floating-panel-toggle--left"
              onClick={() => setPlanOpen(true)}
              title="Afficher le parcours"
            >
              <Route className="h-4 w-4" />
            </button>
          )}
          {!sidebarOpen && (
            <button
              type="button"
              className="line-editor-floating-panel-toggle line-editor-floating-panel-toggle--right"
              onClick={() => setSidebarOpen(true)}
              title="Afficher l’inspecteur"
            >
              <LayoutPanelLeft className="h-4 w-4" />
            </button>
          )}
        </div>

        {sidebarOpen && (
          <LineEditorSidebar
            selectedPoint={selectedPoint}
            allPoints={activePoints}
            trunkStops={trunkStops}
            branches={activeBranches}
            originLegs={activeOriginLegs}
            activeBranchId={state.activeBranchId}
            activeOriginLegId={state.activeOriginLegId}
            stopPosition={stopContext?.position ?? null}
            totalStops={stopContext?.total ?? stops.length}
            onUpdateType={(type) => {
              if (selectedPoint) editor.updatePointType(selectedPoint.id, type);
            }}
            onUpdateStop={(patch) => {
              if (selectedPoint) editor.updateStopDetails(selectedPoint.id, patch);
            }}
            onUpdatePassage={(patch) => {
              if (selectedPoint) editor.updatePassageDetails(selectedPoint.id, patch);
            }}
            onDelete={() => {
              if (selectedPoint) editor.deletePoint(selectedPoint.id);
            }}
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

      <footer className="line-editor-info-bar">
        <div className="line-editor-info-item">
          <BusFront className="h-3.5 w-3.5" />
          <strong>{stats.stopCount}</strong> arrêts
        </div>
        <div className="line-editor-info-item">
          <Route className="h-3.5 w-3.5" />
          <strong>{formatDistance(stats.distanceKm)}</strong>
        </div>
        <div className="line-editor-info-item">
          <Eye className="h-3.5 w-3.5" />
          <strong>{stats.travelMinutes} min</strong>
        </div>
        <div className="line-editor-info-item">
          <CircleDot className="h-3.5 w-3.5" />
          <strong>{passageCount}</strong> points de passage
        </div>
        <div className="line-editor-info-item">
          <TrafficCone className="h-3.5 w-3.5" />
          <strong>{turnCount}</strong> virages
        </div>
        <button
          type="button"
          className="line-editor-quality-trigger"
          onClick={() => setShowQuality((visible) => !visible)}
          aria-expanded={showQuality}
        >
          <span>Qualité du parcours</span>
          <span className="line-editor-quality-meter" aria-hidden>
            <span style={{ width: `${qualityScore}%` }} />
          </span>
          <strong>{qualityScore} %</strong>
        </button>
        {showQuality && (
          <div className="line-editor-quality-popover">
            <div className="line-editor-quality-popover-head">
              <div>
                <span>Qualité du parcours</span>
                <strong>{qualityScore} %</strong>
              </div>
              <Sparkles className="h-4 w-4" />
            </div>
            <div className="line-editor-quality-large-meter">
              <span style={{ width: `${qualityScore}%` }} />
            </div>
            <ul>
              <li className={allStopsConnected ? "ok" : "warning"}>
                <Check className="h-3.5 w-3.5" />
                {allStopsConnected ? "Tous les arrêts sont reliés" : "Des arrêts restent à relier"}
              </li>
              <li className={duplicatePointCount === 0 ? "ok" : "warning"}>
                <Check className="h-3.5 w-3.5" />
                {duplicatePointCount === 0 ? "Aucun point en doublon" : `${duplicatePointCount} doublon détecté`}
              </li>
              <li className="ok">
                <Check className="h-3.5 w-3.5" />
                Temps inter-arrêts cohérents
              </li>
              {hasLongSegment && (
                <li className="warning">
                  <TrafficCone className="h-3.5 w-3.5" />
                  Segment supérieur à 2,5 km
                </li>
              )}
            </ul>
          </div>
        )}
      </footer>
    </div>
  );
}
