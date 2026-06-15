export type StaffRole =
  | "passenger"
  | "driver"
  | "msr_agent"
  | "msr_supervisor"
  | "regulator"
  | "admin";

export const WEB_STAFF_ROLES: StaffRole[] = [
  "msr_supervisor",
  "regulator",
  "admin",
];

export type FleetSource = "driver" | "community" | "operator";

export interface LiveFleetPosition {
  id: string;
  route_id: string;
  trip_id: string | null;
  transport_type: string;
  geom: { type: "Point"; coordinates: [number, number] };
  speed: number | null;
  heading: number | null;
  source: FleetSource;
  source_confidence: number | null;
  reliability_score: number;
  freshness_seconds: number;
  coherence_score: number | null;
  last_seen_at: string;
  estimated_delay_seconds: number | null;
}

export interface NetworkIncident {
  id: string;
  incident_type: string;
  severity: "info" | "warning" | "critical";
  status: string;
  title: string;
  description: string | null;
  route_id: string | null;
  source: string;
  created_at: string;
}

export interface UserProfile {
  id: string;
  role: StaffRole;
  display_name: string | null;
}

export function reliabilityColor(score: number): string {
  if (score >= 80) return "#16a34a";
  if (score >= 50) return "#ea580c";
  return "#dc2626";
}

export function sourceLabel(source: FleetSource): string {
  switch (source) {
    case "driver":
      return "Conducteur";
    case "operator":
      return "Opérateur";
    default:
      return "Communauté";
  }
}
