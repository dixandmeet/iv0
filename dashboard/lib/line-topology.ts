import type { RouteTimelinePoint } from "@/lib/regulation-data";
import type {
  LineEditorState,
  LineVoice,
  RoutePoint,
} from "@/lib/line-editor-types";

/** Rôle d'un nœud dans la topologie de ligne. */
export type TopologyNodeRole = "terminus" | "hub" | "stop";

/** Type de variante GTFS (service complet, partiel ou branche). */
export type VariantKind = "full" | "partial" | "branch";

export interface LineVariant {
  /** Identifiant stable (signature de séquence d'arrêts). */
  id: string;
  tripId: string;
  /** Toutes les courses GTFS regroupées dans ce parcours, aller et retour inclus. */
  tripIds?: string[];
  headsign: string;
  directionId: number;
  origin: string;
  destination: string;
  label: string;
  kind: VariantKind;
  stopIds: string[];
  stops: RouteTimelinePoint[];
}

export interface TopologyNode {
  id: string;
  stopId: string;
  stationId?: string;
  name: string;
  coordinates: [number, number];
  theoreticalTime: string;
  role: TopologyNodeRole;
  /** Position horizontale (tronçon commun = même colonne). */
  column: number;
  /** Voie verticale : 0 = tronc principal, >0 = débranchements. */
  lane: number;
  /** Terminus desservis par ce nœud (plusieurs si hub). */
  terminusFor: string[];
}

export interface TopologyEdge {
  fromId: string;
  toId: string;
  variantIds: string[];
  /** Emprunté par toutes les variantes actives. */
  isCommon: boolean;
  fromColumn: number;
  fromLane: number;
  toColumn: number;
  toLane: number;
}

export interface LineTopology {
  nodes: TopologyNode[];
  edges: TopologyEdge[];
  variants: LineVariant[];
  /** Variante la plus longue (référence d'affichage). */
  mainVariantId: string;
  columnCount: number;
  laneCount: number;
  /** Vrai si plusieurs terminus ou débranchements. */
  isComplex: boolean;
}

export interface TripStopSequence {
  tripId: string;
  headsign: string;
  directionId: number;
  shapeId: string | null;
  stopIds: string[];
  stops: RouteTimelinePoint[];
}

function sequenceKey(stopIds: string[]): string {
  return stopIds.join(">");
}

function bidirectionalSequenceKey(stopIds: string[]): string {
  const forward = sequenceKey(stopIds);
  const backward = sequenceKey([...stopIds].reverse());
  return forward.localeCompare(backward) <= 0 ? forward : backward;
}

function physicalStopIds(trip: TripStopSequence): string[] {
  return trip.stopIds.map((stopId, index) => {
    const stationId = trip.stops[index]?.stationId?.trim();
    return stationId ? `station:${stationId}` : stopId;
  });
}

function isPrefixOf(shorter: string[], longer: string[]): boolean {
  if (shorter.length > longer.length) return false;
  return shorter.every((id, i) => id === longer[i]);
}

function isSuffixOf(shorter: string[], longer: string[]): boolean {
  if (shorter.length > longer.length) return false;
  const offset = longer.length - shorter.length;
  return shorter.every((id, i) => id === longer[offset + i]);
}

function isContiguousPartOf(shorter: string[], longer: string[]): boolean {
  if (shorter.length > longer.length) return false;
  const limit = longer.length - shorter.length;
  for (let start = 0; start <= limit; start++) {
    if (shorter.every((id, index) => id === longer[start + index])) return true;
  }
  return false;
}

interface CommonBlock {
  variantStart: number;
  mainStart: number;
  length: number;
}

/** Plus long tronçon contigu partagé, même lorsqu'une ligne bifurque aux deux extrémités. */
function longestCommonBlock(variant: string[], main: string[]): CommonBlock {
  let best: CommonBlock = { variantStart: 0, mainStart: 0, length: 0 };

  for (let variantStart = 0; variantStart < variant.length; variantStart++) {
    for (let mainStart = 0; mainStart < main.length; mainStart++) {
      let length = 0;
      while (
        variantStart + length < variant.length &&
        mainStart + length < main.length &&
        variant[variantStart + length] === main[mainStart + length]
      ) {
        length += 1;
      }
      if (length > best.length) {
        best = { variantStart, mainStart, length };
      }
    }
  }

  return best;
}

