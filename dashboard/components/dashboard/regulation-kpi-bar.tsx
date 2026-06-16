"use client";

import {
  AlertTriangle,
  Bell,
  Bus,
  Clock,
  LogOut,
  RefreshCw,
  ShieldAlert,
  UserCheck,
  Users,
} from "lucide-react";
import { motion } from "framer-motion";
import { createClient } from "@/lib/supabase/client";
import { formatKpiNumber } from "@/lib/regulation-data";

interface RegulationKpis {
  vehicleCount: number;
  connectedDrivers: number;
  punctuality: number;
  incidentCount: number;
  alertCount: number;
  activeUsers: number;
}

interface RegulationKpiBarProps {
  onRefresh?: () => void;
  loading?: boolean;
  kpis: RegulationKpis;
  alertCount?: number;
}

export function RegulationKpiBar({
  onRefresh,
  loading,
  kpis,
  alertCount,
}: RegulationKpiBarProps) {
  const notifications = alertCount ?? kpis.alertCount;

  const items = [
    {
      label: "Véhicules en ligne",
      value: formatKpiNumber(kpis.vehicleCount),
      icon: Bus,
      iconColor: "#2563EB",
    },
    {
      label: "Conducteurs connectés",
      value: formatKpiNumber(kpis.connectedDrivers),
      icon: UserCheck,
      iconColor: kpis.connectedDrivers > 0 ? "#22C55E" : "#94A3B8",
    },
    {
      label: "Taux de ponctualité",
      value: kpis.vehicleCount > 0 ? `${kpis.punctuality} %` : "—",
      icon: Clock,
      iconColor:
        kpis.punctuality >= 80
          ? "#22C55E"
          : kpis.punctuality >= 60
            ? "#F59E0B"
            : "#EF4444",
    },
    {
      label: "Incidents en cours",
      value: formatKpiNumber(kpis.incidentCount),
      icon: AlertTriangle,
      iconColor: kpis.incidentCount > 0 ? "#EF4444" : "#94A3B8",
    },
    {
      label: "Alertes prioritaires",
      value: formatKpiNumber(kpis.alertCount),
      icon: ShieldAlert,
      iconColor: kpis.alertCount > 0 ? "#EF4444" : "#94A3B8",
    },
    {
      label: "Contributeurs actifs",
      value: kpis.activeUsers > 0 ? formatKpiNumber(kpis.activeUsers) : "—",
      icon: Users,
      iconColor: kpis.activeUsers > 0 ? "#2563EB" : "#94A3B8",
    },
  ];

  async function signOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    window.location.href = "/login";
  }

  return (
    <header className="regulation-kpi-bar">
      <div className="regulation-kpi-grid">
        {items.map((item, index) => (
          <motion.div
            key={item.label}
            className="regulation-kpi-card"
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.04, duration: 0.3 }}
          >
            <item.icon
              className="h-5 w-5 shrink-0"
              style={{ color: item.iconColor }}
              strokeWidth={1.5}
            />
            <div className="min-w-0">
              <p className="truncate text-[11px] text-[#94A3B8]">{item.label}</p>
              <span className="text-xl font-semibold text-white">{item.value}</span>
            </div>
          </motion.div>
        ))}
      </div>

      <div className="regulation-kpi-actions">
        <button
          type="button"
          className="regulation-action-btn"
          onClick={onRefresh}
          aria-label="Rafraîchir"
          disabled={loading}
        >
          <RefreshCw className={`h-[18px] w-[18px]${loading ? " animate-spin" : ""}`} />
        </button>
        <button type="button" className="regulation-action-btn relative" aria-label="Notifications">
          <Bell className="h-[18px] w-[18px]" />
          {notifications > 0 && (
            <span className="regulation-notif-badge">
              {notifications > 99 ? "99+" : notifications}
            </span>
          )}
        </button>
        <button
          type="button"
          className="regulation-action-btn"
          onClick={signOut}
          aria-label="Déconnexion"
        >
          <LogOut className="h-[18px] w-[18px]" />
        </button>
      </div>
    </header>
  );
}
