import type { StopListItem, StopServingLine } from "@/lib/stops-types";
import type { StopTransportMode } from "@/lib/stations-types";
import { TRANSPORT_MODE_LABELS } from "@/lib/stations-types";
import { pointCoordinates } from "@/lib/geo";

export function formatCompactCoords(geom: StopListItem["geom"]): string | null {
  const coords = pointCoordinates(geom);
  if (!coords) return null;
  const [lng, lat] = coords;
  return `${lat.toFixed(4)}° N, ${lng.toFixed(4)}° E`;
}

export function haversineMeters(a: [number, number], b: [number, number]): number {
  const [lng1, lat1] = a;
  const [lng2, lat2] = b;
  const R = 6371000;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lng2 - lng1) * Math.PI) / 180;
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return Math.round(R * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x)));
}

export function stopDisambiguationLine(stop: StopListItem): string {
  const mode = TRANSPORT_MODE_LABELS[stop.transport_mode];
  const parts = [mode, `code ${stop.code}`];
  if (stop.platform) parts.push(`quai ${stop.platform}`);
  const coords = formatCompactCoords(stop.geom);
  if (coords) parts.push(coords);
  return parts.join(" · ");
}

export function routeTypeLabel(routeType: number): string {
  switch (routeType) {
    case 0:
      return "Tram";
    case 1:
      return "Métro";
    case 2:
      return "Train";
    case 3:
      return "Bus";
    case 4:
      return "Navibus";
    default:
      return "Autre";
  }
}

export function routeBadgeStyle(color: string | null | undefined): {
  backgroundColor: string;
  color: string;
} {
  const hex = color?.replace("#", "") ?? "64748b";
  return {
    backgroundColor: `#${hex}`,
    color: parseInt(hex, 16) > 0xffffff / 2 ? "#0f172a" : "#fff",
  };
}

export function directionLabel(directionId: number | null): string {
  if (directionId === 1) return "Retour";
  if (directionId === 0) return "Aller";
  return "—";
}

export interface MapRouteGroup {
  route_id: string;
  route_short_name: string;
  route_color: string | null;
  route_type: number;
  has_aller: boolean;
  has_retour: boolean;
}

/** Regroupe les lignes par route (sans doublons direction × arrêt). */
export function groupMapRoutes(lines: StopServingLine[]): MapRouteGroup[] {
  const map = new Map<string, MapRouteGroup>();
  for (const line of lines) {
    let group = map.get(line.route_id);
    if (!group) {
      group = {
        route_id: line.route_id,
        route_short_name: line.route_short_name ?? line.route_id,
        route_color: line.route_color,
        route_type: line.route_type,
        has_aller: false,
        has_retour: false,
      };
      map.set(line.route_id, group);
    }
    if (line.direction_id === 1) group.has_retour = true;
    else group.has_aller = true;
  }
  return [...map.values()].sort((a, b) =>
    a.route_short_name.localeCompare(b.route_short_name, "fr", { numeric: true }),
  );
}

export function collectMapServingLines(
  lines: StopServingLine[],
  nearby: { serving_lines?: StopServingLine[] }[],
): StopServingLine[] {
  const all = [...lines];
  for (const stop of nearby) {
    all.push(...(stop.serving_lines ?? []));
  }
  return all;
}

export function formatDistanceMeters(m: number | null): string {
  if (m == null) return "—";
  if (m < 1000) return `${Math.round(m)} m`;
  return `${(m / 1000).toFixed(1)} km`;
}

export function stopToCsvRow(stop: StopListItem): string {
  const coords = pointCoordinates(stop.geom);
  const fields = [
    stop.code,
    stop.name ?? "",
    stop.station_name ?? "",
    String(coords?.[1] ?? ""),
    String(coords?.[0] ?? ""),
    stop.status,
    String(stop.is_accessible),
    stop.tariff_zone ?? "",
    stop.transport_mode,
    stop.source,
  ];
  return fields.map(escapeCsvField).join(",");
}

function escapeCsvField(value: string): string {
  if (value.includes(",") || value.includes('"') || value.includes("\n")) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

export const STOP_CSV_HEADER =
  "code,name,station_name,lat,lng,status,is_accessible,tariff_zone,transport_mode,source";

export function exportStopsCsv(stops: StopListItem[]): string {
  return [STOP_CSV_HEADER, ...stops.map(stopToCsvRow)].join("\n");
}

export function exportStopsJson(stops: StopListItem[]): string {
  return JSON.stringify(stops, null, 2);
}

export function primaryTransportMode(stop: { transport_mode: StopTransportMode }): StopTransportMode {
  return stop.transport_mode;
}
