"use client";

import { useState } from "react";
import { X } from "lucide-react";
import { useMsrResources } from "@/hooks/use-msr-resources";
import { MSR_ZONES } from "@/lib/msr-mock-data";

const TEAM_COLORS = [
  { value: "#3B82F6", label: "Bleu" },
  { value: "#22C55E", label: "Vert" },
  { value: "#F97316", label: "Orange" },
  { value: "#A855F7", label: "Violet" },
  { value: "#EF4444", label: "Rouge" },
  { value: "#06B6D4", label: "Cyan" },
];

interface MsrCreateTeamModalProps {
  open: boolean;
  onClose: () => void;
  onSuccess?: (name: string) => void;
}

export function MsrCreateTeamModal({
  open,
  onClose,
  onSuccess,
}: MsrCreateTeamModalProps) {
  const { addTeam } = useMsrResources();
  const [name, setName] = useState("");
  const [managerName, setManagerName] = useState("");
  const [color, setColor] = useState(TEAM_COLORS[0].value);
  const [zoneId, setZoneId] = useState(MSR_ZONES[0]?.id ?? "");
  const [error, setError] = useState<string | null>(null);

  if (!open) return null;

  function handleClose() {
    setName("");
    setManagerName("");
    setColor(TEAM_COLORS[0].value);
    setZoneId(MSR_ZONES[0]?.id ?? "");
    setError(null);
    onClose();
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const trimmedName = name.trim();
    const trimmedManager = managerName.trim();
    if (trimmedName.length < 2) {
      setError("Le nom de l'équipe doit contenir au moins 2 caractères.");
      return;
    }
    if (trimmedManager.length < 2) {
      setError("Le nom du responsable est requis.");
      return;
    }
    addTeam({
      name: trimmedName,
      managerName: trimmedManager,
      color,
      zoneId: zoneId || undefined,
    });
    onSuccess?.(trimmedName);
    handleClose();
  }

  return (
    <div
      className="msr-modal-overlay"
      role="dialog"
      aria-modal="true"
      aria-labelledby="create-team-title"
      onClick={(e) => e.target === e.currentTarget && handleClose()}
    >
      <div className="msr-modal">
        <div className="msr-modal-header">
          <div>
            <h2 id="create-team-title" className="msr-wizard-title">
              Créer une équipe
            </h2>
            <p className="msr-wizard-subtitle">
              Constituer une nouvelle équipe de patrouille MSR.
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
            <label htmlFor="team-name">Nom de l&apos;équipe</label>
            <input
              id="team-name"
              type="text"
              className="msr-form-input"
              value={name}
              onChange={(e) => {
                setName(e.target.value);
                setError(null);
              }}
              placeholder="Ex. Équipe Est"
              autoFocus
            />
          </div>

          <div className="msr-filter-field">
            <label htmlFor="team-manager">Responsable</label>
            <input
              id="team-manager"
              type="text"
              className="msr-form-input"
              value={managerName}
              onChange={(e) => {
                setManagerName(e.target.value);
                setError(null);
              }}
              placeholder="Ex. Jean Dupont"
            />
          </div>

          <div className="msr-filter-field">
            <label htmlFor="team-zone">Zone d&apos;intervention</label>
            <select
              id="team-zone"
              className="msr-form-input"
              value={zoneId}
              onChange={(e) => setZoneId(e.target.value)}
            >
              {MSR_ZONES.map((zone) => (
                <option key={zone.id} value={zone.id}>
                  {zone.teamName}
                </option>
              ))}
            </select>
          </div>

          <div className="msr-filter-field">
            <span className="msr-form-label">Couleur de l&apos;équipe</span>
            <div className="msr-color-picker">
              {TEAM_COLORS.map((c) => (
                <button
                  key={c.value}
                  type="button"
                  className={`msr-color-swatch${color === c.value ? " msr-color-swatch--selected" : ""}`}
                  style={{ background: c.value }}
                  onClick={() => setColor(c.value)}
                  title={c.label}
                  aria-label={c.label}
                />
              ))}
            </div>
          </div>

          {error && <p className="msr-form-error">{error}</p>}

          <div className="msr-modal-footer">
            <button
              type="button"
              className="msr-btn msr-btn--outline"
              onClick={handleClose}
            >
              Annuler
            </button>
            <button type="submit" className="msr-btn msr-btn--purple">
              Créer l&apos;équipe
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
