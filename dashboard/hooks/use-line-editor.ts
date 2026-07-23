"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  countStops,
  createDemoLineEditorState,
  createRetourPointsFromAller,
  createRoutePoint,
  estimatedTravelMinutes,
  coordinatesForNewStop,
  findSegmentInsertIndex,
  getVoicePoints,
  insertStopInPoints,
  interpolateCoordinates,
  isStopType,
  normalizeLineEditorState,
  reorderStopsInPoints,
  segmentDistanceKm,
  setVoicePoints,
  updateVoicePoints,
} from "@/lib/line-editor-utils";
import {
  allBranchStops,
  allOriginLegStops,
  branchesFromHub,
  createBranchFromHub,
  createOriginLegFromHub,
  createOriginLegId,
  findPointInEditor,
  getVoiceBranches,
  getVoiceOriginLegs,
  originLegsFromHub,
  setVoiceBranches,
  updateVoiceBranches,
  updateVoiceOriginLegs,
} from "@/lib/line-editor-branches";
import type {
  EditorLineStatus,
  LineBranch,
  LineEditorState,
  LineOriginLeg,
  LineVoice,
  PointType,
  PassageDetails,
  RoutePoint,
  StopDetails,
} from "@/lib/line-editor-types";
import { tracePointsOnRoads, traceSegmentBetween } from "@/lib/line-editor-routing";
import { syncPublishedLineTrace, unpublishLineTrace } from "@/lib/line-editor-immersive-sync";

const MAX_HISTORY = 50;
const IMMERSIVE_SYNC_DEBOUNCE_MS = 1500;
const AUTO_SAVE_DEBOUNCE_MS = 500;

function getContextPoints(state: LineEditorState): RoutePoint[] {
  if (state.activeOriginLegId) {
    const leg = getVoiceOriginLegs(state).find((l) => l.id === state.activeOriginLegId);
    return leg?.points ?? [];
  }
  if (state.activeBranchId) {
    const branch = getVoiceBranches(state).find((b) => b.id === state.activeBranchId);
    return branch?.points ?? [];
  }
  return getVoicePoints(state);
}

function insertPassageInContext(
  prev: LineEditorState,
  insertIndex: number,
  point: RoutePoint,
): LineEditorState {
  if (prev.activeOriginLegId) {
    return {
      ...updateVoiceOriginLegs(prev, (legs) =>
        legs.map((leg) => {
          if (leg.id !== prev.activeOriginLegId) return leg;
          const nextPoints = [...leg.points];
          nextPoints.splice(insertIndex, 0, point);
          return { ...leg, points: nextPoints };
        }),
      ),
      selectedPointId: point.id,
    };
  }

  if (prev.activeBranchId) {
    return {
      ...updateVoiceBranches(prev, (branches) =>
        branches.map((branch) => {
          if (branch.id !== prev.activeBranchId) return branch;
          const nextPoints = [...branch.points];
          nextPoints.splice(insertIndex, 0, point);
          return { ...branch, points: nextPoints };
        }),
      ),
      selectedPointId: point.id,
    };
  }

  const points = getVoicePoints(prev);
  const nextPoints = [...points];
  nextPoints.splice(insertIndex, 0, point);
  return {
    ...setVoicePoints(prev, nextPoints),
    selectedPointId: point.id,
  };
}

function cloneState(state: LineEditorState): LineEditorState {
  return JSON.parse(JSON.stringify(state)) as LineEditorState;
}

export interface UseLineEditorOptions {
  onAutoSave?: (state: LineEditorState) => void | Promise<void>;
}

