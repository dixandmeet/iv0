"use client";

import { RefreshCw } from "lucide-react";

interface TimelineLegendProps {
  lastUpdated: Date | null;
  onRefresh?: () => void;
}

const LEGEND_ITEMS = [
  { color: "#22C55E", label: "En avance (< 0)" },
  { color: "#FFFFFF", label: "À l'heure (0)" },
  { color: "#F59E0B", label: "Retard léger (+1 à +4)" },
  { color: "#EF4444", label: "Retard important (≥ +5)" },
];

export function TimelineLegend({ lastUpdated, onRefresh }: TimelineLegendProps) {
  const timeLabel = lastUpdated
    ? lastUpdated.toLocaleTimeString("fr-FR", {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
      })
    : "10:24:30";

  return (
    <footer className="regulation-legend">
      <div className="regulation-legend-items">
        {LEGEND_ITEMS.map((item) => (
          <div key={item.label} className="regulation-legend-item">
            <span
              className="regulation-legend-dot"
              style={{ backgroundColor: item.color }}
            />
            <span className="text-[11px] text-[#94A3B8]">{item.label}</span>
          </div>
        ))}
      </div>

      <button
        type="button"
        className="regulation-sync-status"
        onClick={onRefresh}
      >
        <RefreshCw className="h-3.5 w-3.5 text-[#94A3B8]" />
        <span className="text-[11px] text-[#94A3B8]">
          Mise à jour : <span className="text-white">{timeLabel}</span>
        </span>
      </button>
    </footer>
  );
}