function orientVariantToMain(
  variant: LineVariant,
  mainStopIds: string[],
): LineVariant {
  const forward = longestCommonBlock(variant.stopIds, mainStopIds);
  const reversedStopIds = [...variant.stopIds].reverse();
  const backward = longestCommonBlock(reversedStopIds, mainStopIds);
  const shouldReverse =
    backward.length > forward.length ||
    (backward.length === forward.length &&
      backward.length > 0 &&
      backward.variantStart < forward.variantStart);

  if (!shouldReverse) return variant;
  return {
    ...variant,
    origin: variant.destination,
    destination: variant.origin,
    stopIds: reversedStopIds,
    stops: [...variant.stops].reverse(),
  };
}

function classifyVariant(
  variant: Omit<LineVariant, "kind">,
  mainStopIds: string[],
): VariantKind {
  const reversedMain = [...mainStopIds].reverse();
  if (
    sequenceKey(variant.stopIds) === sequenceKey(mainStopIds) ||
    sequenceKey(variant.stopIds) === sequenceKey(reversedMain)
  ) {
    return "full";
  }
  if (
    isPrefixOf(variant.stopIds, mainStopIds) ||
    isSuffixOf(variant.stopIds, mainStopIds) ||
    isPrefixOf(variant.stopIds, reversedMain) ||
    isSuffixOf(variant.stopIds, reversedMain) ||
    isContiguousPartOf(variant.stopIds, mainStopIds) ||
    isContiguousPartOf(variant.stopIds, reversedMain)
  ) {
    return "partial";
  }
  return "branch";
}

function buildVariantLabel(origin: string, destination: string, headsign: string): string {
  if (origin && destination && origin !== destination) {
    return `${origin} ↔ ${destination}`;
  }
  if (headsign.trim()) return headsign.trim();
  return origin || destination || "Variante";
}

export function buildVariantsFromTrips(trips: TripStopSequence[]): LineVariant[] {
  const bySequence = new Map<string, LineVariant>();

  for (const trip of trips) {
    if (trip.stopIds.length < 2) continue;
    const stopIds = physicalStopIds(trip);
    const key = bidirectionalSequenceKey(stopIds);
    const existing = bySequence.get(key);
    if (existing) {
      if (!existing.tripIds?.includes(trip.tripId)) {
        existing.tripIds = [...(existing.tripIds ?? [existing.tripId]), trip.tripId];
      }
      continue;
    }

    const origin = trip.stops[0]?.name ?? "—";
    const destination = trip.stops[trip.stops.length - 1]?.name ?? "—";

    bySequence.set(key, {
      id: key,
      tripId: trip.tripId,
      tripIds: [trip.tripId],
      headsign: trip.headsign || destination,
      directionId: trip.directionId,
      origin,
      destination,
      label: buildVariantLabel(origin, destination, trip.headsign),
      kind: "full",
      stopIds,
      stops: trip.stops,
    });
  }

  const variants = [...bySequence.values()];
  if (variants.length === 0) return [];

  const main = variants.reduce((a, b) =>
    a.stopIds.length >= b.stopIds.length ? a : b,
  );

  return variants.map((v) => ({
    ...v,
    kind: classifyVariant(v, main.stopIds),
  }));
}

