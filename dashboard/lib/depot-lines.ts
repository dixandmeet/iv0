/**
 * Registre unifié des dépôts Semitan et de leurs schémas lignes.
 */

import { BELE_DEPOT, BELE_DEPOT_LINES } from "@/lib/bele-depot-lines";
import { TTX_DEPOT, TTX_DEPOT_LINES } from "@/lib/ttx-depot-lines";
import { SHX_DEPOT, SHX_DEPOT_LINES } from "@/lib/shx-depot-lines";
import {
  type DepotInfo,
  type DepotLine,
  makeLineId,
  parseLineId,
} from "@/lib/depot-types";

export type { DepotInfo, DepotLine } from "@/lib/depot-types";
export { makeLineId, parseLineId, gtfsRouteIdFromLineId } from "@/lib/depot-types";

export const DEPOTS: DepotInfo[] = [BELE_DEPOT, TTX_DEPOT, SHX_DEPOT];

export const ALL_DEPOT_LINES: DepotLine[] = [
  ...BELE_DEPOT_LINES.map((line) => ({ ...line, depotCode: BELE_DEPOT.code })),
  ...TTX_DEPOT_LINES,
  ...SHX_DEPOT_LINES,
];

const DEPOT_BY_CODE = new Map(DEPOTS.map((d) => [d.code, d]));

const LINES_BY_COMPOSITE_ID = new Map(
  ALL_DEPOT_LINES.map((line) => [makeLineId(line.depotCode, line.id), line]),
);

const LINES_BY_ROUTE = new Map<string, DepotLine[]>();
for (const line of ALL_DEPOT_LINES) {
  const list = LINES_BY_ROUTE.get(line.id) ?? [];
  list.push(line);
  LINES_BY_ROUTE.set(line.id, list);
}

export function getDepot(code: string): DepotInfo | undefined {
  return DEPOT_BY_CODE.get(code);
}

export function isDepotRoute(routeId: string): boolean {
  return LINES_BY_ROUTE.has(routeId);
}

/** @deprecated Utiliser isDepotRoute */
export function isBeleDepotLine(routeId: string): boolean {
  return isDepotRoute(routeId);
}

export function getDepotLinesForRoute(routeId: string): DepotLine[] {
  return LINES_BY_ROUTE.get(routeId) ?? [];
}

export function getDepotLine(depotCode: string, routeId: string): DepotLine | undefined {
  return LINES_BY_COMPOSITE_ID.get(makeLineId(depotCode, routeId));
}

export function getDepotLineByCompositeId(compositeId: string): DepotLine | undefined {
  const { depotCode, routeId } = parseLineId(compositeId);
  if (!depotCode) {
    return ALL_DEPOT_LINES.find((line) => line.id === routeId);
  }
  return getDepotLine(depotCode, routeId);
}

/** @deprecated Utiliser getDepotLineByCompositeId ou getDepotLine */
export function getBeleDepotLine(routeId: string): DepotLine | undefined {
  return ALL_DEPOT_LINES.find(
    (line) => line.depotCode === BELE_DEPOT.code && line.id === routeId,
  );
}

export function getAllDepotLineIds(): string[] {
  return ALL_DEPOT_LINES.map((line) => makeLineId(line.depotCode, line.id));
}

export function depotLabel(code: string): string {
  const depot = getDepot(code);
  return depot ? `${depot.name} (${depot.code})` : code;
}
