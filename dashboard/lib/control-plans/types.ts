import type { MsrDisplayStatus } from "@/lib/msr-mock-data";

export type ControlPlanStatus = "draft" | "active" | "completed" | "suspended";
export type ControlPlanPriority = "high" | "medium" | "low";

export interface ControlPlan {
  id: string;
  name: string;
  description: string;
  objective: string;
  priority: ControlPlanPriority;
  status: ControlPlanStatus;
  start_date: string;
  end_date: string;
  created_by: string;
}

export interface ControlPlanTeam {
  plan_id: string;
  team_id: string;
}

export interface ControlPlanAgent {
  plan_id: string;
  agent_id: string;
}

export interface ControlPlanLine {
  plan_id: string;
  line_id: string;
}

export interface ControlPlanStation {
  plan_id: string;
  station_id: string;
}

export interface ControlPlanZone {
  plan_id: string;
  zone_id: string;
}

export interface ControlPlanInstruction {
  id: string;
  plan_id: string;
  content: string;
  sort_order: number;
}

export interface ControlPlanMission {
  id: string;
  control_plan_id: string;
  team_id: string;
  zone_id: string;
  start_time: string;
  end_time: string;
  status: MsrDisplayStatus;
}

export interface ControlPlanTimeSlot {
  label: string;
  start: string;
  end: string;
}

export interface ControlPlanMetrics {
  coverageRate: number;
  incidentsReported: number;
  completionRate: number;
  activeAgents: number;
}

/** Plan enrichi pour l'UI (mock + agrégats) */
export interface ControlPlanView extends ControlPlan {
  manager: string;
  missionCount: number;
  teamCount: number;
  agentCount: number;
  zoneCount: number;
  networks: string[];
  lines: string[];
  stations: string[];
  zoneLabels: string[];
  timeSlots: ControlPlanTimeSlot[];
  vehicles: string[];
  equipment: string[];
  instructions: string[];
  metrics: ControlPlanMetrics;
  missions: ControlPlanMissionView[];
}

export interface ControlPlanMissionView extends ControlPlanMission {
  teamName: string;
  zoneLabel: string;
  title: string;
}

export function controlPlanStatusLabel(status: ControlPlanStatus): string {
  switch (status) {
    case "draft":
      return "Brouillon";
    case "active":
      return "Actif";
    case "completed":
      return "Terminé";
    case "suspended":
      return "Suspendu";
  }
}

export function controlPlanStatusColor(status: ControlPlanStatus): string {
  switch (status) {
    case "draft":
      return "#64748B";
    case "active":
      return "#3B82F6";
    case "completed":
      return "#22C55E";
    case "suspended":
      return "#F97316";
  }
}

export function controlPlanPriorityLabel(p: ControlPlanPriority): string {
  switch (p) {
    case "high":
      return "Haute";
    case "medium":
      return "Moyenne";
    case "low":
      return "Basse";
  }
}

export function formatPlanPeriod(start: string, end: string): string {
  const fmt = (iso: string) => {
    const d = new Date(iso);
    return d.toLocaleDateString("fr-FR", { day: "2-digit", month: "2-digit" });
  };
  return `${fmt(start)} → ${fmt(end)}`;
}
