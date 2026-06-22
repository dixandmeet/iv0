import type {
  LineBranch,
  LineEditorState,
  LineOriginLeg,
  LineVoice,
  RoutePoint,
} from "@/lib/line-editor-types";
import { createRoutePoint, isStopType } from "@/lib/line-editor-utils";

export function createBranchId(): string {
  return `br-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
}

export function createOriginLegId(): string {
  return `ol-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
}

export function getVoiceBranches(
  state: Pick<LineEditorState, "activeVoice" | "branchesAller" | "branchesRetour">,
  voice?: LineVoice,
): LineBranch[] {
  return (voice ?? state.activeVoice) === "aller"
    ? state.branchesAller
    : state.branchesRetour;
}

export function getVoiceOriginLegs(
  state: Pick<LineEditorState, "activeVoice" | "originLegsAller" | "originLegsRetour">,
  voice?: LineVoice,
): LineOriginLeg[] {
  return (voice ?? state.activeVoice) === "aller"
    ? state.originLegsAller
    : state.originLegsRetour;
}

export function setVoiceBranches(
  state: LineEditorState,
  branches: LineBranch[],
  voice?: LineVoice,
): LineEditorState {
  const target = voice ?? state.activeVoice;
  return target === "aller"
    ? { ...state, branchesAller: branches }
    : { ...state, branchesRetour: branches };
}

export function setVoiceOriginLegs(
  state: LineEditorState,
  legs: LineOriginLeg[],
  voice?: LineVoice,
): LineEditorState {
  const target = voice ?? state.activeVoice;
  return target === "aller"
    ? { ...state, originLegsAller: legs }
    : { ...state, originLegsRetour: legs };
}

export function updateVoiceBranches(
  state: LineEditorState,
  updater: (branches: LineBranch[]) => LineBranch[],
  voice?: LineVoice,
): LineEditorState {
  return setVoiceBranches(state, updater(getVoiceBranches(state, voice)), voice);
}

export function updateVoiceOriginLegs(
  state: LineEditorState,
  updater: (legs: LineOriginLeg[]) => LineOriginLeg[],
  voice?: LineVoice,
): LineEditorState {
  return setVoiceOriginLegs(state, updater(getVoiceOriginLegs(state, voice)), voice);
}

export function findBranch(
  state: LineEditorState,
  branchId: string,
  voice?: LineVoice,
): LineBranch | null {
  return getVoiceBranches(state, voice).find((b) => b.id === branchId) ?? null;
}

export function findOriginLeg(
  state: LineEditorState,
  legId: string,
  voice?: LineVoice,
): LineOriginLeg | null {
  return getVoiceOriginLegs(state, voice).find((l) => l.id === legId) ?? null;
}

export function branchesFromHub(
  branches: LineBranch[],
  forkPointId: string,
): LineBranch[] {
  return branches.filter((b) => b.forkPointId === forkPointId);
}

export function originLegsFromHub(
  legs: LineOriginLeg[],
  mergePointId: string,
): LineOriginLeg[] {
  return legs.filter((l) => l.mergePointId === mergePointId);
}

export function createBranchFromHub(
  hubPoint: RoutePoint,
  branchIndex: number,
): LineBranch {
  const [lng, lat] = hubPoint.coordinates;
  const offset: [number, number] = [lng + 0.008 * (branchIndex + 1), lat - 0.006];
  const terminus = createRoutePoint(offset, "terminus_end", 1);
  if (terminus.stop) {
    terminus.stop.name = "Nouveau terminus";
    terminus.stop.travelTimeMinutes = 4;
  }

  return {
    id: createBranchId(),
    forkPointId: hubPoint.id,
    label: `Branche ${branchIndex + 1}`,
    terminusName: terminus.stop?.name ?? "Nouveau terminus",
    points: [terminus],
  };
}

export function createOriginLegFromHub(
  hubPoint: RoutePoint,
  legIndex: number,
): LineOriginLeg {
  const [lng, lat] = hubPoint.coordinates;
  const offset: [number, number] = [lng - 0.01 * (legIndex + 1), lat + 0.006 * (legIndex + 1)];
  const terminus = createRoutePoint(offset, "terminus_start", 1);
  if (terminus.stop) {
    terminus.stop.name = `Départ ${legIndex + 1}`;
    terminus.stop.travelTimeMinutes = 3;
  }

  return {
    id: createOriginLegId(),
    mergePointId: hubPoint.id,
    label: `Départ ${legIndex + 1}`,
    points: [terminus],
  };
}

