"use client";

import { ChevronDown, Megaphone, MoreHorizontal, ShieldAlert } from "lucide-react";
import { motion } from "framer-motion";
import {
  type RegulationLine,
  lineStatusColor,
  lineStatusLabel,
} from "@/lib/regulation-mock-data";

interface LineDetailHeaderProps {
  line: RegulationLine;
}

export function LineDetailHeader({ line }: LineDetailHeaderProps) {
  return (
    <div className="regulation-line-header">
      <div className="regulation-line-header-main">
        <div className="flex items-start gap-3">
          <span
            className="regulation-line-id-badge"
            style={{ backgroundColor: line.lineColor }}
          >
            {line.shortName}
          </span>
          <div>
            <h1 className="text-lg font-semibold text-white">
              {line.origin} ↔ {line.destination}
            </h1>
            <p className="mt-0.5 text-sm text-[#94A3B8]">
              {line.transportType} · {line.stopCount} arrêts · {line.vehicleCount}{" "}
              véhicules en ligne
            </p>
          </div>
          <span
            className="regulation-status-badge"
            style={{
              color: lineStatusColor(line.status),
              borderColor: `${lineStatusColor(line.status)}40`,
              backgroundColor: `${lineStatusColor(line.status)}15`,
            }}
          >
            {lineStatusLabel(line.status)}
          </span>
        </div>

        <div className="regulation-line-actions">
          <button type="button" className="regulation-btn-outline">
            <Megaphone className="h-4 w-4" />
            Envoyer une info
          </button>
          <button type="button" className="regulation-btn-outline">
            <ShieldAlert className="h-4 w-4" />
            Déclarer un incident
          </button>
          <button type="button" className="regulation-btn-ghost">
            <MoreHorizontal className="h-4 w-4" />
            Plus d&apos;actions
            <ChevronDown className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>

      <motion.div
        className="regulation-line-stats"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.1 }}
      >
        <Stat label="Ponctualité" value={`${line.punctuality} %`} />
        <Stat
          label="Retard moyen"
          value={`${line.avgDelay > 0 ? "+" : ""}${line.avgDelay} min`}
          accent={line.avgDelay >= 2 ? "#F59E0B" : undefined}
        />
        <Stat
          label="Véhicules en ligne"
          value={`${line.vehicleCount} / ${line.maxVehicles}`}
        />
        <Stat label="Premier départ" value={line.firstDeparture} />
        <Stat label="Dernier départ" value={line.lastDeparture} />
      </motion.div>
    </div>
  );
}

function Stat({
  label,
  value,
  accent,
}: {
  label: string;
  value: string;
  accent?: string;
}) {
  return (
    <div className="regulation-stat">
      <span className="text-[11px] text-[#94A3B8]">{label}</span>
      <span className="text-sm font-semibold" style={{ color: accent ?? "#FFFFFF" }}>
        {value}
      </span>
    </div>
  );
}
