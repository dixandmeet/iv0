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
  driver_session_id?: string | null;
  community_vehicle_id?: string | null;
  active_user_count?: number | null;
}

export interface DriverSession {
  id: string;
  driver_id: string;
  route_id: string | null;
  direction_id: number | null;
  trip_id: string | null;
  headsign: string | null;
  detection_mode: string;
  detection_confidence: number | null;
  status: "detecting" | "active" | "paused" | "ended";
  started_at: string;
  confirmed_at: string | null;
  ended_at: string | null;
  driver?: {
    display_name: string | null;
    role: string;
  };
}

export interface StaffMessage {
  id: string;
  sender_id: string;
  recipient_id: string | null;
  recipient_role: string | null;
  route_id: string | null;
  subject: string | null;
  body: string;
  message_type: "direct" | "group" | "broadcast";
  read_at: string | null;
  created_at: string;
  sender?: { display_name: string | null };
  recipient?: { display_name: string | null };
}

export interface PassengerAnnouncement {
  id: string;
  title: string;
  message: string;
  announcement_type: "info" | "disruption" | "cancellation" | "deviation" | "delay";
  route_ids: string[];
  severity: NetworkIncident["severity"];
  incident_id: string | null;
  published_by: string | null;
  published_at: string;
  expires_at: string | null;
  is_active: boolean;
}

export interface IncidentActionLog {
  id: string;
  incident_id: string;
  action_type: string;
  result: Record<string, unknown>;
  executed_at: string;
}

export interface GtfsRoute {
  route_id: string;
  route_short_name: string | null;
  route_long_name: string | null;
  route_type: number;
  route_color: string | null;
}

export interface GtfsStop {
  stop_id: string;
  stop_name: string;
  station_id?: string;
  wheelchair_boarding?: number;
  geom: { type: "Point"; coordinates: [number, number] };
  status?: "active" | "inactive" | "works" | "relocated";
  address?: string | null;
  commune?: string | null;
  tariff_zone?: string | null;
  platform_count?: number;
  transport_modes?: string[];
  updated_at?: string;
  updated_by?: string | null;
}

export interface OperationalAlert {
  id: string;
  type: "delay" | "gps_loss" | "immobilized" | "off_route" | "driver_disconnect" | "crowding" | "incident";
  severity: "info" | "warning" | "critical";
  title: string;
  description: string;
  route_id?: string | null;
  vehicle_id?: string | null;
  incident_id?: string | null;
  created_at: string;
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

export function announcementTypeLabel(
  type: PassengerAnnouncement["announcement_type"],
): string {
  switch (type) {
    case "disruption":
      return "Perturbation";
    case "cancellation":
      return "Annulation";
    case "deviation":
      return "Déviation";
    case "delay":
      return "Retard";
    default:
      return "Information";
  }
}

export function driverStatusLabel(status: DriverSession["status"]): string {
  switch (status) {
    case "active":
      return "En service";
    case "paused":
      return "Pause";
    case "detecting":
      return "Détection";
    case "ended":
      return "Terminé";
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
