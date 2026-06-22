export type LineStatus = "normal" | "perturbe" | "critique";

export type NetworkMode = "bus" | "tram" | "boat";

export interface RegulationStop {
  stopId?: string;
  stationId?: string;
  name: string;
  theoreticalTime: string;
  isTerminus?: boolean;
  unavailable?: boolean;
}

export function normalizeNetworkMode(transportType: string): NetworkMode {
  const t = transportType.toLowerCase();
  if (t.includes("tram")) return "tram";
  if (t.includes("navibus") || t.includes("bateau") || t.includes("ferry")) return "boat";
  return "bus";
}

export const NETWORK_MODE_LABELS: Record<NetworkMode, string> = {
  bus: "Bus",
  tram: "Tram",
  boat: "Bateau",
};

export interface RegulationVehicle {
  id: string;
  /** Identifiant de service affiché (ex. « 11-2 »). */
  service: string;
  /** Retard ou avance courant en minutes à la position actuelle. */
  currentDelay: number;
  delays: number[];
  segmentIndex: number;
  segmentProgress: number;
}

export interface RegulationLine {
  id: string;
  shortName: string;
  origin: string;
  destination: string;
  status: LineStatus;
  vehicleCount: number;
  avgDelay: number;
  incidentCount: number;
  transportType: string;
  depotCode: string;
  routeId: string;
  stopCount: number;
  maxVehicles: number;
  punctuality: number;
  firstDeparture: string;
  lastDeparture: string;
  stops: RegulationStop[];
  segmentQuality: Array<"on-time" | "light-delay" | "major-delay">;
  vehicles: RegulationVehicle[];
  lineColor: string;
}

export function formatDelayMinutes(delay: number): string {
  if (delay === 0) return "0";
  return delay > 0 ? `+${delay}` : `${delay}`;
}

/** Libellé lisible pour la fiche véhicule et les contextes embarqués. */
export function formatDelayLabel(delay: number): string {
  if (delay === 0) return "À l'heure";
  return formatDelayMinutes(delay);
}

export function delayColor(delay: number): string {
  if (delay < 0) return "#22C55E";
  if (delay === 0) return "#FFFFFF";
  if (delay >= 1 && delay <= 4) return "#F59E0B";
  return "#EF4444";
}

export function segmentColor(quality: "on-time" | "light-delay" | "major-delay"): string {
  if (quality === "on-time") return "#22C55E";
  if (quality === "light-delay") return "#F59E0B";
  return "#EF4444";
}

export function lineStatusLabel(status: LineStatus): string {
  if (status === "normal") return "Normal";
  if (status === "perturbe") return "Perturbé";
  return "Critique";
}

export function lineStatusColor(status: LineStatus): string {
  if (status === "normal") return "#22C55E";
  if (status === "perturbe") return "#F59E0B";
  return "#EF4444";
}