export function collectTerminiLabels(
  points: RoutePoint[],
  branches: LineBranch[],
  originLegs: LineOriginLeg[] = [],
): {
  starts: string[];
  ends: string[];
} {
  const starts: string[] = [];
  const ends: string[] = [];

  for (const point of points) {
    const name = point.stop?.name?.trim();
    if (!name) continue;
    if (point.type === "terminus_start") starts.push(name);
    if (point.type === "terminus_end") ends.push(name);
  }

  for (const leg of originLegs) {
    const first = leg.points[0];
    const name = leg.label.trim() || first?.stop?.name?.trim();
    if (name && !starts.includes(name)) starts.push(name);
  }

  for (const branch of branches) {
    const last = branch.points[branch.points.length - 1];
    const name =
      branch.terminusName.trim() ||
      last?.stop?.name?.trim() ||
      branch.label.trim();
    if (name && !ends.includes(name)) ends.push(name);
  }

  return { starts, ends };
}

export function findPointInEditor(
  state: LineEditorState,
  pointId: string,
): { point: RoutePoint; branchId: string | null; originLegId: string | null } | null {
  const trunk = state.activeVoice === "aller" ? state.pointsAller : state.pointsRetour;
  const trunkPoint = trunk.find((p) => p.id === pointId);
  if (trunkPoint) return { point: trunkPoint, branchId: null, originLegId: null };

  for (const branch of getVoiceBranches(state)) {
    const point = branch.points.find((p) => p.id === pointId);
    if (point) return { point, branchId: branch.id, originLegId: null };
  }

  for (const leg of getVoiceOriginLegs(state)) {
    const point = leg.points.find((p) => p.id === pointId);
    if (point) return { point, branchId: null, originLegId: leg.id };
  }

  return null;
}

export interface EditorPlanNode {
  point: RoutePoint;
  column: number;
  lane: number;
  branchId: string | null;
  originLegId: string | null;
}

export interface EditorPlanEdge {
  fromId: string;
  toId: string;
  branchId: string | null;
  originLegId: string | null;
  fromLane: number;
  toLane: number;
  fromColumn: number;
  toColumn: number;
}

