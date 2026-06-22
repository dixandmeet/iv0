import type { RouteTimelinePoint } from "@/lib/regulation-data";

/** Rôle d'un nœud dans la topologie de ligne. */
export type TopologyNodeRole = "terminus" | "hub" | "stop";

/** Type de variante GTFS (service complet, partiel ou branche). */
export type VariantKind = "full" | "partial" | "branch";

export interface LineVariant {
  /** Identifiant stable (signature de séquence d'arrêts). */
  id: string;
  tripId: string;
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

function isPrefixOf(shorter: string[], longer: string[]): boolean {
  if (shorter.length > longer.length) return false;
  return shorter.every((id, i) => id === longer[i]);
}

function isSuffixOf(shorter: string[], longer: string[]): boolean {
  if (shorter.length > longer.length) return false;
  const offset = longer.length - shorter.length;
  return shorter.every((id, i) => id === longer[offset + i]);
}

function commonPrefixLength(a: string[], b: string[]): number {
  const len = Math.min(a.length, b.length);
  let i = 0;
  while (i < len && a[i] === b[i]) i += 1;
  return i;
}

function classifyVariant(
  variant: Omit<LineVariant, "kind">,
  mainStopIds: string[],
): VariantKind {
  if (sequenceKey(variant.stopIds) === sequenceKey(mainStopIds)) return "full";
  if (isPrefixOf(variant.stopIds, mainStopIds) || isSuffixOf(variant.stopIds, mainStopIds)) {
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
    const key = sequenceKey(trip.stopIds);
    if (bySequence.has(key)) continue;

    const origin = trip.stops[0]?.name ?? "—";
    const destination = trip.stops[trip.stops.length - 1]?.name ?? "—";

    bySequence.set(key, {
      id: key,
      tripId: trip.tripId,
      headsign: trip.headsign || destination,
      directionId: trip.directionId,
      origin,
      destination,
      label: buildVariantLabel(origin, destination, trip.headsign),
      kind: "full",
      stopIds: trip.stopIds,
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

  const main = variants.reduce((a, b) =>
    a.stopIds.length >= b.stopIds.length ? a : b,
  );

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
  for (const variant of variants) {
    if (variant.id === main.id) continue;

    const prefixLen = commonPrefixLength(variant.stopIds, main.stopIds);
    const divergesFromMain =
      variant.kind === "branch" ||
      (prefixLen < variant.stopIds.length &&
        prefixLen < main.stopIds.length &&
        variant.stopIds[prefixLen] !== main.stopIds[prefixLen]);

    if (!divergesFromMain) {
      for (let i = 0; i < variant.stopIds.length; i++) {
        const stopId = variant.stopIds[i];
        const stop = variant.stops.find((s) => s.stopId === stopId) ?? variant.stops[i];
        if (!stop) continue;
        ensureNode(stopId, stop, i, 0);
      }
      for (let i = 0; i < variant.stopIds.length - 1; i++) {
        addEdge(variant.stopIds[i], variant.stopIds[i + 1], variant.id);
      }
      continue;
    }

    const lane = nextLane;
    nextLane += 1;
    const divergeColumn = Math.max(prefixLen - 1, 0);

    for (let i = prefixLen; i < variant.stopIds.length; i++) {
      const stopId = variant.stopIds[i];
      const stop = variant.stops.find((s) => s.stopId === stopId) ?? variant.stops[i];
      if (!stop) continue;
      const column = divergeColumn + (i - prefixLen + 1);
      ensureNode(stopId, stop, column, lane);
    }

    if (prefixLen > 0) {
      const junctionId = variant.stopIds[prefixLen - 1];
      const junction = nodeById.get(junctionId);
      if (junction) junction.role = "hub";
    }

    for (let i = Math.max(prefixLen - 1, 0); i < variant.stopIds.length - 1; i++) {
      addEdge(variant.stopIds[i], variant.stopIds[i + 1], variant.id);
    }
  }

  // Terminus et rôles
  const terminusIds = new Set<string>();
  for (const variant of variants) {
    if (variant.stopIds.length === 0) continue;
    terminusIds.add(variant.stopIds[0]);
    terminusIds.add(variant.stopIds[variant.stopIds.length - 1]);
  }

  for (const variant of variants) {
    const first = variant.stopIds[0];
    const last = variant.stopIds[variant.stopIds.length - 1];
    const firstNode = nodeById.get(first);
    const lastNode = nodeById.get(last);
    if (firstNode && !firstNode.terminusFor.includes(variant.destination)) {
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

  const allVariantIds = variants.map((v) => v.id);
  for (const edge of edgeMap.values()) {
    edge.isCommon = allVariantIds.every((id) => edge.variantIds.includes(id));
  }

  const nodes = [...nodeById.values()].sort((a, b) =>
    a.lane !== b.lane ? a.lane - b.lane : a.column - b.column,
  );

  const columnCount = nodes.reduce((max, n) => Math.max(max, n.column + 1), 0);
  const laneCount = nodes.reduce((max, n) => Math.max(max, n.lane + 1), 0);

  const uniqueTermini = new Set<string>();
  for (const v of variants) {
    uniqueTermini.add(v.origin);
    uniqueTermini.add(v.destination);
  }

  const hasBranch = variants.some((v) => v.kind === "branch");
  const hasMultipleVariants = variants.length > 1;
  const isComplex = hasBranch || (hasMultipleVariants && uniqueTermini.size > 2);

  return {
    nodes,
    edges: [...edgeMap.values()],
    variants,
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

export function variantForTripId(
  topology: LineTopology,
  tripId: string | null | undefined,
): LineVariant | null {
  if (!tripId) return null;
  return topology.variants.find((v) => v.tripId === tripId) ?? null;
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
