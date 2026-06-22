import type { StopSource, StopTransportMode, ServedRouteBadge } from "@/lib/stations-types";

export type StopStatus = "active" | "inactive" | "works" | "relocated";

export interface StopListItem {
  id: string;
  station_id: string;
  network_id: string;
  code: string;
  name: string | null;
  latitude: number;
  longitude: number;
  geom: { type: "Point"; coordinates: [number, number] };
  platform: string | null;
  transport_mode: StopTransportMode;
  source: StopSource;
  gtfs_source_id: string | null;
  is_accessible: boolean;
  status: StopStatus;
  address: string | null;
  tariff_zone: string | null;
  updated_at: string;
  served_routes: ServedRouteBadge[];
  station_name?: string;
}

export interface StopServingLine {
  route_id: string;
  route_short_name: string | null;
  route_long_name: string | null;
  route_type: number;
  route_color: string | null;
  direction_id: number | null;
  trip_id: string;
  stop_sequence: number;
  prev_stop_id: string | null;
  prev_stop_name: string | null;
  next_stop_id: string | null;
  next_stop_name: string | null;
  arrival_time: string;
  time_from_terminus_seconds: number | null;
}

export interface StopDeparture {
  trip_id: string;
  route_id: string;
  route_short_name: string | null;
  route_color: string | null;
  direction_id: number | null;
  theoretical_time: string;
  stop_sequence: number;
  realtime_time?: string | null;
  delay_minutes?: number | null;
  vehicle_id?: string | null;
}

export interface StopAuditEntry {
  id: string;
  stop_id: string;
  action: string;
  changes: Record<string, unknown>;
  performed_by: string | null;
  created_at: string;
  performer_name?: string | null;
}

export interface NearbyStop {
  stop_id: string;
  stop_code: string;
  stop_name: string;
  station_id: string;
  station_name: string;
  status: StopStatus;
  distance_m: number;
  geom: { type: "Point"; coordinates: [number, number] };
  serving_lines?: StopServingLine[];
}

export interface StopFormPayload {
  code: string;
  name?: string | null;
  status: StopStatus;
  address?: string | null;
  tariff_zone?: string | null;
  platform?: string | null;
  transport_mode: StopTransportMode;
  source: StopSource;
  is_accessible: boolean;
  coordinates: [number, number];
}

export const STOP_STATUS_LABELS: Record<StopStatus, string> = {
  active: "Actif",
  inactive: "Inactif",
  works: "Travaux",
  relocated: "Déplacé",
};

export function stopStatusLabel(status: StopStatus): string {
  return STOP_STATUS_LABELS[status] ?? status;
}

export function stopStatusColor(status: StopStatus): string {
  switch (status) {
    case "active":
      return "#22c55e";
    case "inactive":
      return "#94a3b8";
    case "works":
      return "#f59e0b";
    case "relocated":
      return "#3b82f6";
    default:
      return "#94a3b8";
  }
}

export const STOP_INCIDENT_TYPES = [
  { value: "stop_disruption", label: "Perturbation arrêt" },
  { value: "stop_closed", label: "Arrêt fermé" },
  { value: "accessibility", label: "Accessibilité" },
] as const;

export function wheelchairLabel(accessible: boolean): string {
  return accessible ? "Accessible PMR" : "Accessibilité inconnue ou non accessible";
}

export function formatDelayMinutes(minutes: number | null | undefined): string {
  if (minutes == null || minutes === 0) return "0";
  if (minutes > 0) return `+${minutes}`;
  return String(minutes);
}

export function formatTimeFromTerminus(seconds: number | null): string {
  if (seconds == null || seconds < 0) return "—";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}

// Labels importés depuis stations-types
export { TRANSPORT_MODE_LABELS } from "@/lib/stations-types";