export function layoutLineTopology(variants: LineVariant[]): LineTopology | null {
  if (variants.length === 0) return null;

  const selectedMain = variants.reduce((a, b) =>
    a.stopIds.length >= b.stopIds.length ? a : b,
  );
  const orientedVariants = variants.map((variant) =>
    variant.id === selectedMain.id
      ? variant
      : orientVariantToMain(variant, selectedMain.stopIds),
  );
  const main =
    orientedVariants.find((variant) => variant.id === selectedMain.id) ??
    selectedMain;

  const nodeById = new Map<string, TopologyNode>();
  const edgeMap = new Map<string, TopologyEdge>();
  let nextLane = 1;

  const ensureNode = (
    stopId: string,
    stop: RouteTimelinePoint,
    column: number,
    lane: number,
  ): TopologyNode => {
    const existing = nodeById.get(stopId);
    if (existing) {
      if (lane !== existing.lane && existing.lane === 0) {
        existing.role = "hub";
      }
      if (column > existing.column) existing.column = column;
      return existing;
    }

    const node: TopologyNode = {
      id: stopId,
      stopId,
      stationId: stop.stationId,
      name: stop.name,
      coordinates: stop.coordinates,
      theoreticalTime: stop.theoreticalTime,
      role: "stop",
      column,
      lane,
      terminusFor: [],
    };
    nodeById.set(stopId, node);
    return node;
  };

  const addEdge = (fromId: string, toId: string, variantId: string) => {
    const key = `${fromId}>${toId}`;
    const from = nodeById.get(fromId);
    const to = nodeById.get(toId);
    if (!from || !to) return;

    const existing = edgeMap.get(key);
    if (existing) {
      if (!existing.variantIds.includes(variantId)) {
        existing.variantIds.push(variantId);
      }
      return;
    }

    edgeMap.set(key, {
      fromId,
      toId,
      variantIds: [variantId],
      isCommon: false,
      fromColumn: from.column,
      fromLane: from.lane,
      toColumn: to.column,
      toLane: to.lane,
    });
  };

  // Tronc principal (lane 0)
  main.stopIds.forEach((stopId, column) => {
    const stop = main.stops.find((s) => s.stopId === stopId) ?? main.stops[column];
    if (!stop) return;
    ensureNode(stopId, stop, column, 0);
  });

  for (let i = 0; i < main.stopIds.length - 1; i++) {
    addEdge(main.stopIds[i], main.stopIds[i + 1], main.id);
  }

  // Variantes secondaires
  for (const variant of orientedVariants) {
    if (variant.id === main.id) continue;

    const common = longestCommonBlock(variant.stopIds, main.stopIds);
    const divergesFromMain = variant.kind === "branch";

    if (!divergesFromMain) {
      for (let i = 0; i < variant.stopIds.length; i++) {
        const stopId = variant.stopIds[i];
        const stop = variant.stops.find((s) => s.stopId === stopId) ?? variant.stops[i];
        if (!stop) continue;
        ensureNode(stopId, stop, common.mainStart + i, 0);
      }
      for (let i = 0; i < variant.stopIds.length - 1; i++) {
        addEdge(variant.stopIds[i], variant.stopIds[i + 1], variant.id);
      }
      continue;
    }

    const lane = nextLane;
    nextLane += 1;

    if (common.length > 0) {
      for (let i = 0; i < common.variantStart; i++) {
        const stopId = variant.stopIds[i];
        const stop = variant.stops.find((s) => s.stopId === stopId) ?? variant.stops[i];
        if (!stop) continue;
        const column = Math.max(0, common.mainStart - common.variantStart + i);
        ensureNode(stopId, stop, column, lane);
      }

      const suffixStart = common.variantStart + common.length;
      const mainSuffixColumn = common.mainStart + common.length;
      for (let i = suffixStart; i < variant.stopIds.length; i++) {
        const stopId = variant.stopIds[i];
        const stop = variant.stops.find((s) => s.stopId === stopId) ?? variant.stops[i];
        if (!stop) continue;
        ensureNode(stopId, stop, mainSuffixColumn + (i - suffixStart), lane);
      }

      if (common.variantStart > 0) {
        const junction = nodeById.get(variant.stopIds[common.variantStart]);
        if (junction) junction.role = "hub";
      }
      if (suffixStart < variant.stopIds.length) {
        const junction = nodeById.get(variant.stopIds[suffixStart - 1]);
        if (junction) junction.role = "hub";
      }
    } else {
      for (let i = 0; i < variant.stopIds.length; i++) {
        const stopId = variant.stopIds[i];
        const stop = variant.stops.find((s) => s.stopId === stopId) ?? variant.stops[i];
        if (!stop) continue;
        ensureNode(stopId, stop, i, lane);
      }
    }

    for (let i = 0; i < variant.stopIds.length - 1; i++) {
      addEdge(variant.stopIds[i], variant.stopIds[i + 1], variant.id);
    }
  }

  // Terminus et rôles
  const terminusIds = new Set<string>();
  for (const variant of orientedVariants) {
    if (variant.stopIds.length === 0) continue;
    terminusIds.add(variant.stopIds[0]);
    terminusIds.add(variant.stopIds[variant.stopIds.length - 1]);
  }

  for (const variant of orientedVariants) {
    const first = variant.stopIds[0];
    const last = variant.stopIds[variant.stopIds.length - 1];
    const firstNode = nodeById.get(first);
    const lastNode = nodeById.get(last);
    if (firstNode && !firstNode.terminusFor.includes(variant.origin)) {
      firstNode.terminusFor.push(variant.origin);
    }
    if (lastNode && !lastNode.terminusFor.includes(variant.destination)) {
      lastNode.terminusFor.push(variant.destination);
    }
  }

  for (const node of nodeById.values()) {
    if (terminusIds.has(node.id)) {
      node.role = node.role === "hub" ? "hub" : "terminus";
    }
  }

  const allVariantIds = orientedVariants.map((v) => v.id);
  for (const edge of edgeMap.values()) {
    edge.isCommon = allVariantIds.every((id) => edge.variantIds.includes(id));
  }

  const nodes = [...nodeById.values()].sort((a, b) =>
    a.lane !== b.lane ? a.lane - b.lane : a.column - b.column,
  );

  const columnCount = nodes.reduce((max, n) => Math.max(max, n.column + 1), 0);
  const laneCount = nodes.reduce((max, n) => Math.max(max, n.lane + 1), 0);

  const uniqueTermini = new Set<string>();
  for (const v of orientedVariants) {
    uniqueTermini.add(v.origin);
    uniqueTermini.add(v.destination);
  }

  const hasBranch = orientedVariants.some((v) => v.kind === "branch");
  const hasMultipleVariants = orientedVariants.length > 1;
  const isComplex = hasBranch || (hasMultipleVariants && uniqueTermini.size > 2);

  return {
    nodes,
    edges: [...edgeMap.values()],
    variants: orientedVariants,
    mainVariantId: main.id,
    columnCount,
    laneCount,
    isComplex,
  };
}

