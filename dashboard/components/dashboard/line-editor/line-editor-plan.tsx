"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ChevronDown,
  ChevronUp,
  GitBranchPlus,
  GripVertical,
  Pencil,
  Plus,
  Signpost,
  Trash2,
} from "lucide-react";
import {
  branchesFromHub,
  originLegsFromHub,
  hasComplexTopology,
} from "@/lib/line-editor-branches";
import { isStopType } from "@/lib/line-editor-utils";
import {
  POINT_TYPE_COLORS,
  type LineBranch,
  type LineOriginLeg,
  type RoutePoint,
} from "@/lib/line-editor-types";

interface LineEditorPlanProps {
  trunkStops: RoutePoint[];
  allTrunkPoints: RoutePoint[];
  branches: LineBranch[];
  originLegs: LineOriginLeg[];
  activeBranchId: string | null;
  activeOriginLegId: string | null;
  selectedPointId: string | null;
  lineColor: string;
  onSelectStop: (
    pointId: string,
    branchId: string | null,
    originLegId: string | null,
  ) => void;
  onReorder: (fromIndex: number, toIndex: number) => void;
  onAddStop: (stopIndex: number) => void;
  onAddStopAfterSelected: () => void;
  onAddBranch: (hubPointId: string) => void;
  onAddOriginLeg: (hubPointId: string) => void;
  onSelectBranch: (branchId: string | null) => void;
  onSelectOriginLeg: (legId: string | null) => void;
  onDeleteOriginLeg: (legId: string) => void;
  onUpdateOriginLegMeta: (
    legId: string,
    patch: Partial<Pick<LineOriginLeg, "label">>,
  ) => void;
}

interface PlanListItem {
  stop: RoutePoint;
  branchId: string | null;
  originLegId: string | null;
  kind?: "stop" | "merge";
}

function originLegTabLabel(leg: LineOriginLeg, index: number): string {
  const stopName = leg.points[0]?.stop?.name?.trim();
  const label = leg.label.trim();
  const generic = /^(Nouveau départ|Départ \d+)$/i;
  if (stopName && !generic.test(stopName)) return stopName;
  if (label && !generic.test(label)) return label;
  return `Départ ${index + 1}`;
}

function branchTabLabel(branch: LineBranch): string {
  const terminus = branch.terminusName.trim();
  const lastName = branch.points[branch.points.length - 1]?.stop?.name?.trim();
  const label = branch.label.trim();
  if (terminus && terminus !== "Nouveau terminus") return terminus;
  if (lastName) return lastName;
  if (label && !/^Branche \d+$/.test(label)) return label;
  return branch.label || "Branche";
}

