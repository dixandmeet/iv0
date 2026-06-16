/**
 * Types communs aux schémas lignes dépôts Semitan (BLX, TTX, SHX)
 */

export interface DepotInfo {
  code: string;
  name: string;
  operator: string;
  season: string;
}

export interface DepotLine {
  id: string;
  shortName: string;
  origin: string;
  destination: string;
  lineColor: string;
  stops: string[];
  depotCode: string;
}

export function makeLineId(depotCode: string, routeId: string): string {
  return `${depotCode}:${routeId}`;
}

export function parseLineId(id: string): { depotCode: string | null; routeId: string } {
  const sep = id.indexOf(":");
  if (sep === -1) return { depotCode: null, routeId: id };
  return {
    depotCode: id.slice(0, sep),
    routeId: id.slice(sep + 1),
  };
}

export function gtfsRouteIdFromLineId(lineId: string): string {
  return parseLineId(lineId).routeId;
}