export function buildLineTopologyFromTrips(trips: TripStopSequence[]): LineTopology | null {
  const variants = buildVariantsFromTrips(trips);
  if (variants.length === 0) return null;
  return layoutLineTopology(variants);
}

function normalizedEditorStopId(point: RoutePoint): string {
  const name = point.stop?.name
    .trim()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("fr")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
  if (name) return `editor-name:${name}`;

  const code = point.stop?.code.trim().toLocaleUpperCase("fr");
  return code ? `editor-code:${code}` : `editor-point:${point.id}`;
}

function editorStops(points: RoutePoint[]): RouteTimelinePoint[] {
  return points
    .filter((point) => point.type !== "passage" && point.stop)
    .map((point, index) => {
      return {
        stopId: normalizedEditorStopId(point),
        name: point.stop?.name.trim() || `Arrêt ${index + 1}`,
        coordinates: [...point.coordinates] as [number, number],
        theoreticalTime: "—",
      };
    });
}

function editorVoiceSequences(
  state: LineEditorState,
  voice: LineVoice,
): TripStopSequence[] {
  const trunk = voice === "aller" ? state.pointsAller : state.pointsRetour;
  const branches = voice === "aller" ? state.branchesAller : state.branchesRetour;
  const originLegs = voice === "aller" ? state.originLegsAller : state.originLegsRetour;
  const candidates: Array<{ id: string; points: RoutePoint[] }> = [
    { id: "trunk", points: trunk },
  ];

  for (const branch of branches) {
    const forkIndex = trunk.findIndex((point) => point.id === branch.forkPointId);
    if (forkIndex < 0) continue;
    candidates.push({
      id: `branch-${branch.id}`,
      points: [...trunk.slice(0, forkIndex + 1), ...branch.points],
    });
  }

  for (const leg of originLegs) {
    const mergeIndex = trunk.findIndex((point) => point.id === leg.mergePointId);
    if (mergeIndex < 0) continue;
    candidates.push({
      id: `origin-${leg.id}`,
      points: [...leg.points, ...trunk.slice(mergeIndex)],
    });
  }

  return candidates.flatMap((candidate) => {
    const stops = editorStops(candidate.points);
    if (stops.length < 2) return [];
    return [{
      tripId: `editor-${voice}-${candidate.id}`,
      headsign: stops[stops.length - 1].name,
      directionId: voice === "aller" ? 0 : 1,
      shapeId: null,
      stopIds: stops.map((stop) => stop.stopId),
      stops,
    }];
  });
}

/** Construit le plan opérationnel depuis la topologie explicitement enregistrée dans l’éditeur. */
export function buildLineTopologyFromEditorState(
  state: LineEditorState,
): LineTopology | null {
  return buildLineTopologyFromTrips([
    ...editorVoiceSequences(state, "aller"),
    ...editorVoiceSequences(state, "retour"),
  ]);
}

export function variantForTripId(
  topology: LineTopology,
  tripId: string | null | undefined,
): LineVariant | null {
  if (!tripId) return null;
  return (
    topology.variants.find(
      (variant) =>
        variant.tripId === tripId || variant.tripIds?.includes(tripId),
    ) ?? null
  );
}

