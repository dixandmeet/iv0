import { createClient } from "@/lib/supabase/client";
import { isStopType } from "@/lib/line-editor-utils";
import type { RoutePoint } from "@/lib/line-editor-types";

export interface RegisteredStop {
  id: string;
  name: string;
  code: string;
  coordinates?: [number, number];
  address?: string;
  wheelchairAccessible?: boolean;
  stationName?: string;
  source: "database" | "editor";
}

export const REGISTERED_STOP_SUGGESTION_LIMIT = 8;

function stopKey(stop: Pick<RegisteredStop, "name" | "code">): string {
  const code = stop.code.trim().toUpperCase();
  if (code) return `code:${code}`;
  return `name:${stop.name.trim().toLowerCase()}`;
}

export function mergeRegisteredStops(
  primary: RegisteredStop[],
  secondary: RegisteredStop[],
): RegisteredStop[] {
  const seen = new Set<string>();
  const merged: RegisteredStop[] = [];

  for (const stop of [...primary, ...secondary]) {
    const key = stopKey(stop);
    if (seen.has(key)) continue;
    seen.add(key);
    merged.push(stop);
  }

  return merged.sort((a, b) =>
    a.name.localeCompare(b.name, "fr", { sensitivity: "base" }),
  );
}

export function registeredStopsFromPoints(points: RoutePoint[]): RegisteredStop[] {
  const seen = new Set<string>();
  const result: RegisteredStop[] = [];

  for (const point of points) {
    if (!isStopType(point.type) || !point.stop) continue;
    const name = point.stop.name.trim();
    if (!name) continue;

    const stop: RegisteredStop = {
      id: `editor-point-${point.id}`,
      name,
      code: point.stop.code.trim(),
      coordinates: point.coordinates,
      address: point.stop.address.trim() || undefined,
      wheelchairAccessible: point.stop.wheelchairAccessible,
      source: "editor",
    };

    const key = stopKey(stop);
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(stop);
  }

  return result;
}

export function normalizeStopQuery(query: string): string {
  return query.trim().toLowerCase();
}

export function stopMatchesQuery(stop: RegisteredStop, query: string): boolean {
  const normalized = normalizeStopQuery(query);
  if (!normalized) return true;

  const name = stop.name.toLowerCase();
  const code = stop.code.toLowerCase();
  const station = stop.stationName?.toLowerCase() ?? "";

  return (
    name.includes(normalized) ||
    code.includes(normalized) ||
    station.includes(normalized)
  );
}

export function filterRegisteredStops(
  catalog: RegisteredStop[],
  query: string,
  limit = REGISTERED_STOP_SUGGESTION_LIMIT,
): RegisteredStop[] {
  const normalized = normalizeStopQuery(query);

  if (!normalized) {
    return catalog.slice(0, limit);
  }

  const matches = catalog.filter((stop) => stopMatchesQuery(stop, normalized));
  const exactIndex = matches.findIndex(
    (stop) => stop.name.trim().toLowerCase() === normalized,
  );

  if (exactIndex > 0) {
    const [exact] = matches.splice(exactIndex, 1);
    matches.unshift(exact);
  }

  return matches.slice(0, limit);
}

export function hasExactRegisteredStopName(
  catalog: RegisteredStop[],
  query: string,
): boolean {
  const normalized = normalizeStopQuery(query);
  if (!normalized) return false;
  return catalog.some((stop) => stop.name.trim().toLowerCase() === normalized);
}

export async function fetchRegisteredStopsFromDatabase(): Promise<RegisteredStop[]> {
  const supabase = createClient();
  const pageSize = 1000;
  let from = 0;
  const all: RegisteredStop[] = [];

  while (true) {
    const { data, error } = await supabase
      .from("stops")
      .select(
        "id, code, name, latitude, longitude, is_accessible, address, stations(name)",
      )
      .eq("status", "active")
      .order("name")
      .range(from, from + pageSize - 1);

    if (error) throw error;
    if (!data?.length) break;

    for (const row of data) {
      const station = row.stations as
        | { name: string }
        | { name: string }[]
        | null;
      const stationName = Array.isArray(station)
        ? station[0]?.name
        : station?.name;
      const name =
        (row.name as string) ?? stationName ?? (row.code as string);

      all.push({
        id: row.id as string,
        name,
        code: row.code as string,
        coordinates: [row.longitude as number, row.latitude as number],
        address: (row.address as string) ?? undefined,
        wheelchairAccessible: Boolean(row.is_accessible),
        stationName: stationName ?? undefined,
        source: "database",
      });
    }

    if (data.length < pageSize) break;
    from += pageSize;
  }

  return all;
}
