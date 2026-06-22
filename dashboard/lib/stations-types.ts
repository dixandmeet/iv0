export type StationStatus = "active" | "inactive" | "works" | "relocated";

export type StopSource = "gtfs" | "manual" | "temporary" | "works" | "community";

export type StopTransportMode = "bus" | "tram" | "train" | "ferry" | "metro";

export interface StationListItem {
  id: string;
  network_id: string;
  name: string;
  commune: string | null;
  status: StationStatus;
  latitude_center: number | null;
  longitude_center: number | null;
  stop_count: number;
  description?: string | null;
}

export interface StationStopItem {
  id: string;
  code: string;
  name: string | null;
  platform: string | null;
  transport_mode: StopTransportMode;
  is_accessible: boolean;
  status: string;
  latitude: number;
  longitude: number;
  source: StopSource;
  distance_m: number | null;
  served_routes?: ServedRouteBadge[];
}

export interface StationDetail {
  station: {
    id: string;
    name: string;
    description: string | null;
    commune: string | null;
    status: StationStatus;
    latitude_center: number | null;
    longitude_center: number | null;
  };
  stops: StationStopItem[];
}

export interface ServedRouteBadge {
  route_id: string;
  route_short_name: string | null;
  route_color: string | null;
}

export interface StationFilters {
  status: StationStatus | "all";
  commune: string;
}

export interface StationFormPayload {
  name: string;
  description?: string | null;
  commune?: string | null;
  latitude_center?: number | null;
  longitude_center?: number | null;
  status: StationStatus;
}

export const STATION_STATUS_LABELS: Record<StationStatus, string> = {
  active: "Actif",
  inactive: "Inactif",
  works: "Travaux",
  relocated: "Déplacé",
};

export const STOP_SOURCE_LABELS: Record<StopSource, string> = {
  gtfs: "GTFS",
  manual: "Manuel",
  temporary: "Temporaire",
  works: "Travaux",
  community: "Communautaire",
};

export const TRANSPORT_MODE_LABELS: Record<StopTransportMode, string> = {
  bus: "Bus",
  tram: "Tram",
  train: "Train",
  ferry: "Navibus",
  metro: "Métro",
};

export function stationStatusLabel(status: StationStatus): string {
  return STATION_STATUS_LABELS[status] ?? status;
}

export function stationStatusColor(status: StationStatus): string {
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

export const DUPLICATE_STATION_NAME_ERROR = "Une station portant ce nom existe déjà.";

export function isDuplicateStationNameError(message: string): boolean {
  return message.includes("stations_network_id_name_normalized_key") || message.includes("23505");
}
