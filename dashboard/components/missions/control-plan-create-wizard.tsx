"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  ArrowLeft,
  ArrowRight,
  Check,
  Clock,
  FileCheck,
  Info,
  MapPin,
  Users,
  X,
} from "lucide-react";
import {
  controlPlanFormSchema,
  defaultControlPlanFormValues,
  type ControlPlanFormValues,
} from "@/lib/control-plans/schema";
import { MSR_ZONES } from "@/lib/msr-mock-data";
import { useMsrResources } from "@/hooks/use-msr-resources";

const STEPS = [
  { id: 1, label: "Informations", icon: Info },
  { id: 2, label: "Période", icon: Clock },
  { id: 3, label: "Périmètre", icon: MapPin },
  { id: 4, label: "Ressources", icon: Users },
  { id: 5, label: "Consignes", icon: Check },
  { id: 6, label: "Validation", icon: FileCheck },
];

const AVAILABLE_LINES = ["T1", "T2", "T3", "Bus C3", "Bus C4", "Bus E3", "Bus 12"];
const AVAILABLE_STATIONS = [
  "Commerce",
  "Haluchère",
  "Gare Nord",
  "Beaujoire",
  "Doulon",
  "Gare Maritime",
  "Talensac",
];
const AVAILABLE_VEHICLES = ["Véhicule MSR-01", "Véhicule MSR-02", "Véhicule MSR-03"];

interface ControlPlanCreateWizardProps {
  open: boolean;
  onClose: () => void;
}

