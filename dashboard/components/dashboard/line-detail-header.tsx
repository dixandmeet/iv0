"use client";

import { useEffect, useRef, useState } from "react";
import {
  AlertTriangle,
  ChevronDown,
  Map,
  Megaphone,
  MoreHorizontal,
  Pencil,
  RefreshCw,
  ShieldAlert,
  Trash2,
} from "lucide-react";
import { motion } from "framer-motion";
import {
  type RegulationLine,
  lineStatusColor,
  lineStatusLabel,
} from "@/lib/regulation-mock-data";
import type { LineTopology } from "@/lib/line-topology";

interface LineDetailHeaderProps {
  line: RegulationLine;
  topology?: LineTopology | null;
  onOpenEditor?: () => void;
  onEditLineInfo?: () => void;
  onRegenerate?: () => void;
  onDeleteAllStops?: () => void;
  isRegenerating?: boolean;
  regenerationDisabled?: boolean;
}

function lineRouteTitle(line: RegulationLine): string {
  return `${line.origin} ↔ ${line.destination}`;
}

export function LineDetailHeader({
  line,
  topology,
  onOpenEditor,
  onEditLineInfo,
  onRegenerate,
  onDeleteAllStops,
  isRegenerating = false,
  regenerationDisabled = false,
}: LineDetailHeaderProps) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [confirmDeleteOpen, setConfirmDeleteOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!menuOpen) return;

    const handleClick = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setMenuOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [menuOpen]);

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
              {lineRouteTitle(line)}
            </h1>
            <p className="mt-0.5 text-sm text-[#94A3B8]">
              {line.transportType} · {topology?.nodes.length ?? line.stopCount} arrêts · {line.vehicleCount}{" "}
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
          {onRegenerate && (
            <button
              type="button"
              className="regulation-btn-outline regulation-btn-regenerate"
              onClick={onRegenerate}
              disabled={isRegenerating || regenerationDisabled}
              aria-busy={isRegenerating}
              title={
                regenerationDisabled
                  ? "La séquence d’arrêts de référence est indisponible"
                  : "Recalculer les noms des arrêts et le tracé de la ligne"
              }
            >
              <RefreshCw
                className={`h-4 w-4${isRegenerating ? " animate-spin" : ""}`}
              />
              {isRegenerating ? "Régénération…" : "Régénérer la ligne"}
            </button>
          )}
          {onOpenEditor && (
            <button
              type="button"
              className="regulation-btn-outline regulation-btn-editor"
              onClick={onOpenEditor}
            >
              <Map className="h-4 w-4" />
              Éditeur carte
            </button>
          )}
          <button type="button" className="regulation-btn-outline">
            <Megaphone className="h-4 w-4" />
            Envoyer une info
          </button>
          <button type="button" className="regulation-btn-outline">
            <ShieldAlert className="h-4 w-4" />
            Déclarer un incident
          </button>
          <div className="regulation-actions-menu-wrap" ref={menuRef}>
            <button
              type="button"
              className={`regulation-btn-ghost${menuOpen ? " active" : ""}`}
              aria-expanded={menuOpen}
              aria-haspopup="menu"
              onClick={() => setMenuOpen((open) => !open)}
            >
              <MoreHorizontal className="h-4 w-4" />
              Plus d&apos;actions
              <ChevronDown className="h-3.5 w-3.5" />
            </button>
            {menuOpen && (
              <div className="regulation-actions-menu" role="menu">
                {onEditLineInfo && (
                  <button
                    type="button"
                    className="regulation-actions-menu-item"
                    role="menuitem"
                    onClick={() => {
                      setMenuOpen(false);
                      onEditLineInfo();
                    }}
                  >
                    <Pencil className="h-4 w-4" />
                    Modifier les informations
                  </button>
                )}
                {onDeleteAllStops && (
                  <button
                    type="button"
                    className="regulation-actions-menu-item regulation-actions-menu-item--danger"
                    role="menuitem"
                    onClick={() => {
                      setMenuOpen(false);
                      setConfirmDeleteOpen(true);
                    }}
                  >
                    <Trash2 className="h-4 w-4" />
                    Supprimer tous les arrêts
                  </button>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {confirmDeleteOpen && onDeleteAllStops && (
        <div
          className="regulation-line-info-overlay"
          role="presentation"
          onClick={() => setConfirmDeleteOpen(false)}
        >
          <div
            className="regulation-confirm-modal"
            role="alertdialog"
            aria-modal="true"
            aria-labelledby="delete-all-stops-title"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="regulation-confirm-icon" aria-hidden>
              <AlertTriangle className="h-6 w-6" />
            </div>
            <h2 id="delete-all-stops-title" className="regulation-confirm-title">
              Supprimer tous les arrêts ?
            </h2>
            <p className="regulation-confirm-text">
              Les {topology?.nodes.length ?? line.stopCount} arrêts de la ligne{" "}
              {line.shortName} seront retirés. Vous pourrez ensuite reconstruire
              le tracé depuis zéro. Cette action est irréversible.
            </p>
            <div className="regulation-confirm-footer">
              <button
                type="button"
                className="regulation-line-info-btn-secondary"
                onClick={() => setConfirmDeleteOpen(false)}
              >
                Annuler
              </button>
              <button
                type="button"
                className="regulation-confirm-btn-danger"
                onClick={() => {
                  setConfirmDeleteOpen(false);
                  onDeleteAllStops();
                }}
              >
                <Trash2 className="h-4 w-4" />
                Tout supprimer
              </button>
            </div>
          </div>
        </div>
      )}

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