export function resolveActiveVariant(
  topology: LineTopology,
  preferredVariantId?: string | null,
  preferredTripId?: string | null,
): LineVariant {
  if (preferredVariantId) {
    const found = topology.variants.find((v) => v.id === preferredVariantId);
    if (found) return found;
  }
  if (preferredTripId) {
    const fromTrip = variantForTripId(topology, preferredTripId);
    if (fromTrip) return fromTrip;
  }
  return (
    topology.variants.find((v) => v.id === topology.mainVariantId) ??
    topology.variants[0]
  );
}

export function stopsForVariant(variant: LineVariant): RouteTimelinePoint[] {
  return variant.stops.map((stop, index, arr) => ({
    ...stop,
    isTerminus: index === 0 || index === arr.length - 1,
  }));
}

export function topologyMinWidth(columnCount: number, stopColumnPx = 72): number {
  return 72 + columnCount * stopColumnPx;
}

/**
 * Réduit uniformément les colonnes pour que toute la topologie tienne dans la
 * largeur disponible. La largeur préférée est conservée sur les lignes courtes.
 */
export function fitTopologyColumnWidth(
  columnCount: number,
  availableWidth: number,
  preferredWidth = 72,
  leadingColumnWidth = 72,
): number {
  if (columnCount <= 0 || availableWidth <= leadingColumnWidth) {
    return preferredWidth;
  }

  return Math.min(
    preferredWidth,
    Math.max(1, (availableWidth - leadingColumnWidth) / columnCount),
  );
}

/** Position d'un véhicule sur le plan (colonne + voie + % le long du segment). */
export function vehicleLayoutPosition(
  topology: LineTopology,
  variant: LineVariant,
  segmentIndex: number,
  segmentProgress: number,
): { column: number; lane: number; alongPercent: number } | null {
  if (variant.stopIds.length < 2) return null;

  const fromId = variant.stopIds[Math.min(segmentIndex, variant.stopIds.length - 2)];
  const toId = variant.stopIds[Math.min(segmentIndex + 1, variant.stopIds.length - 1)];
  const fromNode = topology.nodes.find((n) => n.id === fromId);
  const toNode = topology.nodes.find((n) => n.id === toId);
  if (!fromNode || !toNode) return null;

  const columnSpan = toNode.column - fromNode.column;
  const column = fromNode.column + segmentProgress * Math.max(columnSpan, 1);

  return {
    column,
    lane: fromNode.lane,
    alongPercent: segmentProgress * 100,
  };
}

/** Nœuds visibles pour une variante (inclut le tronc commun). */
export function nodesForVariant(topology: LineTopology, variantId: string): Set<string> {
  const variant = topology.variants.find((v) => v.id === variantId);
  if (!variant) return new Set(topology.nodes.map((n) => n.id));
  return new Set(variant.stopIds);
}

/** Exemple de topologie pour tests / démo (ligne C6). */
export function demoBranchingTopology(): LineTopology {
  const mk = (
    id: string,
    name: string,
    col: number,
    lane: number,
    time: string,
  ): RouteTimelinePoint => ({
    stopId: id,
    name,
    coordinates: [col * 0.01, lane * 0.01],
    theoreticalTime: time,
  });

  const hermeland = mk("h", "Hermeland", 0, 0, "08:00");
  const common1 = mk("c1", "Château", 1, 0, "08:05");
  const common2 = mk("c2", "Trentemoult", 2, 0, "08:12");
  const junction = mk("j", "Pont Rousseau", 3, 0, "08:18");
  const chanterie = mk("ch", "Chantrerie", 4, 0, "08:28");
  const ecole = mk("ec", "École Centrale", 4, 1, "08:26");

  const variantMain: LineVariant = {
    id: "h>j>ch",
    tripId: "demo-c6-ch",
    headsign: "Chantrerie",
    directionId: 0,
    origin: "Hermeland",
    destination: "Chantrerie",
    label: "Hermeland ↔ Chantrerie",
    kind: "branch",
    stopIds: ["h", "c1", "c2", "j", "ch"],
    stops: [hermeland, common1, common2, junction, chanterie],
  };

  const variantBranch: LineVariant = {
    id: "h>j>ec",
    tripId: "demo-c6-ec",
    headsign: "École Centrale",
    directionId: 0,
    origin: "Hermeland",
    destination: "École Centrale",
    label: "Hermeland ↔ École Centrale",
    kind: "branch",
    stopIds: ["h", "c1", "c2", "j", "ec"],
    stops: [hermeland, common1, common2, junction, ecole],
  };

  return layoutLineTopology([variantMain, variantBranch])!;
}