export function ControlPlanCreateWizard({
  open,
  onClose,
}: ControlPlanCreateWizardProps) {
  const { agents, teams } = useMsrResources();
  const [step, setStep] = useState(1);

  const form = useForm<ControlPlanFormValues>({
    resolver: zodResolver(controlPlanFormSchema),
    defaultValues: defaultControlPlanFormValues,
    mode: "onChange",
  });

  const values = form.watch();

  if (!open) return null;

  function handleClose() {
    form.reset(defaultControlPlanFormValues);
    setStep(1);
    onClose();
  }

  async function handleNext() {
    const fieldsByStep: (keyof ControlPlanFormValues)[][] = [
      ["name", "description", "objective", "priority"],
      ["start_date", "end_date", "time_slots"],
      ["lines", "stations", "zone_ids"],
      ["team_ids", "agent_ids", "vehicles"],
      ["general_instructions", "specific_instructions"],
      [],
    ];

    const valid = await form.trigger(fieldsByStep[step - 1]);
    if (!valid) return;

    if (step < 6) setStep(step + 1);
    else handleClose();
  }

  function handleBack() {
    if (step > 1) setStep(step - 1);
  }

  function toggleArrayItem(
    field: "lines" | "stations" | "zone_ids" | "team_ids" | "agent_ids" | "vehicles",
    id: string,
  ) {
    const current = form.getValues(field) as string[];
    form.setValue(
      field,
      current.includes(id) ? current.filter((x) => x !== id) : [...current, id],
      { shouldValidate: true },
    );
  }

  const generatedMissions =
    values.auto_generate_missions
      ? values.team_ids.length * values.zone_ids.length * values.time_slots.length
      : 0;

  const conflicts =
    values.team_ids.length > values.agent_ids.length ? 1 : 0;
  const resourceWarnings =
    values.agent_ids.length < values.team_ids.length * 2 ? 1 : 0;

  return (
    <div className="msr-plan-wizard-overlay" role="dialog" aria-modal="true">
      <div className="msr-plan-wizard">
        <div className="msr-plan-wizard-header">
          <div>
            <h2 className="msr-wizard-title">Créer un plan de contrôle</h2>
            <p className="msr-wizard-subtitle">
              Étape {step} sur 6 — {STEPS[step - 1].label}
            </p>
          </div>
          <button type="button" className="msr-detail-close" onClick={handleClose} aria-label="Fermer">
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="msr-wizard-steps msr-plan-wizard-steps">
          {STEPS.map((s) => (
            <div
              key={s.id}
              className={`msr-wizard-step${step === s.id ? " msr-wizard-step--active" : ""}${step > s.id ? " msr-wizard-step--done" : ""}`}
            >
              <div className="msr-wizard-step-icon">
                {step > s.id ? (
                  <Check className="h-3.5 w-3.5" />
                ) : (
                  <s.icon className="h-3.5 w-3.5" />
                )}
              </div>
              <span className="msr-wizard-step-label">{s.label}</span>
            </div>
          ))}
        </div>

        <div className="msr-plan-wizard-body">
          {step === 1 && (
            <div className="msr-plan-wizard-form-grid">
              <Field label="Nom du plan" error={form.formState.errors.name?.message}>
                <input {...form.register("name")} className="msr-form-input" placeholder="Ex. Contrôle rentrée scolaire" />
              </Field>
              <Field label="Objectif" error={form.formState.errors.objective?.message}>
                <input {...form.register("objective")} className="msr-form-input" />
              </Field>
              <Field label="Priorité" className="msr-plan-wizard-full">
                <select {...form.register("priority")} className="msr-form-input">
                  <option value="high">Haute</option>
                  <option value="medium">Moyenne</option>
                  <option value="low">Basse</option>
                </select>
              </Field>
              <Field label="Description" error={form.formState.errors.description?.message} className="msr-plan-wizard-full">
                <textarea {...form.register("description")} className="msr-wizard-textarea" rows={4} />
              </Field>
            </div>
          )}

          {step === 2 && (
            <div className="msr-plan-wizard-form-grid">
              <Field label="Date de début" error={form.formState.errors.start_date?.message}>
                <input type="date" {...form.register("start_date")} className="msr-form-input" />
              </Field>
              <Field label="Date de fin" error={form.formState.errors.end_date?.message}>
                <input type="date" {...form.register("end_date")} className="msr-form-input" />
              </Field>
              <div className="msr-plan-wizard-full">
                <p className="msr-wizard-hint">Créneaux horaires</p>
                {values.time_slots.map((slot, i) => (
                  <div key={i} className="msr-time-slot-row">
                    <input
                      className="msr-form-input"
                      value={slot.label}
                      onChange={(e) => {
                        const slots = [...values.time_slots];
                        slots[i] = { ...slot, label: e.target.value };
                        form.setValue("time_slots", slots);
                      }}
                      placeholder="Libellé"
                    />
                    <input
                      type="time"
                      className="msr-form-input"
                      value={slot.start}
                      onChange={(e) => {
                        const slots = [...values.time_slots];
                        slots[i] = { ...slot, start: e.target.value };
                        form.setValue("time_slots", slots);
                      }}
                    />
                    <input
                      type="time"
                      className="msr-form-input"
                      value={slot.end}
                      onChange={(e) => {
                        const slots = [...values.time_slots];
                        slots[i] = { ...slot, end: e.target.value };
                        form.setValue("time_slots", slots);
                      }}
                    />
                  </div>
                ))}
                <button
                  type="button"
                  className="msr-link-btn"
                  onClick={() =>
                    form.setValue("time_slots", [
                      ...values.time_slots,
                      { label: "Créneau", start: "08:00", end: "12:00" },
                    ])
                  }
                >
                  + Ajouter un créneau
                </button>
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="msr-plan-wizard-form-grid">
              <div className="msr-plan-wizard-full">
                <p className="msr-wizard-hint">Lignes concernées</p>
                <div className="msr-chip-grid">
                  {AVAILABLE_LINES.map((line) => (
                    <Chip
                      key={line}
                      label={line}
                      selected={values.lines.includes(line)}
                      onClick={() => toggleArrayItem("lines", line)}
                    />
                  ))}
                </div>
              </div>
              <div className="msr-plan-wizard-full">
                <p className="msr-wizard-hint">Stations concernées</p>
                <div className="msr-chip-grid">
                  {AVAILABLE_STATIONS.map((st) => (
                    <Chip
                      key={st}
                      label={st}
                      selected={values.stations.includes(st)}
                      onClick={() => toggleArrayItem("stations", st)}
                    />
                  ))}
                </div>
              </div>
              <div className="msr-plan-wizard-full">
                <p className="msr-wizard-hint">Zones d&apos;intervention</p>
                <div className="msr-chip-grid">
                  {MSR_ZONES.map((z) => (
                    <Chip
                      key={z.id}
                      label={z.teamName}
                      selected={values.zone_ids.includes(z.id)}
                      onClick={() => toggleArrayItem("zone_ids", z.id)}
                      color={z.color}
                    />
                  ))}
                </div>
                <div className="msr-wizard-zone-map mt-3" aria-hidden />
              </div>
            </div>
          )}

          {step === 4 && (
            <div className="msr-plan-wizard-form-grid">
              <div className="msr-plan-wizard-full">
                <p className="msr-wizard-hint">Équipes</p>
                <div className="msr-wizard-team-list">
                  {teams.map((team) => (
                    <button
                      key={team.id}
                      type="button"
                      className={`msr-wizard-team-card${values.team_ids.includes(team.id) ? " msr-wizard-team-card--selected" : ""}`}
                      onClick={() => toggleArrayItem("team_ids", team.id)}
                    >
                      <div className="msr-wizard-team-dot" style={{ background: team.color }} />
                      <div className="text-left">
                        <p className="text-sm font-medium text-white">{team.name}</p>
                        <p className="text-xs text-[#64748B]">{team.manager.name}</p>
                      </div>
                    </button>
                  ))}
                </div>
              </div>
              <div className="msr-plan-wizard-full">
                <p className="msr-wizard-hint">Agents</p>
                <div className="msr-wizard-agent-grid">
                  {agents.map((agent) => (
                    <button
                      key={agent.id}
                      type="button"
                      className={`msr-wizard-agent-card${values.agent_ids.includes(agent.id) ? " msr-wizard-agent-card--selected" : ""}`}
                      onClick={() => toggleArrayItem("agent_ids", agent.id)}
                    >
                      <div className="msr-agent-avatar">{agent.initials}</div>
                      <div className="min-w-0 text-left">
                        <p className="text-sm font-medium text-white">{agent.name}</p>
                      </div>
                    </button>
                  ))}
                </div>
              </div>
              <div className="msr-plan-wizard-full">
                <p className="msr-wizard-hint">Véhicules</p>
                <div className="msr-chip-grid">
                  {AVAILABLE_VEHICLES.map((v) => (
                    <Chip
                      key={v}
                      label={v}
                      selected={values.vehicles.includes(v)}
                      onClick={() => toggleArrayItem("vehicles", v)}
                    />
                  ))}
                </div>
              </div>
            </div>
          )}

          {step === 5 && (
            <div className="msr-plan-wizard-form-grid">
              <Field label="Consignes générales" error={form.formState.errors.general_instructions?.message} className="msr-plan-wizard-full">
                <textarea
                  {...form.register("general_instructions")}
                  className="msr-wizard-textarea"
                  rows={5}
                  placeholder="Une consigne par ligne..."
                />
              </Field>
              <Field label="Consignes spécifiques" className="msr-plan-wizard-full">
                <textarea
                  {...form.register("specific_instructions")}
                  className="msr-wizard-textarea"
                  rows={3}
                />
              </Field>
              <label className="msr-auto-gen-toggle msr-plan-wizard-full">
                <input
                  type="checkbox"
                  {...form.register("auto_generate_missions")}
                />
                <span>Génération automatique des missions</span>
                <p className="text-xs text-[#64748B]">
                  Crée les missions selon les équipes, zones et créneaux sélectionnés.
                </p>
              </label>
            </div>
          )}

          {step === 6 && (
            <div className="msr-plan-summary">
              <div className="msr-plan-summary-grid">
                <SummaryCard label="Missions générées" value={String(generatedMissions)} accent="#3B82F6" />
                <SummaryCard label="Agents mobilisés" value={String(values.agent_ids.length)} accent="#22C55E" />
                <SummaryCard label="Zones couvertes" value={String(values.zone_ids.length)} accent="#06B6D4" />
                <SummaryCard label="Lignes" value={String(values.lines.length)} accent="#A855F7" />
              </div>

              <div className="msr-plan-summary-details">
                <h4 className="msr-detail-section-title">Récapitulatif</h4>
                <Row k="Nom" v={values.name || "—"} />
                <Row k="Période" v={`${values.start_date || "—"} → ${values.end_date || "—"}`} />
                <Row k="Équipes" v={values.team_ids.length} />
                <Row k="Créneaux" v={values.time_slots.length} />
              </div>

              {(conflicts > 0 || resourceWarnings > 0) && (
                <div className="msr-plan-alerts">
                  {conflicts > 0 && (
                    <p className="msr-plan-alert msr-plan-alert--warning">
                      Conflits horaires potentiels détectés entre équipes.
                    </p>
                  )}
                  {resourceWarnings > 0 && (
                    <p className="msr-plan-alert msr-plan-alert--danger">
                      Ressources insuffisantes : ratio agents/équipes trop faible.
                    </p>
                  )}
                </div>
              )}

              {values.auto_generate_missions && generatedMissions > 0 && (
                <p className="msr-plan-success">
                  ✓ {generatedMissions} mission(s) seront créées automatiquement à la validation.
                </p>
              )}
            </div>
          )}
        </div>

        <div className="msr-wizard-footer">
          <button
            type="button"
            className="msr-btn msr-btn--outline"
            onClick={handleBack}
            disabled={step === 1}
          >
            <ArrowLeft className="h-4 w-4" />
            Précédent
          </button>
          <button type="button" className="msr-btn msr-btn--primary" onClick={handleNext}>
            {step === 6 ? "Créer le plan" : "Suivant"}
            {step < 6 && <ArrowRight className="h-4 w-4" />}
          </button>
        </div>
      </div>
    </div>
  );
}

function Field({
  label,
  error,
  children,
  className,
}: {
  label: string;
  error?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={className}>
      <label className="msr-form-label">{label}</label>
      {children}
      {error && <p className="msr-form-error">{error}</p>}
    </div>
  );
}

function Chip({
  label,
  selected,
  onClick,
  color,
}: {
  label: string;
  selected: boolean;
  onClick: () => void;
  color?: string;
}) {
  return (
    <button
      type="button"
      className={`msr-chip${selected ? " msr-chip--selected" : ""}`}
      style={
        selected && color
          ? { borderColor: color, background: `${color}22`, color: "#fff" }
          : undefined
      }
      onClick={onClick}
    >
      {label}
    </button>
  );
}

function SummaryCard({
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

function Row({ k, v }: { k: string; v: string | number }) {
  return (
    <div className="msr-detail-row">
      <span className="msr-detail-label">{k}</span>
      <span>{v}</span>
    </div>
  );
}