export function layoutEditorPlan(
  trunkStops: RoutePoint[],
  branches: LineBranch[],
  originLegs: LineOriginLeg[] = [],
): {
  nodes: EditorPlanNode[];
  edges: EditorPlanEdge[];
  laneCount: number;
  columnCount: number;
  hubColumnById: Map<string, number>;
} {
  const nodes: EditorPlanNode[] = [];
  const edges: EditorPlanEdge[] = [];
  const hubColumnById = new Map<string, number>();

  trunkStops.forEach((point, index) => {
    if (point.type === "hub") {
      hubColumnById.set(point.id, index);
    }
    nodes.push({
      point,
      column: index,
      lane: 0,
      branchId: null,
      originLegId: null,
    });
  });

  let nextLane = 1;

  for (const leg of originLegs) {
    const mergeColumn = hubColumnById.get(leg.mergePointId);
    if (mergeColumn == null) continue;

    const lane = nextLane;
    nextLane += 1;
    const legStops = leg.points.filter((p) => isStopType(p.type));
    if (legStops.length === 0) continue;

    legStops.forEach((point, i) => {
      const column = mergeColumn - (legStops.length - i);
      nodes.push({
        point,
        column,
        lane,
        branchId: null,
        originLegId: leg.id,
      });
    });

    const hubStop = trunkStops[mergeColumn];
    const lastOrigin = legStops[legStops.length - 1];
    const lastCol = mergeColumn - 1;

    edges.push({
      fromId: lastOrigin.id,
      toId: hubStop.id,
      branchId: null,
      originLegId: leg.id,
      fromLane: lane,
      toLane: 0,
      fromColumn: lastCol,
      toColumn: mergeColumn,
    });

    for (let i = 0; i < legStops.length - 1; i++) {
      edges.push({
        fromId: legStops[i].id,
        toId: legStops[i + 1].id,
        branchId: null,
        originLegId: leg.id,
        fromLane: lane,
        toLane: lane,
        fromColumn: mergeColumn - (legStops.length - i),
        toColumn: mergeColumn - (legStops.length - i - 1),
      });
    }
  }

  for (const branch of branches) {
    const forkColumn = hubColumnById.get(branch.forkPointId);
    if (forkColumn == null || forkColumn < 0) continue;

    const lane = nextLane;
    nextLane += 1;

    branch.points.forEach((point, i) => {
      nodes.push({
        point,
        column: forkColumn + i + 1,
        lane,
        branchId: branch.id,
        originLegId: null,
      });
    });

    const forkStop = trunkStops[forkColumn];
    if (branch.points.length > 0) {
      edges.push({
        fromId: forkStop.id,
        toId: branch.points[0].id,
        branchId: branch.id,
        originLegId: null,
        fromLane: 0,
        toLane: lane,
        fromColumn: forkColumn,
        toColumn: forkColumn + 1,
      });
    }

    for (let i = 0; i < branch.points.length - 1; i++) {
      edges.push({
        fromId: branch.points[i].id,
        toId: branch.points[i + 1].id,
        branchId: branch.id,
        originLegId: null,
        fromLane: lane,
        toLane: lane,
        fromColumn: forkColumn + i + 1,
        toColumn: forkColumn + i + 2,
      });
    }
  }

  for (let i = 0; i < trunkStops.length - 1; i++) {
    edges.push({
      fromId: trunkStops[i].id,
      toId: trunkStops[i + 1].id,
      branchId: null,
      originLegId: null,
      fromLane: 0,
      toLane: 0,
      fromColumn: i,
      toColumn: i + 1,
    });
  }

  const columnCount =
    nodes.reduce((max, n) => Math.max(max, n.column + 1), 0) -
    Math.min(0, nodes.reduce((min, n) => Math.min(min, n.column), 0));
  const laneCount = nodes.reduce((max, n) => Math.max(max, n.lane + 1), 0);

  return { nodes, edges, laneCount, columnCount, hubColumnById };
}

export function allBranchStops(branches: LineBranch[]): RoutePoint[] {
  return branches.flatMap((b) => b.points.filter((p) => isStopType(p.type)));
}

export function allOriginLegStops(legs: LineOriginLeg[]): RoutePoint[] {
  return legs.flatMap((l) => l.points.filter((p) => isStopType(p.type)));
}

function setVoicePointsInternal(
  state: LineEditorState,
  points: RoutePoint[],
  voice: LineVoice,
): LineEditorState {
  return voice === "aller"
    ? { ...state, pointsAller: points }
    : { ...state, pointsRetour: points };
}

/** Déplace les terminus départ linéaires précédant un hub vers des origin legs. */
export function migrateLinearOriginsToLegs(
  state: LineEditorState,
  hubPointId: string,
  voice?: LineVoice,
): LineEditorState {
  const v = voice ?? state.activeVoice;
  const trunk = v === "aller" ? state.pointsAller : state.pointsRetour;
  const hubIndex = trunk.findIndex((p) => p.id === hubPointId);
  if (hubIndex <= 0) return state;

  const preceding = trunk.slice(0, hubIndex).filter((p) => isStopType(p.type));
  if (preceding.length === 0) return state;

  const existingLegs = getVoiceOriginLegs(state, v);
  const newLegs: LineOriginLeg[] = preceding.map((point, i) => ({
    id: createOriginLegId(),
    mergePointId: hubPointId,
    label: point.stop?.name?.trim() || `Départ ${i + 1}`,
    points: [{ ...point, type: "terminus_start" as const }],
  }));

  const remainingTrunk = trunk.filter((p) => !preceding.some((o) => o.id === p.id));
  let next = setVoicePointsInternal(state, remainingTrunk, v);
  next = setVoiceOriginLegs(next, [...existingLegs, ...newLegs], v);
  return next;
}

export function hasComplexTopology(
  branches: LineBranch[],
  originLegs: LineOriginLeg[],
): boolean {
  return branches.length > 0 || originLegs.length > 0;
}

export function hubsOnTrunk(trunkStops: RoutePoint[]): RoutePoint[] {
  return trunkStops.filter((s) => s.type === "hub");
}
