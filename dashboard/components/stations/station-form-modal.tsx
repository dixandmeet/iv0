"use client";

import { useEffect, useId, useState } from "react";
import { AlertTriangle, Info, Loader2, MapPin, X } from "lucide-react";
import type { StationFormPayload, StationStatus } from "@/lib/stations-types";
import { STATION_STATUS_LABELS, stationStatusColor } from "@/lib/stations-types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label, Select } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

interface StationFormModalProps {
  open: boolean;
  onClose: () => void;
  onSubmit: (payload: StationFormPayload) => Promise<void>;
  submitting: boolean;
  communes?: string[];
  error?: string | null;
}

interface FormState {
  name: string;
  description: string;
  commune: string;
  status: StationStatus;
  latitude: string;
  longitude: string;
}

const EMPTY_FORM: FormState = {
  name: "",
  description: "",
  commune: "Nantes",
  status: "active",
  latitude: "",
  longitude: "",
};

const STATION_STATUS_HINTS: Record<StationStatus, string> = {
  active: "Visible et desservie par le réseau voyageur.",
  inactive: "Masquée côté voyageur, conservée pour l'historique.",
  works: "Travaux en cours — affichage adapté sur les plans.",
  relocated: "Emplacement déplacé — mettez à jour les coordonnées.",
};

function toPayload(form: FormState): StationFormPayload {
  const lat = form.latitude.trim() === "" ? null : Number(form.latitude);
  const lng = form.longitude.trim() === "" ? null : Number(form.longitude);
  return {
    name: form.name.trim(),
    description: form.description.trim() || null,
    commune: form.commune.trim() || "Nantes",
    latitude_center: lat != null && Number.isFinite(lat) ? lat : null,
    longitude_center: lng != null && Number.isFinite(lng) ? lng : null,
    status: form.status,
  };
}

