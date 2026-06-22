"use client";

import {
  AlertTriangle,
  CalendarRange,
  ClipboardList,
  Shield,
  Users,
  UsersRound,
} from "lucide-react";
import { CONTROL_PLAN_KPI } from "@/lib/control-plans/mock-data";

const KPI_ITEMS = [
  {
    label: "Plans actifs",
    value: String(CONTROL_PLAN_KPI.activePlans),
    sub: "En cours d'exécution",
    icon: CalendarRange,
    accent: "#3B82F6",
    glow: "rgba(59, 130, 246, 0.15)",
  },
  {
    label: "Missions planifiées",
    value: String(CONTROL_PLAN_KPI.totalMissions),
    sub: "Tous plans confondus",
    icon: ClipboardList,
    accent: "#A855F7",
    glow: "rgba(168, 85, 247, 0.15)",
  },
  {
    label: "Agents mobilisés",
    value: String(CONTROL_PLAN_KPI.agentsMobilized),
    sub: "Sur l'ensemble des plans",
    icon: Users,
    accent: "#22C55E",
    glow: "rgba(34, 197, 94, 0.15)",
  },
  {
    label: "Couverture réseau",
    value: `${CONTROL_PLAN_KPI.coverageRate}%`,
    sub: "Taux moyen",
    icon: Shield,
    accent: "#06B6D4",
    glow: "rgba(6, 182, 212, 0.15)",
  },
  {
    label: "Alertes ressources",
    value: String(CONTROL_PLAN_KPI.criticalAlerts),
    sub: "Nécessitent action",
    icon: AlertTriangle,
    accent: "#EF4444",
    glow: "rgba(239, 68, 68, 0.15)",
  },
];

export function ControlPlanKpiCards() {
  return (
    <div className="msr-kpi-grid">
      {KPI_ITEMS.map((item) => (
        <div
          key={item.label}
          className="msr-kpi-card"
          style={{ "--msr-kpi-glow": item.glow } as React.CSSProperties}
        >
          <div className="msr-kpi-card-content">
            <p className="msr-kpi-label">{item.label}</p>
            <p className="msr-kpi-value">{item.value}</p>
            <p className="msr-kpi-sub">{item.sub}</p>
          </div>
          <div
            className="msr-kpi-icon"
            style={{ background: `${item.accent}22`, color: item.accent }}
          >
            <item.icon className="h-5 w-5" strokeWidth={1.5} />
          </div>
        </div>
      ))}
    </div>
  );
}
