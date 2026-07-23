"use client";

import { useEffect, useId, useState } from "react";
import {
  ArrowLeftRight,
  Bus,
  Save,
  Ship,
  TrainFront,
  X,
} from "lucide-react";
import {
  ADD_LINE_DEPOT_OPTIONS,
  isCustomRegulationLine,
  lineToInfoInput,
  type NewLineInput,
} from "@/lib/regulation-custom-line";
import {
  NETWORK_MODE_LABELS,
  type NetworkMode,
  type RegulationLine,
} from "@/lib/regulation-mock-data";
import { useNetwork } from "@/components/network/network-provider";
import { createClient } from "@/lib/supabase/client";

interface LineInfoEditModalProps {
  open: boolean;
  line: RegulationLine | null;
  onClose: () => void;
  onSubmit: (input: NewLineInput) => void;
}

const NETWORK_OPTIONS: Array<{
  value: NetworkMode;
  label: string;
  icon: typeof Bus;
}> = [
  { value: "bus", label: NETWORK_MODE_LABELS.bus, icon: Bus },
  { value: "tram", label: NETWORK_MODE_LABELS.tram, icon: TrainFront },
  { value: "boat", label: NETWORK_MODE_LABELS.boat, icon: Ship },
];

export function LineInfoEditModal({
  open,
  line,
  onClose,
  onSubmit,
}: LineInfoEditModalProps) {
  const { network, isPilotNetwork } = useNetwork();
  const formId = useId();
  const [shortName, setShortName] = useState("");
  const [origin, setOrigin] = useState("");
  const [destination, setDestination] = useState("");
  const [transportType, setTransportType] = useState<NetworkMode>("bus");
  const [depotCode, setDepotCode] = useState("BLX");
  const [depotOptions, setDepotOptions] = useState(ADD_LINE_DEPOT_OPTIONS);

  useEffect(() => {
    if (isPilotNetwork) {
      setDepotOptions(ADD_LINE_DEPOT_OPTIONS);
      return;
    }
    const supabase = createClient();
    void supabase.from("network_depots").select("code, name").eq("network_id", network.id).order("name").then(({ data }) => {
      const options = (data ?? []).map((depot) => ({ code: depot.code as string, label: depot.name as string }));
      setDepotOptions(options.length ? options : [{ code: "NETWORK", label: network.name }]);
    });
  }, [isPilotNetwork, network.id, network.name]);

  useEffect(() => {
    if (!open || !line) return;
    const input = lineToInfoInput(line);
    setShortName(input.shortName);
    setOrigin(input.origin);
    setDestination(input.destination);
    setTransportType(input.transportType);
    setDepotCode(input.depotCode);
  }, [open, line]);

  useEffect(() => {
    if (!open) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [open, onClose]);

  if (!open || !line) return null;

  const canSubmit =
    shortName.trim().length > 0 &&
    origin.trim().length > 0 &&
    destination.trim().length > 0;

  const previewOrigin = origin.trim() || "Origine";
  const previewDestination = destination.trim() || "Destination";

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    if (!canSubmit) return;
    onSubmit({
      shortName: shortName.trim(),
      origin: origin.trim(),
      destination: destination.trim(),
      transportType,
      depotCode,
    });
    onClose();
  };

  return (
    <div
      className="regulation-line-info-overlay"
      onClick={onClose}
      role="presentation"
    >
      <div
        className="regulation-line-info-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby={`${formId}-title`}
        onClick={(event) => event.stopPropagation()}
      >
        <div className="regulation-line-info-header">
          <div className="regulation-line-info-header-top">
            <div className="regulation-line-info-preview">
              <span
                className="regulation-line-info-badge"
                style={{ backgroundColor: line.lineColor }}
              >
                {shortName.trim() || line.shortName}
              </span>
              <div className="regulation-line-info-preview-text">
                <h2 id={`${formId}-title`}>Modifier les informations</h2>
                <p>
                  {previewOrigin} ↔ {previewDestination}
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={onClose}
              className="regulation-line-info-close"
              aria-label="Fermer"
            >
              <X className="h-5 w-5" />
            </button>
          </div>
          {!isCustomRegulationLine(line.id) && (
            <p className="regulation-line-info-notice">
              Les changements sont enregistrés localement sur ce poste et ne
              modifient pas les données GTFS du réseau.
            </p>
          )}
        </div>

        <form
          id={formId}
          onSubmit={handleSubmit}
          className="regulation-line-info-form"
        >
          <section className="regulation-line-info-section">
            <div className="regulation-line-info-row">
              <Field label="N° de ligne" htmlFor={`${formId}-shortName`}>
                <input
                  id={`${formId}-shortName`}
                  type="text"
                  className="regulation-line-info-input regulation-line-info-input--short"
                  placeholder="Ex. 10"
                  value={shortName}
                  onChange={(event) => setShortName(event.target.value)}
                  autoFocus
                />
              </Field>

              <Field label="Réseau">
                <div
                  className="regulation-line-info-segments"
                  role="radiogroup"
                  aria-label="Réseau"
                >
                  {NETWORK_OPTIONS.map(({ value, label, icon: Icon }) => (
                    <button
                      key={value}
                      type="button"
                      role="radio"
                      aria-checked={transportType === value}
                      className={`regulation-line-info-segment${transportType === value ? " active" : ""}`}
                      onClick={() => setTransportType(value)}
                    >
                      <Icon className="h-4 w-4" />
                      {label}
                    </button>
                  ))}
                </div>
              </Field>
            </div>
          </section>

          <section className="regulation-line-info-section">
            <p className="regulation-line-info-section-title">Itinéraire</p>
            <div className="regulation-line-info-direction">
              <Field label="Origine" htmlFor={`${formId}-origin`}>
                <input
                  id={`${formId}-origin`}
                  type="text"
                  className="regulation-line-info-input"
                  placeholder="Terminus de départ"
                  value={origin}
                  onChange={(event) => setOrigin(event.target.value)}
                />
              </Field>
              <div className="regulation-line-info-direction-icon" aria-hidden>
                <ArrowLeftRight className="h-4 w-4" />
              </div>
              <Field label="Destination" htmlFor={`${formId}-destination`}>
                <input
                  id={`${formId}-destination`}
                  type="text"
                  className="regulation-line-info-input"
                  placeholder="Terminus d'arrivée"
                  value={destination}
                  onChange={(event) => setDestination(event.target.value)}
                />
              </Field>
            </div>
          </section>

          <section className="regulation-line-info-section">
            <Field label="Dépôt d'affectation">
              <div
                className="regulation-line-info-depot-grid"
                role="radiogroup"
                aria-label="Dépôt d'affectation"
              >
                {depotOptions.map((depot) => (
                  <button
                    key={depot.code}
                    type="button"
                    role="radio"
                    aria-checked={depotCode === depot.code}
                    className={`regulation-line-info-depot${depotCode === depot.code ? " active" : ""}`}
                    onClick={() => setDepotCode(depot.code)}
                  >
                    {depot.label}
                  </button>
                ))}
              </div>
            </Field>
          </section>

          <footer className="regulation-line-info-footer">
            <button
              type="button"
              className="regulation-line-info-btn-secondary"
              onClick={onClose}
            >
              Annuler
            </button>
            <button
              type="submit"
              className="regulation-line-info-btn-primary"
              disabled={!canSubmit}
            >
              <Save className="h-4 w-4" />
              Enregistrer
            </button>
          </footer>
        </form>
      </div>
    </div>
  );
}

function Field({
  label,
  htmlFor,
  children,
}: {
  label: string;
  htmlFor?: string;
  children: React.ReactNode;
}) {
  const className = "regulation-line-info-field";

  if (htmlFor) {
    return (
      <label className={className} htmlFor={htmlFor}>
        <span className="regulation-line-info-label">{label}</span>
        {children}
      </label>
    );
  }

  return (
    <div className={className}>
      <span className="regulation-line-info-label">{label}</span>
      {children}
    </div>
  );
}