export function useLineEditor(
  initialState?: LineEditorState,
  options?: UseLineEditorOptions,
) {
  const [state, setState] = useState<LineEditorState>(() =>
    normalizeLineEditorState(initialState ?? createDemoLineEditorState()),
  );
  const historyRef = useRef<LineEditorState[]>([]);
  const futureRef = useRef<LineEditorState[]>([]);
  const [historyAvailability, setHistoryAvailability] = useState({
    canUndo: false,
    canRedo: false,
  });
  const [tracing, setTracing] = useState(false);
  const [traceError, setTraceError] = useState<string | null>(null);
  const traceAbortRef = useRef<AbortController | null>(null);
  const onAutoSaveRef = useRef(options?.onAutoSave);
  const [lastSavedAt, setLastSavedAt] = useState<number | null>(null);
  const [saveStatus, setSaveStatus] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [saveError, setSaveError] = useState<string | null>(null);
  const autoSaveTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pendingSaveRef = useRef<LineEditorState | null>(null);
  const saveVersionRef = useRef(0);
  const saveQueueRef = useRef<Promise<void>>(Promise.resolve());
  const immersiveSyncTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastPublishedLineIdRef = useRef<string | null>(
    initialState?.status === "published" ? initialState.shortName.trim() || null : null,
  );

  useEffect(() => {
    onAutoSaveRef.current = options?.onAutoSave;
  }, [options?.onAutoSave]);

  const syncImmersiveMap = useCallback((next: LineEditorState) => {
    if (immersiveSyncTimerRef.current) clearTimeout(immersiveSyncTimerRef.current);

    const previousLineId = lastPublishedLineIdRef.current;
    const nextLineId = next.status === "published" ? next.shortName.trim() || null : null;

    if (previousLineId && previousLineId !== nextLineId) {
      void unpublishLineTrace(previousLineId);
    }
    lastPublishedLineIdRef.current = nextLineId;

    if (!nextLineId) return;

    // Une première publication (ou un changement de numéro de ligne) doit être
    // visible immédiatement, même si l'utilisateur quitte ensuite l'éditeur.
    if (previousLineId !== nextLineId) {
      void syncPublishedLineTrace(next);
      return;
    }

    immersiveSyncTimerRef.current = setTimeout(() => {
      void syncPublishedLineTrace(next);
    }, IMMERSIVE_SYNC_DEBOUNCE_MS);
  }, []);

  const flushAutoSave = useCallback(async () => {
    const next = pendingSaveRef.current;
    if (!next) return;

    pendingSaveRef.current = null;
    autoSaveTimerRef.current = null;
    const version = saveVersionRef.current;

    try {
      const queuedSave = saveQueueRef.current
        .catch(() => undefined)
        .then(async () => {
          await onAutoSaveRef.current?.(next);
        });
      saveQueueRef.current = queuedSave;
      await queuedSave;
      if (version === saveVersionRef.current) {
        setLastSavedAt(Date.now());
        setSaveStatus("saved");
        setSaveError(null);
      }
    } catch (error) {
      if (version === saveVersionRef.current) {
        setSaveStatus("error");
        setSaveError(
          error instanceof Error ? error.message : "Impossible d’enregistrer les modifications",
        );
      }
    }
  }, []);

  const persistState = useCallback(
    (next: LineEditorState) => {
      syncImmersiveMap(next);
      pendingSaveRef.current = next;
      saveVersionRef.current += 1;
      setSaveStatus("saving");
      setSaveError(null);
      if (autoSaveTimerRef.current) clearTimeout(autoSaveTimerRef.current);
      autoSaveTimerRef.current = setTimeout(() => {
        void flushAutoSave();
      }, AUTO_SAVE_DEBOUNCE_MS);
    },
    [flushAutoSave, syncImmersiveMap],
  );

  useEffect(() => () => {
    if (autoSaveTimerRef.current) clearTimeout(autoSaveTimerRef.current);
    const pending = pendingSaveRef.current;
    if (pending) {
      saveQueueRef.current = saveQueueRef.current
        .catch(() => undefined)
        .then(async () => {
          await onAutoSaveRef.current?.(pending);
        });
      void saveQueueRef.current.catch(console.error);
    }
  }, []);

  const pushHistory = useCallback((prev: LineEditorState) => {
    historyRef.current = [...historyRef.current.slice(-(MAX_HISTORY - 1)), cloneState(prev)];
    futureRef.current = [];
    setHistoryAvailability({ canUndo: true, canRedo: false });
  }, []);

  const commit = useCallback(
    (updater: (prev: LineEditorState) => LineEditorState) => {
      setState((prev) => {
        pushHistory(prev);
        const next = updater(prev);
        queueMicrotask(() => persistState(next));
        return next;
      });
    },
    [pushHistory, persistState],
  );

  const undo = useCallback(() => {
    const past = historyRef.current;
    if (past.length === 0) return;
    const previous = past[past.length - 1];
    historyRef.current = past.slice(0, -1);
    setState((current) => {
      futureRef.current = [cloneState(current), ...futureRef.current];
      queueMicrotask(() => persistState(previous));
      return previous;
    });
    setHistoryAvailability({ canUndo: past.length > 1, canRedo: true });
  }, [persistState]);

  const redo = useCallback(() => {
    const future = futureRef.current;
    if (future.length === 0) return;
    const next = future[0];
    futureRef.current = future.slice(1);
    setState((current) => {
      historyRef.current = [...historyRef.current, cloneState(current)];
      queueMicrotask(() => persistState(next));
      return next;
    });
    setHistoryAvailability({ canUndo: true, canRedo: future.length > 1 });
  }, [persistState]);

  const activePoints = useMemo(() => {
    if (state.activeOriginLegId) {
      const leg = getVoiceOriginLegs(state).find((l) => l.id === state.activeOriginLegId);
      return leg?.points ?? [];
    }
    if (state.activeBranchId) {
      const branch = getVoiceBranches(state).find((b) => b.id === state.activeBranchId);
      return branch?.points ?? [];
    }
    return getVoicePoints(state);
  }, [state]);

  const trunkPoints = useMemo(() => getVoicePoints(state), [state]);

  const activeBranches = useMemo(() => getVoiceBranches(state), [state]);
  const activeOriginLegs = useMemo(() => getVoiceOriginLegs(state), [state]);

  const inactivePoints = useMemo(
    () =>
      state.activeVoice === "aller" ? state.pointsRetour : state.pointsAller,
    [state.activeVoice, state.pointsAller, state.pointsRetour],
  );

  const addPoint = useCallback(
    (coordinates: [number, number], type: PointType = "passage") => {
      commit((prev) => {
        const points = getContextPoints(prev);
        const insertIndex = findSegmentInsertIndex(points, coordinates);
        const point = createRoutePoint(coordinates, type, countStops(points) + 1);
        return insertPassageInContext(prev, insertIndex, point);
      });
    },
    [commit],
  );

  const insertPointAtSegment = useCallback(
    (segmentIndex: number) => {
      commit((prev) => {
        const points = getContextPoints(prev);
        if (segmentIndex < 0 || segmentIndex >= points.length - 1) {
          return prev;
        }
        const from = points[segmentIndex].coordinates;
        const to = points[segmentIndex + 1].coordinates;
        const coordinates = interpolateCoordinates(from, to, 0.5);
        const point = createRoutePoint(coordinates, "passage");
        return insertPassageInContext(prev, segmentIndex + 1, point);
      });
    },
    [commit],
  );

  const commitPointMove = useCallback(
    (pointId: string, coordinates: [number, number]) => {
      commit((prev) => {
        const located = findPointInEditor(prev, pointId);
        if (!located) return prev;

        if (located.originLegId) {
          return updateVoiceOriginLegs(prev, (legs) =>
            legs.map((leg) =>
              leg.id === located.originLegId
                ? {
                    ...leg,
                    points: leg.points.map((p) =>
                      p.id === pointId ? { ...p, coordinates } : p,
                    ),
                  }
                : leg,
            ),
          );
        }

        if (located.branchId) {
          return updateVoiceBranches(prev, (branches) =>
            branches.map((branch) =>
              branch.id === located.branchId
                ? {
                    ...branch,
                    points: branch.points.map((p) =>
                      p.id === pointId ? { ...p, coordinates } : p,
                    ),
                  }
                : branch,
            ),
          );
        }

        return updateVoicePoints(prev, (points) =>
          points.map((p) => (p.id === pointId ? { ...p, coordinates } : p)),
        );
      });
    },
    [commit],
  );

  const deletePoint = useCallback(
    (pointId: string) => {
      commit((prev) => {
        if (prev.activeOriginLegId) {
          return updateVoiceOriginLegs(prev, (legs) =>
            legs.map((leg) => {
              if (leg.id !== prev.activeOriginLegId) return leg;
              const points = reorderStopsInPoints(
                leg.points.filter((p) => p.id !== pointId),
              );
              return { ...leg, points };
            }),
          );
        }

        if (prev.activeBranchId) {
          return updateVoiceBranches(prev, (branches) =>
            branches.map((branch) => {
              if (branch.id !== prev.activeBranchId) return branch;
              const points = reorderStopsInPoints(
                branch.points.filter((p) => p.id !== pointId),
              );
              return { ...branch, points };
            }),
          );
        }

        const originLegs = getVoiceOriginLegs(prev).filter(
          (l) => l.mergePointId !== pointId,
        );
        const nextOriginLegs =
          originLegs.length === getVoiceOriginLegs(prev).length
            ? getVoiceOriginLegs(prev)
            : originLegs;

        const branches = getVoiceBranches(prev).filter((b) => b.forkPointId !== pointId);
        const nextBranches =
          branches.length === getVoiceBranches(prev).length
            ? getVoiceBranches(prev)
            : branches;

        const points = reorderStopsInPoints(
          getVoicePoints(prev).filter((p) => p.id !== pointId),
        );
        const selectedPointId =
          prev.selectedPointId === pointId
            ? (points[points.length - 1]?.id ?? null)
            : prev.selectedPointId;

        let next = setVoicePoints(prev, points);
        next = setVoiceBranches(next, nextBranches);
        next = updateVoiceOriginLegs(next, () => nextOriginLegs);

        return {
          ...next,
          selectedPointId,
          activeBranchId:
            prev.activeBranchId &&
            nextBranches.some((b) => b.id === prev.activeBranchId)
              ? prev.activeBranchId
              : null,
          activeOriginLegId:
            prev.activeOriginLegId &&
            nextOriginLegs.some((l) => l.id === prev.activeOriginLegId)
              ? prev.activeOriginLegId
              : null,
        };
      });
    },
    [commit],
  );

  const selectPoint = useCallback((pointId: string | null) => {
    setState((prev) => {
      if (!pointId) {
        return { ...prev, selectedPointId: null };
      }
      const located = findPointInEditor(prev, pointId);
      if (!located) {
        return { ...prev, selectedPointId: pointId };
      }
      return {
        ...prev,
        selectedPointId: pointId,
        activeOriginLegId: located.originLegId,
        activeBranchId: located.branchId,
      };
    });
  }, []);

  const updatePointType = useCallback(
    (pointId: string, type: PointType) => {
      commit((prev) => {
        const applyType = (points: RoutePoint[]): RoutePoint[] =>
          points.map((p) => {
            if (p.id !== pointId) return p;
            const next: RoutePoint = { ...p, type };
            if (isStopType(type) && !next.stop) {
              const order = countStops(points) + 1;
              next.stop = {
                name: "",
                code: "",
                address: "",
                direction: "both",
                order,
                travelTimeMinutes: 3,
                wheelchairAccessible: false,
                connections: "",
                notes: "",
              };
            }
            if (type === "passage") {
              delete next.stop;
              next.gps ??= {
                name: "",
                radiusMeters: 15,
                estimatedMinutes: 1,
                notes: "",
              };
            } else {
              delete next.gps;
            }
            return next;
          });

        if (prev.activeOriginLegId) {
          return updateVoiceOriginLegs(prev, (legs) =>
            legs.map((leg) =>
              leg.id === prev.activeOriginLegId
                ? { ...leg, points: reorderStopsInPoints(applyType(leg.points)) }
                : leg,
            ),
          );
        }

        if (prev.activeBranchId) {
          return updateVoiceBranches(prev, (branches) =>
            branches.map((branch) =>
              branch.id === prev.activeBranchId
                ? { ...branch, points: reorderStopsInPoints(applyType(branch.points)) }
                : branch,
            ),
          );
        }

        return setVoicePoints(
          prev,
          reorderStopsInPoints(applyType(getVoicePoints(prev))),
        );
      });
    },
    [commit],
  );

  const updateStopDetails = useCallback(
    (pointId: string, patch: Partial<StopDetails>) => {
      commit((prev) => {
        const mapStop = (points: RoutePoint[]) =>
          points.map((p) =>
            p.id === pointId && p.stop ? { ...p, stop: { ...p.stop, ...patch } } : p,
          );

        if (prev.activeOriginLegId) {
          return updateVoiceOriginLegs(prev, (legs) =>
            legs.map((leg) => {
              if (leg.id !== prev.activeOriginLegId) return leg;
              const points = mapStop(leg.points);
              const first = points[0];
              const label =
                first?.id === pointId && patch.name ? patch.name : leg.label;
              return { ...leg, points, label };
            }),
          );
        }

        if (prev.activeBranchId) {
          return updateVoiceBranches(prev, (branches) =>
            branches.map((branch) => {
              if (branch.id !== prev.activeBranchId) return branch;
              const points = mapStop(branch.points);
              const last = points[points.length - 1];
              const terminusName =
                last?.id === pointId && patch.name
                  ? patch.name
                  : branch.terminusName;
              return { ...branch, points, terminusName };
            }),
          );
        }

        return updateVoicePoints(prev, mapStop);
      });
    },
    [commit],
  );

  const updatePassageDetails = useCallback(
    (pointId: string, patch: Partial<PassageDetails>) => {
      commit((prev) => {
        const mapPassage = (points: RoutePoint[]) =>
          points.map((point) => {
            if (point.id !== pointId || point.type !== "passage") return point;
            return {
              ...point,
              gps: {
                name: point.gps?.name ?? "",
                radiusMeters: point.gps?.radiusMeters ?? 15,
                estimatedMinutes: point.gps?.estimatedMinutes ?? 1,
                notes: point.gps?.notes ?? "",
                ...patch,
              },
            };
          });

        if (prev.activeOriginLegId) {
          return updateVoiceOriginLegs(prev, (legs) =>
            legs.map((leg) =>
              leg.id === prev.activeOriginLegId
                ? { ...leg, points: mapPassage(leg.points) }
                : leg,
            ),
          );
        }
        if (prev.activeBranchId) {
          return updateVoiceBranches(prev, (branches) =>
            branches.map((branch) =>
              branch.id === prev.activeBranchId
                ? { ...branch, points: mapPassage(branch.points) }
                : branch,
            ),
          );
        }
        return updateVoicePoints(prev, mapPassage);
      });
    },
    [commit],
  );

  const updateLineMeta = useCallback(
    (
      patch: Partial<
        Pick<
          LineEditorState,
          | "name"
          | "shortName"
          | "color"
          | "transportMode"
          | "directionAller"
          | "directionRetour"
          | "status"
        >
      >,
    ) => {
      commit((prev) => ({ ...prev, ...patch }));
    },
    [commit],
  );

  const reorderStops = useCallback(
    (fromIndex: number, toIndex: number) => {
      if (fromIndex === toIndex) return;
      commit((prev) => {
        if (prev.activeOriginLegId) {
          return updateVoiceOriginLegs(prev, (legs) =>
            legs.map((leg) => {
              if (leg.id !== prev.activeOriginLegId) return leg;
              const stops = leg.points.filter((p) => isStopType(p.type));
              if (fromIndex < 0 || toIndex < 0) return leg;
              if (fromIndex >= stops.length || toIndex >= stops.length) return leg;
              const reordered = [...stops];
              const [moved] = reordered.splice(fromIndex, 1);
              reordered.splice(toIndex, 0, moved);
              return { ...leg, points: reorderStopsInPoints(reordered) };
            }),
          );
        }

        if (prev.activeBranchId) {
          return updateVoiceBranches(prev, (branches) =>
            branches.map((branch) => {
              if (branch.id !== prev.activeBranchId) return branch;
              const stops = branch.points.filter((p) => isStopType(p.type));
              if (fromIndex < 0 || toIndex < 0) return branch;
              if (fromIndex >= stops.length || toIndex >= stops.length) return branch;
              const reordered = [...stops];
              const [moved] = reordered.splice(fromIndex, 1);
              reordered.splice(toIndex, 0, moved);
              return { ...branch, points: reorderStopsInPoints(reordered) };
            }),
          );
        }

        const voicePoints = getVoicePoints(prev);
        const stops = voicePoints.filter((p) => isStopType(p.type));
        const passages = voicePoints.filter((p) => p.type === "passage");
        if (fromIndex < 0 || toIndex < 0) return prev;
        if (fromIndex >= stops.length || toIndex >= stops.length) return prev;

        const reordered = [...stops];
        const [moved] = reordered.splice(fromIndex, 1);
        reordered.splice(toIndex, 0, moved);

        const stopIds = new Set(reordered.map((s) => s.id));
        const merged: RoutePoint[] = [];
        let stopIdx = 0;
        let passageIdx = 0;

        for (const p of voicePoints) {
          if (stopIds.has(p.id)) {
            if (stopIdx < reordered.length) {
              merged.push(reordered[stopIdx]);
              stopIdx += 1;
            }
          } else if (p.type === "passage") {
            merged.push(passages[passageIdx] ?? p);
            passageIdx += 1;
          }
        }

        while (stopIdx < reordered.length) {
          merged.push(reordered[stopIdx]);
          stopIdx += 1;
        }

        return setVoicePoints(prev, reorderStopsInPoints(merged));
      });
    },
    [commit],
  );

  const addStopAt = useCallback(
    (stopIndex: number): string => {
      let newPointId = "";
      commit((prev) => {
      if (prev.activeOriginLegId) {
        const updated = updateVoiceOriginLegs(prev, (legs) =>
          legs.map((leg) => {
            if (leg.id !== prev.activeOriginLegId) return leg;
            const coords = coordinatesForNewStop(leg.points, stopIndex);
            const legStops = leg.points.filter((p) => isStopType(p.type));
            const pointType =
              legStops.length === 0 && stopIndex === 0 ? "terminus_start" : "stop";
            const newStop = createRoutePoint(coords, pointType, stopIndex + 1);
            newPointId = newStop.id;
            const points = insertStopInPoints(leg.points, stopIndex, newStop);
            return { ...leg, points };
          }),
        );
        return { ...updated, selectedPointId: newPointId };
      }

        if (prev.activeBranchId) {
          const updated = updateVoiceBranches(prev, (branches) =>
            branches.map((branch) => {
              if (branch.id !== prev.activeBranchId) return branch;
              const coords = coordinatesForNewStop(branch.points, stopIndex);
              const newStop = createRoutePoint(coords, "stop", stopIndex + 1);
              newPointId = newStop.id;
              const points = insertStopInPoints(branch.points, stopIndex, newStop);
              return { ...branch, points };
            }),
          );
          return { ...updated, selectedPointId: newPointId };
        }

        const voicePoints = getVoicePoints(prev);
        const coords = coordinatesForNewStop(voicePoints, stopIndex);
        const newStop = createRoutePoint(coords, "stop", stopIndex + 1);
        newPointId = newStop.id;
        const points = insertStopInPoints(voicePoints, stopIndex, newStop);
        return { ...setVoicePoints(prev, points), selectedPointId: newStop.id };
      });
      return newPointId;
    },
    [commit],
  );

  const addStopAfterSelected = useCallback((): string => {
    let newPointId = "";
    commit((prev) => {
      const contextPoints = prev.activeOriginLegId
        ? getVoiceOriginLegs(prev).find((l) => l.id === prev.activeOriginLegId)?.points ?? []
        : prev.activeBranchId
          ? getVoiceBranches(prev).find((b) => b.id === prev.activeBranchId)?.points ?? []
          : getVoicePoints(prev);

      const stopsList = contextPoints.filter((p) => isStopType(p.type));
      let insertIndex = stopsList.length;
      if (prev.selectedPointId) {
        const selectedIdx = stopsList.findIndex((s) => s.id === prev.selectedPointId);
        if (selectedIdx >= 0) insertIndex = selectedIdx + 1;
      }

      if (prev.activeOriginLegId) {
        const updated = updateVoiceOriginLegs(prev, (legs) =>
          legs.map((leg) => {
            if (leg.id !== prev.activeOriginLegId) return leg;
            const coords = coordinatesForNewStop(leg.points, insertIndex);
            const pointType =
              stopsList.length === 0 && insertIndex === 0 ? "terminus_start" : "stop";
            const newStop = createRoutePoint(coords, pointType, insertIndex + 1);
            newPointId = newStop.id;
            const points = insertStopInPoints(leg.points, insertIndex, newStop);
            return { ...leg, points };
          }),
        );
        return { ...updated, selectedPointId: newPointId };
      }

      if (prev.activeBranchId) {
        const updated = updateVoiceBranches(prev, (branches) =>
          branches.map((branch) => {
            if (branch.id !== prev.activeBranchId) return branch;
            const coords = coordinatesForNewStop(branch.points, insertIndex);
            const newStop = createRoutePoint(coords, "stop", insertIndex + 1);
            newPointId = newStop.id;
            const points = insertStopInPoints(branch.points, insertIndex, newStop);
            return { ...branch, points };
          }),
        );
        return { ...updated, selectedPointId: newPointId };
      }

      const voicePoints = getVoicePoints(prev);
      const coords = coordinatesForNewStop(voicePoints, insertIndex);
      const newStop = createRoutePoint(coords, "stop", insertIndex + 1);
      newPointId = newStop.id;
      const points = insertStopInPoints(voicePoints, insertIndex, newStop);
      return { ...setVoicePoints(prev, points), selectedPointId: newStop.id };
    });
    return newPointId;
  }, [commit]);

  const transformToStop = useCallback(
    (pointId: string) => updatePointType(pointId, "stop"),
    [updatePointType],
  );

  const setAsTerminus = useCallback(
    (pointId: string, which: "start" | "end") => {
      updatePointType(pointId, which === "start" ? "terminus_start" : "terminus_end");
    },
    [updatePointType],
  );

  const setActiveVoice = useCallback(
    (voice: LineVoice) => {
      setState((prev) => {
        let next: LineEditorState = {
          ...prev,
          activeVoice: voice,
          selectedPointId: null,
          activeBranchId: null,
          activeOriginLegId: null,
        };
        if (
          voice === "retour" &&
          prev.pointsRetour.length === 0 &&
          prev.pointsAller.length > 0
        ) {
          next = {
            ...next,
            pointsRetour: createRetourPointsFromAller(prev.pointsAller),
          };
        }
        queueMicrotask(() => persistState(next));
        return next;
      });
      setTraceError(null);
    },
    [persistState],
  );

  const addBranchFromHub = useCallback(
    (hubPointId: string) => {
      commit((prev) => {
        const hub = getVoicePoints(prev).find((p) => p.id === hubPointId);
        if (!hub || hub.type !== "hub") return prev;

        const existing = branchesFromHub(getVoiceBranches(prev), hubPointId);
        const branch = createBranchFromHub(hub, existing.length);
        const firstStop = branch.points[0];
        return {
          ...updateVoiceBranches(prev, (branches) => [...branches, branch]),
          activeBranchId: branch.id,
          selectedPointId: firstStop?.id ?? null,
        };
      });
    },
    [commit],
  );

  const deleteBranch = useCallback(
    (branchId: string) => {
      commit((prev) => ({
        ...updateVoiceBranches(prev, (branches) =>
          branches.filter((b) => b.id !== branchId),
        ),
        activeBranchId: prev.activeBranchId === branchId ? null : prev.activeBranchId,
        selectedPointId:
          prev.activeBranchId === branchId ? null : prev.selectedPointId,
      }));
    },
    [commit],
  );

  const setActiveBranch = useCallback((branchId: string | null) => {
    setState((prev) => ({
      ...prev,
      activeBranchId: branchId,
      activeOriginLegId: branchId ? null : prev.activeOriginLegId,
      selectedPointId: null,
    }));
  }, []);

  const setActiveOriginLeg = useCallback((legId: string | null) => {
    setState((prev) => ({
      ...prev,
      activeOriginLegId: legId,
      activeBranchId: legId ? null : prev.activeBranchId,
      selectedPointId: null,
    }));
  }, []);

  const addOriginLegFromHub = useCallback(
    (hubPointId: string) => {
      commit((prev) => {
        const hub = getVoicePoints(prev).find((p) => p.id === hubPointId);
        if (!hub || hub.type !== "hub") return prev;

        const existing = originLegsFromHub(getVoiceOriginLegs(prev), hubPointId);
        const leg = createOriginLegFromHub(hub, existing.length);
        const firstStop = leg.points[0];
        return {
          ...updateVoiceOriginLegs(prev, (legs) => [...legs, leg]),
          activeOriginLegId: leg.id,
          activeBranchId: null,
          selectedPointId: firstStop?.id ?? null,
        };
      });
    },
    [commit],
  );

  const attachStopAsOriginLeg = useCallback(
    (pointId: string, hubPointId: string) => {
      commit((prev) => {
        const trunk = getVoicePoints(prev);
        const point = trunk.find((p) => p.id === pointId);
        const hub = trunk.find((p) => p.id === hubPointId);
        if (!point || !hub || hub.type !== "hub") return prev;

        const existing = originLegsFromHub(getVoiceOriginLegs(prev), hubPointId);
        const leg: LineOriginLeg = {
          id: createOriginLegId(),
          mergePointId: hubPointId,
          label: point.stop?.name?.trim() || `Départ ${existing.length + 1}`,
          points: reorderStopsInPoints([{ ...point, type: "terminus_start" }]),
        };

        const remainingTrunk = reorderStopsInPoints(
          trunk.filter((p) => p.id !== pointId),
        );

        return {
          ...updateVoiceOriginLegs(prev, (legs) => [...legs, leg]),
          ...setVoicePoints(prev, remainingTrunk),
          activeOriginLegId: leg.id,
          activeBranchId: null,
          selectedPointId: point.id,
        };
      });
    },
    [commit],
  );

  const deleteOriginLeg = useCallback(
    (legId: string, reintegrate = true) => {
      commit((prev) => {
        const leg = getVoiceOriginLegs(prev).find((l) => l.id === legId);
        if (!leg) return prev;

        let next = updateVoiceOriginLegs(prev, (legs) =>
          legs.filter((l) => l.id !== legId),
        );

        if (reintegrate && leg.points.length > 0) {
          const trunk = getVoicePoints(next);
          const hubIndex = trunk.findIndex((p) => p.id === leg.mergePointId);
          const insertAt = hubIndex >= 0 ? hubIndex : 0;
          const legPoints = leg.points.filter((p) => isStopType(p.type));
          const newTrunk = [...trunk];
          newTrunk.splice(insertAt, 0, ...legPoints);
          next = setVoicePoints(next, reorderStopsInPoints(newTrunk));
        }

        return {
          ...next,
          activeOriginLegId:
            prev.activeOriginLegId === legId ? null : prev.activeOriginLegId,
          selectedPointId:
            prev.activeOriginLegId === legId ? null : prev.selectedPointId,
        };
      });
    },
    [commit],
  );

  const updateOriginLegMeta = useCallback(
    (legId: string, patch: Partial<Pick<LineOriginLeg, "label">>) => {
      commit((prev) =>
        updateVoiceOriginLegs(prev, (legs) =>
          legs.map((leg) => (leg.id === legId ? { ...leg, ...patch } : leg)),
        ),
      );
    },
    [commit],
  );

  const updateBranchMeta = useCallback(
    (branchId: string, patch: Partial<Pick<LineBranch, "label" | "terminusName">>) => {
      commit((prev) =>
        updateVoiceBranches(prev, (branches) =>
          branches.map((branch) =>
            branch.id === branchId ? { ...branch, ...patch } : branch,
          ),
        ),
      );
    },
    [commit],
  );

  const publishLine = useCallback(() => {
    updateLineMeta({ status: "published" as EditorLineStatus });
  }, [updateLineMeta]);

  const traceItinerary = useCallback(async (): Promise<boolean> => {
    if (activePoints.length < 2) {
      setTraceError("Ajoutez au moins 2 points pour tracer l'itinéraire");
      return false;
    }

    traceAbortRef.current?.abort();
    const controller = new AbortController();
    traceAbortRef.current = controller;

    setTracing(true);
    setTraceError(null);

    try {
      const traced = await tracePointsOnRoads(
        activePoints,
        state.transportMode,
        state.id,
        controller.signal,
      );
      if (controller.signal.aborted) return false;

      commit((prev) => setVoicePoints(prev, traced));
      return true;
    } catch (err) {
      if (controller.signal.aborted) return false;
      setTraceError(
        err instanceof Error
          ? err.message
          : "Impossible de tracer l'itinéraire sur les voies",
      );
      return false;
    } finally {
      if (!controller.signal.aborted) setTracing(false);
    }
  }, [commit, activePoints, state.transportMode, state.id]);

  const traceSegmentTo = useCallback(
    async (fromId: string, toId: string): Promise<boolean> => {
      traceAbortRef.current?.abort();
      const controller = new AbortController();
      traceAbortRef.current = controller;

      setTracing(true);
      setTraceError(null);

      try {
        const traced = await traceSegmentBetween(
          activePoints,
          fromId,
          toId,
          state.transportMode,
          state.id,
          controller.signal,
        );
        if (controller.signal.aborted) return false;

        commit((prev) => ({
          ...setVoicePoints(prev, traced),
          selectedPointId: fromId,
        }));
        return true;
      } catch (err) {
        if (controller.signal.aborted) return false;
        setTraceError(
          err instanceof Error
            ? err.message
            : "Impossible de proposer le tracé sur ce segment",
        );
        return false;
      } finally {
        if (!controller.signal.aborted) setTracing(false);
      }
    },
    [commit, activePoints, state.transportMode, state.id],
  );

  const hasPassagePoints = useMemo(
    () => activePoints.some((p) => p.type === "passage"),
    [activePoints],
  );

  const clearRouteTrace = useCallback(() => {
    commit((prev) => {
      const withoutPassages = (points: RoutePoint[]) =>
        reorderStopsInPoints(points.filter((point) => point.type !== "passage"));

      let points: RoutePoint[];
      let nextState: LineEditorState;

      if (prev.activeOriginLegId) {
        const activeLeg = getVoiceOriginLegs(prev).find(
          (leg) => leg.id === prev.activeOriginLegId,
        );
        points = withoutPassages(activeLeg?.points ?? []);
        nextState = updateVoiceOriginLegs(prev, (legs) =>
          legs.map((leg) =>
            leg.id === prev.activeOriginLegId ? { ...leg, points } : leg,
          ),
        );
      } else if (prev.activeBranchId) {
        const activeBranch = getVoiceBranches(prev).find(
          (branch) => branch.id === prev.activeBranchId,
        );
        points = withoutPassages(activeBranch?.points ?? []);
        nextState = updateVoiceBranches(prev, (branches) =>
          branches.map((branch) =>
            branch.id === prev.activeBranchId ? { ...branch, points } : branch,
          ),
        );
      } else {
        points = withoutPassages(getVoicePoints(prev));
        nextState = setVoicePoints(prev, points);
      }

      const selectedPointId =
        prev.selectedPointId &&
        points.some((p) => p.id === prev.selectedPointId)
          ? prev.selectedPointId
          : (points[points.length - 1]?.id ?? null);
      return { ...nextState, selectedPointId };
    });
    setTraceError(null);
  }, [commit]);

  const selectedPoint = useMemo(() => {
    const located = state.selectedPointId
      ? findPointInEditor(state, state.selectedPointId)
      : null;
    return located?.point ?? null;
  }, [state]);

  const stops = useMemo(() => {
    if (state.activeOriginLegId || state.activeBranchId) {
      return activePoints.filter((p) => isStopType(p.type));
    }
    return trunkPoints.filter((p) => isStopType(p.type));
  }, [state.activeOriginLegId, state.activeBranchId, activePoints, trunkPoints]);

  const trunkStops = useMemo(
    () => trunkPoints.filter((p) => isStopType(p.type)),
    [trunkPoints],
  );

  const passagePoints = useMemo(
    () => activePoints.filter((p) => p.type === "passage"),
    [activePoints],
  );

  const stats = useMemo(() => {
    const branchStops = allBranchStops(activeBranches);
    const originStops = allOriginLegStops(activeOriginLegs);
    const allStops = [
      ...trunkPoints.filter((p) => isStopType(p.type)),
      ...branchStops,
      ...originStops,
    ];
    const combinedPoints = [
      ...trunkPoints,
      ...activeBranches.flatMap((b) => b.points),
      ...activeOriginLegs.flatMap((l) => l.points),
    ];
    return {
      distanceKm: segmentDistanceKm(combinedPoints),
      stopCount: allStops.length,
      travelMinutes:
        estimatedTravelMinutes(trunkPoints) +
        activeBranches.reduce((sum, b) => sum + estimatedTravelMinutes(b.points), 0) +
        activeOriginLegs.reduce((sum, l) => sum + estimatedTravelMinutes(l.points), 0),
    };
  }, [trunkPoints, activeBranches, activeOriginLegs]);

  const resetEditor = useCallback((next?: LineEditorState) => {
    historyRef.current = [];
    futureRef.current = [];
    setHistoryAvailability({ canUndo: false, canRedo: false });
    setState(normalizeLineEditorState(next ?? createDemoLineEditorState()));
  }, []);

  return {
    state,
    activePoints,
    trunkPoints,
    trunkStops,
    activeBranches,
    activeOriginLegs,
    inactivePoints,
    selectedPoint,
    stops,
    passagePoints,
    stats,
    tracing,
    traceError,
    lastSavedAt,
    saveStatus,
    saveError,
    hasPassagePoints,
    canUndo: historyAvailability.canUndo,
    canRedo: historyAvailability.canRedo,
    undo,
    redo,
    addPoint,
    insertPointAtSegment,
    commitPointMove,
    deletePoint,
    selectPoint,
    updatePointType,
    updateStopDetails,
    updatePassageDetails,
    updateLineMeta,
    reorderStops,
    addStopAt,
    addStopAfterSelected,
    transformToStop,
    setAsTerminus,
    setActiveVoice,
    addBranchFromHub,
    deleteBranch,
    setActiveBranch,
    updateBranchMeta,
    addOriginLegFromHub,
    attachStopAsOriginLeg,
    deleteOriginLeg,
    setActiveOriginLeg,
    updateOriginLegMeta,
    publishLine,
    traceItinerary,
    traceSegmentTo,
    clearRouteTrace,
    resetEditor,
  };
}

export type LineEditorActions = ReturnType<typeof useLineEditor>;
