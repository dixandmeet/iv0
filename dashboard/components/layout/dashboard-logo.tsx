"use client";

import Link from "next/link";
import type { NetworkSummary } from "@/lib/network/types";

interface DashboardLogoProps {
  collapsed?: boolean;
  network: NetworkSummary;
  canManage?: boolean;
}

export function DashboardLogo({ collapsed = false, network, canManage = false }: DashboardLogoProps) {
  const content = (
    <div className={`dashboard-logo${collapsed ? " dashboard-logo--collapsed" : ""}`}>
      <div className="dashboard-logo-icon" aria-hidden>
        <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
          <path
            d="M8 6L14 3L20 6V14L14 21L8 14V6Z"
            stroke="#2563EB"
            strokeWidth="1.5"
            fill="none"
          />
          <path
            d="M14 3V21M8 6L20 14M20 6L8 14"
            stroke="#2563EB"
            strokeWidth="1"
            opacity="0.5"
          />
        </svg>
      </div>
      <div className="dashboard-logo-text">
        <p className="dashboard-logo-title">{network.name}</p>
        <p className="dashboard-logo-subtitle">
          {[network.operator, network.territory].filter(Boolean).join(" · ") || "Poste de contrôle"}
        </p>
      </div>
    </div>
  );
  return canManage ? <Link href="/configuration/reseau" aria-label="Configurer le réseau">{content}</Link> : content;
}
