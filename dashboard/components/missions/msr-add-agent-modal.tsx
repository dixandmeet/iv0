"use client";

import { useState } from "react";
import { X } from "lucide-react";
import { useMsrResources } from "@/hooks/use-msr-resources";

interface MsrAddAgentModalProps {
  open: boolean;
  onClose: () => void;
  onSuccess?: (name: string) => void;
}

export function MsrAddAgentModal({
  open,
  onClose,
  onSuccess,
}: MsrAddAgentModalProps) {
  const { teams, addAgent } = useMsrResources();
  const [name, setName] = useState("");
  const [teamId, setTeamId] = useState(teams[0]?.id ?? "");
  const [available, setAvailable] = useState(true);
  const [error, setError] = useState<string | null>(null);

  if (!open) return null;

  function handleClose() {
    setName("");
    setTeamId(teams[0]?.id ?? "");
    setAvailable(true);
    setError(null);
    onClose();
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const trimmed = name.trim();
    if (trimmed.length < 2) {
      setError("Le nom doit contenir au moins 2 caractères.");
      return;
    }
    if (!teamId) {
      setError("Sélectionnez une équipe.");
      return;
    }
    addAgent({ name: trimmed, teamId, available });
    onSuccess?.(trimmed);
    handleClose();
  }

  return (
    <div
      className="msr-modal-overlay"
      role="dialog"
      aria-modal="true"
      aria-labelledby="add-agent-title"
      onClick={(e) => e.target === e.currentTarget && handleClose()}
    >
      <div className="msr-modal">
        <div className="msr-modal-header">
          <div>
            <h2 id="add-agent-title" className="msr-wizard-title">
              Ajouter un agent
            </h2>
            <p className="msr-wizard-subtitle">
              Enregistrer un nouvel agent MSR dans le pool opérationnel.
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

        <form onSubmit={handleSubmit} className="msr-modal-body">
          <div className="msr-filter-field">
            <label htmlFor="agent-name">Nom complet</label>
            <input
              id="agent-name"
              type="text"
              className="msr-form-input"
              value={name}
              onChange={(e) => {
                setName(e.target.value);
                setError(null);
              }}
              placeholder="Ex. Pierre Durand"
              autoFocus
            />
          </div>

          <div className="msr-filter-field">
            <label htmlFor="agent-team">Équipe assignée</label>
            <select
              id="agent-team"
              className="msr-form-input"
              value={teamId}
              onChange={(e) => setTeamId(e.target.value)}
            >
              {teams.map((team) => (
                <option key={team.id} value={team.id}>
                  {team.name}
                </option>
              ))}
            </select>
          </div>

          <label className="msr-checkbox-field">
            <input
              type="checkbox"
              checked={available}
              onChange={(e) => setAvailable(e.target.checked)}
            />
            <span>Agent disponible immédiatement</span>
          </label>

          {error && <p className="msr-form-error">{error}</p>}

          <div className="msr-modal-footer">
            <button
              type="button"
              className="msr-btn msr-btn--outline"
              onClick={handleClose}
            >
              Annuler
            </button>
            <button type="submit" className="msr-btn msr-btn--primary">
              Ajouter l&apos;agent
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
