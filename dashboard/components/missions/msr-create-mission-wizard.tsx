"use client";

import { useState } from "react";
import {
  ArrowLeft,
  ArrowRight,
  Check,
  Clock,
  MapPin,
  Users,
  UsersRound,
  X,
} from "lucide-react";
import {
  type MsrAgent,
  type MsrTeam,
} from "@/lib/msr-mock-data";
import { useMsrResources } from "@/hooks/use-msr-resources";

const STEPS = [
  { id: 1, label: "Agents", icon: Users },
  { id: 2, label: "Équipe", icon: UsersRound },
  { id: 3, label: "Zone", icon: MapPin },
  { id: 4, label: "Consignes", icon: Check },
  { id: 5, label: "Horaires", icon: Clock },
];

interface MsrCreateMissionWizardProps {
  open: boolean;
  onClose: () => void;
}

export function MsrCreateMissionWizard({
  open,
  onClose,
}: MsrCreateMissionWizardProps) {
  const { agents, teams } = useMsrResources();
  const [step, setStep] = useState(1);
  const [selectedAgents, setSelectedAgents] = useState<string[]>([]);
  const [teamMode, setTeamMode] = useState<"existing" | "new">("existing");
  const [selectedTeam, setSelectedTeam] = useState(teams[0]?.id ?? "");
  const [newTeamName, setNewTeamName] = useState("");
  const [instructions, setInstructions] = useState("");
  const [startTime, setStartTime] = useState("07:00");
  const [endTime, setEndTime] = useState("11:00");

  if (!open) return null;

  function toggleAgent(id: string) {
    setSelectedAgents((prev) =>
      prev.includes(id) ? prev.filter((a) => a !== id) : [...prev, id],
    );
  }

  function handleClose() {
    setStep(1);
    setSelectedAgents([]);
    setTeamMode("existing");
    setSelectedTeam(teams[0]?.id ?? "");
    setNewTeamName("");
    setInstructions("");
    setStartTime("07:00");
    setEndTime("11:00");
    onClose();
  }

  function handleNext() {
    if (step < 5) setStep(step + 1);
    else handleClose();
  }

  function handleBack() {
    if (step > 1) setStep(step - 1);
  }

  return (
    <div className="msr-wizard-overlay" role="dialog" aria-modal="true">
      <div className="msr-wizard">
        <div className="msr-wizard-header">
          <div>
            <h2 className="msr-wizard-title">Nouvelle mission</h2>
            <p className="msr-wizard-subtitle">
              Étape {step} sur 5 — {STEPS[step - 1].label}
            </p>
          </div>
          <button
            type="button"
            className="msr-detail-close"
            onClick={handleClose}
            aria-label="Fermer"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="msr-wizard-steps">
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

        <div className="msr-wizard-body">
          {step === 1 && (
            <AgentStep
              agents={agents}
              selected={selectedAgents}
              onToggle={toggleAgent}
            />
          )}
          {step === 2 && (
            <TeamStep
              teams={teams}
              mode={teamMode}
              onModeChange={setTeamMode}
              selectedTeam={selectedTeam}
              onTeamChange={setSelectedTeam}
              newTeamName={newTeamName}
              onNewTeamNameChange={setNewTeamName}
            />
          )}
          {step === 3 && <ZoneStep />}
          {step === 4 && (
            <InstructionsStep
              value={instructions}
              onChange={setInstructions}
            />
          )}
          {step === 5 && (
            <ScheduleStep
              startTime={startTime}
              endTime={endTime}
              onStartChange={setStartTime}
              onEndChange={setEndTime}
            />
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
          <button
            type="button"
            className="msr-btn msr-btn--primary"
            onClick={handleNext}
          >
            {step === 5 ? "Créer la mission" : "Suivant"}
            {step < 5 && <ArrowRight className="h-4 w-4" />}
          </button>
        </div>
      </div>
    </div>
  );
}

function AgentStep({
  agents,
  selected,
  onToggle,
}: {
  agents: MsrAgent[];
  selected: string[];
  onToggle: (id: string) => void;
}) {
  return (
    <div>
      <p className="msr-wizard-hint">
        Sélectionnez les agents à affecter à cette mission.
      </p>
      <div className="msr-wizard-agent-grid">
        {agents.map((agent) => {
          const isSelected = selected.includes(agent.id);
          return (
            <button
              key={agent.id}
              type="button"
              className={`msr-wizard-agent-card${isSelected ? " msr-wizard-agent-card--selected" : ""}`}
              onClick={() => onToggle(agent.id)}
            >
              <div className="msr-agent-avatar">{agent.initials}</div>
              <div className="min-w-0 text-left">
                <p className="text-sm font-medium text-white">{agent.name}</p>
                <p className="text-xs text-[#64748B]">
                  {agent.available ? "Disponible" : "Indisponible"}
                </p>
              </div>
              {isSelected && <Check className="msr-wizard-check h-4 w-4" />}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function TeamStep({
  teams,
  mode,
  onModeChange,
  selectedTeam,
  onTeamChange,
  newTeamName,
  onNewTeamNameChange,
}: {
  teams: MsrTeam[];
  mode: "existing" | "new";
  onModeChange: (m: "existing" | "new") => void;
  selectedTeam: string;
  onTeamChange: (id: string) => void;
  newTeamName: string;
  onNewTeamNameChange: (v: string) => void;
}) {
  return (
    <div>
      <div className="msr-wizard-toggle">
        <button
          type="button"
          className={mode === "existing" ? "active" : ""}
          onClick={() => onModeChange("existing")}
        >
          Équipe existante
        </button>
        <button
          type="button"
          className={mode === "new" ? "active" : ""}
          onClick={() => onModeChange("new")}
        >
          Nouvelle équipe
        </button>
      </div>
      {mode === "existing" ? (
        <div className="msr-wizard-team-list">
          {teams.map((team) => (
            <button
              key={team.id}
              type="button"
              className={`msr-wizard-team-card${selectedTeam === team.id ? " msr-wizard-team-card--selected" : ""}`}
              onClick={() => onTeamChange(team.id)}
            >
              <div
                className="msr-wizard-team-dot"
                style={{ background: team.color }}
              />
              <div className="text-left">
                <p className="text-sm font-medium text-white">{team.name}</p>
                <p className="text-xs text-[#64748B]">
                  Responsable : {team.manager.name}
                </p>
              </div>
            </button>
          ))}
        </div>
      ) : (
        <div className="msr-filter-field">
          <label htmlFor="new-team-name">Nom de l&apos;équipe</label>
          <input
            id="new-team-name"
            type="text"
            value={newTeamName}
            onChange={(e) => onNewTeamNameChange(e.target.value)}
            placeholder="Ex. Équipe Est"
          />
        </div>
      )}
    </div>
  );
}

function ZoneStep() {
  return (
    <div>
      <p className="msr-wizard-hint">
        Définissez la zone d&apos;intervention sur la carte. Cliquez pour placer
        les sommets du polygone.
      </p>
      <div className="msr-wizard-zone-map" aria-hidden />
      <p className="mt-3 text-xs text-[#64748B]">
        Zone sélectionnée : Commerce → Haluchère (T1)
      </p>
    </div>
  );
}

function InstructionsStep({
  value,
  onChange,
}: {
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div>
      <p className="msr-wizard-hint">
        Ajoutez les consignes opérationnelles pour les agents.
      </p>
      <textarea
        className="msr-wizard-textarea"
        rows={6}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder="- Renforcer la présence sur les quais&#10;- Vérifier la fluidité des correspondances"
      />
    </div>
  );
}

function ScheduleStep({
  startTime,
  endTime,
  onStartChange,
  onEndChange,
}: {
  startTime: string;
  endTime: string;
  onStartChange: (v: string) => void;
  onEndChange: (v: string) => void;
}) {
  return (
    <div className="msr-wizard-schedule">
      <div className="msr-filter-field">
        <label htmlFor="mission-start">Heure de début</label>
        <input
          id="mission-start"
          type="time"
          value={startTime}
          onChange={(e) => onStartChange(e.target.value)}
        />
      </div>
      <div className="msr-filter-field">
        <label htmlFor="mission-end">Heure de fin</label>
        <input
          id="mission-end"
          type="time"
          value={endTime}
          onChange={(e) => onEndChange(e.target.value)}
        />
      </div>
    </div>
  );
}
