"use client";

import { useMemo, useState } from "react";
import {
  createColumnHelper,
  flexRender,
  getCoreRowModel,
  useReactTable,
} from "@tanstack/react-table";
import { Pencil, X } from "lucide-react";
import type { ControlPlanView } from "@/lib/control-plans/types";
import type { ControlPlanMissionView } from "@/lib/control-plans/types";
import {
  controlPlanPriorityLabel,
  controlPlanStatusColor,
  controlPlanStatusLabel,
  formatPlanPeriod,
} from "@/lib/control-plans/types";
import { displayStatusColor, displayStatusLabel } from "@/lib/msr-mock-data";
import { priorityColor } from "@/lib/msr-mock-data";

type DetailSection = "overview" | "missions" | "metrics";

const missionColumnHelper = createColumnHelper<ControlPlanMissionView>();

interface ControlPlanDetailPanelProps {
  plan: ControlPlanView;
  onClose: () => void;
  onInstructionsChange: (instructions: string[]) => void;
}

export function ControlPlanDetailPanel({
  plan,
  onClose,
  onInstructionsChange,
}: ControlPlanDetailPanelProps) {
  const [section, setSection] = useState<DetailSection>("overview");
  const [instructions, setInstructions] = useState(plan.instructions);
  const [editingInstructions, setEditingInstructions] = useState(false);

  const statusColor = controlPlanStatusColor(plan.status);
  const prioColor = priorityColor(plan.priority);

  const missionColumns = useMemo(
    () => [
      missionColumnHelper.accessor("title", { header: "Mission" }),
      missionColumnHelper.accessor("teamName", { header: "Équipe" }),
      missionColumnHelper.accessor("zoneLabel", { header: "Zone" }),
      missionColumnHelper.accessor("start_time", {
        header: "Horaires",
        cell: (info) => {
          const m = info.row.original;
          const start = new Date(m.start_time).toLocaleTimeString("fr-FR", {
            hour: "2-digit",
            minute: "2-digit",
          });
          const end = new Date(m.end_time).toLocaleTimeString("fr-FR", {
            hour: "2-digit",
            minute: "2-digit",
          });
          return `${start} – ${end}`;
        },
      }),
      missionColumnHelper.accessor("status", {
        header: "Statut",
        cell: (info) => {
          const s = info.getValue();
          const c = displayStatusColor(s);
          return (
            <span style={{ color: c, fontWeight: 600, fontSize: 12 }}>
              {displayStatusLabel(s)}
            </span>
          );
        },
      }),
    ],
    [],
  );

  const missionTable = useReactTable({
    data: plan.missions,
    columns: missionColumns,
    getCoreRowModel: getCoreRowModel(),
  });

  function saveInstructions() {
    onInstructionsChange(instructions);
    setEditingInstructions(false);
  }

  const sections: { id: DetailSection; label: string }[] = [
    { id: "overview", label: "Vue d'ensemble" },
    { id: "missions", label: "Missions" },
    { id: "metrics", label: "Indicateurs" },
  ];

  return (
    <div className="msr-detail-panel msr-plan-detail-panel">
      <div className="msr-detail-header">
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="msr-detail-title">{plan.name}</h2>
            <span
              className="msr-status-badge"
              style={{
                background: `${statusColor}22`,
                color: statusColor,
                borderColor: `${statusColor}44`,
              }}
            >
              {controlPlanStatusLabel(plan.status)}
            </span>
          </div>
        </div>
        <button type="button" className="msr-detail-close" onClick={onClose} aria-label="Fermer">
          <X className="h-4 w-4" />
        </button>
      </div>

      <div className="msr-detail-tabs">
        {sections.map((s) => (
          <button
            key={s.id}
            type="button"
            className={`msr-detail-tab${section === s.id ? " msr-detail-tab--active" : ""}`}
            onClick={() => setSection(s.id)}
          >
            {s.label}
          </button>
        ))}
      </div>

      <div className="msr-detail-scroll">
        {section === "overview" && (
          <>
            <Section title="Informations générales">
              <Row label="Nom" value={plan.name} />
              <p className="msr-detail-text">{plan.description}</p>
              <Row label="Objectif" value={plan.objective} />
              <Row
                label="Priorité"
                value={
                  <span style={{ color: prioColor }}>
                    ● {controlPlanPriorityLabel(plan.priority)}
                  </span>
                }
              />
              <Row label="Responsable" value={plan.manager} />
              <Row
                label="Statut"
                value={
                  <span style={{ color: statusColor }}>
                    {controlPlanStatusLabel(plan.status)}
                  </span>
                }
              />
            </Section>

            <Section title="Période">
              <Row label="Début" value={new Date(plan.start_date).toLocaleDateString("fr-FR")} />
              <Row label="Fin" value={new Date(plan.end_date).toLocaleDateString("fr-FR")} />
              <Row label="Durée" value={formatPlanPeriod(plan.start_date, plan.end_date)} />
              <div className="msr-time-slots">
                {plan.timeSlots.map((slot) => (
                  <span key={`${slot.label}-${slot.start}`} className="msr-time-slot-chip">
                    {slot.label} : {slot.start} – {slot.end}
                  </span>
                ))}
              </div>
            </Section>

            <Section title="Périmètre">
              <Row label="Réseaux" value={plan.networks.join(", ")} />
              <Row label="Lignes" value={plan.lines.join(", ")} />
              <Row label="Stations" value={plan.stations.join(", ")} />
              <Row label="Zones" value={plan.zoneLabels.join(", ")} />
            </Section>

            <Section title="Ressources">
              <Row label="Équipes" value={String(plan.teamCount)} />
              <Row label="Agents" value={String(plan.agentCount)} />
              <Row label="Véhicules" value={plan.vehicles.join(", ") || "—"} />
              <Row label="Équipements" value={plan.equipment.join(", ")} />
            </Section>

            <Section
              title="Consignes générales"
              action={
                <button
                  type="button"
                  className="msr-icon-btn"
                  onClick={() => setEditingInstructions((v) => !v)}
                  aria-label="Modifier les consignes"
                >
                  <Pencil className="h-3.5 w-3.5" />
                </button>
              }
            >
              {editingInstructions ? (
                <div className="msr-instructions-edit">
                  <textarea
                    className="msr-wizard-textarea"
                    rows={5}
                    value={instructions.join("\n")}
                    onChange={(e) =>
                      setInstructions(
                        e.target.value.split("\n").filter((l) => l.trim()),
                      )
                    }
                  />
                  <button
                    type="button"
                    className="msr-btn msr-btn--primary msr-btn--sm"
                    onClick={saveInstructions}
                  >
                    Enregistrer
                  </button>
                </div>
              ) : (
                <ul className="msr-instructions-list">
                  {instructions.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              )}
            </Section>
          </>
        )}

        {section === "missions" && (
          <Section title="Missions générées">
            {plan.missions.length === 0 ? (
              <p className="msr-detail-text">Aucune mission générée pour ce plan.</p>
            ) : (
              <div className="msr-plan-missions-table-wrap">
                <table className="msr-plan-missions-table">
                  <thead>
                    {missionTable.getHeaderGroups().map((hg) => (
                      <tr key={hg.id}>
                        {hg.headers.map((h) => (
                          <th key={h.id}>
                            {flexRender(h.column.columnDef.header, h.getContext())}
                          </th>
                        ))}
                      </tr>
                    ))}
                  </thead>
                  <tbody>
                    {missionTable.getRowModel().rows.map((row) => (
                      <tr key={row.id}>
                        {row.getVisibleCells().map((cell) => (
                          <td key={cell.id}>
                            {flexRender(cell.column.columnDef.cell, cell.getContext())}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Section>
        )}

        {section === "metrics" && (
          <Section title="Indicateurs de suivi">
            <div className="msr-plan-metrics-grid">
              <MetricCard
                label="Taux de couverture"
                value={`${plan.metrics.coverageRate}%`}
                accent="#3B82F6"
              />
              <MetricCard
                label="Incidents remontés"
                value={String(plan.metrics.incidentsReported)}
                accent="#F97316"
              />
              <MetricCard
                label="Taux de réalisation"
                value={`${plan.metrics.completionRate}%`}
                accent="#22C55E"
              />
              <MetricCard
                label="Agents actifs"
                value={String(plan.metrics.activeAgents)}
                accent="#A855F7"
              />
            </div>
          </Section>
        )}
      </div>
    </div>
  );
}

function Section({
  title,
  children,
  action,
}: {
  title: string;
  children: React.ReactNode;
  action?: React.ReactNode;
}) {
  return (
    <section className="msr-detail-section">
      <div className="msr-detail-section-header">
        <h3 className="msr-detail-section-title">{title}</h3>
        {action}
      </div>
      {children}
    </section>
  );
}

function Row({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  return (
    <div className="msr-detail-row">
      <span className="msr-detail-label">{label}</span>
      <span>{value}</span>
    </div>
  );
}

function MetricCard({
  label,
  value,
  accent,
}: {
  label: string;
  value: string;
  accent: string;
}) {
  return (
    <div className="msr-plan-metric-card" style={{ borderColor: `${accent}44` }}>
      <p className="msr-plan-metric-value" style={{ color: accent }}>
        {value}
      </p>
      <p className="msr-plan-metric-label">{label}</p>
    </div>
  );
}
