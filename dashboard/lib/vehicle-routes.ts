import type { GtfsRoute } from "@/lib/types";
import {
  getDepotLinesForRoute,
  makeLineId,
} from "@/lib/depot-lines";

export function vehicleDetailHref(
  vehicleId: string,
  opts?: {
    service?: string;
    line?: string;
    delay?: number;
    demo?: boolean;
  },
): string {
  const base = `/dashboard/vehicules/${encodeURIComponent(vehicleId)}`;
  if (!opts) return base;

  const params = new URLSearchParams();
  if (opts.service) params.set("service", opts.service);
  if (opts.line) params.set("line", opts.line);
  if (opts.delay != null) params.set("delay", String(opts.delay));
  if (opts.demo) params.set("demo", "1");

  const qs = params.toString();
  return qs ? `${base}?${qs}` : base;
}

/** Résout l'identifiant composite ligne (ex. BLX:10) depuis le numéro affiché. */
export function resolveLineIdFromShortName(
  shortName: string,
  routes: GtfsRoute[],
): string | null {
  const depotMatches = getDepotLinesForRoute(shortName);
  if (depotMatches.length > 0) {
    return makeLineId(depotMatches[0].depotCode, depotMatches[0].id);
  }

  const gtfs = routes.find((route) => route.route_short_name === shortName);
  return gtfs?.route_id ?? null;
}