export function StationFormModal({
  open,
  onClose,
  onSubmit,
  submitting,
  communes = [],
  error,
}: StationFormModalProps) {
  const communesListId = useId();
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [validationError, setValidationError] = useState<string | null>(null);
  const [geoLoading, setGeoLoading] = useState(false);

  useEffect(() => {
    if (open) {
      setForm(EMPTY_FORM);
      setValidationError(null);
    }
  }, [open]);

  if (!open) return null;

  const displayError = validationError ?? error;
  const statusHint = STATION_STATUS_HINTS[form.status];
  const statusColor = stationStatusColor(form.status);

  const handleGeolocate = () => {
    if (!navigator.geolocation) {
      setValidationError("La géolocalisation n'est pas disponible sur ce navigateur.");
      return;
    }
    setGeoLoading(true);
    setValidationError(null);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setForm((prev) => ({
          ...prev,
          latitude: pos.coords.latitude.toFixed(6),
          longitude: pos.coords.longitude.toFixed(6),
        }));
        setGeoLoading(false);
      },
      () => {
        setValidationError(
          "Impossible d'obtenir votre position. Saisissez les coordonnées manuellement.",
        );
        setGeoLoading(false);
      },
      { enableHighAccuracy: true, timeout: 10000 },
    );
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setValidationError(null);

    if (!form.name.trim()) {
      setValidationError("Le nom de la station est obligatoire.");
      return;
    }

    const lat = form.latitude.trim() === "" ? null : Number(form.latitude);
    const lng = form.longitude.trim() === "" ? null : Number(form.longitude);
    if ((lat != null && !Number.isFinite(lat)) || (lng != null && !Number.isFinite(lng))) {
      setValidationError("Latitude ou longitude invalide.");
      return;
    }
    if ((lat != null) !== (lng != null)) {
      setValidationError("Renseignez la latitude et la longitude, ou laissez les deux vides.");
      return;
    }

    try {
      await onSubmit(toPayload(form));
      onClose();
    } catch {
      // L'erreur serveur est affichée via la propriété error.
    }
  };

  return (
    <div className="stops-modal-overlay" onClick={onClose}>
      <div
        className="stops-modal stops-glass-card max-w-[640px]"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="stops-modal-header">
          <div>
            <h2>Ajouter une station</h2>
            <p className="stops-edit-section-hint mb-0 mt-1">
              Créez un hub regroupant plusieurs arrêts. Les lignes seront associées lors de
              l&apos;ajout des arrêts.
            </p>
          </div>
          <button type="button" onClick={onClose} className="stops-modal-close shrink-0">
            <X className="h-5 w-5" />
          </button>
        </div>

        <form onSubmit={(e) => void handleSubmit(e)} className="stops-form stops-form--modal space-y-5">
          <fieldset className="space-y-3 border-0 p-0">
            <legend className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-400">
              Identité
            </legend>
            <div className="space-y-1.5">
              <Label className="text-slate-300">
                Nom de la station <span className="text-red-400">*</span>
              </Label>
              <Input
                className="station-field"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="Ex. Commerce, Gare du Nord…"
                required
                autoFocus
              />
            </div>
            <div className="space-y-1.5">
              <Label className="text-slate-300">Description</Label>
              <Textarea
                className="station-field min-h-[72px] resize-none"
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                placeholder="Quartier, accès PMR, repère local…"
              />
            </div>
          </fieldset>

          <fieldset className="space-y-3 border-0 p-0">
            <legend className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-400">
              Localisation
            </legend>
            <div className="space-y-1.5">
              <Label className="text-slate-300">Commune</Label>
              <Input
                className="station-field"
                list={communes.length > 0 ? communesListId : undefined}
                value={form.commune}
                onChange={(e) => setForm({ ...form, commune: e.target.value })}
                placeholder="Nantes"
              />
              {communes.length > 0 && (
                <datalist id={communesListId}>
                  {communes.map((c) => (
                    <option key={c} value={c} />
                  ))}
                </datalist>
              )}
            </div>
            <div className="grid gap-3 sm:grid-cols-2">
              <div className="space-y-1.5">
                <Label className="text-slate-300">Latitude</Label>
                <Input
                  className="station-field"
                  value={form.latitude}
                  inputMode="decimal"
                  placeholder="47.2184"
                  onChange={(e) => setForm({ ...form, latitude: e.target.value })}
                />
              </div>
              <div className="space-y-1.5">
                <Label className="text-slate-300">Longitude</Label>
                <Input
                  className="station-field"
                  value={form.longitude}
                  inputMode="decimal"
                  placeholder="-1.5536"
                  onChange={(e) => setForm({ ...form, longitude: e.target.value })}
                />
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                disabled={geoLoading}
                onClick={handleGeolocate}
              >
                {geoLoading ? (
                  <Loader2 className="h-3 w-3 animate-spin" />
                ) : (
                  <MapPin className="h-3 w-3" />
                )}
                Utiliser ma position
              </Button>
            </div>
            <p className="text-xs text-muted-foreground">
              Coordonnées optionnelles — vous pourrez affiner la position sur la carte après création.
            </p>
          </fieldset>

          <fieldset className="space-y-3 border-0 p-0">
            <legend className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-400">
              Statut
            </legend>
            <div className="space-y-1.5">
              <Label className="text-slate-300">État de la station</Label>
              <Select
                className="station-field"
                value={form.status}
                onChange={(e) =>
                  setForm({ ...form, status: e.target.value as StationStatus })
                }
              >
                {(Object.keys(STATION_STATUS_LABELS) as StationStatus[]).map((s) => (
                  <option key={s} value={s}>
                    {STATION_STATUS_LABELS[s]}
                  </option>
                ))}
              </Select>
            </div>
            <div
              className="flex items-start gap-2 rounded-lg border border-border/60 bg-muted/30 px-3 py-2 text-xs text-muted-foreground"
              style={{ borderLeftColor: statusColor, borderLeftWidth: 3 }}
            >
              <span
                className="mt-0.5 inline-block h-2 w-2 shrink-0 rounded-full"
                style={{ backgroundColor: statusColor }}
                aria-hidden
              />
              <span>{statusHint}</span>
            </div>
          </fieldset>

          <div className="flex items-start gap-2 rounded-lg border border-blue-500/20 bg-blue-500/10 px-3 py-2.5 text-xs text-blue-200/90">
            <Info className="mt-0.5 h-3.5 w-3.5 shrink-0" />
            <p>
              Après création, la station apparaîtra dans la liste. Vous pourrez y ajouter des arrêts
              et configurer les lignes depuis le panneau de détail.
            </p>
          </div>

          {displayError && (
            <p className="flex items-center gap-2 text-sm text-red-400">
              <AlertTriangle className="h-4 w-4 shrink-0" />
              {displayError}
            </p>
          )}

          <div className="stops-modal-footer">
            <Button type="button" variant="outline" onClick={onClose} disabled={submitting}>
              Annuler
            </Button>
            <Button type="submit" disabled={submitting || !form.name.trim()}>
              {submitting ? "Création…" : "Créer la station"}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