export function LineEditorPlan({
  trunkStops,
  allTrunkPoints,
  branches,
  originLegs,
  activeBranchId,
  activeOriginLegId,
  selectedPointId,
  lineColor,
  onSelectStop,
  onReorder,
  onAddStop,
  onAddStopAfterSelected,
  onAddBranch,
  onAddOriginLeg,
  onSelectBranch,
  onSelectOriginLeg,
  onDeleteOriginLeg,
  onUpdateOriginLegMeta,
}: LineEditorPlanProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [dragIndex, setDragIndex] = useState<number | null>(null);
  const [overIndex, setOverIndex] = useState<number | null>(null);
  const [renamingLegId, setRenamingLegId] = useState<string | null>(null);

  const complexTopology = hasComplexTopology(branches, originLegs);

  const activeOriginLeg = useMemo(
    () => originLegs.find((l) => l.id === activeOriginLegId) ?? null,
    [originLegs, activeOriginLegId],
  );

  const activeOriginLegMergeHub = useMemo(() => {
    if (!activeOriginLeg) return null;
    return trunkStops.find((s) => s.id === activeOriginLeg.mergePointId) ?? null;
  }, [activeOriginLeg, trunkStops]);

  const listItems = useMemo((): PlanListItem[] => {
    if (activeOriginLegId) {
      const leg = originLegs.find((l) => l.id === activeOriginLegId);
      return (leg?.points.filter((p) => isStopType(p.type)) ?? []).map((stop) => ({
        stop,
        branchId: null,
        originLegId: leg!.id,
        kind: "stop" as const,
      }));
    }
    if (activeBranchId) {
      const branch = branches.find((b) => b.id === activeBranchId);
      return (branch?.points.filter((p) => isStopType(p.type)) ?? []).map((stop) => ({
        stop,
        branchId: branch!.id,
        originLegId: null,
        kind: "stop" as const,
      }));
    }

    const items: PlanListItem[] = [];
    const hubsWithOrigins = new Set<string>();

    for (const stop of trunkStops) {
      if (stop.type === "hub" && originLegs.length > 0) {
        const legs = originLegsFromHub(originLegs, stop.id);
        if (legs.length > 0 && !hubsWithOrigins.has(stop.id)) {
          hubsWithOrigins.add(stop.id);
          for (const leg of legs) {
            for (const p of leg.points.filter((pt) => isStopType(pt.type))) {
              items.push({
                stop: p,
                branchId: null,
                originLegId: leg.id,
                kind: "stop",
              });
            }
          }
          items.push({
            stop,
            branchId: null,
            originLegId: null,
            kind: "merge",
          });
        }
      }
      items.push({
        stop,
        branchId: null,
        originLegId: null,
        kind: "stop",
      });
    }
    return items;
  }, [activeOriginLegId, activeBranchId, originLegs, branches, trunkStops]);

  const reorderableStops = useMemo(
    () =>
      listItems
        .filter((item) => item.kind !== "merge")
        .filter((item) => {
          if (activeOriginLegId) return item.originLegId === activeOriginLegId;
          if (activeBranchId) return item.branchId === activeBranchId;
          return !item.branchId && !item.originLegId;
        })
        .map((item) => item.stop),
    [listItems, activeOriginLegId, activeBranchId],
  );

  const canReorderStop = useCallback(
    (branchId: string | null, originLegId: string | null): boolean => {
      if (activeOriginLegId) return originLegId === activeOriginLegId;
      if (activeBranchId) return branchId === activeBranchId;
      return !branchId && !originLegId;
    },
    [activeOriginLegId, activeBranchId],
  );

  const reorderIndexFor = useCallback(
    (stop: RoutePoint, branchId: string | null, originLegId: string | null): number | null => {
      if (!canReorderStop(branchId, originLegId)) return null;
      const idx = reorderableStops.findIndex((s) => s.id === stop.id);
      return idx >= 0 ? idx : null;
    },
    [canReorderStop, reorderableStops],
  );

  const handleDrop = useCallback(
    (toIndex: number) => {
      if (dragIndex != null && dragIndex !== toIndex) {
        onReorder(dragIndex, toIndex);
      }
      setDragIndex(null);
      setOverIndex(null);
    },
    [dragIndex, onReorder],
  );

  const clearDrag = useCallback(() => {
    setDragIndex(null);
    setOverIndex(null);
  }, []);

  const scrollToStopId = useCallback((stopId: string) => {
    const el = scrollRef.current?.querySelector(`[data-stop-id="${stopId}"]`);
    el?.scrollIntoView({ block: "nearest", behavior: "smooth" });
  }, []);

  const scroll = useCallback((dir: "up" | "down") => {
    scrollRef.current?.scrollBy({
      top: dir === "up" ? -220 : 220,
      behavior: "smooth",
    });
  }, []);

  useEffect(() => {
    if (selectedPointId) scrollToStopId(selectedPointId);
  }, [selectedPointId, listItems, scrollToStopId]);

  const travelTimeBetween = useCallback(
    (item: PlanListItem): number | null => {
      const { stop, branchId, originLegId } = item;

      if (originLegId) {
        const leg = originLegs.find((l) => l.id === originLegId);
        if (!leg) return stop.stop?.travelTimeMinutes ?? null;
        const legStops = leg.points.filter((p) => isStopType(p.type));
        const stopIndex = legStops.findIndex((p) => p.id === stop.id);
        if (stopIndex <= 0) return null;
        const prev = legStops[stopIndex - 1];
        return stop.stop?.travelTimeMinutes ?? prev?.stop?.travelTimeMinutes ?? null;
      }

      if (branchId) {
        const branch = branches.find((b) => b.id === branchId);
        if (!branch) return stop.stop?.travelTimeMinutes ?? null;
        const branchStops = branch.points.filter((p) => isStopType(p.type));
        const stopIndex = branchStops.findIndex((p) => p.id === stop.id);
        if (stopIndex <= 0) return null;
        const prev = branchStops[stopIndex - 1];
        return stop.stop?.travelTimeMinutes ?? prev?.stop?.travelTimeMinutes ?? null;
      }

      const trunkIndex = trunkStops.findIndex((p) => p.id === stop.id);
      if (trunkIndex <= 0) return null;
      const prevStop = trunkStops[trunkIndex - 1];
      const prevIdx = allTrunkPoints.findIndex((p) => p.id === prevStop.id);
      const currIdx = allTrunkPoints.findIndex((p) => p.id === stop.id);
      if (prevIdx < 0 || currIdx < 0) return stop.stop?.travelTimeMinutes ?? null;

      let minutes = 0;
      for (let i = prevIdx + 1; i <= currIdx; i++) {
        minutes += allTrunkPoints[i].stop?.travelTimeMinutes ?? 1;
      }
      return minutes || stop.stop?.travelTimeMinutes || null;
    },
    [allTrunkPoints, branches, originLegs, trunkStops],
  );

  const stopIndexInContext = useCallback(
    (
      point: RoutePoint,
      branchId: string | null,
      originLegId: string | null,
    ): number => {
      if (originLegId) {
        const leg = originLegs.find((l) => l.id === originLegId);
        return leg?.points.filter((p) => isStopType(p.type)).findIndex((p) => p.id === point.id) ?? 0;
      }
      if (branchId) {
        const branch = branches.find((b) => b.id === branchId);
        return branch?.points.filter((p) => isStopType(p.type)).findIndex((p) => p.id === point.id) ?? 0;
      }
      return trunkStops.findIndex((p) => p.id === point.id);
    },
    [branches, originLegs, trunkStops],
  );

  const returnToTrunk = () => {
    onSelectBranch(null);
    onSelectOriginLeg(null);
  };

  const selectStop = (
    stop: RoutePoint,
    branchId: string | null,
    originLegId: string | null,
  ) => {
    if (branchId) onSelectBranch(branchId);
    else if (originLegId) onSelectOriginLeg(originLegId);
    else {
      onSelectBranch(null);
      onSelectOriginLeg(null);
    }
    onSelectStop(stop.id, branchId, originLegId);
  };

  const openOriginLeg = (leg: LineOriginLeg) => {
    const first = leg.points.find((p) => isStopType(p.type));
    if (first) {
      onSelectStop(first.id, null, leg.id);
      scrollToStopId(first.id);
    } else {
      onSelectOriginLeg(leg.id);
      onSelectBranch(null);
    }
  };

  const openBranch = (branch: LineBranch) => {
    const first = branch.points.find((p) => isStopType(p.type));
    if (first) {
      onSelectStop(first.id, branch.id, null);
    } else {
      onSelectBranch(branch.id);
      onSelectOriginLeg(null);
    }
    if (first) scrollToStopId(first.id);
  };

  const renderStopCard = (
    stop: RoutePoint,
    branchId: string | null,
    originLegId: string | null,
  ) => {
    const index = stopIndexInContext(stop, branchId, originLegId);
    const reorderIndex = reorderIndexFor(stop, branchId, originLegId);
    const isDraggable = reorderIndex != null;
    const isSelected = stop.id === selectedPointId;
    const isTerminusStart = stop.type === "terminus_start";
    const isTerminusEnd = stop.type === "terminus_end";
    const isHub = stop.type === "hub";
    const color = POINT_TYPE_COLORS[stop.type];
    const hubBranches = isHub ? branchesFromHub(branches, stop.id) : [];
    const hubOriginLegs = isHub ? originLegsFromHub(originLegs, stop.id) : [];
    const isContextActive =
      (branchId && activeBranchId === branchId) ||
      (originLegId && activeOriginLegId === originLegId) ||
      (!branchId && !originLegId && !activeBranchId && !activeOriginLegId);

    const isInlineOrigin =
      originLegId != null && !activeOriginLegId && !activeBranchId;

    return (
      <div
        className={`line-editor-plan-v-stop${isSelected ? " selected" : ""}${isTerminusStart ? " terminus-start" : ""}${isTerminusEnd ? " terminus-end" : ""}${isHub ? " hub" : ""}${isInlineOrigin ? " origin-inline" : ""}${isContextActive && (branchId || originLegId) ? " branch-active" : ""}${dragIndex === reorderIndex ? " dragging" : ""}${overIndex === reorderIndex ? " drop-target" : ""}`}
        onClick={() => selectStop(stop, branchId, originLegId)}
        onDragOver={
          isDraggable
            ? (e) => {
                e.preventDefault();
                e.dataTransfer.dropEffect = "move";
                setOverIndex(reorderIndex);
              }
            : undefined
        }
        onDragLeave={isDraggable ? () => setOverIndex(null) : undefined}
        onDrop={
          isDraggable
            ? (e) => {
                e.preventDefault();
                e.stopPropagation();
                handleDrop(reorderIndex);
              }
            : undefined
        }
        role="button"
        tabIndex={0}
        onKeyDown={(e) => {
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            selectStop(stop, branchId, originLegId);
          }
        }}
      >
        {isDraggable ? (
          <button
            type="button"
            className="line-editor-plan-v-grip"
            draggable
            onDragStart={(e) => {
              e.stopPropagation();
              setDragIndex(reorderIndex);
              e.dataTransfer.effectAllowed = "move";
            }}
            onDragEnd={clearDrag}
            onClick={(e) => e.stopPropagation()}
            aria-label={`Déplacer ${stop.stop?.name || "l'arrêt"}`}
            title="Glisser pour réordonner"
          >
            <GripVertical className="h-3.5 w-3.5" />
          </button>
        ) : (
          <span className="line-editor-plan-v-grip line-editor-plan-v-grip--static" aria-hidden />
        )}
        <span
          className="line-editor-plan-v-dot"
          style={{
            background: color,
            boxShadow: isSelected ? `0 0 0 3px ${color}40` : undefined,
          }}
        />
        <div className="line-editor-plan-v-info">
          <span className="line-editor-plan-v-name">
            {stop.stop?.name || `Arrêt ${index + 1}`}
          </span>
          {stop.stop?.code && (
            <span className="line-editor-plan-v-code">{stop.stop.code}</span>
          )}
        </div>
        <div className="line-editor-plan-v-badges">
          {isTerminusStart && !isHub && (
            <span className="line-editor-plan-v-badge line-editor-plan-v-badge--start">Départ</span>
          )}
          {isTerminusEnd && (
            <span className="line-editor-plan-v-badge line-editor-plan-v-badge--end">Arrivée</span>
          )}
          {isHub && (
            <span className="line-editor-plan-v-badge line-editor-plan-v-badge--hub">Hub</span>
          )}
        </div>
        {isHub && (
          <div className="line-editor-plan-v-hub-actions">
            <button
              type="button"
              className="line-editor-plan-v-hub-btn line-editor-plan-v-hub-btn--origin"
              onClick={(e) => {
                e.stopPropagation();
                onAddOriginLeg(stop.id);
              }}
              title="Ajouter un départ"
            >
              <Signpost className="h-3 w-3" />
            </button>
            <button
              type="button"
              className="line-editor-plan-v-hub-btn line-editor-plan-v-hub-btn--branch"
              onClick={(e) => {
                e.stopPropagation();
                onAddBranch(stop.id);
              }}
              title="Ajouter une branche"
            >
              <GitBranchPlus className="h-3 w-3" />
            </button>
            {(hubOriginLegs.length > 0 || hubBranches.length > 0) && (
              <span className="line-editor-plan-v-hub-count">
                {hubOriginLegs.length > 0 ? `${hubOriginLegs.length}↓` : ""}
                {hubBranches.length > 0 ? `${hubBranches.length}↗` : ""}
              </span>
            )}
          </div>
        )}
      </div>
    );
  };

  const shouldShowTravel = useCallback(
    (item: PlanListItem, index: number): boolean => {
      if (index === 0 || item.kind === "merge") return false;
      const prev = listItems[index - 1];
      if (prev?.kind === "merge") return false;
      if (
        item.originLegId &&
        prev?.originLegId &&
        item.originLegId !== prev.originLegId
      ) {
        return false;
      }
      return true;
    },
    [listItems],
  );

  const renderTravelSegment = (item: PlanListItem, index: number) => {
    if (!shouldShowTravel(item, index)) return null;
    const travel = travelTimeBetween(item);
    const reorderIndex = reorderIndexFor(item.stop, item.branchId, item.originLegId);
    return (
      <div className="line-editor-plan-v-travel">
        {reorderIndex != null && (
          <button
            type="button"
            className="line-editor-plan-v-insert"
            onClick={() => onAddStop(reorderIndex)}
            title="Insérer un arrêt ici"
          >
            <Plus className="h-3 w-3" />
          </button>
        )}
        {travel != null && <span>{travel} min</span>}
      </div>
    );
  };

  const renderMergeConnector = (hubStop: RoutePoint) => (
    <div className="line-editor-plan-v-merge" data-stop-id={hubStop.id}>
      <div className="line-editor-plan-v-merge-line" />
      <span className="line-editor-plan-v-merge-label">Convergence</span>
    </div>
  );

  const showTrunkDepartures =
    complexTopology &&
    !activeBranchId &&
    !activeOriginLegId &&
    originLegs.length > 0;

  if (trunkStops.length === 0 && originLegs.length === 0) {
    return (
      <aside className="line-editor-plan line-editor-plan--vertical line-editor-plan--empty">
        <p>Aucun arrêt défini.</p>
        <button type="button" className="line-editor-timeline-add-btn" onClick={() => onAddStop(0)}>
          <Plus className="h-4 w-4" />
          Ajouter
        </button>
      </aside>
    );
  }

  return (
    <aside className="line-editor-plan line-editor-plan--vertical">
      <div className="line-editor-plan-v-header">
        <div>
          <span className="line-editor-plan-v-title">Plan</span>
          <span className="line-editor-plan-v-count">
            {reorderableStops.length} arrêt{reorderableStops.length > 1 ? "s" : ""}
            {reorderableStops.length > 1 && (
              <span className="line-editor-plan-v-hint"> · glisser ↕</span>
            )}
          </span>
        </div>
        {(activeBranchId || activeOriginLegId) && (
          <button type="button" className="line-editor-plan-trunk-btn" onClick={returnToTrunk}>
            Tronc
          </button>
        )}
        <button
          type="button"
          className="line-editor-plan-v-add"
          onClick={onAddStopAfterSelected}
          title="Ajouter un arrêt"
        >
          <Plus className="h-4 w-4" />
        </button>
      </div>

      {complexTopology && (
        <div className="line-editor-plan-v-tabs">
          <button
            type="button"
            className={`line-editor-plan-v-tab${!activeBranchId && !activeOriginLegId ? " active" : ""}`}
            onClick={returnToTrunk}
          >
            Tronc
          </button>
          {originLegs.map((leg, i) => (
            <div
              key={leg.id}
              className={`line-editor-plan-v-tab-wrap${activeOriginLegId === leg.id ? " active" : ""}`}
            >
              <button
                type="button"
                className={`line-editor-plan-v-tab origin${activeOriginLegId === leg.id ? " active" : ""}`}
                onClick={() => openOriginLeg(leg)}
                onDoubleClick={(e) => {
                  e.preventDefault();
                  openOriginLeg(leg);
                  setRenamingLegId(leg.id);
                }}
              >
                {originLegTabLabel(leg, i)}
              </button>
              {activeOriginLegId === leg.id && (
                <>
                  <button
                    type="button"
                    className="line-editor-plan-v-tab-action"
                    title="Renommer le départ"
                    onClick={(e) => {
                      e.stopPropagation();
                      setRenamingLegId(leg.id);
                    }}
                  >
                    <Pencil className="h-3 w-3" />
                  </button>
                  <button
                    type="button"
                    className="line-editor-plan-v-tab-action danger"
                    title="Supprimer ce départ"
                    onClick={(e) => {
                      e.stopPropagation();
                      onDeleteOriginLeg(leg.id);
                      setRenamingLegId(null);
                    }}
                  >
                    <Trash2 className="h-3 w-3" />
                  </button>
                </>
              )}
            </div>
          ))}
          {branches.map((branch) => (
            <button
              key={branch.id}
              type="button"
              className={`line-editor-plan-v-tab fork${activeBranchId === branch.id ? " active" : ""}`}
              onClick={() => openBranch(branch)}
            >
              {branchTabLabel(branch)}
            </button>
          ))}
        </div>
      )}

      {showTrunkDepartures && (
        <div className="line-editor-plan-v-departures">
          <span className="line-editor-plan-v-departures-label">Départs convergents</span>
          <div className="line-editor-plan-v-departures-chips">
            {originLegs.map((leg, i) => {
              const first = leg.points.find((p) => isStopType(p.type));
              const selectedInLeg =
                first && selectedPointId === first.id && !activeOriginLegId && !activeBranchId;
              return (
                <div key={leg.id} className="line-editor-plan-v-departure-chip-wrap">
                  <button
                    type="button"
                    className={`line-editor-plan-v-departure-chip${selectedInLeg ? " selected" : ""}`}
                    onClick={() => openOriginLeg(leg)}
                  >
                    {originLegTabLabel(leg, i)}
                  </button>
                  <button
                    type="button"
                    className="line-editor-plan-v-departure-chip-action danger"
                    title="Supprimer ce départ"
                    onClick={(e) => {
                      e.stopPropagation();
                      onDeleteOriginLeg(leg.id);
                    }}
                  >
                    <Trash2 className="h-2.5 w-2.5" />
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {activeOriginLeg && (
        <div className="line-editor-plan-v-origin-toolbar">
          <label className="line-editor-plan-v-origin-label">
            {renamingLegId === activeOriginLeg.id ? "Nom du départ" : "Départ actif"}
            <input
              className="line-editor-plan-v-origin-input"
              value={activeOriginLeg.label}
              onChange={(e) =>
                onUpdateOriginLegMeta(activeOriginLeg.id, { label: e.target.value })
              }
              onFocus={() => setRenamingLegId(activeOriginLeg.id)}
              onBlur={() => setRenamingLegId(null)}
              placeholder="Ex. Beaujoire"
            />
          </label>
          {activeOriginLegMergeHub && (
            <span className="line-editor-plan-v-origin-merge">
              → {activeOriginLegMergeHub.stop?.name ?? "Hub"}
            </span>
          )}
          <button
            type="button"
            className="line-editor-plan-v-origin-delete"
            title="Supprimer ce départ"
            onClick={() => {
              onDeleteOriginLeg(activeOriginLeg.id);
              setRenamingLegId(null);
            }}
          >
            <Trash2 className="h-3.5 w-3.5" />
          </button>
        </div>
      )}

      <div className="line-editor-plan-v-scroll-wrap">
        <button type="button" className="line-editor-plan-v-nav" onClick={() => scroll("up")}>
          <ChevronUp className="h-4 w-4" />
        </button>

        <div className="line-editor-plan-v-scroll" ref={scrollRef}>
          {activeOriginLegId && listItems.length === 0 ? (
            <div className="line-editor-plan-v-empty-leg">
              <p>Aucun arrêt sur ce départ.</p>
              <button
                type="button"
                className="line-editor-timeline-add-btn"
                onClick={onAddStopAfterSelected}
              >
                <Plus className="h-4 w-4" />
                Ajouter un terminus
              </button>
              <button
                type="button"
                className="line-editor-plan-v-empty-leg-delete"
                onClick={() => onDeleteOriginLeg(activeOriginLegId)}
              >
                <Trash2 className="h-3.5 w-3.5" />
                Supprimer ce départ
              </button>
            </div>
          ) : (
          <div
            className="line-editor-plan-v-track"
            style={{ "--line-color": lineColor } as React.CSSProperties}
          >
            {listItems.map((item, index) => {
              const { stop, branchId, originLegId, kind } = item;
              return (
                <div
                  key={`${kind ?? "stop"}-${stop.id}-${originLegId ?? ""}-${index}`}
                  className="line-editor-plan-v-segment"
                  data-stop-id={stop.id}
                >
                  {kind === "merge" ? (
                    renderMergeConnector(stop)
                  ) : (
                    <>
                      {renderTravelSegment(item, index)}
                      {renderStopCard(stop, branchId, originLegId)}
                    </>
                  )}
                </div>
              );
            })}
          </div>
          )}
        </div>

        <button type="button" className="line-editor-plan-v-nav" onClick={() => scroll("down")}>
          <ChevronDown className="h-4 w-4" />
        </button>
      </div>
    </aside>
  );
}
