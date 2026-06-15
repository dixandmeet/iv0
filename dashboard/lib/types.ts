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
  geom: { type: "Point"; coordinates: [number, number] } | null;
  source: string;
  created_at: string;
}

export type MsrMissionStatus =
  | "draft"
  | "assigned"
  | "in_progress"
  | "completed"
  | "cancelled";

export interface MsrMission {
  id: string;
  supervisor_id: string | null;
  agent_id: string | null;
  zone_type: "sector" | "line_buffer" | "custom_polygon";
  zone_config: Record<string, unknown>;
  status: MsrMissionStatus;
  started_at: string | null;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
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

export function formatRelativeTime(isoDate: string): string {
  const diffSec = Math.floor((Date.now() - new Date(isoDate).getTime()) / 1000);
  if (diffSec < 60) return `il y a ${diffSec}s`;
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `il y a ${diffMin} min`;
  const diffH = Math.floor(diffMin / 60);
  if (diffH < 24) return `il y a ${diffH} h`;
  const diffD = Math.floor(diffH / 24);
  return `il y a ${diffD} j`;
}

export function severityColor(severity: NetworkIncident["severity"]): string {
  switch (severity) {
    case "critical":
      return "#dc2626";
    case "warning":
      return "#ea580c";
    default:
      return "#1b66f5";
  }
}

export function severityLabel(severity: NetworkIncident["severity"]): string {
  switch (severity) {
    case "critical":
      return "Critique";
    case "warning":
      return "Alerte";
    default:
      return "Info";
  }
}

export function statusLabel(status: string): string {
  switch (status) {
    case "open":
      return "Ouvert";
    case "acknowledged":
      return "Acquitté";
    case "in_progress":
      return "En cours";
    case "resolved":
      return "Résolu";
    case "closed":
      return "Clôturé";
    case "draft":
      return "Brouillon";
    case "assigned":
      return "Assignée";
    case "completed":
      return "Terminée";
    case "cancelled":
      return "Annulée";
    default:
      return status;
  }
}

export function missionStatusColor(status: MsrMissionStatus): string {
  switch (status) {
    case "in_progress":
      return "#16a34a";
    case "assigned":
      return "#1b66f5";
    case "draft":
      return "#64748b";
    case "completed":
      return "#059669";
    case "cancelled":
      return "#dc2626";
    default:
      return "#64748b";
  }
}
