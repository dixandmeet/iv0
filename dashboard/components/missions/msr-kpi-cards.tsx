"use client";

import {
  AlertTriangle,
  ClipboardList,
  Shield,
  Users,
  UsersRound,
} from "lucide-react";
import { MSR_KPI } from "@/lib/msr-mock-data";

const KPI_ITEMS = [
  {
    label: "Missions en cours",
    value: String(MSR_KPI.missionsInProgress),
    sub: `↗ ${MSR_KPI.missionsDelta} depuis hier`,
    icon: ClipboardList,
    accent: "#3B82F6",
    glow: "rgba(59, 130, 246, 0.15)",
  },
  {
    label: "Agents disponibles",
    value: `${MSR_KPI.agentsAvailable} / ${MSR_KPI.agentsTotal}`,
    sub: "● Disponibles",
    subColor: "#22C55E",
    icon: Users,
    accent: "#22C55E",
    glow: "rgba(34, 197, 94, 0.15)",
  },
  {
    label: "Équipes actives",
    value: String(MSR_KPI.activeTeams),
    sub: `↗ ${MSR_KPI.teamsDelta} depuis hier`,
    icon: UsersRound,
    accent: "#A855F7",
    glow: "rgba(168, 85, 247, 0.15)",
  },
  {
    label: "Zones couvertes",
    value: String(MSR_KPI.zonesCovered),
    sub: `Sur ${MSR_KPI.zonesTotal} zones définies`,
    icon: Shield,
    accent: "#06B6D4",
    glow: "rgba(6, 182, 212, 0.15)",
  },
  {
    label: "Alertes critiques",
    value: String(MSR_KPI.criticalAlerts),
    sub: "Nécessitent intervention",
    icon: AlertTriangle,
    accent: "#EF4444",
    glow: "rgba(239, 68, 68, 0.15)",
  },
];

export function MsrKpiCards() {
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
            <p
              className="msr-kpi-sub"
              style={item.subColor ? { color: item.subColor } : undefined}
            >
              {item.sub}
            </p>
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
